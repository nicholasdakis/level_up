import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'poi.dart';
import '../user/user_data_manager.dart' show getIdToken, backendBaseUrl;

class POIService {
  // SharedPreferences keys for storing cached data
  static const String _poisKey = 'cached_pois'; // the cached list of POIs
  static const String _cachedLatKey =
      'cached_poi_lat'; // latitude of the last fetch location
  static const String _cachedLngKey =
      'cached_poi_lng'; // longitude of the last fetch location
  static const String _visitedKey =
      'visited_pois'; // map of POI names to their last visit timestamp

  // How far the user must move (in meters) before fresh POIs are fetched
  static const double _refreshDistance = 250;

  // SharedPreferencesAsync instance for persistent local storage
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // Fetch nearby POIs, using the cache if the user hasn't moved far
  Future<List<POI>> getNearbyPOIs(double lat, double lng) async {
    // Check if a valid cache exists for this area
    final cached = await _getCachedPOIs(lat, lng);
    if (cached != null) {
      return cached; // cache is still valid, no need to hit the backend
    }

    // Cache is stale or empty, fetch fresh data from the backend
    final fresh = await _fetchFromBackend(lat, lng);

    // Save the fresh results and the fetch location
    await _cachePOIs(fresh, lat, lng);

    return fresh;
  }

  // Check if cached POIs exist and if the user is still close enough to use them
  Future<List<POI>?> _getCachedPOIs(double lat, double lng) async {
    final raw = await _prefs.getString(_poisKey); // get the cached JSON string
    if (raw == null) return null; // no cache exists yet

    // Get the location of the last fetch
    final cachedLat = await _prefs.getDouble(_cachedLatKey);
    final cachedLng = await _prefs.getDouble(_cachedLngKey);
    if (cachedLat == null || cachedLng == null) {
      return null; // no cached location
    }

    // Calculate how far the user has moved since the last fetch
    final distance = haversine(lat, lng, cachedLat, cachedLng);
    if (distance > _refreshDistance) {
      return null; // user moved too far, cache is stale
    }

    // Cache is valid, decode the JSON into POI objects
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((item) => POI.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Save POIs and the fetch location to SharedPreferences
  Future<void> _cachePOIs(List<POI> pois, double lat, double lng) async {
    // Convert the list of POIs to JSON and store it
    final jsonList = pois.map((poi) => poi.toJson()).toList();
    await _prefs.setString(_poisKey, jsonEncode(jsonList));

    // Store the fetch location so distance can be compared later
    await _prefs.setDouble(_cachedLatKey, lat);
    await _prefs.setDouble(_cachedLngKey, lng);
  }

  // Call the backend endpoint to get POIs from Overpass
  Future<List<POI>> _fetchFromBackend(double lat, double lng) async {
    final token = await getIdToken();

    // POST to the backend with the user's coordinates and auth token
    final response = await http
        .post(
          Uri.parse('$backendBaseUrl/get_nearby_pois'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': token, 'lat': lat, 'lng': lng}),
        )
        .timeout(
          const Duration(seconds: 20),
        ); // longer timeout since Overpass can be slow

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch POIs: ${response.statusCode}');
    }

    // Parse the response JSON into POI objects
    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic> poisJson =
        data['pois']; // backend returns { "pois": [...] }
    return poisJson
        .map((item) => POI.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Haversine formula calculation (same as backend)
  double haversine(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c =
        2 * atan2(sqrt(a), sqrt(1 - a)); // convert angular distance to radians
    return earthRadius * c; // multiply by Earth's radius to get meters
  }

  // Method to convert degrees to radians for trig functions in the Haversine formula
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Method to send a check-in request to the backend for a specific POI
  Future<Map<String, dynamic>> checkInPOI(
    POI poi,
    double userLat,
    double userLng,
  ) async {
    final token = await getIdToken();

    // POST to the check-in endpoint with both the POI and user coordinates
    final response = await http
        .post(
          Uri.parse('$backendBaseUrl/check_in_poi'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_token': token,
            'poi_name': poi.name,
            'poi_lat': poi.lat,
            'poi_lng': poi.lng,
            'user_lat': userLat,
            'user_lng': userLng,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final result = jsonDecode(response.body) as Map<String, dynamic>;

    // If successful, also mark as visited locally so the UI updates without waiting for next fetch
    if (result['success'] == true) {
      await markVisited(poi.name);
    }

    return result;
  }

  // Find the closest POI to the user that hasn't been visited in 24 hours
  // Returns null if no unvisited POI is within the given radius
  Future<POI?> getClosestCheckInPOI(
    List<POI> pois,
    double userLat,
    double userLng,
    double maxDistance,
  ) async {
    POI? closest;
    double closestDistance =
        maxDistance; // start at the max, only keep closer ones

    for (final poi in pois) {
      // Skip POIs that were already visited today
      final visited = await isVisitedRecently(poi.name);
      if (visited) continue;

      // Calculate how far this POI is from the user
      final distance = haversine(userLat, userLng, poi.lat, poi.lng);
      if (distance < closestDistance) {
        closest = poi; // closest POI found so far
        closestDistance = distance;
      }
    }
    return closest;
  }

  // Mark a POI as visited right now (stores the current timestamp)
  Future<void> markVisited(String poiName) async {
    final visited = await _getVisitedMap(); // load the current visited map
    visited[poiName] = DateTime.now()
        .millisecondsSinceEpoch; // store current time as milliseconds
    await _prefs.setString(
      _visitedKey,
      jsonEncode(visited),
    ); // save back to storage
  }

  // Check if a POI was visited in the last 24 hours
  Future<bool> isVisitedRecently(String poiName) async {
    final visited = await _getVisitedMap();
    final lastVisit = visited[poiName]; // get the timestamp of the last visit
    if (lastVisit == null) return false; // never visited

    // Calculate how long ago the visit was
    final visitTime = DateTime.fromMillisecondsSinceEpoch(lastVisit);
    final hoursSince = DateTime.now().difference(visitTime).inHours;
    return hoursSince < 24; // true if visited less than 24 hours ago
  }

  // Load the visited POIs map from SharedPreferences
  // Returns a map of POI name to the timestamp (in milliseconds) of the last visit
  Future<Map<String, int>> _getVisitedMap() async {
    final raw = await _prefs.getString(_visitedKey);
    if (raw == null) return {}; // no visits recorded yet

    // Decode the JSON string into a Map<String, dynamic> then cast values to int
    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map((key, value) => MapEntry(key, value as int));
  }

  // Remove visit records older than 24 hours to prevent storage from growing infinitely
  Future<void> cleanupOldVisits() async {
    final visited = await _getVisitedMap();
    final now = DateTime.now().millisecondsSinceEpoch;
    const oneDayMs = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

    // Remove entries where the visit was more than 24 hours ago
    visited.removeWhere((name, timestamp) => (now - timestamp) > oneDayMs);
    await _prefs.setString(
      _visitedKey,
      jsonEncode(visited),
    ); // save the cleaned map
  }
}

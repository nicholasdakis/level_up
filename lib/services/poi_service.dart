import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/poi.dart';
import '../utility/shared_preferences/shared_prefs_async.dart';
import 'user_data_manager.dart' show getIdToken, backendBaseUrl;

// Error code thrown when the backend rejects a POI fetch because the user is moving too fast
const String movingTooFastCode = 'moving_too_fast';

class POIService {
  // How far the user must move (in meters) before fresh POIs are fetched
  static const double _refreshDistance = 250;

  // Centralized cache wrapper for SharedPreferences
  final SharedPrefsService _prefs = SharedPrefsService();

  // Fetch nearby POIs, using the cache if the user hasn't moved far
  // If the cache is not full, a background fetch fills in the rest
  Future<List<POI>> getNearbyPOIs(
    double lat,
    double lng, {
    void Function(List<POI>)?
    onSupplement, // callback function for updating the UI
    void Function()? onFillStart, // called when a background fill begins
  }) async {
    // Check if a valid cache exists for this area
    final cached = await _getCachedPOIs(lat, lng);
    if (cached != null) {
      // Cache is valid but not filled
      if (onSupplement != null) {
        onFillStart?.call(); // notify the UI that a fill is starting
        _fillCache(lat, lng, cached)
            .then((filled) {
              onSupplement(
                filled ?? cached,
              ); // send the result back to the callback function
            })
            .catchError((_) {
              onSupplement(cached); // clear the filling indicator on error
            });
      }
      return cached;
    }

    // Cache is stale or empty, fetch fresh data from the backend
    final fresh = await _fetchFromBackend(lat, lng);

    // Save the fresh results and the fetch location
    await _prefsPOIs(fresh, lat, lng);

    // if (fresh.length > 5) return fresh.sublist(0, 5); // line for testing unfilled cache

    return fresh;
  }

  // Method to fill the cache with backend POIs if the cache is not filled already
  // Returns null if nothing new was added
  Future<List<POI>?> _fillCache(
    double lat,
    double lng,
    List<POI> cached,
  ) async {
    final fresh = await _fetchFromBackend(lat, lng);

    // Cache already has as many as the backend would return
    if (cached.length >= fresh.length) return null;

    // Start with cached POIs, then add all fresh ones
    final combined = List<POI>.from(cached);
    combined.addAll(fresh);

    // Remove duplicates using name and rounded coordinates (in case two places with a similar location share a name)
    final seen = <String>{};
    final result = <POI>[];
    for (final poi in combined) {
      final key =
          '${poi.name},${poi.lat.toStringAsFixed(5)},${poi.lng.toStringAsFixed(5)}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(poi);
      }
    }

    // Nothing new was added
    if (result.length == cached.length) return null;

    await _prefsPOIs(result, lat, lng);
    return result;
  }

  // Check if cached POIs exist and if the user is still close enough to use them
  Future<List<POI>?> _getCachedPOIs(double lat, double lng) async {
    final raw = await _prefs.getString(
      SharedPreferencesKey.cachedPois,
    ); // get the cached JSON string
    if (raw == null) return null; // no cache exists yet

    // Get the location of the last fetch
    final cachedLat = await _prefs.getDouble(SharedPreferencesKey.cachedPoiLat);
    final cachedLng = await _prefs.getDouble(SharedPreferencesKey.cachedPoiLng);
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
  Future<void> _prefsPOIs(List<POI> pois, double lat, double lng) async {
    // Convert the list of POIs to JSON and store it
    final jsonList = pois.map((poi) => poi.toJson()).toList();
    await _prefs.setString(
      SharedPreferencesKey.cachedPois,
      jsonEncode(jsonList),
    );

    // Store the fetch location so distance can be compared later
    await _prefs.setDouble(SharedPreferencesKey.cachedPoiLat, lat);
    await _prefs.setDouble(SharedPreferencesKey.cachedPoiLng, lng);
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

    // Backend flagged this request as too fast between fetches
    if (response.statusCode == 429) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['code'] == movingTooFastCode) {
        throw Exception(movingTooFastCode);
      }
    }

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
      SharedPreferencesKey.visitedPois,
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
    final raw = await _prefs.getString(SharedPreferencesKey.visitedPois);
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
      SharedPreferencesKey.visitedPois,
      jsonEncode(visited),
    ); // save the cleaned map
  }
}

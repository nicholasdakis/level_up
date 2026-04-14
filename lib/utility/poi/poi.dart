// Model class representing a single Point of Interest from the Overpass API
class POI {
  final String name; // display name of the place (e.g. "Starbucks")
  final double lat; // latitude coordinate
  final double lng; // longitude coordinate
  final String category; // type of place (e.g. "cafe", "park", "gym")

  POI({
    required this.name,
    required this.lat,
    required this.lng,
    required this.category,
  });

  // Formatted category for display (e.g. "fast_food" becomes "Fast Food")
  String get displayCategory => category
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  // Create a POI from a JSON map (used when parsing the backend response)
  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      name: json['name'] as String,
      lat: (json['lat'] as num)
          .toDouble(), // num.toDouble() handles both int and double from JSON
      lng: (json['lng'] as num).toDouble(),
      category: json['category'] as String,
    );
  }

  // Convert a POI to a JSON map (used when saving to SharedPreferences cache)
  Map<String, dynamic> toJson() {
    return {'name': name, 'lat': lat, 'lng': lng, 'category': category};
  }
}

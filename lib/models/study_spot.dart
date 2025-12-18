class StudySpot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final List<String> perks;
  final String? incentive;
  final bool isVerified;
  final String source; // 'supabase' or 'osm'
  final String type; // 'cafe', 'library', 'restaurant', 'other'

  StudySpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.perks = const [],
    this.incentive,
    this.isVerified = true,
    this.source = 'supabase',
    this.type = 'other',
  });

  factory StudySpot.fromJson(Map<String, dynamic> json) {
    return StudySpot(
      id: json['id'].toString(), // Ensure string for OSM compatibility
      name: json['name'] ?? 'Unknown Spot',
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['long'] ?? 0.0).toDouble(),
      imageUrl: json['image_url'],
      perks: json['perks'] != null ? List<String>.from(json['perks']) : [],
      incentive: json['incentive'],
      isVerified: json['is_verified'] ?? true, // Default to true for Supabase
      source: json['source'] ?? 'supabase',
      type: json['type'] ?? 'other',
    );
  }

  // Helper for OSM
  // Helper for OSM
  factory StudySpot.fromOSM(Map<String, dynamic> json) {
    double lat = 0.0;
    double lon = 0.0;

    // Handle 'node' vs 'way' (center)
    if (json.containsKey('lat') && json.containsKey('lon')) {
      lat = (json['lat'] as num).toDouble();
      lon = (json['lon'] as num).toDouble();
    } else if (json.containsKey('center')) {
      final center = json['center'];
      if (center != null) {
        lat = (center['lat'] as num).toDouble();
        lon = (center['lon'] as num).toDouble();
      }
    }

    return StudySpot(
      id: json['id'].toString(),
      name: json['tags']?['name'] ?? 'Unknown Place',
      latitude: lat,
      longitude: lon,
      isVerified: false,
      source: 'osm',
      type: json['tags']?['amenity'] ?? 'other',
      imageUrl: json['tags']?['image'] ??
          getOSMImageUrl(
              json['tags']?['amenity'] ?? 'other', json['id'].toString()),
      perks: [],
    );
  }

  static String getOSMImageUrl(String type, String id) {
    // Use hashCode to ensure a valid integer for the lock
    final lockId = id.hashCode;
    switch (type.toLowerCase()) {
      case 'cafe':
        return 'https://loremflickr.com/800/600/coffee,shop,interior?lock=$lockId';
      case 'library':
        return 'https://loremflickr.com/800/600/library,books,university?lock=$lockId';
      case 'restaurant':
        return 'https://loremflickr.com/800/600/restaurant,dining,food?lock=$lockId';
      case 'bar':
        return 'https://loremflickr.com/800/600/bar,pub,club?lock=$lockId';
      default:
        // Use a broader random category for 'other'
        return 'https://loremflickr.com/800/600/city,architecture,street?lock=$lockId';
    }
  }
}

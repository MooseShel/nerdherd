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
  factory StudySpot.fromOSM(Map<String, dynamic> json) {
    return StudySpot(
      id: json['id'].toString(),
      name: json['tags']['name'] ?? 'Unknown Place',
      latitude: json['lat'].toDouble(),
      longitude: json['lon'].toDouble(),
      isVerified: false,
      source: 'osm',
      type: json['tags']['amenity'] ?? 'other',
      perks: [],
    );
  }
}

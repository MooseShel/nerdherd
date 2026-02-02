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
  final String? ownerId; // NEW
  final bool isSponsored; // NEW
  final bool autoRenew; // NEW
  final DateTime? sponsorshipExpiry; // NEW
  final String? promotionalText; // NEW
  final int occupancyPercent; // NEW: 0 to 100
  final int noiseLevel; // NEW: 1 to 5
  final String? vibeSummary; // NEW: AI-generated summary
  final List<String> aiTags; // NEW: AI-distilled review tags
  final DateTime? adminDeletionScheduledAt; // NEW

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
    this.ownerId, // NEW
    required bool
        isSponsored, // Changed to required param but logic handles it below
    this.autoRenew = false, // NEW
    this.sponsorshipExpiry, // NEW
    this.promotionalText, // NEW
    this.occupancyPercent = 0, // NEW
    this.noiseLevel = 1, // NEW
    this.vibeSummary, // NEW
    this.aiTags = const [], // NEW
    this.adminDeletionScheduledAt, // NEW
  }) : isSponsored = isSponsored &&
            (sponsorshipExpiry == null ||
                sponsorshipExpiry.isAfter(DateTime.now()));

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
      ownerId: json['owner_id'], // NEW
      isSponsored: json['is_sponsored'] ?? false, // NEW
      autoRenew: json['auto_renew'] ?? false, // NEW
      sponsorshipExpiry: json['sponsorship_expiry'] != null
          ? DateTime.tryParse(json['sponsorship_expiry'])
          : null, // NEW
      promotionalText: json['promotional_text'], // NEW
      occupancyPercent: json['occupancy_percent'] ?? 0, // NEW
      noiseLevel: json['noise_level'] ?? 1, // NEW
      vibeSummary: json['vibe_summary'], // NEW
      aiTags: json['ai_tags'] != null
          ? List<String>.from(json['ai_tags'])
          : [], // NEW
      adminDeletionScheduledAt: json['admin_deletion_scheduled_at'] != null
          ? DateTime.tryParse(json['admin_deletion_scheduled_at'])
          : null, // NEW
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
      isSponsored: false, // Default to false for OSM spots
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

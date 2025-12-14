import 'package:maplibre_gl/maplibre_gl.dart';

class UserProfile {
  /// Unique identifier for the user (UUID from Supabase Auth).
  final String userId;

  /// University student ID (optional).
  final String? universityId;

  /// Whether the user is a tutor or not.
  final bool isTutor;

  /// List of current classes/subjects the user is studying or tutoring.
  final List<String> currentClasses;

  /// Short tagline or intent (e.g., "Looking for math help").
  final String? intentTag;

  /// User's full display name.
  final String? fullName;

  /// User's physical location address (optional).
  final String? address; // NEW: Address field
  /// URL to the user's avatar image.
  final String? avatarUrl;

  /// Last known location (lat/lng).
  ///
  /// Note: This is derived from the PostGIS `location_geom` column in the database.
  /// Last known location (lat/lng).
  ///
  /// Note: This is derived from the PostGIS `location_geom` column in the database.
  final LatLng? location; // Derived from location_geom
  /// Average rating from reviews (1.0 - 5.0).
  final double? averageRating;

  /// Total number of ratings/reviews received.
  final int? reviewCount;

  /// Hourly rate for tutors (in dollars).
  final int? hourlyRate;

  /// Short biography.
  final String? bio;

  /// Timestamp of the last profile update.
  final DateTime? lastUpdated;

  UserProfile({
    required this.userId,
    this.universityId,
    this.isTutor = false,
    this.currentClasses = const [],
    this.intentTag,
    this.fullName,
    this.address,
    this.avatarUrl,
    this.location,
    this.averageRating,
    this.reviewCount,
    this.hourlyRate,
    this.bio,
    this.lastUpdated,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Handle location_geom if it comes as GeoJSON or ignore for basic fetch
    // For now assuming we might parse it manually or separate lat/lng columns in a view
    LatLng? loc;
    var lat = json['lat'];
    var lng = json['lng'] ?? json['long'];
    if (lat != null && lng != null) {
      loc = LatLng(lat, lng);
    }

    return UserProfile(
      userId: json['user_id'],
      universityId: json['university_id'],
      isTutor: json['is_tutor'] ?? false,
      currentClasses: List<String>.from(json['current_classes'] ?? []),
      intentTag: json['intent_tag'],
      fullName: json['full_name'],
      address: json['address'],
      avatarUrl: json['avatar_url'],
      location: loc,
      averageRating: json['average_rating'] != null
          ? (json['average_rating'] as num).toDouble()
          : null,
      reviewCount: json['review_count'],
      hourlyRate: json['hourly_rate'],
      bio: json['bio'],
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'university_id': universityId,
      'is_tutor': isTutor,
      'current_classes': currentClasses,
      'intent_tag': intentTag,
      'full_name': fullName,
      'address': address,
      'avatar_url': avatarUrl,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'hourly_rate': hourlyRate,
      'bio': bio,
      if (location != null) 'lat': location!.latitude,
      if (location != null) 'long': location!.longitude,
      'last_updated': DateTime.now().toIso8601String(), // Auto-update timestamp
    };
  }
}

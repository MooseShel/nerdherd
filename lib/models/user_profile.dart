import 'package:maplibre_gl/maplibre_gl.dart';

class UserProfile {
  /// Unique identifier for the user (UUID from Supabase Auth).
  final String userId;

  /// University student ID (optional).
  final String? universityId;

  /// University Name (fetched via join)
  final String? universityName;

  /// Whether the user is a tutor or not.
  final bool isTutor;

  /// Whether the tutor is verified by admin.
  final bool isVerifiedTutor;

  /// List of current classes/subjects the user is studying or tutoring.
  final List<String> currentClasses;

  /// Short tagline or intent (e.g., "Looking for math help").
  final String? intentTag;

  /// User's full display name.
  final String? fullName;

  /// User's physical location address (optional).
  final String? address;

  /// URL to the user's avatar image.
  final String? avatarUrl;

  /// Last known location (lat/lng).
  ///
  /// Note: This is derived from the PostGIS `location_geom` column in the database.
  final LatLng? location;

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

  /// Whether the user has admin privileges.
  final bool isAdmin;

  /// Whether the user is banned.
  final bool isBanned;

  /// Wallet balance of the user.
  final double walletBalance;

  /// URL to the uploaded verification document.
  final String? verificationDocumentUrl;

  /// Current verification status (pending, verified, rejected).
  final String verificationStatus;

  UserProfile({
    required this.userId,
    this.universityId,
    this.universityName,
    this.isTutor = false,
    this.isVerifiedTutor = false,
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
    this.isAdmin = false,
    this.isBanned = false,
    this.walletBalance = 0.0,
    this.verificationDocumentUrl,
    this.verificationStatus = 'pending',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Handle location_geom if it comes as GeoJSON or ignore for basic fetch
    LatLng? loc;
    var lat = json['lat'];
    var lng = json['lng'] ?? json['long'];
    if (lat != null && lng != null) {
      loc = LatLng(lat, lng);
    }

    String? uniName;
    if (json['university'] != null && json['university'] is Map) {
      uniName = json['university']['name'];
    }

    return UserProfile(
      userId: json['user_id'],
      universityId: json['university_id'],
      universityName: uniName,
      isTutor: json['is_tutor'] ?? false,
      isVerifiedTutor: json['is_verified_tutor'] ?? false,
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
          ? DateTime.tryParse(json['last_updated'])
          : null,
      isAdmin: json['is_admin'] ?? false,
      isBanned: json['is_banned'] ?? false,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      verificationDocumentUrl: json['verification_document_url'],
      verificationStatus: json['verification_status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'university_id': universityId,
      'is_tutor': isTutor,
      'is_verified_tutor': isVerifiedTutor,
      'current_classes': currentClasses,
      'intent_tag': intentTag,
      'full_name': fullName,
      'address': address,
      'avatar_url': avatarUrl,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'hourly_rate': hourlyRate,
      'bio': bio,
      'is_admin': isAdmin,
      'is_banned': isBanned,
      'wallet_balance': walletBalance,
      'verification_document_url': verificationDocumentUrl,
      'verification_status': verificationStatus,
      if (location != null) 'lat': location!.latitude,
      if (location != null) 'long': location!.longitude,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }
}

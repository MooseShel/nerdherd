import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:convert';

class UserProfile {
  /// Unique identifier for the user (UUID from Supabase Auth).
  final String userId;

  /// University student ID (optional).
  final String? universityId;

  /// University Name (fetched via join)
  final String? universityName;

  /// Whether the user is a tutor or not.
  final bool isTutor;
  final bool isBusinessOwner; // NEW

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

  /// Whether Serendipity Engine is enabled.
  @Deprecated('Serendipity is now always enabled')
  final bool serendipityEnabled;

  /// Semantic embedding of the user's bio/profile.
  final List<double>? bioEmbedding;

  /// Study style: 0.0 (Silent) to 1.0 (Social).
  final double studyStyleSocial;

  /// Study style: 0.0 (Morning) to 1.0 (Night).
  final double studyStyleTemporal;

  /// Semantic Match Similarity (0.0 - 1.0)
  final double? matchSimilarity;

  /// Timestamp of when the user agreed to the tutor platform fee.
  final DateTime? tutorFeeAgreedAt;

  /// Stripe Customer ID linked to the user.
  final String? stripeCustomerId;

  /// Whether to use university-specific branding colors.
  final bool useUniversityTheme;

  UserProfile({
    required this.userId,
    this.universityId,
    this.universityName,
    this.isTutor = false,
    this.isBusinessOwner = false, // NEW
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
    @Deprecated('Serendipity is now always enabled')
    this.serendipityEnabled = false,
    this.bioEmbedding,
    this.studyStyleSocial = 0.5,
    this.studyStyleTemporal = 0.5,
    this.matchSimilarity,
    this.tutorFeeAgreedAt,
    this.stripeCustomerId,
    this.useUniversityTheme = true,
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
      isBusinessOwner: json['is_business_owner'] ?? false, // NEW
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
      // ignore: deprecated_member_use_from_same_package
      serendipityEnabled: json['serendipity_enabled'] ?? false,
      bioEmbedding: json['bio_embedding'] != null
          ? (json['bio_embedding'] is String
              ? List<double>.from((jsonDecode(json['bio_embedding']) as List)
                  .map((e) => (e as num).toDouble()))
              : List<double>.from((json['bio_embedding'] as List)
                  .map((e) => (e as num).toDouble())))
          : null,
      studyStyleSocial: (json['study_style_social'] as num?)?.toDouble() ?? 0.5,
      studyStyleTemporal:
          (json['study_style_temporal'] as num?)?.toDouble() ?? 0.5,
      matchSimilarity: (json['similarity'] as num?)?.toDouble(),
      tutorFeeAgreedAt: json['tutor_fee_agreed_at'] != null
          ? DateTime.tryParse(json['tutor_fee_agreed_at'])
          : null,
      stripeCustomerId: json['stripe_customer_id'],
      useUniversityTheme: json['use_university_theme'] ?? true,
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
      'serendipity_enabled':
          // ignore: deprecated_member_use_from_same_package
          serendipityEnabled, // Deprecated but kept for schema compatibility
      'study_style_social': studyStyleSocial,
      'study_style_temporal': studyStyleTemporal,
      if (bioEmbedding != null) 'bio_embedding': bioEmbedding,
      if (location != null) 'lat': location!.latitude,
      if (location != null) 'long': location!.longitude,
      'last_updated': DateTime.now().toIso8601String(),
      if (tutorFeeAgreedAt != null)
        'tutor_fee_agreed_at': tutorFeeAgreedAt!.toIso8601String(),
      if (stripeCustomerId != null) 'stripe_customer_id': stripeCustomerId,
      'use_university_theme': useUniversityTheme,
    };
  }

  UserProfile copyWith({
    String? userId,
    String? universityId,
    String? universityName,
    bool? isTutor,
    bool? isBusinessOwner,
    bool? isVerifiedTutor,
    List<String>? currentClasses,
    String? intentTag,
    String? fullName,
    String? address,
    String? avatarUrl,
    LatLng? location,
    double? averageRating,
    int? reviewCount,
    int? hourlyRate,
    String? bio,
    DateTime? lastUpdated,
    bool? isAdmin,
    bool? isBanned,
    double? walletBalance,
    String? verificationDocumentUrl,
    String? verificationStatus,
    bool? serendipityEnabled,
    List<double>? bioEmbedding,
    double? studyStyleSocial,
    double? studyStyleTemporal,
    DateTime? tutorFeeAgreedAt,
    String? stripeCustomerId,
    bool? useUniversityTheme,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      universityId: universityId ?? this.universityId,
      universityName: universityName ?? this.universityName,
      isTutor: isTutor ?? this.isTutor,
      isBusinessOwner: isBusinessOwner ?? this.isBusinessOwner,
      isVerifiedTutor: isVerifiedTutor ?? this.isVerifiedTutor,
      currentClasses: currentClasses ?? this.currentClasses,
      intentTag: intentTag ?? this.intentTag,
      fullName: fullName ?? this.fullName,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      bio: bio ?? this.bio,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      walletBalance: walletBalance ?? this.walletBalance,
      verificationDocumentUrl:
          verificationDocumentUrl ?? this.verificationDocumentUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      // ignore: deprecated_member_use_from_same_package
      serendipityEnabled: serendipityEnabled ?? this.serendipityEnabled,
      bioEmbedding: bioEmbedding ?? this.bioEmbedding,
      studyStyleSocial: studyStyleSocial ?? this.studyStyleSocial,
      studyStyleTemporal: studyStyleTemporal ?? this.studyStyleTemporal,
      tutorFeeAgreedAt: tutorFeeAgreedAt ?? this.tutorFeeAgreedAt,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      useUniversityTheme: useUniversityTheme ?? this.useUniversityTheme,
    );
  }
}

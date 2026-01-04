import 'package:maplibre_gl/maplibre_gl.dart';

class StruggleSignal {
  final String id;
  final String userId;
  final String subject;
  final String? topic;
  final int confidenceLevel; // 1-5 (1 = totally lost, 5 = just checking)
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime expiresAt;

  StruggleSignal({
    required this.id,
    required this.userId,
    required this.subject,
    this.topic,
    required this.confidenceLevel,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.expiresAt,
  });

  // Computed property
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Get LatLng for map integration
  LatLng get location => LatLng(latitude, longitude);

  // Get time remaining until expiration
  Duration get timeRemaining {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }

  // Get confidence level label
  String get confidenceLabel {
    switch (confidenceLevel) {
      case 1:
        return 'Totally lost 😵';
      case 2:
        return 'Pretty stuck 😓';
      case 3:
        return 'Need a hint 🤔';
      case 4:
        return 'Almost there 😊';
      case 5:
        return 'Just checking 😎';
      default:
        return 'Unknown';
    }
  }

  factory StruggleSignal.fromJson(Map<String, dynamic> json) {
    // Parse location from PostGIS geography point
    double lat = 0.0;
    double lon = 0.0;

    if (json['location'] != null) {
      // PostGIS returns geography as GeoJSON or WKT
      // Handle both formats
      if (json['location'] is Map) {
        final coords = json['location']['coordinates'];
        if (coords != null && coords.length >= 2) {
          lon = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      } else if (json['location'] is String) {
        // Parse WKT format: POINT(lon lat)
        final wkt = json['location'] as String;
        final match = RegExp(r'POINT\(([^ ]+) ([^ ]+)\)').firstMatch(wkt);
        if (match != null) {
          lon = double.parse(match.group(1)!);
          lat = double.parse(match.group(2)!);
        }
      }
    }

    return StruggleSignal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subject: json['subject'] as String,
      topic: json['topic'] as String?,
      confidenceLevel: json['confidence_level'] as int,
      latitude: lat,
      longitude: lon,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subject': subject,
      'topic': topic,
      'confidence_level': confidenceLevel,
      // PostGIS geography format: POINT(longitude latitude)
      'location': 'POINT($longitude $latitude)',
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  // Create a new struggle signal (for insertion)
  Map<String, dynamic> toInsert() {
    return {
      'user_id': userId,
      'subject': subject,
      'topic': topic,
      'confidence_level': confidenceLevel,
      'location': 'POINT($longitude $latitude)',
      // created_at and expires_at will be set by database defaults
    };
  }

  StruggleSignal copyWith({
    String? id,
    String? userId,
    String? subject,
    String? topic,
    int? confidenceLevel,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return StruggleSignal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

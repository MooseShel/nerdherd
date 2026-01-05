import 'dart:math';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/user_profile.dart';

class SimulationService {
  final Random _random = Random();

  /// Generate a list of simulated users around a center point
  List<UserProfile> generateBots({
    required LatLng center,
    int studentCount = 3,
    int tutorCount = 3,
    double radiusInMeters = 800, // ~0.5 mile
  }) {
    final List<UserProfile> bots = [];

    // Create a pool of potential "personas" to ensure uniqueness
    var studentPool = List<String>.from(_studentNames);
    var tutorPool = List<String>.from(_tutorNames);

    studentPool.shuffle(_random);
    tutorPool.shuffle(_random);

    // Generate Students
    for (int i = 0; i < studentCount; i++) {
      if (studentPool.isEmpty) {
        studentPool = List.from(_studentNames)..shuffle(_random);
      }
      final name = studentPool.removeLast();
      bots.add(_generateRandomUser(center, radiusInMeters, name, false));
    }

    // Generate Tutors
    for (int i = 0; i < tutorCount; i++) {
      if (tutorPool.isEmpty) {
        tutorPool = List.from(_tutorNames)..shuffle(_random);
      }
      final name = tutorPool.removeLast();
      bots.add(_generateRandomUser(center, radiusInMeters, name, true));
    }

    return bots;
  }

  UserProfile _generateRandomUser(
      LatLng center, double radiusInMeters, String name, bool isTutor) {
    // 1 degree lat is ~111km. 1m is ~1/111000 degrees.
    final double maxOffset = radiusInMeters / 111000;

    // Random offset
    final double latOffset = (_random.nextDouble() * 2 - 1) * maxOffset;
    final double lngOffset = (_random.nextDouble() * 2 - 1) * maxOffset;

    final LatLng location = LatLng(
      center.latitude + latOffset,
      center.longitude + lngOffset,
    );

    return UserProfile(
      userId: _generatePseudoUuid(),
      fullName: name,
      avatarUrl: null,
      intentTag:
          isTutor ? 'Tutoring' : _intents[_random.nextInt(_intents.length)],
      isTutor: isTutor,
      location: location,
      lastUpdated: DateTime.now(), // Online now
      bio: "Automated study buddy",
    );
  }

  // Data Banks
  static const List<String> _studentNames = [
    "Alex R.",
    "Sam K.",
    "Jordan T.",
    "Casey L.",
    "Jamie O.",
    "Taylor S.",
    "Morgan H.",
    "Riley D.",
    "Quinn F.",
    "Avery B.",
    "Cameron W.",
    "Dakota J.",
    "Ellis P.",
    "Finley M.",
    "Grayson N."
  ];

  static const List<String> _tutorNames = [
    "Dr. Smith",
    "Prof. Miller",
    "Tutor Sarah",
    "Dave the Math Guy",
    "Physics Phil",
    "Chem Cathy",
    "History Hank",
    "Bio Bob"
  ];

  static const List<String> _intents = [
    "Studying Calc",
    "Physics HW",
    "Essay Writing",
    "Chill Study",
    "Group Project",
    "Cramming",
    "Coffee & Code"
  ];

  /// Generates a valid-looking UUID v4 string to satisfy Supabase type checks
  String _generatePseudoUuid() {
    String hex(int length) {
      const chars = '0123456789abcdef';
      return List.generate(length, (_) => chars[_random.nextInt(16)]).join();
    }

    return '${hex(8)}-${hex(4)}-4${hex(3)}-${[
      '8',
      '9',
      'a',
      'b'
    ][_random.nextInt(4)]}${hex(3)}-${hex(12)}';
  }
}

import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/study_spot.dart';
import 'logger_service.dart';

class PlacesService {
  // Overpass API Endpoints (Fallbacks for reliability)
  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.osm.ch/api/interpreter',
  ];

  /// Fetches nearby cafes, libraries, and restaurants from OpenStreetMap
  Future<List<StudySpot>> fetchNearbyPOIs(double lat, double lon,
      {double radius = 1000}) async {
    for (var endpoint in _endpoints) {
      try {
        final query = '''
          [out:json][timeout:25];
          (
            node["amenity"~"cafe|library|restaurant"](around:$radius, $lat, $lon);
            way["amenity"~"cafe|library|restaurant"](around:$radius, $lat, $lon);
          );
          out center;
        ''';

        logger.debug("🌍 Fetching OSM spots from $endpoint (r=$radius)");

        final response = await http.post(
          Uri.parse(endpoint),
          body: {'data': query},
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final elements = data['elements'] as List;

          logger.info(
              "🌍 OSM fetched ${elements.length} places from ${Uri.parse(endpoint).host}");

          return elements
              .where((e) =>
                  e['tags'] != null &&
                  e['tags']['name'] != null) // Filter unnamed
              .map((e) => StudySpot.fromOSM(e))
              .toList();
        } else if (response.statusCode == 429 || response.statusCode >= 500) {
          logger.warning(
              "⚠️ Endpoint $endpoint failed (${response.statusCode}), trying next...");
          continue;
        } else {
          logger.error(
              "❌ OSM Request Failed on $endpoint: ${response.statusCode}");
          continue;
        }
      } catch (e) {
        logger.warning("⚠️ Error with endpoint $endpoint: $e");
        continue;
      }
    }

    // ALL ENDPOINTS FAILED
    if (kDebugMode) {
      logger.error(
          "❌ All OSM endpoints failed. Generating synthetic spots for simulation (DEBUG ONLY)...");
      return _generateSyntheticSpots(lat, lon, radius: radius);
    }

    logger.error("❌ All OSM endpoints failed.");
    return [];
  }

  List<StudySpot> _generateSyntheticSpots(double lat, double lon,
      {required double radius}) {
    // Generate 4 randomized spots nearby for simulation purposes
    final spots = <StudySpot>[];
    final types = ['cafe', 'library', 'restaurant', 'cafe'];
    final names = [
      'The Study Nook',
      'Geek Retreat',
      'Brain Brew',
      'Knowledge Corner'
    ];

    // Offset factor: 0.001 roughly equals 111 meters
    final offsetRange = (radius / 111000);

    for (int i = 0; i < 4; i++) {
      final latOffset = math.sin(3.14 * (i + 1)) * offsetRange * 0.7;
      final lonOffset = math.cos(2.71 * (i + 1)) * offsetRange * 0.7;

      final type = types[i % types.length];
      final id = 'synthetic_$i';

      spots.add(StudySpot(
        id: id,
        name: names[i % names.length],
        type: type,
        latitude: lat + latOffset,
        longitude: lon + lonOffset,
        isVerified: false,
        isSponsored: false, // Synthetic spots are not sponsored
        source: 'osm',
        imageUrl: StudySpot.getOSMImageUrl(type, id),
      ));
    }
    return spots;
  }
}

final placesService = PlacesService();

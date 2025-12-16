import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/study_spot.dart';
import 'logger_service.dart';

class PlacesService {
  // Overpass API Endpoint
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Fetches nearby cafes, libraries, and restaurants from OpenStreetMap
  Future<List<StudySpot>> fetchNearbyPOIs(double lat, double lon,
      {double radius = 1000}) async {
    try {
      // Overpass QL Query
      // node(around:radius, lat, lon)[amenity~"cafe|library|restaurant"]; out;
      final query = '''
        [out:json];
        (
          node["amenity"~"cafe|library|restaurant"](around:$radius, $lat, $lon);
        );
        out;
      ''';

      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        logger.debug("🌍 OSM fetched ${elements.length} places");

        return elements
            .where((e) =>
                e['tags'] != null &&
                e['tags']['name'] != null) // Filter unnamed
            .map((e) => StudySpot.fromOSM(e))
            .toList();
      } else {
        logger.error("❌ OSM Request Failed: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      logger.error("❌ Error fetching OSM data", error: e);
      return [];
    }
  }
}

final placesService = PlacesService();

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/study_spot.dart';
import '../models/user_profile.dart';
import 'places_service.dart';
import 'logger_service.dart';

class MapService {
  final SupabaseClient _supabase;
  final PlacesService _placesService;

  MapService(this._supabase, this._placesService);

  // 1. Fetch Study Spots
  Future<List<StudySpot>> fetchStudySpots(LatLng center,
      {double radius = 2000}) async {
    try {
      // 1. Load Verified Spots (Database) - Fast
      final verifiedData = await _supabase.from('study_spots').select();
      final verifiedSpots =
          (verifiedData as List).map((e) => StudySpot.fromJson(e)).toList();

      // 2. Load OSM Spots (API) - Slower
      // Note: merging logic can stay here or be handled by the caller.
      // For now, we return combined list.
      try {
        final osmSpots = await _placesService.fetchNearbyPOIs(
          center.latitude,
          center.longitude,
          radius: radius,
        );
        return [...verifiedSpots, ...osmSpots];
      } catch (e) {
        logger.warning("Failed to fetch OSM spots", error: e);
        return verifiedSpots; // Return at least the verified ones
      }
    } catch (e) {
      logger.error("Error fetching study spots", error: e);
      return [];
    }
  }

  // 2. Subscribe to Peers
  Stream<List<UserProfile>> getPeersStream() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['user_id'])
        .order('last_updated', ascending: false)
        .limit(50)
        .map((data) {
          return data.map((e) => UserProfile.fromJson(e)).toList();
        });
  }

  // 3. Update Location
  Future<void> updateLocation(String userId, double lat, double long) async {
    try {
      await _supabase.from('profiles').upsert({
        'user_id': userId,
        'lat': lat,
        'long': long,
        'last_updated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      logger.error("❌ MapService: Upsert failed", error: e);
      rethrow;
    }
  }

  // 4. Go Ghost (Clear Location)
  Future<void> goGhost(String userId) async {
    try {
      logger.debug("👻 Going Ghost: Clearing location from DB...");
      await _supabase.from('profiles').update({
        'lat': null,
        'long': null,
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      logger.error("Failed to go ghost", error: e);
      rethrow;
    }
  }
}

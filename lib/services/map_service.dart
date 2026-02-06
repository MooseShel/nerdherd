import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/study_spot.dart';
import '../models/user_profile.dart';
import 'logger_service.dart';

class MapService {
  final SupabaseClient _supabase;

  MapService(this._supabase);

  // 1. Fetch Study Spots
  Future<List<StudySpot>> fetchStudySpots(LatLng center,
      {double radius = 2000}) async {
    try {
      // 1. Load Verified Spots (Database) - Fast
      // Note: For large DBs, use PostGIS. Here we fetch and filter locally for simulation.
      final verifiedData = await _supabase.from('study_spots').select();
      final allVerified =
          (verifiedData as List).map((e) => StudySpot.fromJson(e)).toList();

      // Filter verified spots by distance
      final verifiedSpots = allVerified.where((spot) {
        final dist = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          spot.latitude,
          spot.longitude,
        );
        return dist <= radius;
      }).toList();

      return verifiedSpots;
    } catch (e) {
      logger.error("Error fetching study spots", error: e);
      return [];
    }
  }

  // 2. Subscribe to Peers with Blocking Filter
  Stream<List<UserProfile>> getPeersStream() async* {
    final myId = _supabase.auth.currentUser?.id;

    // Initial blocked list fetch
    final blockedListWrapper = {'ids': <String>{}};
    if (myId != null) {
      final blocked = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', myId);
      blockedListWrapper['ids'] =
          (blocked as List).map((e) => e['blocked_id'] as String).toSet();
    }

    // Stream profiles
    final stream = _supabase.from('profiles').stream(
        primaryKey: ['user_id']).order('last_updated', ascending: false);

    await for (final data in stream) {
      // Re-fetch blocks occasionally? For now, we rely on local state or simplified flow.
      // Ideally, we'd combine streams, but for MVP:
      final blockedIds = blockedListWrapper['ids']!;

      yield data
          .map((e) => UserProfile.fromJson(e))
          .where((u) => u.userId != myId && !blockedIds.contains(u.userId))
          .toList();
    }
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

  Future<Set<String>> getBlockedUserIds() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return {};

    try {
      final response = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', myId);

      return (response as List).map((e) => e['blocked_id'] as String).toSet();
    } catch (e) {
      logger.error("Error fetching blocked users", error: e);
      return {};
    }
  }
}

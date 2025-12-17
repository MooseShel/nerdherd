import 'dart:async';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/study_spot.dart';
import '../models/user_profile.dart';
import '../services/places_service.dart';
import '../services/map_service.dart';
import 'auth_provider.dart';

part 'map_provider.g.dart';

// 1. Map Service Provider
@Riverpod(keepAlive: true)
MapService mapService(MapServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MapService(supabase, PlacesService());
}

// 2. User Location Provider (Stream)
@Riverpod(keepAlive: true)
Stream<LatLng> userLocation(UserLocationRef ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).map((p) => LatLng(p.latitude, p.longitude));
}

// 3. Study Spots Provider
@Riverpod(keepAlive: true)
class StudySpots extends _$StudySpots {
  @override
  FutureOr<List<StudySpot>> build() async {
    // Initial empty state or fetch nearby defaults?
    // We'll wait for manual search triggers or location updates.
    return [];
  }

  Future<void> search(LatLng center, {double radius = 2000}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(mapServiceProvider);
      return service.fetchStudySpots(center, radius: radius);
    });
  }
}

// 4. Peers Provider
@Riverpod(keepAlive: true)
Stream<List<UserProfile>> peers(PeersRef ref) {
  final service = ref.watch(mapServiceProvider);
  return service.getPeersStream();
}

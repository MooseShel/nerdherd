import 'dart:async';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/study_spot.dart';
import '../models/user_profile.dart';
import '../services/map_service.dart';
import 'auth_provider.dart';

part 'map_provider.g.dart';

// 1. Map Service Provider
@Riverpod(keepAlive: true)
MapService mapService(MapServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MapService(supabase);
}

// 2. User Location Provider (Stream)
@Riverpod(keepAlive: true)
Stream<LatLng> userLocation(UserLocationRef ref) async* {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return;
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return;
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  yield* Geolocator.getPositionStream(
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

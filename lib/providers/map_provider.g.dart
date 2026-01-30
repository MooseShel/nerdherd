// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mapServiceHash() => r'04a00eaa276cdf2b9d0934f95ada11586afb4f2b';

/// See also [mapService].
@ProviderFor(mapService)
final mapServiceProvider = Provider<MapService>.internal(
  mapService,
  name: r'mapServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mapServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MapServiceRef = ProviderRef<MapService>;
String _$userLocationHash() => r'966ab6af3a6ad3464f8fd18d011c71cb80500852';

/// See also [userLocation].
@ProviderFor(userLocation)
final userLocationProvider = StreamProvider<LatLng>.internal(
  userLocation,
  name: r'userLocationProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userLocationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserLocationRef = StreamProviderRef<LatLng>;
String _$peersHash() => r'1d29047137def50dfca4ce67fa02fd7ce5360bb0';

/// See also [peers].
@ProviderFor(peers)
final peersProvider = StreamProvider<List<UserProfile>>.internal(
  peers,
  name: r'peersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$peersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PeersRef = StreamProviderRef<List<UserProfile>>;
String _$studySpotsHash() => r'180bb902b963f79f159217a949a34698da0b1447';

/// See also [StudySpots].
@ProviderFor(StudySpots)
final studySpotsProvider =
    AsyncNotifierProvider<StudySpots, List<StudySpot>>.internal(
  StudySpots.new,
  name: r'studySpotsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$studySpotsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StudySpots = AsyncNotifier<List<StudySpot>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

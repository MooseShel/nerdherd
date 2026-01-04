// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myProfileHash() => r'a5bae6b4f20caa9d472cd9177f7c76ef6369c7d4';

/// See also [myProfile].
@ProviderFor(myProfile)
final myProfileProvider = StreamProvider<UserProfile?>.internal(
  myProfile,
  name: r'myProfileProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyProfileRef = StreamProviderRef<UserProfile?>;
String _$profileHash() => r'c378aa23bb1e6f1260a0c1f6387d7ae7b65cc203';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [profile].
@ProviderFor(profile)
const profileProvider = ProfileFamily();

/// See also [profile].
class ProfileFamily extends Family<AsyncValue<UserProfile?>> {
  /// See also [profile].
  const ProfileFamily();

  /// See also [profile].
  ProfileProvider call(
    String userId,
  ) {
    return ProfileProvider(
      userId,
    );
  }

  @override
  ProfileProvider getProviderOverride(
    covariant ProfileProvider provider,
  ) {
    return call(
      provider.userId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'profileProvider';
}

/// See also [profile].
class ProfileProvider extends FutureProvider<UserProfile?> {
  /// See also [profile].
  ProfileProvider(
    String userId,
  ) : this._internal(
          (ref) => profile(
            ref as ProfileRef,
            userId,
          ),
          from: profileProvider,
          name: r'profileProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$profileHash,
          dependencies: ProfileFamily._dependencies,
          allTransitiveDependencies: ProfileFamily._allTransitiveDependencies,
          userId: userId,
        );

  ProfileProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<UserProfile?> Function(ProfileRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProfileProvider._internal(
        (ref) => create(ref as ProfileRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  FutureProviderElement<UserProfile?> createElement() {
    return _ProfileProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProfileRef on FutureProviderRef<UserProfile?> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _ProfileProviderElement extends FutureProviderElement<UserProfile?>
    with ProfileRef {
  _ProfileProviderElement(super.provider);

  @override
  String get userId => (origin as ProfileProvider).userId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

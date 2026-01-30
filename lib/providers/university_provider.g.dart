// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'university_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$universityServiceHash() => r'cd7853d2eba07e130b092017c4acdae1a73a867d';

/// See also [universityService].
@ProviderFor(universityService)
final universityServiceProvider = Provider<UniversityService>.internal(
  universityService,
  name: r'universityServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$universityServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UniversityServiceRef = ProviderRef<UniversityService>;
String _$searchUniversitiesHash() =>
    r'55cddee8b970ebe916a49136cd5c2a02c7b78e18';

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

/// See also [searchUniversities].
@ProviderFor(searchUniversities)
const searchUniversitiesProvider = SearchUniversitiesFamily();

/// See also [searchUniversities].
class SearchUniversitiesFamily extends Family<AsyncValue<List<University>>> {
  /// See also [searchUniversities].
  const SearchUniversitiesFamily();

  /// See also [searchUniversities].
  SearchUniversitiesProvider call(
    String query,
  ) {
    return SearchUniversitiesProvider(
      query,
    );
  }

  @override
  SearchUniversitiesProvider getProviderOverride(
    covariant SearchUniversitiesProvider provider,
  ) {
    return call(
      provider.query,
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
  String? get name => r'searchUniversitiesProvider';
}

/// See also [searchUniversities].
class SearchUniversitiesProvider
    extends AutoDisposeFutureProvider<List<University>> {
  /// See also [searchUniversities].
  SearchUniversitiesProvider(
    String query,
  ) : this._internal(
          (ref) => searchUniversities(
            ref as SearchUniversitiesRef,
            query,
          ),
          from: searchUniversitiesProvider,
          name: r'searchUniversitiesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$searchUniversitiesHash,
          dependencies: SearchUniversitiesFamily._dependencies,
          allTransitiveDependencies:
              SearchUniversitiesFamily._allTransitiveDependencies,
          query: query,
        );

  SearchUniversitiesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<List<University>> Function(SearchUniversitiesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SearchUniversitiesProvider._internal(
        (ref) => create(ref as SearchUniversitiesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<University>> createElement() {
    return _SearchUniversitiesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchUniversitiesProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SearchUniversitiesRef on AutoDisposeFutureProviderRef<List<University>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _SearchUniversitiesProviderElement
    extends AutoDisposeFutureProviderElement<List<University>>
    with SearchUniversitiesRef {
  _SearchUniversitiesProviderElement(super.provider);

  @override
  String get query => (origin as SearchUniversitiesProvider).query;
}

String _$courseCatalogHash() => r'474e05ad6d2a8684608f6edc4ec907daeed25e49';

/// See also [courseCatalog].
@ProviderFor(courseCatalog)
const courseCatalogProvider = CourseCatalogFamily();

/// See also [courseCatalog].
class CourseCatalogFamily extends Family<AsyncValue<List<Course>>> {
  /// See also [courseCatalog].
  const CourseCatalogFamily();

  /// See also [courseCatalog].
  CourseCatalogProvider call({
    required String universityId,
    String? query,
  }) {
    return CourseCatalogProvider(
      universityId: universityId,
      query: query,
    );
  }

  @override
  CourseCatalogProvider getProviderOverride(
    covariant CourseCatalogProvider provider,
  ) {
    return call(
      universityId: provider.universityId,
      query: provider.query,
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
  String? get name => r'courseCatalogProvider';
}

/// See also [courseCatalog].
class CourseCatalogProvider extends AutoDisposeFutureProvider<List<Course>> {
  /// See also [courseCatalog].
  CourseCatalogProvider({
    required String universityId,
    String? query,
  }) : this._internal(
          (ref) => courseCatalog(
            ref as CourseCatalogRef,
            universityId: universityId,
            query: query,
          ),
          from: courseCatalogProvider,
          name: r'courseCatalogProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$courseCatalogHash,
          dependencies: CourseCatalogFamily._dependencies,
          allTransitiveDependencies:
              CourseCatalogFamily._allTransitiveDependencies,
          universityId: universityId,
          query: query,
        );

  CourseCatalogProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.universityId,
    required this.query,
  }) : super.internal();

  final String universityId;
  final String? query;

  @override
  Override overrideWith(
    FutureOr<List<Course>> Function(CourseCatalogRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CourseCatalogProvider._internal(
        (ref) => create(ref as CourseCatalogRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        universityId: universityId,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Course>> createElement() {
    return _CourseCatalogProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CourseCatalogProvider &&
        other.universityId == universityId &&
        other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, universityId.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CourseCatalogRef on AutoDisposeFutureProviderRef<List<Course>> {
  /// The parameter `universityId` of this provider.
  String get universityId;

  /// The parameter `query` of this provider.
  String? get query;
}

class _CourseCatalogProviderElement
    extends AutoDisposeFutureProviderElement<List<Course>>
    with CourseCatalogRef {
  _CourseCatalogProviderElement(super.provider);

  @override
  String get universityId => (origin as CourseCatalogProvider).universityId;
  @override
  String? get query => (origin as CourseCatalogProvider).query;
}

String _$myEnrollmentsHash() => r'335f73664fd52c24ecd4954f86b17fa9f8a35c11';

/// See also [myEnrollments].
@ProviderFor(myEnrollments)
final myEnrollmentsProvider = AutoDisposeFutureProvider<List<Course>>.internal(
  myEnrollments,
  name: r'myEnrollmentsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myEnrollmentsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyEnrollmentsRef = AutoDisposeFutureProviderRef<List<Course>>;
String _$universityByIdHash() => r'704886239dcf973ab8cea98c66aaaf5ddb59b57f';

/// See also [universityById].
@ProviderFor(universityById)
const universityByIdProvider = UniversityByIdFamily();

/// See also [universityById].
class UniversityByIdFamily extends Family<AsyncValue<University?>> {
  /// See also [universityById].
  const UniversityByIdFamily();

  /// See also [universityById].
  UniversityByIdProvider call(
    String id,
  ) {
    return UniversityByIdProvider(
      id,
    );
  }

  @override
  UniversityByIdProvider getProviderOverride(
    covariant UniversityByIdProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'universityByIdProvider';
}

/// See also [universityById].
class UniversityByIdProvider extends AutoDisposeFutureProvider<University?> {
  /// See also [universityById].
  UniversityByIdProvider(
    String id,
  ) : this._internal(
          (ref) => universityById(
            ref as UniversityByIdRef,
            id,
          ),
          from: universityByIdProvider,
          name: r'universityByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$universityByIdHash,
          dependencies: UniversityByIdFamily._dependencies,
          allTransitiveDependencies:
              UniversityByIdFamily._allTransitiveDependencies,
          id: id,
        );

  UniversityByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<University?> Function(UniversityByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UniversityByIdProvider._internal(
        (ref) => create(ref as UniversityByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<University?> createElement() {
    return _UniversityByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UniversityByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UniversityByIdRef on AutoDisposeFutureProviderRef<University?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _UniversityByIdProviderElement
    extends AutoDisposeFutureProviderElement<University?>
    with UniversityByIdRef {
  _UniversityByIdProviderElement(super.provider);

  @override
  String get id => (origin as UniversityByIdProvider).id;
}

String _$myUniversityHash() => r'f0292f93d2c394e400b7173717dc22a9ede3744b';

/// See also [myUniversity].
@ProviderFor(myUniversity)
final myUniversityProvider = AutoDisposeFutureProvider<University?>.internal(
  myUniversity,
  name: r'myUniversityProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myUniversityHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyUniversityRef = AutoDisposeFutureProviderRef<University?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

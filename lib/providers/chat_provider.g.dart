// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatServiceHash() => r'7708cff0cc02987717334313779b76bf166f5cdc';

/// See also [chatService].
@ProviderFor(chatService)
final chatServiceProvider = Provider<ChatService>.internal(
  chatService,
  name: r'chatServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChatServiceRef = ProviderRef<ChatService>;
String _$typingStatusHash() => r'92fbde8be6d87b6cf82d77dbc1e2a3865b8270c0';

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

/// See also [typingStatus].
@ProviderFor(typingStatus)
const typingStatusProvider = TypingStatusFamily();

/// See also [typingStatus].
class TypingStatusFamily extends Family<AsyncValue<bool>> {
  /// See also [typingStatus].
  const TypingStatusFamily();

  /// See also [typingStatus].
  TypingStatusProvider call(
    String otherUserId,
  ) {
    return TypingStatusProvider(
      otherUserId,
    );
  }

  @override
  TypingStatusProvider getProviderOverride(
    covariant TypingStatusProvider provider,
  ) {
    return call(
      provider.otherUserId,
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
  String? get name => r'typingStatusProvider';
}

/// See also [typingStatus].
class TypingStatusProvider extends StreamProvider<bool> {
  /// See also [typingStatus].
  TypingStatusProvider(
    String otherUserId,
  ) : this._internal(
          (ref) => typingStatus(
            ref as TypingStatusRef,
            otherUserId,
          ),
          from: typingStatusProvider,
          name: r'typingStatusProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$typingStatusHash,
          dependencies: TypingStatusFamily._dependencies,
          allTransitiveDependencies:
              TypingStatusFamily._allTransitiveDependencies,
          otherUserId: otherUserId,
        );

  TypingStatusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.otherUserId,
  }) : super.internal();

  final String otherUserId;

  @override
  Override overrideWith(
    Stream<bool> Function(TypingStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TypingStatusProvider._internal(
        (ref) => create(ref as TypingStatusRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        otherUserId: otherUserId,
      ),
    );
  }

  @override
  StreamProviderElement<bool> createElement() {
    return _TypingStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TypingStatusProvider && other.otherUserId == otherUserId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, otherUserId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TypingStatusRef on StreamProviderRef<bool> {
  /// The parameter `otherUserId` of this provider.
  String get otherUserId;
}

class _TypingStatusProviderElement extends StreamProviderElement<bool>
    with TypingStatusRef {
  _TypingStatusProviderElement(super.provider);

  @override
  String get otherUserId => (origin as TypingStatusProvider).otherUserId;
}

String _$chatNotifierHash() => r'd2493c95a9dd72fe4a3425544bfa6b1addb883f3';

abstract class _$ChatNotifier
    extends BuildlessAsyncNotifier<List<Map<String, dynamic>>> {
  late final String otherUserId;

  FutureOr<List<Map<String, dynamic>>> build(
    String otherUserId,
  );
}

/// See also [ChatNotifier].
@ProviderFor(ChatNotifier)
const chatNotifierProvider = ChatNotifierFamily();

/// See also [ChatNotifier].
class ChatNotifierFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [ChatNotifier].
  const ChatNotifierFamily();

  /// See also [ChatNotifier].
  ChatNotifierProvider call(
    String otherUserId,
  ) {
    return ChatNotifierProvider(
      otherUserId,
    );
  }

  @override
  ChatNotifierProvider getProviderOverride(
    covariant ChatNotifierProvider provider,
  ) {
    return call(
      provider.otherUserId,
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
  String? get name => r'chatNotifierProvider';
}

/// See also [ChatNotifier].
class ChatNotifierProvider extends AsyncNotifierProviderImpl<ChatNotifier,
    List<Map<String, dynamic>>> {
  /// See also [ChatNotifier].
  ChatNotifierProvider(
    String otherUserId,
  ) : this._internal(
          () => ChatNotifier()..otherUserId = otherUserId,
          from: chatNotifierProvider,
          name: r'chatNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatNotifierHash,
          dependencies: ChatNotifierFamily._dependencies,
          allTransitiveDependencies:
              ChatNotifierFamily._allTransitiveDependencies,
          otherUserId: otherUserId,
        );

  ChatNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.otherUserId,
  }) : super.internal();

  final String otherUserId;

  @override
  FutureOr<List<Map<String, dynamic>>> runNotifierBuild(
    covariant ChatNotifier notifier,
  ) {
    return notifier.build(
      otherUserId,
    );
  }

  @override
  Override overrideWith(ChatNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatNotifierProvider._internal(
        () => create()..otherUserId = otherUserId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        otherUserId: otherUserId,
      ),
    );
  }

  @override
  AsyncNotifierProviderElement<ChatNotifier, List<Map<String, dynamic>>>
      createElement() {
    return _ChatNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatNotifierProvider && other.otherUserId == otherUserId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, otherUserId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatNotifierRef on AsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `otherUserId` of this provider.
  String get otherUserId;
}

class _ChatNotifierProviderElement extends AsyncNotifierProviderElement<
    ChatNotifier, List<Map<String, dynamic>>> with ChatNotifierRef {
  _ChatNotifierProviderElement(super.provider);

  @override
  String get otherUserId => (origin as ChatNotifierProvider).otherUserId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

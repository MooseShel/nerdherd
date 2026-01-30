// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paymentServiceHash() => r'3bc8e63a5c3e0e049501827aad5780ef98c4e8f4';

/// See also [paymentService].
@ProviderFor(paymentService)
final paymentServiceProvider = Provider<PaymentService>.internal(
  paymentService,
  name: r'paymentServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$paymentServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PaymentServiceRef = ProviderRef<PaymentService>;
String _$paymentHistoryHash() => r'6fdda4f5900e27c107533e2c8f70cb59bc0b2564';

/// See also [paymentHistory].
@ProviderFor(paymentHistory)
final paymentHistoryProvider = FutureProvider<List<Transaction>>.internal(
  paymentHistory,
  name: r'paymentHistoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$paymentHistoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PaymentHistoryRef = FutureProviderRef<List<Transaction>>;
String _$paymentControllerHash() => r'21c018d59af7456afc00e8610b1c595863754775';

/// See also [PaymentController].
@ProviderFor(PaymentController)
final paymentControllerProvider =
    NotifierProvider<PaymentController, void>.internal(
  PaymentController.new,
  name: r'paymentControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$paymentControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PaymentController = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

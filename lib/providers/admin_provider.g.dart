// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$adminStatsHash() => r'0416e88780a72fff19f6e237a8943fd7d205316b';

/// See also [adminStats].
@ProviderFor(adminStats)
final adminStatsProvider = FutureProvider<AdminStats>.internal(
  adminStats,
  name: r'adminStatsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$adminStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminStatsRef = FutureProviderRef<AdminStats>;
String _$supportTicketsHash() => r'369a3f53894238515c7516b979a0ab24e76dfc8a';

/// See also [supportTickets].
@ProviderFor(supportTickets)
final supportTicketsProvider = StreamProvider<List<SupportTicket>>.internal(
  supportTickets,
  name: r'supportTicketsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$supportTicketsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SupportTicketsRef = StreamProviderRef<List<SupportTicket>>;
String _$ledgerHash() => r'7598a54bf2c7a1ae84406bb29f164b4309c33be4';

/// See also [Ledger].
@ProviderFor(Ledger)
final ledgerProvider =
    AsyncNotifierProvider<Ledger, List<Transaction>>.internal(
  Ledger.new,
  name: r'ledgerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$ledgerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Ledger = AsyncNotifier<List<Transaction>>;
String _$adminControllerHash() => r'0432f1ffd78a37d88d1d117b9c35d613a6fad983';

/// See also [AdminController].
@ProviderFor(AdminController)
final adminControllerProvider =
    NotifierProvider<AdminController, void>.internal(
  AdminController.new,
  name: r'adminControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$adminControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AdminController = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

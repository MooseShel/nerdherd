import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

part 'wallet_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<double> walletBalance(Ref ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authStateProvider).value;

  if (user == null) {
    return Stream.value(0.0);
  }

  // Use a StreamController to combine initial fetch + real-time updates
  final controller = StreamController<double>();

  Future<void> fetchBalance() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('user_id', user.id)
          .single();

      final balance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
      if (!controller.isClosed) {
        controller.add(balance);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Initial fetch
  fetchBalance();

  // Subscribe to changes in the profiles table for this user
  final subscription = supabase
      .channel('public:profiles:wallet:${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          final newBalance =
              (payload.newRecord['wallet_balance'] as num?)?.toDouble() ?? 0.0;
          if (!controller.isClosed) {
            controller.add(newBalance);
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    subscription.unsubscribe();
    controller.close();
  });

  return controller.stream;
}

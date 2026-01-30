import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart'; // Add this
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';

part 'auth_provider.g.dart';

// 1. Expose the Supabase Client as a Provider
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

// 2. Auth State Provider (AsyncNotifier)
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  Stream<User?> build() {
    final client = ref.watch(supabaseClientProvider);

    // Listen to Auth State Changes
    return client.auth.onAuthStateChange.map((state) {
      final user = state.session?.user;
      if (user != null) {
        logger.debug("AuthProvider: User is authenticated (${user.id})");
      } else {
        logger.debug("AuthProvider: User is signed out");
      }
      return user;
    }).distinct((prev, next) => prev?.id == next?.id);
  }

  // Helper method to sign out
  Future<void> signOut() async {
    final client = ref.read(supabaseClientProvider);
    // Reset badge
    try {
      await NotificationService().resetBadge();
    } catch (_) {}
    state = const AsyncValue.data(null);
    await client.auth.signOut();
  }
}

// 3. Simple User Provider (Synchronous access helper if needed, but Stream is better)
// We generally use `ref.watch(authProvider)` to get AsyncValue<User?>

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'supabase_provider.dart';

part 'auth_provider.g.dart';

/// Provides the current Supabase session user
@riverpod
Stream<User?> authState(AuthStateRef ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange.map((event) => event.session?.user);
}

/// Provides the current user ID or null if not logged in
@riverpod
String? currentUserId(CurrentUserIdRef ref) {
  final user = ref.watch(authStateProvider).value;
  return user?.id;
}

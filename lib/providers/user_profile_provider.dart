import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

part 'user_profile_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<UserProfile?> myProfile(Ref ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final supabase = ref.watch(supabaseClientProvider);

  // Listen to profile changes
  return supabase
      .from('profiles')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', user.id)
      .map((data) {
        if (data.isEmpty) return null;
        // Note: Realtime does NOT support joins.
        // university_name will be null here.
        // We rely on GlassProfileDrawer or UniversityCheck to assume ID presence.
        return UserProfile.fromJson(data.first);
      });
}

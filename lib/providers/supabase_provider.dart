import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'supabase_provider.g.dart';

/// Provides the Supabase client instance
@riverpod
SupabaseClient supabase(Ref ref) {
  return Supabase.instance.client;
}

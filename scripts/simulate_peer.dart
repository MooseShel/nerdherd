// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:supabase/supabase.dart';

// Configuration
const supabaseUrl = 'https://zzdasdmceaykwjsozums.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6ZGFzZG1jZWF5a3dqc296dW1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxNDM3OTQsImV4cCI6MjA4MDcxOTc5NH0.gUMEknvtbKpU_WMsgd7OVuedQpDsDAtDgQ1bcaMgpwY';

void main() async {
  print('🤖 Initializing Bot...');
  final client = SupabaseClient(supabaseUrl, supabaseKey);

  // 1. Auth as Bot
  final email = 'bot_${DateTime.now().millisecondsSinceEpoch}@nerdherd.test';
  const password = 'password123';

  print('🔑 Registering Bot: $email');
  AuthResponse res;
  try {
    res = await client.auth.signUp(email: email, password: password);
  } catch (e) {
    print('Auth Error (trying login instead): $e');
    // If sign up fails, try login (though typical random email avoids this)
    exit(1);
  }

  if (res.user == null) {
    print('❌ Failed to create bot user.');
    exit(1);
  }

  final userId = res.user!.id;
  print('✅ Bot Authenticated: $userId');

  // 2. Set Initial Profile
  print('📝 Creating Profile...');
  await client.from('profiles').upsert({
    'user_id': userId,
    'is_tutor': true,
    'intent_tag': 'Simulating Movement',
    'current_classes': ['Bot Logic', 'Pathfinding'],
    'lat': 40.7128,
    'long': -74.0060,
  });

  // 3. Move in a circle
  print('🚀 Starting Movement Simulation around NYC...');
  double centerLat = 40.7128;
  double centerLng = -74.0060;
  double radius = 0.005; // approx 500m
  double angle = 0;

  while (true) {
    angle += 0.1;
    final newLat = centerLat + radius * cos(angle);
    final newLng = centerLng + radius * sin(angle);

    try {
      await client.from('profiles').upsert({
        'user_id': userId,
        'lat': newLat,
        'long': newLng,
        'last_updated': DateTime.now().toIso8601String(),
      });
      print('📍 Moved to $newLat, $newLng');
    } catch (e) {
      print('⚠️ Update failed: $e');
    }

    sleep(const Duration(seconds: 2));
  }
}

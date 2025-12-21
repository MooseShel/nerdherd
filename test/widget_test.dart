// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerd_herd/main.dart';
import 'package:nerd_herd/services/logger_service.dart';
import 'package:logger/logger.dart';
import 'package:nerd_herd/providers/auth_provider.dart' as app_auth;
import 'unit/providers/auth_provider_test.mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';

class SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUpAll(() async {
    logger.initialize(output: SilentOutput());
    SharedPreferences.setMockInitialValues({});

    // Initialize dummy Supabase to prevent static access crash in NotificationService
    await supabase.Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'dummy',
    );

    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(mockSupabase.auth).thenReturn(mockAuth);
    // Ensure onAuthStateChange returns an empty stream or initial state
    when(mockAuth.onAuthStateChange).thenAnswer((_) => Stream.value(
        const supabase.AuthState(supabase.AuthChangeEvent.signedOut, null)));
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          app_auth.supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
        child: const NerdHerdApp(hasSeenOnboarding: true),
      ),
    );

    // Allow FutureBuilder/Streams to settle
    await tester.pumpAndSettle();

    // Verify that the app builds.
    // Since Supabase is not initialized in tests, AuthGate catches the error and shows AuthPage.
    // We expect the AuthPage content:
    expect(find.text('Nerd Herd'), findsOneWidget);
    // Button text
    expect(find.text('Log In'), findsOneWidget);
  });
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerd_herd/services/logger_service.dart';
import 'package:logger/logger.dart';
import 'package:nerd_herd/providers/auth_provider.dart' as app_auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'unit/providers/auth_provider_test.mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nerd_herd/main.dart';

class SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUpAll(() async {
    logger.initialize(output: SilentOutput());
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    dotenv.testLoad(fileInput: 'DEBUG=false');

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

  testWidgets('AuthGate smoke test', (WidgetTester tester) async {
    // Override providers if necessary

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          app_auth.supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
        child: const NerdHerdApp(hasSeenOnboarding: true),
      ),
    );

    await tester.pumpAndSettle();

    // With signedOut state (mocked in setUpAll), we expect AuthPage
    // AuthPage typically has a "Log In" or "Sign Up" text or a logo.
    expect(find.text('Nerd Herd'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}

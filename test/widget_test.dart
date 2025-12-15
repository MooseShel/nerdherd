// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerd_herd/main.dart';

import 'package:nerd_herd/services/logger_service.dart';
import 'package:logger/logger.dart';

class SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  setUpAll(() {
    logger.initialize(output: SilentOutput());
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
        const ProviderScope(child: NerdHerdApp(hasSeenOnboarding: true)));

    // Verify that the app builds.
    // Since Supabase is not initialized in tests, AuthGate catches the error and shows AuthPage.
    // We expect the AuthPage content:
    expect(find.text('Nerd Herd'), findsOneWidget);
    // Button text
    expect(find.text('Log In'), findsOneWidget);
  });
}

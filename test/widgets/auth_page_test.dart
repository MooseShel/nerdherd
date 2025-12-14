import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nerd_herd/auth/auth_page.dart';

void main() {
  group('AuthPage', () {
    testWidgets('renders login form initially', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      expect(find.text('ACCESS TERMINAL'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email and password
    });

    testWidgets('toggles to signup mode', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      // Initially in login mode
      expect(find.text('ACCESS TERMINAL'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);

      // Tap toggle button
      await tester.tap(find.text('Create new identity >'));
      await tester.pump();

      // Now in signup mode
      expect(find.text('INITIALIZE PROTOCOL'), findsOneWidget);
      expect(find.text('REGISTER'), findsOneWidget);
    });

    testWidgets('toggles back to login mode', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      // Toggle to signup
      await tester.tap(find.text('Create new identity >'));
      await tester.pump();

      expect(find.text('INITIALIZE PROTOCOL'), findsOneWidget);

      // Toggle back to login
      await tester.tap(find.text('< Back to login'));
      await tester.pump();

      expect(find.text('ACCESS TERMINAL'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('has email and password fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      expect(find.widgetWithText(TextField, 'EMAIL'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'PASSWORD'), findsOneWidget);
    });

    testWidgets('email field accepts input', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      final emailField = find.widgetWithText(TextField, 'EMAIL');
      await tester.enterText(emailField, 'test@example.com');

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('password field is obscured', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      final passwordField = find.widgetWithText(TextField, 'PASSWORD');
      final textField = tester.widget<TextField>(passwordField);

      expect(textField.obscureText, true);
    });

    testWidgets('displays Nerd Herd branding', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      expect(find.text('NERD HERD'), findsOneWidget);
      expect(find.byIcon(Icons.hub), findsOneWidget);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nerd_herd/auth/auth_page.dart';

void main() {
  group('AuthPage', () {
    testWidgets('renders login form initially', (tester) async {
      // Set a larger screen size
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      // Verify initial state (Login Mode)
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Sign Up'), findsNothing);

      // Verify toggle button exists
      expect(find.text('New here? Create account'), findsOneWidget);

      expect(find.byType(TextField), findsNWidgets(2)); // Email and password
    });

    testWidgets('toggles to signup mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      // Tap toggle button
      await tester.tap(find.text('New here? Create account'));
      await tester.pump();

      // Verify state changed to Signup
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('CAMPUS / ADDRESS'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Log In'), findsNothing); // The button text changes
    });

    testWidgets('toggles back to login mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      // Toggle to signup
      await tester.tap(find.text('New here? Create account'));
      await tester.pump();

      // Toggle back to login
      await tester.tap(find.text('Already have an account? Log In'));
      await tester.pump();

      // Verify state is back to Login
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('FULL NAME'), findsNothing);
    });

    testWidgets('email field accepts input', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      final emailField = find.widgetWithText(TextField, 'EMAIL');
      await tester.enterText(emailField, 'test@example.com');

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('password field is obscured', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      final passwordField = find.widgetWithText(TextField, 'PASSWORD');
      final textField = tester.widget<TextField>(passwordField);

      expect(textField.obscureText, true);
    });

    testWidgets('displays Nerd Herd branding', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));

      expect(find.text('Nerd Herd'), findsOneWidget);
      expect(find.text('Academic velocity.'), findsOneWidget);
      expect(find.byIcon(Icons.hub_rounded), findsOneWidget);
    });
  });
}

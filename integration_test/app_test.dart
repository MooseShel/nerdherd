import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nerd_herd/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and shows auth or home page',
      (WidgetTester tester) async {
    // Start app
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Check if we are at AuthPage or MapPage
    // Note: This depends on session state. In test environment, usually starts logged out.
    // We look for widgets common to AuthPage or MapPage
    final findAuth =
        find.text('Sign In'); // Adjust based on actual AuthPage text
    final findMap = find.byTooltip('Recenter'); // Adjust based on MapPage fab

    if (findAuth.evaluate().isNotEmpty) {
      expect(findAuth, findsOneWidget);
    } else {
      expect(findMap, findsOneWidget);
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nerd_herd/config/theme.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AppTheme Logic', () {
    testWidgets('lightTheme has correct brightness and primary color',
        (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.primaryColor, const Color(0xFF5E5CE6)); // Electric Indigo
      expect(theme.colorScheme.primary, const Color(0xFF5E5CE6));
      expect(theme.colorScheme.secondary, const Color(0xFF64D2FF)); // Cyan
    });

    testWidgets('darkTheme has correct brightness and primary color',
        (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.primaryColor, const Color(0xFF5E5CE6));
      expect(theme.colorScheme.primary, const Color(0xFF5E5CE6));
      expect(theme.colorScheme.secondary, const Color(0xFF64D2FF));
    });

    testWidgets('Semantic colors are correctly mapped', (tester) async {
      const errorSystem = Color(0xFFFF453A);
      const successSystem = Color(0xFF32D74B);

      // Light
      expect(AppTheme.lightTheme.colorScheme.error, errorSystem);
      expect(AppTheme.lightTheme.colorScheme.tertiary, successSystem);

      // Dark
      expect(AppTheme.darkTheme.colorScheme.error, errorSystem);
      expect(AppTheme.darkTheme.colorScheme.tertiary, successSystem);
    });
  });
}

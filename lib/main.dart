import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_gate.dart';
import 'onboarding/onboarding_page.dart';
import 'config/app_config.dart';
import 'services/logger_service.dart';
import 'services/notification_service.dart';
import 'config/navigation.dart';
import 'config/theme.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize logger first to catch startup errors
    logger.initialize();
    logger.info('🚀 Nerd Herd starting up...');

    // Initialize Firebase (Skip on Web to avoid startup delay/timeout)
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        logger.error(
            'Failed to initialize Firebase (Warning: Push notifications may not work)',
            error: e);
      }
    }

    // Load configuration from .env file
    await AppConfig.load();

    // Initialize Supabase with config
    await Supabase.initialize(
      url: appConfig.supabaseUrl,
      anonKey: appConfig.supabaseAnonKey,
    );

    logger.info('✅ Supabase initialized');

    // Initialize notification service
    await notificationService.initialize();
    logger.info('✅ Notification service initialized');

    // Check onboarding status
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.fatal("Flutter Framework Error",
          error: details.exception, stackTrace: details.stack);
    };

    runApp(ProviderScope(
      child: NerdHerdApp(hasSeenOnboarding: hasSeenOnboarding),
    ));
  }, (error, stack) {
    // Catch all other unhandled async errors
    logger.fatal("Unhandled Async Error", error: error, stackTrace: stack);
  });
}

class NerdHerdApp extends StatelessWidget {
  final bool hasSeenOnboarding;

  const NerdHerdApp({
    super.key,
    required this.hasSeenOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nerd Herd',
      themeMode: ThemeMode.system, // Use system settings
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: hasSeenOnboarding ? const AuthGate() : const OnboardingPage(),
      navigatorKey: navigatorKey,
    );
  }
}

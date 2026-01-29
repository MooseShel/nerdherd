import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'auth/auth_gate.dart';
import 'onboarding/onboarding_page.dart';
import 'config/app_config.dart';
import 'services/logger_service.dart';
import 'services/notification_service.dart';
import 'services/remote_logger_service.dart';
import 'config/navigation.dart';
import 'config/theme.dart';

import 'providers/theme_provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize logger first to catch startup errors
    logger.initialize();
    logger.info('🚀 Nerd Herd starting up...');

    // Initialize Firebase (Only on Mobile to avoid desktop/web errors)
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        logger.error(
            'Failed to initialize Firebase (Warning: Push notifications may not work)',
            error: e);
      }
    }

    // Load configuration from .env file
    logger.info('⚙️ Loading AppConfig...');
    await AppConfig.load();

    // Initialize Stripe (Skip on Web - flutter_stripe uses Platform internally)
    // Initialize Stripe
    logger.info('💳 Initializing Stripe...');
    Stripe.publishableKey = appConfig.stripePublishableKey;
    if (!kIsWeb) {
      await Stripe.instance.applySettings();
    }
    logger.info('✅ Stripe initialized');

    // Initialize Supabase with config
    logger.info('🗄️ Initializing Supabase...');
    await Supabase.initialize(
      url: appConfig.supabaseUrl,
      anonKey: appConfig.supabaseAnonKey,
    );

    logger.info('✅ Supabase initialized');

    // Initialize Remote logging
    remoteLogger = RemoteLoggerService(Supabase.instance.client);

    // Initialize notification service - Safe and Non-blocking
    if (!kIsWeb) {
      logger.info('🔔 Initializing Notifications...');
      notificationService.initialize().catchError((e) {
        logger.error('Failed to init notifications in main', error: e);
        remoteLogger?.logRemote(
          level: 'error',
          message: 'Notification Init Failed (Main): $e',
          error: e,
        );
      });
    } else {
      logger.info('🔔 Skipping System Notifications on Web (In-app only)');
    }

    // Check onboarding status
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.fatal("Flutter Framework Error",
          error: details.exception, stackTrace: details.stack);
      remoteLogger?.logRemote(
        level: 'fatal',
        message: 'Flutter Framework Error: ${details.exception}',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    runApp(ProviderScope(
      child: NerdHerdApp(hasSeenOnboarding: hasSeenOnboarding),
    ));
  }, (error, stack) {
    // Catch all other unhandled async errors
    logger.fatal("Unhandled Async Error", error: error, stackTrace: stack);
    remoteLogger?.logRemote(
      level: 'fatal',
      message: 'Unhandled Async Error: $error',
      error: error,
      stackTrace: stack,
    );
  });
}

class NerdHerdApp extends ConsumerStatefulWidget {
  final bool hasSeenOnboarding;

  const NerdHerdApp({
    super.key,
    required this.hasSeenOnboarding,
  });

  @override
  ConsumerState<NerdHerdApp> createState() => _NerdHerdAppState();
}

class _NerdHerdAppState extends ConsumerState<NerdHerdApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset badge when app comes to foreground
      notificationService.resetBadge();

      // Refresh Supabase session to prevent stale token errors
      _refreshSessionSafe();
    }
  }

  Future<void> _refreshSessionSafe() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        logger.debug("🔄 Attempting to refresh session on resume...");
        await Supabase.instance.client.auth.refreshSession();
        logger.debug("✅ Session refreshed successfully");
      }
    } catch (e) {
      // Only warn, don't crash - often network issues or already valid
      logger.warning("⚠️ Failed to refresh session on resume (non-fatal)",
          error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeModeAsync = ref.watch(themeNotifierProvider);

    return MaterialApp(
      title: 'Nerd Herd',
      themeMode: themeModeAsync.value ??
          ThemeMode.system, // Default to system if loading
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: (kDebugMode || widget.hasSeenOnboarding)
          ? const AuthGate()
          : const OnboardingPage(),
      navigatorKey: navigatorKey,
    );
  }
}

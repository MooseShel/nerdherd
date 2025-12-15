import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_page.dart';
import 'map_page.dart';
import 'config/app_config.dart';
import 'services/logger_service.dart';
import 'services/notification_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';

// ... imports ...
import 'config/navigation.dart';
import 'config/theme.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load configuration from .env file
    await AppConfig.load();

    // Initialize logger
    logger.initialize();
    logger.info('🚀 Nerd Herd starting up...');

    // Initialize Supabase with config
    await Supabase.initialize(
      url: appConfig.supabaseUrl,
      anonKey: appConfig.supabaseAnonKey,
    );

    logger.info('✅ Supabase initialized');

    // Initialize notification service
    await notificationService.initialize();
    logger.info('✅ Notification service initialized');

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.fatal("Flutter Framework Error",
          error: details.exception, stackTrace: details.stack);
    };

    runApp(const ProviderScope(child: NerdHerdApp()));
  }, (error, stack) {
    // Catch all other unhandled async errors
    logger.fatal("Unhandled Async Error", error: error, stackTrace: stack);
  });
}

class NerdHerdApp extends StatelessWidget {
  const NerdHerdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nerd Herd',
      themeMode: ThemeMode.dark, // Default to dark for now
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthGate(),
      navigatorKey: navigatorKey,
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state using Riverpod
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Subscribe to notifications when authenticated
          // Note: Ideally this side effect should be in a provider/listener,
          // but keeping here for now to match previous logic.
          notificationService.subscribeToNotifications();
          return const MapPage();
        } else {
          notificationService.unsubscribe();
          return const AuthPage();
        }
      },
      loading: () => const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      ),
      error: (err, stack) {
        logger.error("Auth Stream Error", error: err, stackTrace: stack);
        return const AuthPage();
      },
    );
  }
}

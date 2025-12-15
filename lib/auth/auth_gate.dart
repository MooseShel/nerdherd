import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../map_page.dart';
import 'auth_page.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';

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
        return const AuthPage(); // Fail safe to AuthPage
      },
    );
  }
}

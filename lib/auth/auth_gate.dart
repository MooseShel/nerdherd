import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../university/university_check.dart';
import '../providers/auth_provider.dart';
import '../map_page.dart';
import 'auth_page.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import '../services/biometric_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    final email = appConfig.testUserEmail;
    final password = appConfig.testUserPassword;

    // Only attempt if configured and no user is currently signed in
    if (email != null &&
        password != null &&
        Supabase.instance.client.auth.currentSession == null) {
      try {
        logger.info("🤖 Auto-logging in test user: $email");
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        logger.error("Auto-login failed", error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state using Riverpod
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return AppStartupManager(
            child: const BiometricGuard(
              child: UniversityCheck(child: MapPage()),
            ),
          );
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

class BiometricGuard extends StatefulWidget {
  final Widget child;
  const BiometricGuard({super.key, required this.child});

  @override
  State<BiometricGuard> createState() => _BiometricGuardState();
}

class _BiometricGuardState extends State<BiometricGuard> {
  bool _isAuthenticated = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await biometricService.isBiometricEnabled;
    if (!enabled) {
      if (mounted) setState(() => _isAuthenticated = true);
      return;
    }

    final success = await biometricService.authenticate();
    if (mounted) {
      setState(() {
        _isAuthenticated = success;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) return widget.child;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: Colors.cyanAccent),
            const SizedBox(height: 24),
            const Text(
              "Security Check",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            if (!_isChecking)
              ElevatedButton(
                onPressed: _checkBiometrics,
                child: const Text("Try Again"),
              ),
          ],
        ),
      ),
    );
  }
}

/// New Wrapper to handle side-effects safely in initState after login
class AppStartupManager extends StatefulWidget {
  final Widget child;
  const AppStartupManager({super.key, required this.child});

  @override
  State<AppStartupManager> createState() => _AppStartupManagerState();
}

class _AppStartupManagerState extends State<AppStartupManager> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure we don't block the initial build
    // and that we only run these side effects once per session login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    try {
      logger.info("🎬 AppStartupManager: Syncing services...");
      await notificationService.subscribeToNotifications();
      await notificationService.syncToken();
      logger.info("✅ AppStartupManager: Sync complete");
    } catch (e) {
      logger.error("AppStartupManager: Error during sync", error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

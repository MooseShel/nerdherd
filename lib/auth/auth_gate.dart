import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../map_page.dart';
import 'auth_page.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import '../services/biometric_service.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state using Riverpod
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          notificationService.subscribeToNotifications();
          return const BiometricGuard(child: MapPage());
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

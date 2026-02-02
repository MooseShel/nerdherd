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
          // 1. Email Verification Check
          // kDebugMode allows skipping if you are dev, but user requested strictness.
          // Let's enforce it generally but maybe allow a bypass if needed or desired.
          // Supabase user object has property emailConfirmedAt (String?)
          if (user.emailConfirmedAt == null) {
            return const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_unread_outlined,
                          size: 64, color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'Email Verification Required',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please verify your email address to continue.\nCheck your inbox for the verification link.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      // Note: User can't click "Resend" easily without custom logic or just re-signing up
                      // or clicking a button that calls auth.resendResponse
                    ],
                  ),
                ),
              ),
            );
          }

          return const AppStartupManager(
            child: BiometricGuard(
              child: ActiveUserGuard(child: UniversityCheck(child: MapPage())),
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

class ActiveUserGuard extends ConsumerStatefulWidget {
  final Widget child;
  const ActiveUserGuard({super.key, required this.child});

  @override
  ConsumerState<ActiveUserGuard> createState() => _ActiveUserGuardState();
}

class _ActiveUserGuardState extends ConsumerState<ActiveUserGuard> {
  bool _isLoading = true;
  bool _isAllowed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('is_active, is_banned')
          .eq('user_id', userId)
          .single();

      final isActive = response['is_active'] ?? true;
      final isBanned = response['is_banned'] ?? false;

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (isBanned) {
            _isAllowed = false;
            _errorMessage = "Your account has been banned.";
          } else if (!isActive) {
            _isAllowed = false;
            _errorMessage = "Your account has been deactivated.";
          } else {
            _isAllowed = true;
          }
        });

        if (!_isAllowed) {
          // Optional: Supabase.instance.client.auth.signOut();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAllowed = true;
        });
        logger.error("Failed to check user active status", error: e);
      }
    }
  }

  Future<void> _requestReactivation() async {
    final controller = TextEditingController();
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Reactivation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Please explain why your account should be reactivated."),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your message here...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (shouldSubmit == true && controller.text.trim().isNotEmpty) {
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        await Supabase.instance.client.from('activation_requests').insert({
          'user_id': userId,
          'message': controller.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Request submitted successfully."),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Failed to submit request: $e"),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAllowed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _errorMessage?.contains("banned") == true
                      ? Icons.block
                      : Icons.person_off,
                  size: 64,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  "Access Denied",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? "You do not have access.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                if (_errorMessage?.contains("deactivated") == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _requestReactivation,
                      icon: const Icon(Icons.feedback),
                      label: const Text("Appeal Reactivation"),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () {
                    Supabase.instance.client.auth.signOut();
                  },
                  child: const Text("Sign Out"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

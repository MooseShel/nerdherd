import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_profile_provider.dart';
import '../services/logger_service.dart';

class UniversityCheck extends ConsumerStatefulWidget {
  final Widget child;
  const UniversityCheck({super.key, required this.child});

  @override
  ConsumerState<UniversityCheck> createState() => _UniversityCheckState();
}

class _UniversityCheckState extends ConsumerState<UniversityCheck> {
  // We want to redirect ONLY if we are sure the user has no university.
  // We don't want to block the user while loading.
  // Strategy:
  // 1. Listen to Profile Stream.
  // 2. If data arrives and university_id is null, show selection screen.
  // 3. Otherwise show child.

  @override
  Widget build(BuildContext context) {
    // Stream of "My Profile"
    final profileAsync = ref.watch(myProfileProvider);

    return profileAsync.when(
      data: (profile) {
        // REMOVED: Mandatory check
        // User requested to remove forced selection after login.
        // It is now managed only via Settings.

        // Has university -> Show App
        return widget.child;
      },
      error: (err, stack) {
        logger.error("UniversityCheck Profile Error", error: err);
        // On error, let them pass? Or retry?
        // Let's safe fail to App so they aren't locked out, but log it.
        return widget.child;
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      ),
    );
  }
}

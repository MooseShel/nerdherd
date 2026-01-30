import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/university.dart';
import '../providers/university_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/haptic_service.dart';

class UniversityDiscoveryBanner extends ConsumerStatefulWidget {
  const UniversityDiscoveryBanner({super.key});

  @override
  ConsumerState<UniversityDiscoveryBanner> createState() =>
      _UniversityDiscoveryBannerState();
}

class _UniversityDiscoveryBannerState
    extends ConsumerState<UniversityDiscoveryBanner> {
  University? _suggestedUni;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _discoverUniversity();
  }

  Future<void> _discoverUniversity() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || user.email == null) return;

    final service = ref.read(universityServiceProvider);
    final uni = await service.findUniversityByEmail(user.email!);

    if (mounted) {
      setState(() => _suggestedUni = uni);
    }
  }

  Future<void> _setUniversity() async {
    if (_suggestedUni == null) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    hapticService.mediumImpact();

    try {
      await ref
          .read(universityServiceProvider)
          .setUniversity(user.id, _suggestedUni!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome to the ${_suggestedUni!.name} herd! 🐂"),
            backgroundColor: _suggestedUni!.primaryColorInt != null
                ? Color(_suggestedUni!.primaryColorInt!)
                : Colors.green,
          ),
        );
        ref.invalidate(myProfileProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestedUni == null || _dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final myProfile = ref.watch(myProfileProvider).value;
    final useUniTheme = myProfile?.useUniversityTheme ?? true;

    final uniColor = (useUniTheme && _suggestedUni!.primaryColorInt != null)
        ? Color(_suggestedUni!.primaryColorInt!)
        : theme.primaryColor;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: uniColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: uniColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: uniColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school_rounded, color: uniColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Are you at ${_suggestedUni!.shortName}?",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: uniColor,
                  ),
                ),
                Text(
                  "Join your campus herd to see classmates.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _dismissed = true),
            child: Text("Later", style: TextStyle(color: theme.hintColor)),
          ),
          ElevatedButton(
            onPressed: _setUniversity,
            style: ElevatedButton.styleFrom(
              backgroundColor: uniColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }
}

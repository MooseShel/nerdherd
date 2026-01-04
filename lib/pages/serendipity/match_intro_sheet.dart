import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/serendipity_match.dart';
import '../../services/matching_service.dart';
import '../../providers/user_profile_provider.dart';
import '../../config/theme.dart';

class MatchIntroSheet extends ConsumerWidget {
  final SerendipityMatch match;

  const MatchIntroSheet({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myProfileProvider).value?.userId;
    // Check if userA or userB is the other user
    final otherUserId = match.userA == myId ? match.userB : match.userA;
    final otherProfileAsync = ref.watch(profileProvider(otherUserId));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            "It's a Match! 🎉",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.serendipityOrange,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "You found a study buddy nearby.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Profiles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProfileAvatar(
                  context, ref.watch(myProfileProvider).value?.avatarUrl),
              const Icon(Icons.compare_arrows, size: 32, color: Colors.grey),
              otherProfileAsync.when(
                data: (profile) =>
                    _buildProfileAvatar(context, profile?.avatarUrl),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Icon(Icons.error),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Actions
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Accept match logic
                await matchingService.acceptMatch(match.id);
                if (context.mounted) Navigator.pop(context);
                // In a real app, this would navigate to chat
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.serendipityOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.chat_bubble),
              label: const Text("Start Chatting"),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Maybe Later"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context, String? url) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.serendipityOrange, width: 3),
        image: url != null
            ? DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: url == null ? const Icon(Icons.person, size: 40) : null,
    );
  }
}

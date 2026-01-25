import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/serendipity_match.dart';
import '../../services/matching_service.dart';
import '../../providers/user_profile_provider.dart';
import '../../config/theme.dart';
import '../../providers/serendipity_provider.dart';
import '../../chat_page.dart';

class MatchIntroSheet extends ConsumerWidget {
  final SerendipityMatch match;

  const MatchIntroSheet({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myProfileProvider).value?.userId;
    // Check if userA or userB is the other user
    final otherUserId = match.userA == myId ? match.userB : match.userA;
    final otherProfileAsync = ref.watch(profileProvider(otherUserId));

    // Watch the real-time match state
    final liveMatchAsync = ref.watch(matchStreamProvider(match.id));

    // POLLING FALLBACK: Invalidating the provider every 3s if pending
    // This ensures that if the stream fails, we still get the update.
    if (liveMatchAsync.value?.accepted == false) {
      // Use a simple timer effect via a future delay in build (careful with loops) or better, useEffect equivalent.
      // Since this is a ConsumerWidget, we can't easily use Timer.
      // We'll use a Future.delayed to trigger a refresh if we're still waiting.
      // This is a "poor man's poll" but effective for this critical state.
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted && liveMatchAsync.value?.accepted == false) {
          // Only refresh if we are still pending
          ref.invalidate(matchStreamProvider(match.id));
        }
      });
    }

    // Use live match or fallback to initial (but prefer live)
    final liveMatch = liveMatchAsync.valueOrNull ?? match;

    // Safety check: If match was deleted remotely, close sheet
    if (liveMatchAsync is AsyncData && liveMatchAsync.value == null) {
      // Delay pop to avoid build error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
    }

    // Determine roles
    final isSender = liveMatch.userA == myId;

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
            children: [
              Column(
                children: [
                  _buildProfileAvatar(
                      context, ref.watch(myProfileProvider).value?.avatarUrl),
                  const SizedBox(height: 8),
                  Text(
                      ref
                              .watch(myProfileProvider)
                              .value
                              ?.fullName
                              ?.split(' ')
                              .first ??
                          'You',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Icon(Icons.compare_arrows, size: 32, color: Colors.grey),
              otherProfileAsync.when(
                data: (profile) => Column(
                  children: [
                    _buildProfileAvatar(context, profile?.avatarUrl),
                    const SizedBox(height: 8),
                    Text(profile?.fullName?.split(' ').first ?? 'Them',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Icon(Icons.error),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Actions
          if (isSender) ...[
            // I am the SENDER
            if (liveMatch.accepted) ...[
              // ACCEPTED! Show Chat Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final profile = otherProfileAsync.value;
                    if (profile != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatPage(otherUser: profile),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Green for Success
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text("Start Chatting!"),
                ),
              ),
            ] else ...[
              // PENDING - Show Waiting
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.grey.shade600,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.hourglass_empty),
                  label: const Text("Waiting for Response..."),
                ),
              ),
            ]
          ] else ...[
            // I am the RECEIVER
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Accept match logic
                  final success = await matchingService.acceptMatch(match.id);

                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(context); // Close sheet

                      // Navigate to Chat
                      final profile = otherProfileAsync.value;
                      if (profile != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatPage(otherUser: profile),
                          ),
                        );
                      }
                    } else {
                      // Show error (Match probably declined/deleted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              const Text('Matches expired or was canceled.'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.serendipityOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text("Accept Request"),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              // Pop FIRST to avoid viewing a deleted match (avoids crash/race)
              if (context.mounted) Navigator.pop(context);

              await matchingService.declineMatch(match.id);
              // ref.invalidate is NOT needed and causes "Bad State" because widget is disposed.
              // Stream will auto-update.
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text("Decline Match"),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/serendipity_match.dart';
import '../../services/matching_service.dart';
import '../../providers/user_profile_provider.dart';
import '../../config/theme.dart';
import '../../providers/serendipity_provider.dart';
import '../../chat_page.dart';

class MatchIntroSheet extends ConsumerStatefulWidget {
  final SerendipityMatch match;

  const MatchIntroSheet({super.key, required this.match});

  @override
  ConsumerState<MatchIntroSheet> createState() => _MatchIntroSheetState();
}

class _MatchIntroSheetState extends ConsumerState<MatchIntroSheet> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(myProfileProvider).value?.userId;
    // Check if userA or userB is the other user
    final otherUserId =
        widget.match.userA == myId ? widget.match.userB : widget.match.userA;
    final otherProfileAsync = ref.watch(profileProvider(otherUserId));

    // Watch the real-time match state
    final liveMatchAsync = ref.watch(matchStreamProvider(widget.match.id));

    // POLLING FALLBACK: Invalidating the provider every 3s if pending
    if (liveMatchAsync.value?.accepted == false) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && liveMatchAsync.value?.accepted == false) {
          ref.invalidate(matchStreamProvider(widget.match.id));
        }
      });
    }

    // Use live match or fallback to initial (but prefer live)
    final liveMatch = liveMatchAsync.valueOrNull ?? widget.match;

    // Safety check: If match was deleted remotely, close sheet
    if (liveMatchAsync is AsyncData && liveMatchAsync.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
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
                onPressed: _isAccepting
                    ? null
                    : () async {
                        // Accept match logic
                        setState(() => _isAccepting = true);
                        try {
                          final success = await matchingService
                              .acceptMatch(widget.match.id);

                          if (mounted) {
                            if (success) {
                              Navigator.pop(context); // Close sheet

                              // Navigate to Chat
                              final profile = otherProfileAsync.value;
                              if (profile != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ChatPage(otherUser: profile),
                                  ),
                                );
                              }
                            } else {
                              // Show error (Match probably declined/deleted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Matches expired or was canceled.'),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error,
                                ),
                              );
                              Navigator.pop(context);
                            }
                          }
                        } catch (e) {
                          // Handle any exceptions (e.g., duplicate key errors)
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Match accepted! Opening chat...'),
                                backgroundColor: AppTheme.serendipityOrange,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } finally {
                          if (mounted) setState(() => _isAccepting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.serendipityOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isAccepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isAccepting ? "Connecting..." : "Accept Request"),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isAccepting
                ? null
                : () async {
                    // Pop FIRST to avoid viewing a deleted match (avoids crash/race)
                    if (mounted) Navigator.pop(context);

                    await matchingService.declineMatch(widget.match.id);
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

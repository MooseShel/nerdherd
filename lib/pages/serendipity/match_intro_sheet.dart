import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/serendipity_match.dart';
import '../../services/matching_service.dart';
import '../../providers/user_profile_provider.dart';
import '../../config/theme.dart';
import '../../providers/serendipity_provider.dart';
import '../../chat_page.dart';
import '../../services/logger_service.dart';

class MatchIntroSheet extends ConsumerStatefulWidget {
  final SerendipityMatch match;

  const MatchIntroSheet({super.key, required this.match});

  @override
  ConsumerState<MatchIntroSheet> createState() => _MatchIntroSheetState();
}

class _MatchIntroSheetState extends ConsumerState<MatchIntroSheet> {
  bool _isActionInProgress = false;
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(myProfileProvider).value?.userId;
    // Check if userA or userB is the other user
    final otherUserId =
        widget.match.userA == myId ? widget.match.userB : widget.match.userA;
    final otherProfileAsync = ref.watch(profileProvider(otherUserId));

    // Watch the real-time match state
    final liveMatchAsync = ref.watch(matchStreamProvider(widget.match.id));

    // Use live match or fallback to initial (but prefer live)
    final liveMatch = liveMatchAsync.valueOrNull ?? widget.match;

    // Safety check: If match was deleted remotely, close sheet
    if (liveMatchAsync is AsyncData && liveMatchAsync.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }

    // Determine roles
    final actualMyId = supabase.auth.currentUser?.id;
    final isSender =
        (liveMatch.userA == myId) || (liveMatch.userA == actualMyId);

    // SOS Expiration remains triggered by match acceptance (for sender)
    ref.listen<AsyncValue<SerendipityMatch?>>(
        matchStreamProvider(widget.match.id), (previous, next) {
      final match = next.value;
      if (match != null && match.accepted && isSender) {
        logger.info("🎉 Match confirmed! Expiring SOS signal for sender.");
        ref.read(activeStruggleSignalProvider.notifier).expireSignal();
      }
    });

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
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
              liveMatch.accepted
                  ? "Match Confirmed! 🎉"
                  : (liveMatch.receiverInterested
                      ? "Ready to Connect! 🤩"
                      : "New Suggestion 🔭"),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.serendipityOrange,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              liveMatch.accepted
                  ? "You and ${otherProfileAsync.value?.fullName?.split(' ').first ?? 'your buddy'} are connected."
                  : (liveMatch.receiverInterested
                      ? "The receiver is interested! Click confirm to start chatting."
                      : "A potential study buddy was found near your SOS."),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // Profiles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildProfileAvatar(context,
                          ref.watch(myProfileProvider).value?.avatarUrl),
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
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child:
                      Icon(Icons.compare_arrows, size: 32, color: Colors.grey),
                ),
                Expanded(
                  child: otherProfileAsync.when(
                    data: (profile) => Column(
                      children: [
                        _buildProfileAvatar(context, profile?.avatarUrl),
                        const SizedBox(height: 8),
                        Text(profile?.fullName?.split(' ').first ?? 'Them',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Icon(Icons.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ACTIONS BLOCK
            if (isSender) ...[
              // I am the SENDER (Final Decision Maker)
              if (liveMatch.accepted) ...[
                // MATCHED! Show Chat Button
                _buildActionButton(
                  context: context,
                  label: "Start Chatting!",
                  icon: Icons.chat,
                  color: AppTheme.serendipityOrange,
                  onPressed: () {
                    final profile = otherProfileAsync.value;
                    if (profile != null) {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ChatPage(otherUser: profile)),
                      );
                    }
                  },
                ),
              ] else if (liveMatch.receiverInterested) ...[
                // RECEIVER IS INTERESTED - Sender clicks to finalize
                _buildActionButton(
                  context: context,
                  label: "Confirm & Chat!",
                  icon: Icons.check_circle,
                  color: Colors.green,
                  isLoading: _isActionInProgress,
                  onPressed: () async {
                    setState(() => _isActionInProgress = true);
                    final success =
                        await matchingService.confirmMatch(liveMatch.id);
                    if (mounted) {
                      if (success) {
                        // Navigation handled by stream listener or manually here
                        final profile = otherProfileAsync.value;
                        if (profile != null) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ChatPage(otherUser: profile)),
                          );
                        }
                      } else {
                        setState(() => _isActionInProgress = false);
                      }
                    }
                  },
                ),
              ] else ...[
                // PENDING - Wait for Receiver
                _buildActionButton(
                  context: context,
                  label: "Waiting for Buddy's Interest...",
                  icon: Icons.hourglass_top,
                  color: Colors.grey.shade400,
                  onPressed: null,
                ),
              ]
            ] else ...[
              // I am the RECEIVER (Express Interest)
              if (liveMatch.accepted) ...[
                // ALREADY MATCHED
                _buildActionButton(
                  context: context,
                  label: "Open Chat",
                  icon: Icons.chat,
                  color: AppTheme.serendipityOrange,
                  onPressed: () {
                    final profile = otherProfileAsync.value;
                    if (profile != null) {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ChatPage(otherUser: profile)),
                      );
                    }
                  },
                ),
              ] else if (liveMatch.receiverInterested) ...[
                // INTERESTED - Wait for Sender to confirm
                _buildActionButton(
                  context: context,
                  label: "Waiting for Sender's Confirmation...",
                  icon: Icons.hourglass_bottom,
                  color: Colors.grey.shade400,
                  onPressed: null,
                ),
              ] else ...[
                // IDLE - Express Interest
                _buildActionButton(
                  context: context,
                  label: "I'm Interested!",
                  icon: Icons.favorite,
                  color: AppTheme.serendipityOrange,
                  isLoading: _isActionInProgress,
                  onPressed: () async {
                    setState(() => _isActionInProgress = true);
                    final success =
                        await matchingService.expressInterest(liveMatch.id);
                    if (!context.mounted) return;
                    setState(() => _isActionInProgress = false);
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Could not express interest. Try again.')),
                      );
                    }
                  },
                ),
              ]
            ],

            const SizedBox(height: 12),
            TextButton(
              onPressed: _isActionInProgress
                  ? null
                  : () async {
                      if (mounted) Navigator.pop(context);
                      await matchingService.declineMatch(widget.match.id);
                    },
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text("Maybe Later"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade500,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(label),
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

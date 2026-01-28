import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/user_profile.dart';
import '../../config/theme.dart';
import '../../services/matching_service.dart';

class MatchListSheet extends ConsumerStatefulWidget {
  final List<UserProfile> matches;
  final String subject;
  final Function() onClose;

  const MatchListSheet({
    super.key,
    required this.matches,
    required this.subject,
    required this.onClose,
  });

  @override
  ConsumerState<MatchListSheet> createState() => _MatchListSheetState();
}

class _MatchListSheetState extends ConsumerState<MatchListSheet> {
  // Track sent requests locally for UI feedback
  final Set<String> _sentRequests = {};

  void _handleConnect(UserProfile user) {
    final msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => PointerInterceptor(
        child: AlertDialog(
          title:
              Text('Connect with ${user.fullName?.split(' ').first ?? 'them'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a personal message:'),
              const SizedBox(height: 12),
              TextField(
                controller: msgController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. Hey! I see you know Calc 2...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog

                // Send Request
                await matchingService.suggestMatch(
                  otherUserId: user.userId,
                  matchType: 'constellation',
                  message: msgController.text.trim(),
                );

                // Update UI
                setState(() {
                  _sentRequests.add(user.userId);
                });

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request Sent! 📨')),
                );
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Container(
        padding:
            const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Buddies Found! 🎓',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.serendipityOrange,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subject: ${widget.subject}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // List
            Expanded(
              child: widget.matches.isEmpty
                  ? const Center(child: Text('No matches found nearby yet.'))
                  : ListView.separated(
                      itemCount: widget.matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = widget.matches[index];
                        final isSent = _sentRequests.contains(user.userId);

                        // Simple similarity calc (mock/demo or real if passed)
                        // Since we don't have per-user similarity score passed in the List<UserProfile> directly
                        // (unless we wrap it), we'll simulate or hide it.
                        // Actually, the `findNerdMatches` returns pure `UserProfile`.
                        // Ideally we should return a wrapper with the score.
                        // For now, let's just show the card.

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: user.avatarUrl != null
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 12),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName ?? 'Unknown User',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      if (user.matchSimilarity != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            "${(user.matchSimilarity! * 100).toInt()}% Match ✨",
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        ),
                                      if (user.isTutor)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('Tutor',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.currentClasses.take(3).join(', '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),

                                // Action
                                if (isSent)
                                  TextButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.check,
                                        size: 16, color: Colors.green),
                                    label: const Text('Sent',
                                        style: TextStyle(color: Colors.green)),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () => _handleConnect(user),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppTheme.serendipityOrange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    child: const Text('Connect'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

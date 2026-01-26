import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/serendipity_match.dart';
import '../../providers/user_profile_provider.dart';
import '../../config/theme.dart';
import 'match_intro_sheet.dart';

class PendingMatchesSheet extends ConsumerWidget {
  final List<SerendipityMatch> matches;

  const PendingMatchesSheet({super.key, required this.matches});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myProfileProvider).value?.userId;

    // Split matches into Interested (Actionable) and Suggested (Waiting)
    final interestedMatches =
        matches.where((m) => m.receiverInterested && !m.accepted).toList();
    final suggestedMatches =
        matches.where((m) => !m.receiverInterested && !m.accepted).toList();

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
                Text(
                  'Study Buddy Requests 📨',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.serendipityOrange,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (matches.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child:
                    Text("No pending requests.", textAlign: TextAlign.center),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    if (interestedMatches.isNotEmpty) ...[
                      _buildSectionHeader(context, "Ready to Connect! 🤩"),
                      const SizedBox(height: 8),
                      ...interestedMatches.map(
                          (m) => _buildMatchCard(context, ref, m, myId, true)),
                      const SizedBox(height: 24),
                    ],
                    if (suggestedMatches.isNotEmpty) ...[
                      _buildSectionHeader(context, "Suggested Peers 🔭"),
                      const SizedBox(height: 8),
                      ...suggestedMatches.map(
                          (m) => _buildMatchCard(context, ref, m, myId, false)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
    );
  }

  Widget _buildMatchCard(BuildContext context, WidgetRef ref,
      SerendipityMatch match, String? myId, bool isInterested) {
    final otherUserId = match.userA == myId ? match.userB : match.userA;
    final otherProfileAsync = ref.watch(profileProvider(otherUserId));

    return Card(
      elevation: isInterested ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isInterested
            ? const BorderSide(color: AppTheme.serendipityOrange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => PointerInterceptor(
              child: MatchIntroSheet(match: match),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              otherProfileAsync.when(
                data: (profile) => CircleAvatar(
                  radius: 28,
                  backgroundImage: profile?.avatarUrl != null
                      ? NetworkImage(profile!.avatarUrl!)
                      : null,
                  child: profile?.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                loading: () => const CircleAvatar(
                    radius: 28, child: CircularProgressIndicator()),
                error: (_, __) =>
                    const CircleAvatar(radius: 28, child: Icon(Icons.error)),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: otherProfileAsync.when(
                  data: (profile) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName ?? 'Unknown User',
                        style: TextStyle(
                            fontWeight: isInterested
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 16),
                      ),
                      if (isInterested)
                        const Text(
                          "Wants to study with you!",
                          style: TextStyle(
                              color: AppTheme.serendipityOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        )
                      else if (profile?.intentTag != null)
                        Text(
                          "Topic: ${profile?.intentTag}",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                  loading: () => Container(
                      width: 100, height: 16, color: Colors.grey.shade300),
                  error: (_, __) => const Text('Error loading profile'),
                ),
              ),

              // Action Indicator
              if (isInterested)
                const Icon(Icons.check_circle, color: Colors.green)
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 40),
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
                'Incoming Requests 📨',
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

          // List
          if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No pending requests.", textAlign: TextAlign.center),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final match = matches[index];
                  final otherUserId =
                      match.userA == myId ? match.userB : match.userA;
                  final otherProfileAsync =
                      ref.watch(profileProvider(otherUserId));

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () {
                        // Close this list and open the detail sheet
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => MatchIntroSheet(match: match),
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
                                radius: 24,
                                backgroundImage: profile?.avatarUrl != null
                                    ? NetworkImage(profile!.avatarUrl!)
                                    : null,
                                child: profile?.avatarUrl == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              loading: () => const CircleAvatar(
                                  radius: 24,
                                  child: CircularProgressIndicator()),
                              error: (_, __) => const CircleAvatar(
                                  radius: 24, child: Icon(Icons.error)),
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
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    if (profile?.isTutor == true)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text('Tutor',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                loading: () => Container(
                                    width: 100,
                                    height: 16,
                                    color: Colors.grey.shade300),
                                error: (_, __) =>
                                    const Text('Error loading profile'),
                              ),
                            ),

                            // Arrow
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/logger_service.dart';
import 'services/profile_service.dart';

import 'services/haptic_service.dart';
import 'widgets/empty_state_widget.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _historyRequests = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _isLoading = true);
    try {
      // Fetch both Incoming (received by me) and Outgoing (sent by me) requests
      // Fetch ALL requests (pending/accepted/rejected)
      final requestsData = await supabase
          .from('collab_requests')
          .select('*')
          .or('receiver_id.eq.$myId,sender_id.eq.$myId')
          .order('created_at', ascending: false);

      // Fetch all unique user IDs from requests
      final userIds = <String>{};
      for (var request in requestsData) {
        userIds.add(request['sender_id']);
        userIds.add(request['receiver_id']);
      }

      // Fetch profiles efficiently via ProfileService (Cached)
      final profiles = await profileService.getProfiles(userIds.toList());

      // Create a map of user_id -> profile data (toJson)
      final profileMap = <String, Map<String, dynamic>>{};
      for (var profile in profiles) {
        profileMap[profile.userId] = profile.toJson();
      }

      // Manually join requests with profiles
      final enrichedRequests = requestsData.map((request) {
        return {
          ...request,
          'sender': profileMap[request['sender_id']],
          'receiver': profileMap[request['receiver_id']],
        };
      }).toList();

      setState(() {
        _pendingRequests =
            enrichedRequests.where((r) => r['status'] == 'pending').toList();
        _historyRequests =
            enrichedRequests.where((r) => r['status'] != 'pending').toList();
        _isLoading = false;
      });
    } catch (e) {
      logger.error("Error fetching requests", error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e')),
        );
      }
    }
  }

  Future<void> _respondToRequest(
      String requestId, String senderId, bool accept) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      if (accept) {
        // 1. Insert Connection
        // We need to know who the other person is.
        // We can find the request object in our list to get the IDs.
        final req = _pendingRequests.firstWhere((r) => r['id'] == requestId,
            orElse: () => {});
        if (req.isEmpty) {
          logger.warning("Request $requestId not found in local list");
          return;
        }
        final u1 = req['sender_id'];
        final u2 = req['receiver_id'];

        try {
          await supabase.from('connections').insert({
            'user_id_1': u1,
            'user_id_2': u2,
          });
        } catch (e) {
          // Flattening error handling:
          // If connection fails (likely duplicate), we log it but PROCEED to accept the request.
          // This ensures the UI doesn't get stuck.
          logger.info("Ignored connection insert error (likely duplicate): $e");
        }

        // 2. Update Status to Accepted (Preserve History)
        await supabase.from('collab_requests').update({
          'status': 'accepted',
        }).eq('id', requestId);
      } else {
        // Reject: Update status to rejected (or delete if prefer)
        await supabase.from('collab_requests').update({
          'status': 'rejected',
        }).eq('id', requestId);
      }

      // 3. Update UI
      // Move from Pending to History locally
      setState(() {
        final req = _pendingRequests.firstWhere((r) => r['id'] == requestId);
        _pendingRequests.removeWhere((r) => r['id'] == requestId);

        req['status'] = accept ? 'accepted' : 'rejected';
        _historyRequests.insert(0, req);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? "Request Accepted!" : "Request Rejected"),
            backgroundColor: accept ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      logger.error("Error responding to request", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text("Notification Hub",
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          foregroundColor: theme.textTheme.bodyLarge?.color,
          bottom: TabBar(
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.disabledColor,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(text: "PENDING"),
              Tab(text: "HISTORY"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(_pendingRequests, isHistory: false),
                  _buildList(_historyRequests, isHistory: true),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items,
      {required bool isHistory}) {
    if (items.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: isHistory ? Icons.history : Icons.notifications_none,
          title: isHistory ? "No past notifications" : "No pending requests",
          description: isHistory
              ? "Your request history will appear here."
              : "When people want to connect, you'll see it here.",
          actionLabel: isHistory ? null : "Find Peers",
          onAction: isHistory
              ? null
              : () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildRequestCard(context, items[index], isHistory),
    );
  }

  Widget _buildRequestCard(
      BuildContext context, Map<String, dynamic> req, bool isHistory) {
    final theme = Theme.of(context);
    final myId = supabase.auth.currentUser?.id;
    final isIncoming = req['receiver_id'] == myId;
    final status = req['status'] ?? 'pending';

    // Data setup
    final sender = req['sender'] ?? {};
    final receiver = req['receiver'] ?? {};

    final otherUser = isIncoming ? sender : receiver;
    final otherName =
        otherUser['full_name'] ?? otherUser['intent_tag'] ?? "Unknown User";
    final otherAvatar = otherUser['avatar_url'];
    final otherIsTutor = otherUser['is_tutor'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                  backgroundImage:
                      otherAvatar != null ? NetworkImage(otherAvatar) : null,
                  child: otherAvatar == null
                      ? Icon(
                          otherIsTutor ? Icons.school : Icons.person,
                          color:
                              otherIsTutor ? Colors.amber : theme.primaryColor,
                          size: 24,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncoming ? "From: $otherName" : "To: $otherName",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isIncoming
                            ? (otherIsTutor
                                ? "Tutor Requesting..."
                                : "Student Requesting...")
                            : "Waiting for them...",
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isHistory)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: status == 'accepted'
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: status == 'accepted'
                              ? Colors.green
                              : Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: status == 'accepted'
                            ? Colors.green
                            : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
              ],
            ),
            if (!isHistory && isIncoming) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      hapticService.lightImpact();
                      _respondToRequest(req['id'], req['sender_id'], false);
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                            color:
                                theme.colorScheme.error.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12)),
                    child: const Text("Decline"),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      hapticService.mediumImpact();
                      _respondToRequest(req['id'], req['sender_id'], true);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12)),
                    child: const Text("Accept"),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}

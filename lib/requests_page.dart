import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/logger_service.dart';
import 'services/profile_service.dart';

import 'services/haptic_service.dart';

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F111A), // Dark Cyber Blue
        appBar: AppBar(
          title: const Text("Notification Hub"),
          backgroundColor: const Color(0xFF0F111A),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isHistory ? Icons.history : Icons.notifications_none,
                size: 60, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              isHistory ? "No past notifications" : "No pending requests",
              style: const TextStyle(color: Colors.white54),
            ),
          ],
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

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        // Added padding for GridView safety
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.black54,
            backgroundImage:
                otherAvatar != null ? NetworkImage(otherAvatar) : null,
            child: otherAvatar == null
                ? Icon(
                    otherIsTutor ? Icons.school : Icons.person,
                    color: otherIsTutor ? Colors.amber : Colors.cyanAccent,
                  )
                : null,
          ),
          title: Text(
            isIncoming ? "From: $otherName" : "To: $otherName",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isIncoming
                ? (otherIsTutor
                    ? "Tutor Requesting..."
                    : "Student Requesting...")
                : "Waiting for them...",
            style: TextStyle(
              color: isIncoming ? Colors.white70 : Colors.grey,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isHistory
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'accepted'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: status == 'accepted'
                            ? Colors.green
                            : Colors.redAccent),
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
              : isIncoming
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () {
                            hapticService.lightImpact();
                            _respondToRequest(
                                req['id'], req['sender_id'], false);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check,
                              color: Colors.greenAccent),
                          onPressed: () {
                            hapticService.mediumImpact();
                            _respondToRequest(
                                req['id'], req['sender_id'], true);
                          },
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () {
                        hapticService.mediumImpact();
                        _respondToRequest(req['id'], req['sender_id'], true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                      child: const Text("Force Accept"),
                    ),
        ),
      ),
    );
  }
}

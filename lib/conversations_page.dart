import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_page.dart';
import 'models/user_profile.dart';
import 'services/logger_service.dart';
import 'widgets/empty_state_widget.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      // Call the RPC function we created
      final data = await supabase.rpc('get_conversations');

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      logger.error("Error fetching conversations", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading chats: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openChat(Map<String, dynamic> conversation) async {
    // Construct a partial profile for navigation
    // The RPC returns basic info needed for the header
    final profile = UserProfile(
      userId: conversation['other_user_id'],
      fullName: conversation['full_name'],
      avatarUrl: conversation['avatar_url'],
      isTutor: conversation['is_tutor'] ?? false,
      currentClasses: [], // Not needed for chat header
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(otherUser: profile),
      ),
    );

    // Refresh list on return (to update last message/unread count)
    _fetchConversations();
  }

  Future<void> _deleteConversation(String otherUserId) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    // Confirm first? For smooth UI swipe, usually we verify or undo.
    // MVP: Delete immediately (with Undo snackbar ideally, but here just delete).

    try {
      // Delete all messages between these two users
      await supabase.from('messages').delete().or(
          'and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)');

      // Update local state is handled by onDismissed mostly, but we refresh to be safe
      // _fetchConversations(); // Optional if list is already updated
    } catch (e) {
      logger.error("Error deleting conversation", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete chat")),
        );
        _fetchConversations(); // Restore item if failed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("My Chats",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: EmptyStateWidget(
                    icon: Icons.chat_bubble_outline,
                    title: "No conversations yet",
                    description:
                        "Connect with people on the map to start chatting!",
                    actionLabel: "Find Peers",
                    onAction: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final chat = _conversations[index];
                    final otherUserId = chat['other_user_id'];
                    final lastTime = chat['last_message_time'] != null
                        ? DateTime.parse(chat['last_message_time']).toLocal()
                        : DateTime.now();
                    final timeStr =
                        DateFormat('MMM d, h:mm a').format(lastTime);
                    final unread = chat['unread_count'] ?? 0;
                    final isTutor = chat['is_tutor'] ?? false;
                    final avatarUrl = chat['avatar_url'];

                    return Dismissible(
                      key: Key('chat_$otherUserId'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.delete,
                            color: theme.colorScheme.onError),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: theme.cardTheme.color,
                              title: Text("Delete Conversation?",
                                  style: theme.textTheme.titleLarge),
                              content: Text(
                                  "This will permanently delete all messages with this user.",
                                  style: theme.textTheme.bodyMedium),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text("Cancel",
                                        style: TextStyle(
                                            color: theme.disabledColor))),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text("Delete",
                                      style: TextStyle(
                                          color: theme.colorScheme.error)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        // Optimistic remove
                        setState(() {
                          _conversations.removeAt(index);
                        });
                        _deleteConversation(otherUserId);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                theme.dividerColor.withValues(alpha: 0.1),
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Icon(isTutor ? Icons.school : Icons.person,
                                    color: isTutor
                                        ? Colors.amber
                                        : theme.primaryColor)
                                : null,
                          ),
                          title: Text(
                            chat['full_name'] ?? 'User',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                chat['last_message'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: unread > 0
                                      ? theme.textTheme.bodyMedium?.color
                                      : theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.7),
                                  fontWeight: unread > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: unread > 0
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unread.toString(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => _openChat(chat),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'models/notification.dart';
import 'services/logger_service.dart';
import 'schedule_page.dart';
import 'chat_page.dart';
import 'models/user_profile.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supabase = Supabase.instance.client;
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .eq('read', false) // Only fetch unread
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications =
            (data as List).map((e) => AppNotification.fromJson(e)).toList();
      });
    } catch (e) {
      logger.error("Error fetching notifications", error: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await supabase.from('notifications').update({'read': true}).eq('id', id);
      // No need to re-fetch, local UI handles removal in _handleTap
    } catch (e) {
      logger.error("Error marking read", error: e);
    }
  }

  Future<void> _handleTap(AppNotification note) async {
    // 1. Mark as read on server
    if (!note.read) {
      await _markAsRead(note.id);
    }

    // 2. Visually "Clear" it from the list immediately (User Request)
    setState(() {
      _notifications.removeWhere((n) => n.id == note.id);
    });

    if (!mounted) return;

    // 2. Navigate based on type
    if (note.type == 'message' || note.type == 'chat_message') {
      final senderId = note.data?['sender_id'];
      if (senderId != null) {
        // We need the profile object for ChatPage
        // ideally we fetch it.
        try {
          final profileData = await supabase
              .from('profiles')
              .select()
              .eq('user_id', senderId)
              .maybeSingle();

          if (profileData != null && mounted) {
            final profile = UserProfile.fromJson(profileData);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatPage(otherUser: profile)),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Could not load chat: $e")));
        }
      }
    } else if (note.type.startsWith('appointment_') || note.type == 'booking') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SchedulePage()),
      );
    } else if (note.type.contains('request')) {
      // Navigate to Requests (if we have a page, or just show dialog)
      // We don't have a standalone RequestsPage yet exposed easily?
      // Actually we do have RequestsPage possibly if imported.
      // Or just SchedulePage if it handles requests? No, `requests_page.dart` exists?
      // Let's check imports.
      // Trying generic SchedulePage for now as it holds many requests.
      // Or map triggers usually happen there.
    }
  }

  Future<void> _markAllAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Optimistically clear the list (since we only show unread)
    setState(() {
      _notifications.clear();
    });

    try {
      await supabase
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('read', false);
    } catch (e) {
      logger.error("Error marking all as read", error: e);
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await supabase.from('notifications').delete().eq('id', id);
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
    } catch (e) {
      logger.error("Delete failed", error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              style: TextButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.5)),
              child: const Text("Clear All"),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Text("No notifications",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.5))))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final note = _notifications[index];
                    final timeStr = DateFormat('MMM d, h:mm a')
                        .format(note.createdAt.toLocal());

                    IconData icon;
                    Color iconColor;

                    if (note.type == 'message') {
                      icon = Icons.chat_bubble;
                      iconColor = theme.colorScheme.secondary;
                    } else if (note.type.contains('appointment')) {
                      icon = Icons.calendar_month;
                      iconColor = Colors.amber;
                    } else if (note.type == 'appointment_cancelled') {
                      icon = Icons.cancel;
                      iconColor = theme.colorScheme.error;
                    } else {
                      icon = Icons.notifications;
                      iconColor = theme.primaryColor;
                    }

                    return Dismissible(
                      key: Key(note.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteNotification(note.id),
                      background: Container(
                        color: theme.colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete,
                            color: theme.colorScheme.onError),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withValues(alpha: 0.2),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        title: Text(
                          note.title,
                          style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: note.read
                                  ? FontWeight.normal
                                  : FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              note.body,
                              style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.7)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.3),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => _handleTap(note),
                        trailing: !note.read
                            ? CircleAvatar(
                                radius: 5,
                                backgroundColor: theme.colorScheme.error)
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}

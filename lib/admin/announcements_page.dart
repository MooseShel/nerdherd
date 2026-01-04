import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import 'package:intl/intl.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final supabase = Supabase.instance.client;
  List<Announcement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _announcements =
              data.map((json) => Announcement.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAnnouncement() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                  labelText: 'Title', hintText: 'e.g., Maintenance Notice'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                  labelText: 'Message', hintText: 'Details...'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  messageController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await supabase.from('announcements').insert({
          'title': titleController.text,
          'message': messageController.text,
          'is_active': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Announcement posted successfully!')));
          _fetchAnnouncements();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _endAnnouncement(Announcement announcement) async {
    try {
      await supabase
          .from('announcements')
          .update({'is_active': false}).eq('id', announcement.id);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Announcement ended.')));
        _fetchAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _createAnnouncement,
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? Center(
                  child: Text('No announcements history',
                      style: theme.textTheme.bodyLarge))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final item = _announcements[index];
                    return Card(
                      elevation: 0,
                      color: theme.cardTheme.color,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color:
                                  theme.dividerColor.withValues(alpha: 0.1))),
                      child: ListTile(
                        title: Text(item.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.message),
                            const SizedBox(height: 8),
                            Text(
                              'Posted: ${DateFormat('MMM d, HH:mm').format(item.createdAt)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: item.isActive
                            ? IconButton(
                                icon: const Icon(Icons.stop_circle_outlined,
                                    color: Colors.red),
                                tooltip: 'End Announcement',
                                onPressed: () => _endAnnouncement(item),
                              )
                            : Chip(
                                label: const Text('Ended',
                                    style: TextStyle(fontSize: 10)),
                                backgroundColor:
                                    theme.disabledColor.withValues(alpha: 0.1),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

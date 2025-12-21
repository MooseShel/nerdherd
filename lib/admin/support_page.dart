import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/admin_provider.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../chat_page.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  final Map<String, TextEditingController> _replyControllers = {};

  Future<void> _sendReply(String ticketId, String reply) async {
    if (reply.isEmpty) return;
    try {
      await Supabase.instance.client.from('support_tickets').update(
          {'admin_reply': reply, 'status': 'in_progress'}).eq('id', ticketId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Reply saved and ticket status updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openChat(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      final profile = UserProfile.fromJson(data);
      if (mounted) {
        Navigator.pop(context); // Close admin portal? Or just push?
        // Usually better to push ChatPage.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(otherUser: profile)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _resolveTicket(String ticketId) async {
    try {
      await ref.read(adminControllerProvider.notifier).resolveTicket(ticketId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ticket Resolved')));
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
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return ticketsAsync.when(
      data: (tickets) {
        if (tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.thumb_up_alt_outlined,
                    size: 64, color: theme.disabledColor),
                const SizedBox(height: 16),
                Text('All caught up! No open tickets.',
                    style: theme.textTheme.bodyLarge),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return ExpansionTile(
              collapsedBackgroundColor: theme.cardTheme.color,
              backgroundColor: theme.cardTheme.color,
              textColor: theme.textTheme.bodyLarge?.color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.help_outline, color: Colors.cyan),
              title: Text(ticket.subject,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'From: ...${ticket.userId.substring(0, 5)}... • ${DateFormat('MM/dd').format(ticket.createdAt)}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(ticket.message, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      if (ticket.adminReply != null) ...[
                        Text('Admin Reply:',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(ticket.adminReply!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic)),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _replyControllers.putIfAbsent(
                            ticket.id, () => TextEditingController()),
                        decoration: const InputDecoration(
                          hintText: 'Type reply...',
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openChat(ticket.userId),
                              icon: const Icon(Icons.chat_bubble_outline,
                                  size: 16),
                              label: const Text('Chat'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _sendReply(ticket.id,
                                  _replyControllers[ticket.id]!.text.trim()),
                              child: const Text('Reply'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _resolveTicket(ticket.id),
                        icon: const Icon(Icons.check),
                        label: const Text('Mark as Resolved'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white),
                      )
                    ],
                  ),
                )
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

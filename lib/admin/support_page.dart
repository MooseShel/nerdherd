import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import 'package:intl/intl.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
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

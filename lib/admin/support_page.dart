import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_ticket.dart';
import 'package:intl/intl.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final supabase = Supabase.instance.client;
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('support_tickets')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: true) // Oldest first
          .limit(50);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _tickets = data.map((json) => SupportTicket.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveTicket(String ticketId) async {
    try {
      await supabase
          .from('support_tickets')
          .update({'status': 'closed'}).eq('id', ticketId);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ticket Resolved')));
        _fetchTickets();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_tickets.isEmpty) {
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
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return ExpansionTile(
          collapsedBackgroundColor: theme.cardTheme.color,
          backgroundColor: theme.cardTheme.color,
          textColor: theme.textTheme.bodyLarge?.color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }
}

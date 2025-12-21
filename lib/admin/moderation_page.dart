import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../providers/admin_provider.dart';

class ModerationPage extends ConsumerStatefulWidget {
  const ModerationPage({super.key});

  @override
  ConsumerState<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends ConsumerState<ModerationPage> {
  final supabase = Supabase.instance.client;
  List<Report> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('reports')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _reports = data.map((json) => Report.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      await supabase
          .from('reports')
          .update({'status': 'dismissed'}).eq('id', reportId);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Report dismissed')));
        _fetchReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _banUser(String reportId, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban User?'),
        content: const Text('This will ban the reported user indefinitely.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('BAN USER'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 1. Ban User via Provider
        await ref.read(adminControllerProvider.notifier).banUser(userId);

        // 2. Resolve Report
        await supabase
            .from('reports')
            .update({'status': 'resolved'}).eq('id', reportId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User Banned & Report Resolved')));
          _fetchReports();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text('No pending reports', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        return Card(
          elevation: 0,
          color: theme.cardTheme.color,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('Reason: ${report.reason}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Reported User ID: ${report.reportedId}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace')),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _dismissReport(report.id),
                      child: const Text('DISMISS'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _banUser(report.id, report.reportedId),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      child: const Text('BAN USER'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

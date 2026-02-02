import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppealReviewPage extends StatefulWidget {
  const AppealReviewPage({super.key});

  @override
  State<AppealReviewPage> createState() => _AppealReviewPageState();
}

class _AppealReviewPageState extends State<AppealReviewPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _appeals = [];
  final Set<String> _selectedIds = {}; // Track selected items
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppeals();
  }

  Future<void> _fetchAppeals() async {
    try {
      setState(() => _isLoading = true);
      // Fetch pending requests and join with profiles
      final response = await supabase
          .from('activation_requests')
          .select('*, profiles:user_id(*)')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _appeals = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
          _selectedIds.clear(); // Clear selections on refresh
        });
      }
    } catch (e) {
      debugPrint('Error fetching appeals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _appeals.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_appeals.map((a) => a['id'] as String));
      }
    });
  }

  Future<void> _processBulk(bool approve) async {
    if (_selectedIds.isEmpty) return;

    try {
      final idsToProcess = _selectedIds.toList();

      if (approve) {
        // 1. Get user IDs associated with selected appeals
        final selectedAppeals =
            _appeals.where((a) => _selectedIds.contains(a['id']));
        final userIds = selectedAppeals.map((a) => a['user_id']).toList();

        // 2. Reactivate users
        await supabase
            .from('profiles')
            .update({'is_active': true}).inFilter('user_id', userIds);

        // 3. Mark approved
        await supabase
            .from('activation_requests')
            .update({'status': 'approved'}).inFilter('id', idsToProcess);
      } else {
        // Just mark rejected
        await supabase
            .from('activation_requests')
            .update({'status': 'rejected'}).inFilter('id', idsToProcess);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? "${idsToProcess.length} appeals approved & users reactivated"
                : "${idsToProcess.length} appeals rejected"),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
        _fetchAppeals();
      }
    } catch (e) {
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_appeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 60, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text("No pending appeals", style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Bulk Actions Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: _selectedIds.isNotEmpty &&
                    _selectedIds.length == _appeals.length,
                onChanged: (_) => _toggleSelectAll(),
              ),
              Text(
                "${_selectedIds.length} Selected",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_selectedIds.isNotEmpty) ...[
                OutlinedButton(
                  onPressed: () => _processBulk(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: const Text("Reject Selected"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _processBulk(true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  child: const Text("Approve Selected"),
                ),
              ]
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _appeals.length,
            itemBuilder: (context, index) {
              final appeal = _appeals[index];
              final id = appeal['id'] as String;
              final profile = appeal['profiles'] as Map<String, dynamic>? ?? {};
              final name = profile['full_name'] ?? 'Unknown User';
              final message = appeal['message'] ?? 'No message provided.';
              final createdAt = appeal['created_at'] != null
                  ? DateTime.parse(appeal['created_at'])
                      .toLocal()
                      .toString()
                      .split('.')[0]
                  : '';
              final isSelected = _selectedIds.contains(id);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? BorderSide(color: theme.primaryColor, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => _toggleSelection(id),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) => _toggleSelection(id),
                            ),
                            CircleAvatar(
                              backgroundColor:
                                  theme.primaryColor.withValues(alpha: 0.1),
                              child: Text(name.substring(0, 1).toUpperCase()),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  Text("Submitted: $createdAt",
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        const Text("Appeal Message:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            message,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

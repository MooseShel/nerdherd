import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReviewsListDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const ReviewsListDialog(
      {super.key, required this.userId, required this.userName});

  @override
  State<ReviewsListDialog> createState() => _ReviewsListDialogState();
}

class _ReviewsListDialogState extends State<ReviewsListDialog> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      // Fetch reviews with reviewer details
      // Note: We use the foreign key 'reviewer_id' to join profiles.
      // Syntax: table!fk_column(columns)
      final data = await supabase
          .from('reviews')
          .select(
              '*, reviewer:profiles!reviewer_id(full_name, avatar_url, intent_tag)')
          .eq('reviewee_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading reviews: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text("Reviews for ${widget.userName}"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // Fixed height for scrollable list
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
                ? Center(
                    child: Text("No reviews yet.",
                        style: theme.textTheme.bodySmall))
                : ListView.builder(
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      final reviewer = review['reviewer'] ?? {};
                      final rating = review['rating'] as int;
                      final comment = review['comment'] as String?;
                      final date =
                          DateTime.parse(review['created_at']).toLocal();

                      final reviewerName = reviewer['full_name'] ?? "Unknown";
                      final reviewerTag = reviewer['intent_tag'] ?? "Peer";
                      final avatarUrl = reviewer['avatar_url'];

                      return Card(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: avatarUrl != null
                                        ? (avatarUrl.startsWith('assets/')
                                            ? AssetImage(avatarUrl)
                                                as ImageProvider
                                            : ResizeImage(
                                                NetworkImage(avatarUrl),
                                                width: 64,
                                              ))
                                        : null,
                                    child: avatarUrl == null
                                        ? const Icon(Icons.person, size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(reviewerName,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        Text(reviewerTag,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Text(DateFormat('MMM d').format(date),
                                      style: TextStyle(
                                          color: theme
                                              .textTheme.bodySmall?.color
                                              ?.withValues(alpha: 0.4),
                                          fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                              if (comment != null && comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  comment,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.8)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}

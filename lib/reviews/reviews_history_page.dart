import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/empty_state_widget.dart';
import '../models/user_profile.dart';

class ReviewsHistoryPage extends StatefulWidget {
  const ReviewsHistoryPage({super.key});

  @override
  State<ReviewsHistoryPage> createState() => _ReviewsHistoryPageState();
}

class _ReviewsHistoryPageState extends State<ReviewsHistoryPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _givenReviews = [];
  List<Map<String, dynamic>> _receivedReviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Given Reviews
      final givenData = await supabase
          .from('reviews')
          .select('*, reviewee:profiles!reviewee_id(*)')
          .eq('reviewer_id', user.id)
          .order('created_at', ascending: false);

      // Received Reviews
      final receivedData = await supabase
          .from('reviews')
          .select('*, reviewer:profiles!reviewer_id(*)')
          .eq('reviewee_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _givenReviews = List<Map<String, dynamic>>.from(givenData);
          _receivedReviews = List<Map<String, dynamic>>.from(receivedData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReply(String reviewId, String reply) async {
    try {
      await supabase
          .from('reviews')
          .update({'reply': reply}).eq('id', reviewId);
      _fetchReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply posted successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showReplyDialog(String reviewId, String? currentReply) {
    final controller = TextEditingController(text: currentReply);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to Review'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Type your response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _submitReply(reviewId, controller.text.trim());
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text("Reviews", style: theme.textTheme.titleLarge),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Given"),
              Tab(text: "Received"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildReviewList(_givenReviews, true),
                  _buildReviewList(_receivedReviews, false),
                ],
              ),
      ),
    );
  }

  Widget _buildReviewList(List<Map<String, dynamic>> reviews, bool isGiven) {
    final theme = Theme.of(context);
    if (reviews.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.rate_review_outlined,
          title: "No reviews yet",
          description: isGiven
              ? "You haven't reviewed anyone yet."
              : "No one has reviewed you yet.",
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final review = reviews[index];
        final otherUser = isGiven
            ? (review['reviewee'] != null
                ? UserProfile.fromJson(review['reviewee'])
                : null)
            : (review['reviewer'] != null
                ? UserProfile.fromJson(review['reviewer'])
                : null);

        final rating = review['rating'] as int;
        final comment = review['comment'] as String?;
        final reply = review['reply'] as String?;
        final date = DateTime.parse(review['created_at']).toLocal();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: otherUser?.avatarUrl != null
                        ? NetworkImage(otherUser!.avatarUrl!)
                        : null,
                    child: otherUser?.avatarUrl == null
                        ? Text(otherUser?.fullName?.substring(0, 1) ?? "?")
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGiven
                              ? "Reviewed ${otherUser?.fullName ?? 'Unknown'}"
                              : "${otherUser?.fullName ?? 'Anonymous'} reviewed you",
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateFormat.yMMMd().format(date),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.disabledColor),
                        ),
                      ],
                    ),
                  ),
                  _buildRatingBadge(rating),
                ],
              ),
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  "\"$comment\"",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
              ],
              if (reply != null && reply.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.reply,
                              size: 14, color: theme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            "Your Reply",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reply,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
              if (!isGiven && (reply == null || reply.isEmpty)) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _showReplyDialog(review['id'].toString(), reply),
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text("Reply"),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingBadge(int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            rating.toString(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.amber),
          ),
        ],
      ),
    );
  }
}

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
  List<Map<String, dynamic>> _reviews = [];
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

      // Fetch reviews created by me
      final data = await supabase
          .from('reviews')
          .select('*, reviewee:profiles!reviewee_id(*)')
          .eq('reviewer_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback: manual fetch if relation fails (though explicit FK exists)
        // Ignoring error for now or fallback logic could go here
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("My Reviews", style: theme.textTheme.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? const Center(
                  child: EmptyStateWidget(
                    icon: Icons.rate_review_outlined,
                    title: "No reviews yet",
                    description: "You haven't reviewed any sessions yet.",
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final review = _reviews[index];
                    final reviewee = review['reviewee'] != null
                        ? UserProfile.fromJson(review['reviewee'])
                        : null;
                    final rating = review['rating'] as int;
                    final comment = review['comment'] as String?;
                    final date = DateTime.parse(review['created_at']).toLocal();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: reviewee?.avatarUrl != null
                                    ? NetworkImage(reviewee!.avatarUrl!)
                                    : null,
                                child: reviewee?.avatarUrl == null
                                    ? Text(
                                        reviewee?.fullName?.substring(0, 1) ??
                                            "?")
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Reviewed ${reviewee?.fullName ?? 'Unknown User'}",
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      DateFormat.yMMMd().format(date),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: theme.disabledColor),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 14, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (comment != null && comment.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              "\"$comment\"",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

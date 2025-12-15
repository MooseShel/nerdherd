import 'package:flutter/material.dart';

class ReviewDialog extends StatefulWidget {
  final String revieweeName;

  const ReviewDialog({super.key, required this.revieweeName});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      title: Text("Rate ${widget.revieweeName}",
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () => setState(() => _rating = index + 1),
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: "Comment (optional)",
                labelStyle: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                filled: true,
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.primaryColor),
                    borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: TextStyle(color: theme.disabledColor)),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'rating': _rating,
              'comment': _commentController.text,
            });
          },
          style: FilledButton.styleFrom(backgroundColor: theme.primaryColor),
          child: const Text("Submit"),
        ),
      ],
    );
  }
}

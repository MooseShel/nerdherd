import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/logger_service.dart';

/// Dialog shown when a serendipity match is found
class SerendipityMatchDialog extends ConsumerStatefulWidget {
  final UserProfile otherUser;
  final String subject;
  final String? matchId;

  const SerendipityMatchDialog({
    super.key,
    required this.otherUser,
    required this.subject,
    this.matchId,
  });

  @override
  ConsumerState<SerendipityMatchDialog> createState() =>
      _SerendipityMatchDialogState();
}

class _SerendipityMatchDialogState
    extends ConsumerState<SerendipityMatchDialog> {
  bool _isConnecting = false;
  final _supabase = Supabase.instance.client;

  Future<void> _sendConnectionRequest() async {
    setState(() => _isConnecting = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Check if connection already exists
      final existing = await _supabase
          .from('connections')
          .select()
          .or('and(user_id.eq.$currentUserId,connected_user_id.eq.${widget.otherUser.userId}),and(user_id.eq.${widget.otherUser.userId},connected_user_id.eq.$currentUserId)')
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already connected!')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Send connection request
      await _supabase.from('collab_requests').insert({
        'sender_id': currentUserId,
        'receiver_id': widget.otherUser.userId,
        'status': 'pending',
      });

      // Mark match as accepted
      if (widget.matchId != null) {
        await _supabase
            .from('serendipity_matches')
            .update({'accepted': true}).eq('id', widget.matchId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Connection request sent to ${widget.otherUser.fullName ?? "User"}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      logger.error('Error sending connection request', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _dismiss() async {
    // Mark match as seen but not accepted
    if (widget.matchId != null) {
      try {
        await _supabase
            .from('serendipity_matches')
            .update({'accepted': false}).eq('id', widget.matchId!);
      } catch (e) {
        logger.error('Error updating match status', error: e);
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Colors.amber, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Serendipity Match!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _dismiss,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // User Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: widget.otherUser.avatarUrl != null
                        ? NetworkImage(widget.otherUser.avatarUrl!)
                        : null,
                    child: widget.otherUser.avatarUrl == null
                        ? Text(
                            widget.otherUser.fullName ?? 'User',
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // User Name
                  Text(
                    widget.otherUser.fullName ?? 'User',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Subject Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.subject,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'This student is nearby and can help with ${widget.subject}!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // User Info
                  if (widget.otherUser.isTutor) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Verified Tutor',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.otherUser.averageRating != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.otherUser.averageRating!.toStringAsFixed(1)} rating',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isConnecting ? null : _dismiss,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Not Now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed:
                              _isConnecting ? null : _sendConnectionRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isConnecting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Connect',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'rating_dialog.dart';
import 'booking_dialog.dart';
import 'reviews_list_dialog.dart';
import '../models/user_profile.dart';
import '../profile_page.dart';
import '../chat_page.dart';
import '../services/logger_service.dart';
import '../services/haptic_service.dart';

import 'ui_components.dart';

class GlassProfileDrawer extends StatefulWidget {
  final UserProfile profile;

  const GlassProfileDrawer({super.key, required this.profile});

  @override
  State<GlassProfileDrawer> createState() => _GlassProfileDrawerState();
}

class _GlassProfileDrawerState extends State<GlassProfileDrawer> {
  bool _isLoading = false;
  String? _fetchedUniversityName;
  bool _requestSent = false;
  bool _isConnected = false;
  bool _canRate = false; // New: Verified session exists
  String? _incomingRequestId;

  final supabase = Supabase.instance.client;

  // Use a getter for current user to ensure it's fresh
  User? get currentUser => supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (currentUser == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      // 0. Fetch University Name if missing
      if (widget.profile.universityName == null &&
          widget.profile.universityId != null) {
        final uni = await supabase
            .from('universities')
            .select('name')
            .eq('id', widget.profile.universityId!)
            .maybeSingle();
        if (uni != null && mounted) {
          setState(() {
            _fetchedUniversityName = uni['name'];
          });
        }
      }

      // 1. Check if already connected (Friends)
      final connection = await supabase
          .from('connections')
          .select()
          .or('and(user_id_1.eq.${currentUser!.id},user_id_2.eq.${widget.profile.userId}),and(user_id_1.eq.${widget.profile.userId},user_id_2.eq.${currentUser!.id})')
          .maybeSingle();

      if (connection != null) {
        // Connected! Now check if I can rate (i.e. if I am a student and they are a tutor AND a session exists)
        final session = await supabase
            .from('sessions')
            .select()
            .eq('tutor_id', widget.profile.userId)
            .eq('student_id', currentUser!.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _isConnected = true;
            _canRate = session != null;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Check if I sent a request (Pending)
      final myRequest = await supabase
          .from('collab_requests')
          .select()
          .eq('sender_id', currentUser!.id)
          .eq('receiver_id', widget.profile.userId)
          .eq('status', 'pending')
          .maybeSingle();

      if (myRequest != null) {
        if (mounted) {
          setState(() {
            _requestSent = true;
            _isLoading = false;
          });
        }
        return;
      }

      // 3. Check if they sent me a request (Incoming)
      final incomingRequest = await supabase
          .from('collab_requests')
          .select()
          .eq('sender_id', widget.profile.userId)
          .eq('receiver_id', currentUser!.id)
          .eq('status', 'pending')
          .maybeSingle();

      if (incomingRequest != null) {
        if (mounted) {
          setState(() {
            _incomingRequestId = incomingRequest['id'].toString();
            _isLoading = false;
          });
        }
        return;
      }

      // Nothing found
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      logger.error("Error checking connection status", error: e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRating(int rating, String comment) async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      await supabase.from('ratings').insert({
        'rater_id': currentUser!.id,
        'rated_id': widget.profile.userId,
        'rating': rating,
        'comment': comment,
        // 'session_id': ... Ideally track which session, but for 'any valid session' check, this is fine for MVP.
        // We verified a session EXISTS in _checkStatus. RLS will verify it again.
        // To be strict, RLS needs to find ANY valid session. My RLS policy does check `EXISTS (select 1 from public.sessions ...)` so it works.
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text("Review submitted!"),
              backgroundColor: Theme.of(context).colorScheme.tertiary),
        );
        // RatingDialog handles close via onSubmit if we want, or here.
        // But RatingDialog doesn't pop itself. I need to ensure it pops.
        // Usually dialogs are popped by the caller or the dialog itself.
        // My RatingDialog calls `widget.onSubmit`. It does NOT pop.
        // So I must pop here:
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error submitting review: $e"),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => RatingDialog(
        tutorName: widget.profile.fullName ?? "this tutor",
        onSubmit: (rating, comment) {
          // Note: ctx is the dialog context
          _submitRating(rating, comment);
          // Navigator pop is in _submitRating?
          // _submitRating is async. It pops 'context'.
          // If I pass 'ctx' to _submitRating it would be cleaner, but 'context' works if strict.
          // Wait, _submitRating uses 'context' which is the Page context.
          // `Navigator.pop(context)` pops the top route = Dialog. Correct.
        },
      ),
    );
  }

  Future<void> _sendRequest() async {
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("You must be logged in to send requests.")),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.from('collab_requests').insert({
        'sender_id': currentUser!.id,
        'receiver_id': widget.profile.userId,
        'status': 'pending',
      });

      if (mounted) {
        setState(() {
          _requestSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Request sent to ${widget.profile.intentTag ?? 'peer'}!"),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      logger.error("Error sending request", error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send request: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reportUser() async {
    if (currentUser == null) return;

    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report ${widget.profile.fullName ?? "User"}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe the issue:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration:
                  const InputDecoration(hintText: 'Spam, harassment, etc.'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('REPORT'),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.isNotEmpty) {
      try {
        await supabase.from('reports').insert({
          'reporter_id': currentUser!.id,
          'reported_id': widget.profile.userId,
          'reason': reasonController.text,
          'status': 'pending',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Report submitted. We will investigate.'),
              backgroundColor: Theme.of(context).colorScheme.secondary));
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
    final isMe = currentUser?.id == widget.profile.userId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      blur: 20,
      opacity: isDark ? 0.9 : 1.0,
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with premium glow
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.profile.isTutor
                              ? Colors.amber.withValues(alpha: 0.8)
                              : theme.primaryColor.withValues(alpha: 0.8),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.profile.isTutor
                                    ? Colors.amber
                                    : theme.primaryColor)
                                .withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: -2,
                          )
                        ],
                      ),
                      child: Hero(
                        tag: 'avatar_${widget.profile.userId}',
                        child: CircleAvatar(
                          radius: 36, // Slightly larger
                          backgroundColor: theme.scaffoldBackgroundColor,
                          backgroundImage: widget.profile.avatarUrl != null
                              ? (widget.profile.avatarUrl!.startsWith('assets/')
                                  ? AssetImage(widget.profile.avatarUrl!)
                                      as ImageProvider
                                  : ResizeImage(
                                      CachedNetworkImageProvider(
                                          widget.profile.avatarUrl!),
                                      width: 200,
                                    ))
                              : null,
                          child: widget.profile.avatarUrl == null
                              ? Icon(
                                  widget.profile.isTutor
                                      ? Icons.school
                                      : Icons.person,
                                  color: widget.profile.isTutor
                                      ? Colors.amber
                                      : theme.primaryColor,
                                  size: 32,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.profile.fullName?.isNotEmpty == true
                                      ? widget.profile.fullName!
                                      : (widget.profile.isTutor
                                          ? "Verified Tutor"
                                          : "Student Peer"),
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              if (widget.profile.isTutor)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.verified,
                                      color: Colors.amber, size: 22),
                                ),
                            ],
                          ),
                          if (widget.profile.universityName != null ||
                              _fetchedUniversityName != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.school,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.profile.universityName ??
                                        _fetchedUniversityName!,
                                    style: TextStyle(
                                        color: theme.textTheme.bodySmall?.color
                                            ?.withValues(alpha: 0.7),
                                        fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          if (isMe)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    theme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: theme.primaryColor
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                "This is You",
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Text(
                              widget.profile.intentTag ?? "Hanging out",
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          if (widget.profile.isTutor &&
                              widget.profile.hourlyRate != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              "\$${widget.profile.hourlyRate}/hr",
                              style: TextStyle(
                                color: theme.colorScheme.tertiary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                          if (widget.profile.averageRating != null) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ReviewsListDialog(
                                    userId: widget.profile.userId,
                                    userName: widget.profile.fullName ?? "User",
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.amber, size: 20),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${widget.profile.averageRating!.toStringAsFixed(1)} ",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    Flexible(
                                      child: Text(
                                        "(${widget.profile.reviewCount ?? 0} reviews)",
                                        style: TextStyle(
                                          color: theme
                                              .textTheme.bodySmall?.color
                                              ?.withValues(alpha: 0.6),
                                          fontSize: 13,
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  ],
                ),

                if (widget.profile.bio?.isNotEmpty == true) ...[
                  const SizedBox(height: 32),
                  const SectionHeader(title: "About"),
                  const SizedBox(height: 8),
                  Text(
                    widget.profile.bio!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        fontSize: 15,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.8)),
                  ),
                ],

                const SizedBox(height: 32),

                // Report Button
                if (!isMe)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _reportUser,
                      icon: Icon(Icons.flag_outlined,
                          size: 18,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.5)),
                      label: Text('Report User',
                          style: TextStyle(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ),
                  ),

                const SectionHeader(title: "Current Classes"),
                const SizedBox(height: 12),

                if (widget.profile.currentClasses.isEmpty)
                  Text("No classes listed",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic)),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.profile.currentClasses.map<Widget>((cls) {
                    return GlassContainer(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      borderRadius: BorderRadius.circular(20),
                      color: theme.cardColor.withValues(alpha: 0.5),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        // Constraint prevents massive chip overflow
                        child: Text(
                          cls,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 40),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: isMe
                          ? SecondaryButton(
                              label: "Edit Profile",
                              icon: Icons.edit_outlined,
                              onPressed: () {
                                hapticService.mediumImpact();
                                Navigator.pop(context); // Close drawer
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfilePage()),
                                );
                              },
                            )
                          : _isConnected
                              ? PrimaryButton(
                                  label: "Message",
                                  icon: Icons.chat_bubble_outline,
                                  onPressed: () {
                                    hapticService.lightImpact();
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatPage(
                                          otherUser: widget.profile,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : _incomingRequestId != null
                                  ? PrimaryButton(
                                      label: "Check Notifications",
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Check your Map Notifications!")));
                                      },
                                    )
                                  : PrimaryButton(
                                      label: _requestSent
                                          ? "Request Sent"
                                          : "Connect",
                                      isLoading: _isLoading,
                                      onPressed: (_isLoading || _requestSent)
                                          ? null
                                          : () {
                                              hapticService.lightImpact();
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text("Connect?"),
                                                  content: Text(
                                                    "Send a connection request to ${widget.profile.fullName ?? 'this peer'}?",
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx),
                                                      child:
                                                          const Text("Cancel"),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () {
                                                        Navigator.pop(ctx);
                                                        _sendRequest();
                                                      },
                                                      child: const Text("Send"),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                    ),
                    ),
                    if (!isMe && widget.profile.isTutor) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            hapticService.mediumImpact();
                            showDialog(
                              context: context,
                              builder: (context) => BookingDialog(
                                tutorId: widget.profile.userId,
                                tutorName: widget.profile.fullName ?? "Tutor",
                                hourlyRate:
                                    (widget.profile.hourlyRate ?? 0).toDouble(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.tertiary,
                            foregroundColor: theme.colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Book Session",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Separated Rate User Button (Only if verified session exists)
                if (!isMe && _isConnected && _canRate) ...[
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: "Rate User",
                    icon: Icons.star_rate_rounded,
                    fullWidth: true,
                    onPressed: () {
                      hapticService.lightImpact();
                      _showRatingDialog();
                    },
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

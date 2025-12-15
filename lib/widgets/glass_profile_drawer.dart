import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'rating_dialog.dart';
import 'booking_dialog.dart';
import 'reviews_list_dialog.dart';
import '../models/user_profile.dart';
import '../profile_page.dart';
import '../chat_page.dart';
import '../services/logger_service.dart';
import '../services/haptic_service.dart';

class GlassProfileDrawer extends StatefulWidget {
  final UserProfile profile;

  const GlassProfileDrawer({super.key, required this.profile});

  @override
  State<GlassProfileDrawer> createState() => _GlassProfileDrawerState();
}

class _GlassProfileDrawerState extends State<GlassProfileDrawer> {
  bool _isLoading = false;
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
          const SnackBar(
              content: Text("Review submitted!"),
              backgroundColor: Colors.green),
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
              backgroundColor: Colors.red),
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = currentUser?.id == widget.profile.userId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Modern glass effect colors
    final glassColor = theme.cardTheme.color?.withOpacity(0.85) ??
        (isDark
            ? const Color(0xFF1C1C1E).withOpacity(0.85)
            : const Color(0xFFF2F2F7).withOpacity(0.85));

    final borderColor = theme.dividerColor.withOpacity(0.1);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(
              top: BorderSide(color: borderColor, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 1,
                offset: const Offset(0, -5),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
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
                          color: isDark ? Colors.white30 : Colors.black26,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with premium glow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.profile.isTutor
                                  ? Colors.amber.withOpacity(0.8)
                                  : theme.primaryColor.withOpacity(0.8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (widget.profile.isTutor
                                        ? Colors.amber
                                        : theme.primaryColor)
                                    .withOpacity(0.2),
                                blurRadius: 15,
                                spreadRadius: -2,
                              )
                            ],
                          ),
                          child: Hero(
                            tag: 'avatar_${widget.profile.userId}',
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: theme.scaffoldBackgroundColor,
                              backgroundImage: widget.profile.avatarUrl != null
                                  ? (widget.profile.avatarUrl!
                                          .startsWith('assets/')
                                      ? AssetImage(widget.profile.avatarUrl!)
                                          as ImageProvider
                                      : NetworkImage(widget.profile.avatarUrl!))
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
                                      widget.profile.fullName?.isNotEmpty ==
                                              true
                                          ? widget.profile.fullName!
                                          : (widget.profile.isTutor
                                              ? "Verified Tutor"
                                              : "Student Peer"),
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  if (widget.profile.isTutor)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.verified,
                                          color: Colors.amber, size: 20),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (isMe)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "This is You",
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  widget.profile.intentTag ?? "Hanging out",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                              if (widget.profile.isTutor &&
                                  widget.profile.hourlyRate != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  "\$${widget.profile.hourlyRate}/hr",
                                  style: TextStyle(
                                    color: Colors.greenAccent[
                                        400], // Keep generic green for money
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (widget.profile.averageRating != null) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ReviewsListDialog(
                                        userId: widget.profile.userId,
                                        userName:
                                            widget.profile.fullName ?? "User",
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
                                            color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${widget.profile.averageRating!.toStringAsFixed(1)} ",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "(${widget.profile.reviewCount ?? 0} reviews)",
                                          style: TextStyle(
                                            color: theme
                                                .textTheme.bodySmall?.color
                                                ?.withOpacity(0.6),
                                            fontSize: 13,
                                            decoration:
                                                TextDecoration.underline,
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
                      const SizedBox(height: 24),
                      Text(
                        "ABOUT",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.textTheme.labelSmall?.color
                              ?.withOpacity(0.5),
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.profile.bio!,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Text(
                      "CURRENT CLASSES",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            theme.textTheme.labelSmall?.color?.withOpacity(0.5),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (widget.profile.currentClasses.isEmpty)
                      Text("No classes listed",
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic)),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          widget.profile.currentClasses.map<Widget>((cls) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            cls,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: isMe
                              ? ElevatedButton(
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.cardColor,
                                    foregroundColor:
                                        theme.textTheme.bodyMedium?.color,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: theme.dividerColor
                                              .withOpacity(0.2)),
                                    ),
                                  ),
                                  child: const Text("Edit Profile"),
                                )
                              : _isConnected
                                  ? ElevatedButton.icon(
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
                                      icon:
                                          const Icon(Icons.chat_bubble_outline),
                                      label: const Text("Message"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.primaryColor, // Electric Blue
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                      ),
                                    )
                                  : _incomingRequestId != null
                                      ? ElevatedButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        "Check your Map Notifications!")));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.orangeAccent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                          ),
                                          child:
                                              const Text("Incoming Request!"),
                                        )
                                      : ElevatedButton(
                                          onPressed: (_isLoading ||
                                                  _requestSent)
                                              ? null
                                              : () {
                                                  // Connect Confirmation
                                                  hapticService.lightImpact();
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          "Connect?"),
                                                      content: Text(
                                                        "Send a connection request to ${widget.profile.fullName ?? 'this peer'}?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx),
                                                          child: const Text(
                                                              "Cancel"),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            _sendRequest();
                                                          },
                                                          child: const Text(
                                                              "Send"),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.primaryColor,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  _requestSent
                                                      ? "Request Sent"
                                                      : "Connect",
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
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
                                    tutorName:
                                        widget.profile.fullName ?? "Tutor",
                                    hourlyRate: (widget.profile.hourlyRate ?? 0)
                                        .toDouble(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black, // Contrast
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
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
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            hapticService.lightImpact();
                            _showRatingDialog();
                          },
                          icon: const Icon(Icons.star_rate_rounded,
                              color: Colors.amber),
                          label: const Text("Rate User"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber,
                            side: const BorderSide(
                                color: Colors.amber, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

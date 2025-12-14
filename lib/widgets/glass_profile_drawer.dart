import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        if (mounted) {
          setState(() {
            _isConnected = true;
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Review submitted!"),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Close dialog
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
    int selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title:
                const Text("Rate User", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () =>
                          setDialogState(() => selectedRating = index + 1),
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Write a review (optional)",
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  _submitRating(selectedRating, commentController.text);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black),
                child: const Text("Submit"),
              ),
            ],
          );
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F111A).withOpacity(0.85),
            border: Border(
              top: BorderSide(
                color: widget.profile.isTutor
                    ? Colors.amberAccent.withOpacity(0.5)
                    : Colors.cyanAccent.withOpacity(0.5),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.profile.isTutor
                        ? Colors.amberAccent
                        : Colors.cyanAccent)
                    .withOpacity(0.15),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.profile.isTutor
                                    ? Colors.amber
                                    : Colors.cyanAccent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (widget.profile.isTutor
                                          ? Colors.amber
                                          : Colors.cyanAccent)
                                      .withOpacity(0.3),
                                  blurRadius: 12,
                                )
                              ]),
                          child: Hero(
                            tag: 'avatar_${widget.profile.userId}',
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.black87,
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
                                          : Colors.cyanAccent,
                                      size: 28,
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
                                  Text(
                                    widget.profile.fullName?.isNotEmpty == true
                                        ? widget.profile.fullName!
                                        : (widget.profile.isTutor
                                            ? "Verified Tutor"
                                            : "Student Peer"),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                          fontFamily: 'Roboto',
                                        ),
                                  ),
                                  if (widget.profile.fullName?.isNotEmpty ==
                                      true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        isMe
                                            ? (widget.profile.isTutor
                                                ? "Me (Tutor)"
                                                : "Me (Student)")
                                            : (widget.profile.isTutor
                                                ? "Verified Tutor"
                                                : "Student Peer"),
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (widget.profile.isTutor)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(Icons.verified,
                                          color: Colors.amber, size: 20),
                                    )
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.profile.intentTag ?? "Hanging out",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (widget.profile.averageRating != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${widget.profile.averageRating!.toStringAsFixed(1)} (${widget.profile.reviewCount ?? 0})",
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                    ),
                                  ],
                                )
                              ],
                            ],
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      "CURRENT CLASSES",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          widget.profile.currentClasses.map<Widget>((cls) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cls,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

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
                                    backgroundColor: Colors.white24,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text("Edit Profile"),
                                )
                              : _isConnected
                                  ? ElevatedButton.icon(
                                      onPressed: () {
                                        hapticService.lightImpact();
                                        Navigator.pop(context); // Close drawer
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
                                        backgroundColor: Colors.greenAccent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
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
                                              foregroundColor: Colors.black),
                                          child:
                                              const Text("Incoming Request!"),
                                        )
                                      : ElevatedButton(
                                          onPressed: (_isLoading ||
                                                  _requestSent)
                                              ? null
                                              : () {
                                                  hapticService.lightImpact();
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF1E1E1E),
                                                      title: const Text(
                                                          "Connect?",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white)),
                                                      content: Text(
                                                        "Send a connection request to ${widget.profile.fullName ?? widget.profile.intentTag ?? 'this peer'}?",
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white70),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx),
                                                          child: const Text(
                                                              "Cancel",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .grey)),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            _sendRequest();
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors
                                                                      .cyanAccent,
                                                              foregroundColor:
                                                                  Colors.black),
                                                          child: const Text(
                                                              "Send"),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                widget.profile.isTutor
                                                    ? Colors.amber
                                                    : Colors.cyanAccent,
                                            foregroundColor: Colors.black,
                                            disabledBackgroundColor:
                                                Colors.grey[800],
                                            disabledForegroundColor:
                                                Colors.white54,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
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
                                                          FontWeight.bold),
                                                ),
                                        ),
                        ),
                      ],
                    ),

                    // Separated Rate User Button
                    if (!isMe && _isConnected) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            hapticService.lightImpact();
                            _showRatingDialog();
                          },
                          icon:
                              const Icon(Icons.star_rate, color: Colors.amber),
                          label: const Text("Rate User",
                              style: TextStyle(color: Colors.amber)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'models/user_profile.dart';
import 'services/logger_service.dart';
import 'widgets/ui_components.dart';

class ChatPage extends StatefulWidget {
  final UserProfile otherUser;

  const ChatPage({super.key, required this.otherUser});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isOtherUserTyping = false;
  Timer? _typingTimer;
  RealtimeChannel? _channel;
  RealtimeChannel? _typingChannel;

  // Pagination
  static const int _messagesPerPage = 20;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
    _subscribeToTypingStatus();
    _markAsRead();

    // Scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _typingTimer?.cancel();
    _updateTypingStatus(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$myId,receiver_id.eq.${widget.otherUser.userId}),and(sender_id.eq.${widget.otherUser.userId},receiver_id.eq.$myId)')
          .order('created_at', ascending: false) // Newest first for pagination
          .range(0, _messagesPerPage - 1);

      final List<Map<String, dynamic>> newMessages =
          List<Map<String, dynamic>>.from(data);

      // Reverse to display oldest -> newest (top to bottom)
      final reversed = newMessages.reversed.toList();

      if (mounted) {
        setState(() {
          _messages = reversed;
          _isLoading = false;
          _hasMoreMessages = newMessages.length >= _messagesPerPage;
        });

        // Auto-scroll to bottom on initial load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      logger.error("Error fetching messages", error: e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreMessages() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null || _isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);

    try {
      final currentCount = _messages.length;
      final data = await supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$myId,receiver_id.eq.${widget.otherUser.userId}),and(sender_id.eq.${widget.otherUser.userId},receiver_id.eq.$myId)')
          .order('created_at', ascending: false)
          .range(currentCount, currentCount + _messagesPerPage - 1);

      final List<Map<String, dynamic>> olderMessages =
          List<Map<String, dynamic>>.from(data);
      final reversedOlderParams = olderMessages.reversed.toList();

      if (mounted) {
        // Calculate scroll offset adjustment
        // We are inserting at top, so maxScrollExtent will increase.
        // We want to keep the current scroll position relative to the *bottom* (visually stable).
        // Actually, with standard ListView (top-to-bottom), inserting at index 0 pushes content down.
        // We need to adjust scroll position by the height of new content.
        // Since we can't easily measure height before rendering, we'll try maintaining offset from bottom?
        // No, simplest way is to accept the jump or switch to reverse ListView.
        // Let's try to maintain exact pixel position relative to the item that was at top.

        // BETTER APPROACH: Switch UI to Reverse ListView (Bottom-up).
        // But doing that in one go is risky.
        // For now, let's just prepend and see. Flutter usually handles `jumpTo` well if we measure.

        setState(() {
          _messages.insertAll(0, reversedOlderParams);
          _isLoadingMore = false;
          _hasMoreMessages = olderMessages.length >= _messagesPerPage;
        });
      }
    } catch (e) {
      logger.error("Error loading more messages", error: e);
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _subscribeToMessages() {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    _channel = supabase
        .channel('messages:${widget.otherUser.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Handle INSERT
            if (payload.eventType == PostgresChangeEvent.insert) {
              final senderId = payload.newRecord['sender_id'];
              final receiverId = payload.newRecord['receiver_id'];
              if ((senderId == myId && receiverId == widget.otherUser.userId) ||
                  (senderId == widget.otherUser.userId && receiverId == myId)) {
                if (mounted) {
                  setState(() {
                    _messages.add(payload.newRecord);
                  });
                  _markAsRead();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              }
            }
            // Handle UPDATE (Read Receipts)
            else if (payload.eventType == PostgresChangeEvent.update) {
              final newRecord = payload.newRecord;
              final id = newRecord['id'];
              setState(() {
                final index = _messages.indexWhere((m) => m['id'] == id);
                if (index != -1) {
                  _messages[index] = newRecord;
                }
              });
            }
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        logger
            .debug("✅ Chat: Subscribed to messages:${widget.otherUser.userId}");
      } else if (status == RealtimeSubscribeStatus.closed) {
        logger.debug("❌ Chat: Channel closed");
      } else if (error != null) {
        logger.error("🔴 Chat: Subscription error", error: error);
      }
    });
  }

  void _subscribeToTypingStatus() {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    _typingChannel = supabase
        .channel('typing:${widget.otherUser.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'typing_status',
          callback: (payload) {
            final userId = payload.newRecord['user_id'];
            final chatWith = payload.newRecord['chat_with'];

            // Only process typing status for this chat
            if (userId == widget.otherUser.userId && chatWith == myId) {
              if (mounted) {
                final isTyping =
                    payload.newRecord['is_typing'] as bool? ?? false;
                setState(() {
                  _isOtherUserTyping = isTyping;
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await supabase.from('typing_status').upsert({
        'user_id': myId,
        'chat_with': widget.otherUser.userId,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      logger.error("Error updating typing status", error: e);
    }
  }

  Future<void> _markAsRead() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('receiver_id', myId)
          .eq('sender_id', widget.otherUser.userId)
          .isFilter('read_at', null);
    } catch (e) {
      logger.error("Error marking messages as read", error: e);
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    HapticFeedback.lightImpact();

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    final content = _messageController.text.trim();
    if (content.isEmpty && imageUrl == null) return;

    try {
      await supabase.from('messages').insert({
        'sender_id': myId,
        'receiver_id': widget.otherUser.userId,
        'content': content.isEmpty ? '📷 Image' : content,
        'message_type': imageUrl != null ? 'image' : 'text',
        'media_url': imageUrl,
      });

      _messageController.clear();
      _updateTypingStatus(false);
    } catch (e) {
      logger.error("Error sending message", error: e);
      if (mounted) {
        showErrorSnackBar(context, "Failed to send: $e");
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    HapticFeedback.mediumImpact();

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;

      // Show loading
      setState(() => _isUploading = true);

      // Upload to Supabase Storage
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName =
          '$myId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('chat-images').uploadBinary(
            fileName,
            bytes,
          );

      // Get public URL
      final imageUrl =
          supabase.storage.from('chat-images').getPublicUrl(fileName);

      // Send message with image
      await _sendMessage(imageUrl: imageUrl);
      setState(() => _isUploading = false);

      if (mounted) {
        setState(() => _isUploading = false);
        // ScaffoldMessenger.of(context).clearSnackBars(); // Optional
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      logger.error("Error uploading image", error: e);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to upload image: $e');
      }
    }
  }

  void _onTextChanged(String text) {
    // Update typing status
    if (text.isNotEmpty) {
      _updateTypingStatus(true);

      // Cancel previous timer
      _typingTimer?.cancel();

      // Set new timer to stop typing after 2 seconds of inactivity
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _updateTypingStatus(false);
      });
    } else {
      _updateTypingStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F111A),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.otherUser.userId}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black54,
                backgroundImage: widget.otherUser.avatarUrl != null
                    ? NetworkImage(widget.otherUser.avatarUrl!)
                    : null,
                child: widget.otherUser.avatarUrl == null
                    ? Icon(
                        widget.otherUser.isTutor ? Icons.school : Icons.person,
                        color: widget.otherUser.isTutor
                            ? Colors.amber
                            : Colors.cyanAccent,
                        size: 20,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.fullName ??
                        widget.otherUser.intentTag ??
                        "User",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.otherUser.isTutor ? "Tutor" : "Student",
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.otherUser.isTutor
                          ? Colors.amberAccent
                          : Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                if (_isLoadingMore)
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                Expanded(
                                  child: _messages.isEmpty
                                      ? const Center(
                                          child: Text(
                                            "No messages yet. Say hi! 👋",
                                            style: TextStyle(
                                                color: Colors.white54),
                                          ),
                                        )
                                      : ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.all(16),
                                          itemCount: _messages.length,
                                          itemBuilder: (context, index) {
                                            final msg = _messages[index];
                                            final isMine =
                                                msg['sender_id'] == myId;
                                            final timestamp = DateTime.parse(
                                                msg['created_at']);
                                            final messageType =
                                                msg['message_type'] ?? 'text';
                                            final mediaUrl = msg['media_url'];
                                            final readAt = msg['read_at'];

                                            return Align(
                                              alignment: isMine
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 12),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 10),
                                                constraints: BoxConstraints(
                                                  maxWidth: min(
                                                      600,
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.7),
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isMine
                                                      ? Colors.cyanAccent
                                                          .withOpacity(0.2)
                                                      : Colors.white
                                                          .withOpacity(0.05),
                                                  border: Border.all(
                                                    color: isMine
                                                        ? Colors.cyanAccent
                                                            .withOpacity(0.5)
                                                        : Colors.white24,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: isMine
                                                      ? CrossAxisAlignment.end
                                                      : CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    // Image if present
                                                    if (messageType ==
                                                            'image' &&
                                                        mediaUrl != null) ...[
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Image.network(
                                                          mediaUrl,
                                                          width: 200,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (context, error,
                                                                      stack) =>
                                                                  const Icon(
                                                            Icons.broken_image,
                                                            color:
                                                                Colors.white54,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                    ],
                                                    // Text content
                                                    Text(
                                                      msg['content'],
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    // Timestamp and read receipt
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                Colors.white38,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        if (isMine) ...[
                                                          const SizedBox(
                                                              width: 4),
                                                          Icon(
                                                            readAt != null
                                                                ? Icons.done_all
                                                                : Icons.done,
                                                            size: 14,
                                                            color: readAt !=
                                                                    null
                                                                ? Colors
                                                                    .cyanAccent
                                                                : Colors
                                                                    .white38,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                    ),
                    if (_isOtherUserTyping)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                backgroundImage: widget.otherUser.avatarUrl !=
                                        null
                                    ? NetworkImage(widget.otherUser.avatarUrl!)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Text(
                                      'typing',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                    SizedBox(width: 4),
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.cyanAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Input Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: Colors.cyanAccent,
                      minHeight: 2,
                    ),
                  ),
                Row(
                  children: [
                    // Image picker button
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.cyanAccent),
                      onPressed: _pickAndSendImage,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onChanged: _onTextChanged,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.cyanAccent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.black),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

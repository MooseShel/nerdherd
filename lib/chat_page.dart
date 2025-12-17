import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'models/user_profile.dart';
import 'services/logger_service.dart';
import 'widgets/ui_components.dart';
import 'providers/chat_provider.dart';
import 'providers/auth_provider.dart'; // For auth check if needed

class ChatPage extends ConsumerStatefulWidget {
  final UserProfile otherUser;

  const ChatPage({super.key, required this.otherUser});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoadingMore = false;
  bool _isUploading = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Initial read mark
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    // Check if we have data to load more
    final messagesState =
        ref.read(chatNotifierProvider(widget.otherUser.userId));
    if (!messagesState.hasValue || messagesState.value!.isEmpty) return;

    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    try {
      await ref
          .read(chatNotifierProvider(widget.otherUser.userId).notifier)
          .loadMore();
    } catch (e) {
      logger.error("Error loading more messages", error: e);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await ref
          .read(chatNotifierProvider(widget.otherUser.userId).notifier)
          .markAsRead();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    HapticFeedback.lightImpact();
    final content = _messageController.text.trim();
    if (content.isEmpty && imageUrl == null) return;

    try {
      await ref
          .read(chatNotifierProvider(widget.otherUser.userId).notifier)
          .sendMessage(
            content.isEmpty ? '📷 Image' : content,
            type: imageUrl != null ? 'image' : 'text',
            mediaUrl: imageUrl,
          );

      _messageController.clear();
      _updateTypingStatus(false);

      // Auto-scroll to bottom after sending
      if (_scrollController.hasClients) {
        // Since list is top-to-bottom, bottom is maxScrollExtent.
        // Wait for build?
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

      setState(() => _isUploading = true);

      // Upload via Service - Accessing ChatService directly for image upload helper if needed
      // Or we can add uploadImage to notifier.
      // Current notifier doesn't have uploadImage.
      // Let's access ChatService via provider directly for this operation.
      final service = ref.read(chatServiceProvider);

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final myId = ref.read(authStateProvider).value?.id;
      if (myId == null) return;

      final imageUrl = await service.uploadImage(myId, bytes, fileExt);

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      logger.error("Error uploading image", error: e);
      if (mounted) showErrorSnackBar(context, 'Failed to upload image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      _updateTypingStatus(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _updateTypingStatus(false);
      });
    } else {
      _updateTypingStatus(false);
    }
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null) return;
    final service = ref.read(chatServiceProvider);
    await service.updateTypingStatus(myId, widget.otherUser.userId, isTyping);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Messages State
    final messagesAsync =
        ref.watch(chatNotifierProvider(widget.otherUser.userId));

    // 2. Typing Status State
    final typingAsync =
        ref.watch(typingStatusProvider(widget.otherUser.userId));
    final isOtherUserTyping = typingAsync.value ?? false;

    // My ID
    final myId = ref.watch(authStateProvider).value?.id;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.otherUser.userId}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black54,
                backgroundImage: widget.otherUser.avatarUrl != null
                    ? CachedNetworkImageProvider(widget.otherUser.avatarUrl!)
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
                      child: messagesAsync.when(
                        data: (messages) {
                          if (messages.isEmpty) {
                            return const Center(
                              child: EmptyStateWidget(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: "No messages yet",
                                description:
                                    "Say hi and start the conversation! 👋",
                              ),
                            );
                          }
                          return Column(
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
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[index];
                                    final isMine = msg['sender_id'] == myId;
                                    final timestamp =
                                        DateTime.tryParse(msg['created_at']) ??
                                            DateTime.now();
                                    final messageType =
                                        msg['message_type'] ?? 'text';
                                    final mediaUrl = msg['media_url'];
                                    final readAt = msg['read_at'];

                                    return Align(
                                      alignment: isMine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
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
                                              : Colors.white.withOpacity(0.05),
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
                                              : CrossAxisAlignment.start,
                                          children: [
                                            // Image if present
                                            if (messageType == 'image' &&
                                                mediaUrl != null) ...[
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: mediaUrl,
                                                  width: 200,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                    width: 200,
                                                    height: 150,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surface
                                                        .withOpacity(0.1),
                                                    child: const Center(
                                                        child:
                                                            CircularProgressIndicator()),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            // Text content
                                            Text(
                                              msg['content'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Timestamp and read receipt
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                if (isMine) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    readAt != null
                                                        ? Icons.done_all
                                                        : Icons.done,
                                                    size: 14,
                                                    color: readAt != null
                                                        ? Colors.cyanAccent
                                                        : Colors.white38,
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
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                          child: Text("Error: $err",
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                    if (isOtherUserTyping)
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
                                backgroundImage:
                                    widget.otherUser.avatarUrl != null
                                        ? CachedNetworkImageProvider(
                                            widget.otherUser.avatarUrl!)
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
                        onPressed: () => _sendMessage(),
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

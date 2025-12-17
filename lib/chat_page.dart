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
    // Determine if we are near the "end" (which is actually the top/start in reverse mode)
    // maxScrollExtent in reverse list is the top of the content
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
      // Optimistic UI update handled by Riverpod subscription usually,
      // preventing double submission
      await ref
          .read(chatNotifierProvider(widget.otherUser.userId).notifier)
          .sendMessage(
            content.isEmpty ? '📷 Image' : content,
            type: imageUrl != null ? 'image' : 'text',
            mediaUrl: imageUrl,
          );

      _messageController.clear();
      _updateTypingStatus(false);

      // Navigate to bottom (start of list in reverse)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        foregroundColor: theme.iconTheme.color,
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.otherUser.userId}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: widget.otherUser.avatarUrl != null
                    ? CachedNetworkImageProvider(widget.otherUser.avatarUrl!)
                    : null,
                child: widget.otherUser.avatarUrl == null
                    ? Icon(
                        widget.otherUser.isTutor ? Icons.school : Icons.person,
                        color: widget.otherUser.isTutor
                            ? Colors.amber
                            : colorScheme.primary,
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
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.otherUser.isTutor ? "Tutor" : "Student",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: widget.otherUser.isTutor
                          ? Colors.amber
                          : colorScheme.secondary,
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
                          return ListView.builder(
                            reverse: true, // Show newest at the bottom
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount:
                                messages.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }

                              final msg = messages[index];
                              final isMine = msg['sender_id'] == myId;
                              final timestamp =
                                  DateTime.tryParse(msg['created_at']) ??
                                      DateTime.now();
                              final messageType = msg['message_type'] ?? 'text';
                              final mediaUrl = msg['media_url'];
                              final readAt = msg['read_at'];

                              return Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  constraints: BoxConstraints(
                                    maxWidth: min(
                                        600,
                                        MediaQuery.of(context).size.width *
                                            0.7),
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
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
                                              color: colorScheme.surface
                                                  .withOpacity(0.1),
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator()),
                                            ),
                                            errorWidget:
                                                (context, url, error) => Icon(
                                              Icons.broken_image,
                                              color: colorScheme.error,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      // Text content
                                      if ((msg['content'] ?? '').isNotEmpty)
                                        Text(
                                          msg['content'] ?? '',
                                          style: TextStyle(
                                            color: isMine
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.onSurface,
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
                                            style: TextStyle(
                                              color: isMine
                                                  ? colorScheme
                                                      .onPrimaryContainer
                                                      .withOpacity(0.6)
                                                  : colorScheme
                                                      .onSurfaceVariant,
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
                                                  ? colorScheme.primary
                                                  : colorScheme
                                                      .onPrimaryContainer
                                                      .withOpacity(0.6),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                          child: Text("Error: $err",
                              style: TextStyle(color: colorScheme.error)),
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
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
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
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'typing',
                                      style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                colorScheme.primary),
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
              color: theme.scaffoldBackgroundColor, // or surface logic
              border: Border(
                top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: colorScheme.primary,
                      minHeight: 2,
                    ),
                  ),
                Row(
                  children: [
                    // Image picker button
                    IconButton(
                      icon: Icon(Icons.image, color: colorScheme.primary),
                      onPressed: _pickAndSendImage,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle:
                              TextStyle(color: colorScheme.onSurfaceVariant),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
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
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.send, color: colorScheme.onPrimary),
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

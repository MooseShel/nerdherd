import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _focusNode = FocusNode();

  bool _isLoadingMore = false;
  bool _isUploading = false;
  Timer? _typingTimer;

  bool _isConnected = false;
  bool _isCheckingConnection = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _scrollController.addListener(_onScroll);
    // Initial read mark
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  Future<void> _checkConnection() async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null) {
      if (mounted) setState(() => _isCheckingConnection = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final connection = await supabase
          .from('connections')
          .select()
          .or('and(user_id_1.eq.$myId,user_id_2.eq.${widget.otherUser.userId}),and(user_id_1.eq.${widget.otherUser.userId},user_id_2.eq.$myId)')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isConnected = connection != null;
          _isCheckingConnection = false;
        });
      }
    } catch (e) {
      logger.error("Error checking connection for chat", error: e);
      if (mounted) setState(() => _isCheckingConnection = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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
    if (!_isConnected) return; // double-check
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

      if (!mounted) return;

      _messageController.clear();
      _updateTypingStatus(false);

      // Keep focus on input field for rapid messaging
      _focusNode.requestFocus();

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
    if (!_isConnected) return;
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

  bool _isTypingLocal = false; // To track what we sent to DB

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      if (!_isTypingLocal) {
        _isTypingLocal = true;
        _updateTypingStatus(true);
      }

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTypingLocal) {
          _isTypingLocal = false;
          _updateTypingStatus(false);
        }
      });
    } else {
      if (_isTypingLocal) {
        _isTypingLocal = false;
        _updateTypingStatus(false);
      }
      _typingTimer?.cancel();
    }
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null) return;
    final service = ref.read(chatServiceProvider);
    await service.updateTypingStatus(myId, widget.otherUser.userId, isTyping);
  }

  Future<void> _showReportDialog() async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null) return;

    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report ${widget.otherUser.fullName ?? "User"}?'),
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
        final supabase = Supabase.instance.client;
        await supabase.from('reports').insert({
          'reporter_id': myId,
          'reported_id': widget.otherUser.userId,
          'reason': reasonController.text,
          'status': 'pending',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Report submitted. We will investigate.'),
              backgroundColor: Colors.orange));
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1. Messages State
    final messagesAsync =
        ref.watch(chatNotifierProvider(widget.otherUser.userId));

    // REAL-TIME READ MARK
    ref.listen(chatNotifierProvider(widget.otherUser.userId), (previous, next) {
      if (next.hasValue && next.value!.isNotEmpty) {
        final newest = next.value!.first;
        // If newest message is from OTHER and not read, mark it!
        if (newest['sender_id'] == widget.otherUser.userId &&
            newest['read_at'] == null) {
          _markAsRead();
        }
      }
    });

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
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Report User'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                                  DateTime.tryParse(msg['created_at'])
                                          ?.toLocal() ??
                                      DateTime.now();
                              final messageType = msg['message_type'] ?? 'text';
                              final mediaUrl = msg['media_url'];
                              final readAt = msg['read_at'];

                              // Format time (e.g. 10:30 AM)
                              final timeStr = TimeOfDay.fromDateTime(timestamp)
                                  .format(context);

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
                                        ? colorScheme.primary
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
                                                  .withValues(alpha: 0.1),
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
                                                ? colorScheme.onPrimary
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
                                            timeStr,
                                            style: TextStyle(
                                              color: isMine
                                                  ? colorScheme
                                                      .onPrimaryContainer
                                                      .withValues(alpha: 0.6)
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
                                                  ? Colors.cyanAccent
                                                  : colorScheme.onPrimary
                                                      .withValues(alpha: 0.6),
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

          // Input Field (Conditionally Rendered)
          if (_isCheckingConnection)
            Container(
              padding: const EdgeInsets.all(20),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (!_isConnected)
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.scaffoldBackgroundColor,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 20, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        "You must be connected to chat.",
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final myId = ref.read(authStateProvider).value?.id;
                          if (myId == null) return;

                          setState(() => _isCheckingConnection = true);

                          // Force check/create
                          // In a real app, this might call an RPC or service method
                          // For recovery, let's just re-check.
                          // Ideally, we'd have a method to "repair" connection.
                          await _checkConnection(); // Re-check

                          if (!context.mounted) return;
                          if (!_isConnected) {
                            // If still failed, show message
                            showErrorSnackBar(context,
                                "Connection repair failed. Please try properly accepting the match.");
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Check Connection"),
                      )
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor, // or surface logic
                border: Border(
                  top: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.1)),
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
                          focusNode: _focusNode,
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
                          onSubmitted: (_) {
                            _sendMessage();
                          },
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

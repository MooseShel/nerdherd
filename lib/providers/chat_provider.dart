import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

part 'chat_provider.g.dart';

@Riverpod(keepAlive: true)
ChatService chatService(ChatServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ChatService(supabase);
}

@Riverpod(keepAlive: true)
class ChatNotifier extends _$ChatNotifier {
  RealtimeChannel? _subscription;

  @override
  Future<List<Map<String, dynamic>>> build(String otherUserId) async {
    final myId = ref.watch(authStateProvider).value?.id;
    if (myId == null) return [];

    final service = ref.read(chatServiceProvider);

    // Setup Realtime Subscription
    _subscription = service.subscribeToMessages(myId, otherUserId, (payload) {
      if (state.value == null) return;
      final currentList = List<Map<String, dynamic>>.from(state.value!);

      if (payload.eventType == PostgresChangeEvent.insert) {
        final newMsg = payload.newRecord;

        // STRICT FILTER: Ensure message belongs to this conversation
        final senderId = newMsg['sender_id'];
        final receiverId = newMsg['receiver_id'];
        final isRelevant = (senderId == myId && receiverId == otherUserId) ||
            (senderId == otherUserId && receiverId == myId);

        if (!isRelevant) return;

        // Check if already exists
        if (!currentList.any((m) => m['id'] == newMsg['id'])) {
          state = AsyncValue.data([newMsg, ...currentList]);
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        final newMsg = payload.newRecord;
        final index = currentList.indexWhere((m) => m['id'] == newMsg['id']);
        if (index != -1) {
          currentList[index] = newMsg;
          state = AsyncValue.data(currentList);
        }
      }
    });

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    // Initial Fetch (20 items)
    final messages = await service.fetchMessages(myId, otherUserId, 20, 0);
    // Service returns Newest First.
    // We want Newest First for Reversed ListView.
    return messages;
  }

  Future<void> loadMore() async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null || state.value == null) return;

    final currentList = state.value!;
    final offset = currentList.length;

    final service = ref.read(chatServiceProvider);
    try {
      final olderMessages =
          await service.fetchMessages(myId, otherUserId, 20, offset);
      if (olderMessages.isNotEmpty) {
        // Older messages are Newest -> Oldest in that page.
        // We append them to the end of the list (which is the top of the reversed ListView)
        state = AsyncValue.data([...currentList, ...olderMessages]);
      }
    } catch (e) {
      // Handle error (maybe toast via callback or separate error state)
    }
  }

  Future<void> sendMessage(String content,
      {String? type = 'text', String? mediaUrl}) async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null) return;
    final service = ref.read(chatServiceProvider);
    await service.sendMessage(myId, otherUserId, content,
        type: type ?? 'text', mediaUrl: mediaUrl);
  }

  Future<void> markAsRead() async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null) return;
    final service = ref.read(chatServiceProvider);
    await service.markMessagesAsRead(myId, otherUserId);
  }
}

// Typing Status Provider (Simple Stream)
@Riverpod(keepAlive: true)
Stream<bool> typingStatus(TypingStatusRef ref, String otherUserId) {
  final service = ref.watch(chatServiceProvider);
  final myId = ref.watch(authStateProvider).value?.id;
  if (myId == null) return const Stream.empty();

  // Transform the Postgres Stream to Boolean
  final streamController = StreamController<bool>();

  final sub = service.subscribeToTyping(myId, otherUserId, (payload) {
    final userId = payload.newRecord['user_id'];
    final chatWith = payload.newRecord['chat_with'];
    if (userId == otherUserId && chatWith == myId) {
      final isTyping = payload.newRecord['is_typing'] as bool? ?? false;
      streamController.add(isTyping);
    }
  });

  ref.onDispose(() {
    sub.unsubscribe();
    streamController.close();
  });

  return streamController.stream;
}

// GLOBAL UNREAD COUNT PROVIDER
@Riverpod(keepAlive: true)
class TotalUnreadMessages extends _$TotalUnreadMessages {
  RealtimeChannel? _subscription;

  @override
  Future<int> build() async {
    final myId = ref.watch(authStateProvider).value?.id;
    if (myId == null) return 0;

    final service = ref.read(chatServiceProvider);

    // 1. Initial Count
    final count = await service.getUnreadCount(myId);

    // 2. Realtime Subscription
    _subscription = service.subscribeToUnreadCount(myId, (payload) {
      // Re-fetch on any change involving us (Insert new msg, Update read status)
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    return count;
  }
}

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
        // Only add if relevant (ChatService filter should handle this but double check)
        final newMsg = payload.newRecord;
        // Check if already exists?
        if (!currentList.any((m) => m['id'] == newMsg['id'])) {
          state = AsyncValue.data([...currentList, newMsg]);
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
    // Service returns Newest First. We want Oldest First for UI.
    return messages.reversed.toList();
  }

  Future<void> loadMore() async {
    final myId = ref.read(authStateProvider).value?.id;
    if (myId == null || state.value == null) return;

    final currentList = state.value!;
    final offset = currentList.length;
    final otherUserId =
        this.otherUserId; // Family argument available as property? No?
    // Wait, Riverpod Generator passes arguments to build, but are they available in class?
    // Yes, for family notifiers, arguments are available as fields if we use generated class?
    // Actually, `otherUserId` is the argument.
    // In @riverpod class, the arguments are passed to build.
    // To access them in other methods, we typically store them or use `arg`.
    // Generator creates `this.otherUserId`?
    // Let's check docs or common pattern.
    // Usually we save it in build or it's available.
    // Riverpod 2: "The arguments of the method are available as properties of the object."
    // So `otherUserId` should be available.

    // Prevent double loading?
    // We can't easily check loading state inside notifier unless we set it.

    final service = ref.read(chatServiceProvider);
    try {
      final olderMessages =
          await service.fetchMessages(myId, otherUserId, 20, offset);
      if (olderMessages.isNotEmpty) {
        // Older messages are Newest -> Oldest in that page.
        // Reversed -> Oldest -> Newest.
        // But these are older than currentList[0].
        // So we prepend reversed list.
        final reversedOlder = olderMessages.reversed.toList();
        state = AsyncValue.data([...reversedOlder, ...currentList]);
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

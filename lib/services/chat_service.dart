import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart';

class ChatService {
  final SupabaseClient _supabase;

  ChatService(this._supabase);

  // 1. Fetch Messages (Pagination)
  Future<List<Map<String, dynamic>>> fetchMessages(
      String myId, String otherId, int limit, int offset) async {
    try {
      final data = await _supabase
          .from('messages')
          .select('*, message_reactions(user_id, reaction_type)')
          .or('and(sender_id.eq.$myId,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$myId)')
          .order('created_at', ascending: false) // Newest first
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      logger.error("ChatService: Error fetching messages", error: e);
      rethrow;
    }
  }

  // 2. Send Message
  Future<void> sendMessage(
    String senderId,
    String receiverId,
    String content, {
    String type = 'text',
    String? mediaUrl,
    String? replyToId,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'message_type': type,
        'media_url': mediaUrl,
        'reply_to_id': replyToId,
      });
      // logger.debug("📨 Message sent to $receiverId");
    } catch (e) {
      logger.error("ChatService: Failed to send message", error: e);
      rethrow;
    }
  }

  // 3. Mark as Read
  Future<void> markMessagesAsRead(String receiverId, String senderId) async {
    try {
      await _supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('receiver_id', receiverId) // Me
          .eq('sender_id', senderId) // Other
          .isFilter('read_at', null);
    } catch (e) {
      // logger.warning("Failed to mark messages as read", error: e);
    }
  }

  // 3.5 Toggle Reaction
  Future<void> toggleReaction(
      String messageId, String userId, String reactionType) async {
    try {
      // Check if exists
      final existing = await _supabase
          .from('message_reactions')
          .select()
          .match({'message_id': messageId, 'user_id': userId}).maybeSingle();

      if (existing != null) {
        if (existing['reaction_type'] == reactionType) {
          // Remove if same
          await _supabase
              .from('message_reactions')
              .delete()
              .match({'id': existing['id']});
        } else {
          // Update if different
          await _supabase.from('message_reactions').update(
              {'reaction_type': reactionType}).match({'id': existing['id']});
        }
      } else {
        // Insert
        await _supabase.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': userId,
          'reaction_type': reactionType
        });
      }
    } catch (e) {
      logger.error("Error toggling reaction", error: e);
    }
  }

  // 4. Upload Image
  Future<String> uploadImage(
      String userId, Uint8List bytes, String fileExt) async {
    try {
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _supabase.storage.from('chat-images').uploadBinary(fileName, bytes);
      return _supabase.storage.from('chat-images').getPublicUrl(fileName);
    } catch (e) {
      logger.error("ChatService: Failed to upload image", error: e);
      rethrow;
    }
  }

  // 5. Typing Status
  Future<void> updateTypingStatus(
      String userId, String chatWith, bool isTyping) async {
    try {
      await _supabase.from('typing_status').upsert({
        'user_id': userId,
        'chat_with': chatWith,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silent fail
    }
  }

  // 6. Subscriptions
  RealtimeChannel subscribeToMessages(String myId, String otherId,
      void Function(PostgresChangePayload) callback) {
    return _supabase
        .channel('messages:$otherId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: callback,
        )
        .subscribe();
  }

  RealtimeChannel subscribeToTyping(String myId, String otherId,
      void Function(PostgresChangePayload) callback) {
    return _supabase
        .channel('typing:$otherId')
        .onPostgresChanges(
          event: PostgresChangeEvent
              .all, // Listen for insert and update (for upsert)
          schema: 'public',
          table: 'typing_status',
          callback: callback,
        )
        .subscribe();
  }

  RealtimeChannel subscribeToReactions(
      void Function(PostgresChangePayload) callback) {
    return _supabase
        .channel('reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: callback,
        )
        .subscribe();
  }

  // 7. Global Unread Count
  Future<int> getUnreadCount(String myId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', myId)
          .isFilter('read_at', null);

      return response.length;
    } catch (e) {
      logger.error("ChatService: Error getting unread count", error: e);
      return 0;
    }
  }

  RealtimeChannel subscribeToUnreadCount(
      String myId, void Function(PostgresChangePayload) callback) {
    return _supabase
        .channel('unread-count:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          // We filter in the callback or here if possible.
          // Supabase Realtime filters are limited, so we handle relevance in the provider/service.
          callback: (payload) {
            final record = payload.newRecord;
            final oldRecord = payload.oldRecord;

            // Check if this message involves me as receiver
            final isForMe = record['receiver_id'] == myId ||
                (oldRecord.isNotEmpty && oldRecord['receiver_id'] == myId);

            if (isForMe) {
              callback(payload);
            }
          },
        )
        .subscribe();
  }
}

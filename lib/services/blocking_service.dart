import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart';

class BlockingService {
  final SupabaseClient _supabase;

  BlockingService(this._supabase);

  /// Blocks a user by inserting a record into the `blocked_users` table.
  /// Returns true if successful.
  Future<bool> blockUser(String userIdToBlock) async {
    try {
      final myUserId = _supabase.auth.currentUser?.id;
      if (myUserId == null) return false;

      await _supabase.from('blocked_users').insert({
        'blocker_id': myUserId,
        'blocked_id': userIdToBlock,
      });

      logger.info('Blocked user: $userIdToBlock');
      return true;
    } catch (e) {
      logger.error('Error blocking user $userIdToBlock', error: e);
      return false;
    }
  }

  /// Unblocks a user by deleting the record from `blocked_users`.
  Future<bool> unblockUser(String userIdToUnblock) async {
    try {
      final myUserId = _supabase.auth.currentUser?.id;
      if (myUserId == null) return false;

      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', myUserId)
          .eq('blocked_id', userIdToUnblock);

      logger.info('Unblocked user: $userIdToUnblock');
      return true;
    } catch (e) {
      logger.error('Error unblocking user $userIdToUnblock', error: e);
      return false;
    }
  }

  /// Fetches the list of user IDs that the current user has blocked.
  Future<List<String>> getBlockedUserIds() async {
    try {
      final myUserId = _supabase.auth.currentUser?.id;
      if (myUserId == null) return [];

      final response = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', myUserId);

      final ids =
          (response as List).map((e) => e['blocked_id'] as String).toList();

      return ids;
    } catch (e) {
      logger.error('Error fetching blocked users', error: e);
      return [];
    }
  }

  /// Fetches the list of user IDs that have blocked the current user.
  Future<List<String>> getBlockedByUserIds() async {
    try {
      final myUserId = _supabase.auth.currentUser?.id;
      if (myUserId == null) return [];

      final response = await _supabase
          .from('blocked_users')
          .select('blocker_id')
          .eq('blocked_id', myUserId);

      final ids =
          (response as List).map((e) => e['blocker_id'] as String).toList();

      return ids;
    } catch (e) {
      logger.error('Error fetching users who blocked me', error: e);
      return [];
    }
  }
}

// Global instance (can be replaced by Riverpod provider)
final blockingService = BlockingService(Supabase.instance.client);

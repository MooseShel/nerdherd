import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/serendipity_match.dart';
import 'logger_service.dart';
import '../models/user_profile.dart';

class MatchingService {
  static final MatchingService _instance = MatchingService._internal();
  factory MatchingService() => _instance;
  MatchingService._internal();

  final _supabase = Supabase.instance.client;

  /// Suggest a match between two users
  Future<SerendipityMatch?> suggestMatch({
    required String otherUserId,
    required String matchType, // 'proximity', 'constellation', 'temporal'
    String? message,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        logger.error('Cannot suggest match: User not authenticated');
        return null;
      }

      // Check if match already exists
      final existing = await _supabase
          .from('serendipity_matches')
          .select()
          .or('and(user_a.eq.$currentUserId,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$currentUserId)')
          .or('and(user_a.eq.$currentUserId,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$currentUserId)')
          .eq('accepted', false) // Only check for pending matches
          .maybeSingle();

      if (existing != null) {
        logger.info(
            'Pending match already exists between $currentUserId and $otherUserId');
        return SerendipityMatch.fromJson(existing);
      }

      // Create new match
      final data = await _supabase
          .from('serendipity_matches')
          .insert({
            'user_a': currentUserId,
            'user_b': otherUserId,
            'match_type': matchType,
          })
          .select()
          .single();

      logger.info('Created new match: $matchType');

      // NOTIFICATION: Notify the other user (Receiver)
      try {
        // NOTIFICATION: We rely on a database trigger or the collab_requests generic handler
        // to send the notification. Explicitly inserting one here causes duplicates.
        // await _supabase.from('notifications').insert({
        //   'user_id': otherUserId,
        //   'type': 'match_request', // Custom type or generic
        //   'title': 'New Nerd Match! 🎓',
        //   'body': 'Someone nearby wants to study!',
        //   'data': {'match_id': data['id'], 'sender_id': currentUserId},
        //   'read': false,
        // });

        // STANDARD REQUEST: Create a formal collab_request
        // This ensures the standard "Accept/Reject" workflow works
        await _supabase.from('collab_requests').insert({
          'sender_id': currentUserId,
          'receiver_id': otherUserId,
          'status': 'pending',
          'message': message, // Added message field
        });
        logger.info('Created collab_request for match');
      } catch (e) {
        // Handle duplicate key errors gracefully
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('23505') ||
            errorString.contains('duplicate key') ||
            errorString.contains('unique constraint')) {
          logger
              .info('Collab request already exists (caught duplicate error).');
        } else {
          logger.warning('Failed to send match notification/request', error: e);
        }
      }

      return SerendipityMatch.fromJson(data);
    } catch (e) {
      logger.error('Error suggesting match', error: e);
      return null;
    }
  }

  /// Accept a match
  Future<bool> acceptMatch(String matchId) async {
    try {
      await _supabase
          .from('serendipity_matches')
          .update({'accepted': true}).eq('id', matchId);
      logger.info('Accepted match $matchId');

      // 1. CREATE CONNECTION (Crucial for Chat)
      // We need to fetch the match to get IDs
      final matchData = await _supabase
          .from('serendipity_matches')
          .select()
          .eq('id', matchId)
          .single();
      final userA = matchData['user_a'];
      final userB = matchData['user_b'];
      final currentUserId = _supabase.auth.currentUser?.id;

      // Determine who is the "Other" (the one who sent the request)
      final otherUserId = (userA == currentUserId) ? userB : userA;

      // Ensure consistent ordering for storage to prevent (A,B) and (B,A) duplicates
      final id1 = (userA.compareTo(userB) < 0) ? userA : userB;
      final id2 = (userA.compareTo(userB) < 0) ? userB : userA;

      // 1. CREATE CONNECTION (Crucial for Chat)
      // Use database function that handles duplicates with ON CONFLICT DO NOTHING
      try {
        await _supabase.rpc('create_connection_safe', params: {
          'uid1': id1,
          'uid2': id2,
        });
        logger.info('Connection ensured between $id1 and $id2');
      } catch (e) {
        logger.warning('Error calling create_connection_safe', error: e);
        // Don't rethrow - function handles duplicates gracefully
      }

      // 2. NOTIFICATION: Notify the Sender
      try {
        await _supabase.from('notifications').insert({
          'user_id': otherUserId,
          'type': 'match_accepted',
          'title': 'Match Accepted! 🎉',
          'body': 'Your study buddy is ready to chat.',
          'data': {'match_id': matchId, 'accepter_id': currentUserId},
          'read': false,
        });
        logger.info('Sent match accepted notification to $otherUserId');
      } catch (e) {
        // Handle duplicate key errors gracefully (e.g., if match was accepted twice)
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('23505') ||
            errorString.contains('duplicate key') ||
            errorString.contains('unique constraint')) {
          logger.info('Notification already exists (caught duplicate error).');
        } else {
          logger.warning('Failed to send accept notification', error: e);
        }
      }

      return true;
    } catch (e) {
      logger.error('Error accepting match $matchId', error: e);
      return false;
    }
  }

  /// Decline/Remove a match
  Future<bool> declineMatch(String matchId) async {
    try {
      // 1. Get match details before deleting (to find the pair)
      final match = await _supabase
          .from('serendipity_matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();

      if (match != null) {
        final u1 = match['user_a'];
        final u2 = match['user_b'];

        // 2. Delete the match record
        await _supabase.from('serendipity_matches').delete().eq('id', matchId);

        // 3. ALSO delete/cancel the collab_request (if any)
        // This ensures the receiver doesn't see a stale request
        await _supabase
            .from('collab_requests')
            .delete()
            .or('and(sender_id.eq.$u1,receiver_id.eq.$u2),and(sender_id.eq.$u2,receiver_id.eq.$u1)')
            .eq('status', 'pending');

        logger.info('Declined/Removed match $matchId and related requests');
      }
      return true;
    } catch (e) {
      logger.error('Error declining match $matchId', error: e);
      return false;
    }
  }

  /// Get pending matches for current user
  Future<List<SerendipityMatch>> getPendingMatches() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await _supabase
          .from('serendipity_matches')
          .select()
          .or('user_a.eq.$userId,user_b.eq.$userId')
          .eq('accepted', false)
          .order('created_at', ascending: false);

      return data.map((e) => SerendipityMatch.fromJson(e)).toList();
    } catch (e) {
      logger.error('Error fetching pending matches', error: e);
      return [];
    }
  }

  /// Stream pending matches for current user
  Stream<List<SerendipityMatch>> streamPendingMatches() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('serendipity_matches')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final matches = data
              .map((e) => SerendipityMatch.fromJson(e))
              .where((m) =>
                  (m.userA == userId || m.userB == userId) && !m.accepted)
              .toList();
          return matches;
        });
  }

  /// Stream a single match by ID (to detect acceptance)
  Stream<SerendipityMatch?> streamMatch(String matchId) {
    return _supabase
        .from('serendipity_matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((data) {
          if (data.isEmpty) return null;
          return SerendipityMatch.fromJson(data.first);
        });
  }

  /// Find semantically similar matches using Nerd Match (vector search)
  Future<List<UserProfile>> findNerdMatches({
    required List<double> queryEmbedding,
    double matchThreshold = 0.5,
    int matchCount = 5,
    double? minSocial,
    double? maxSocial,
    double? minTemporal,
    double? maxTemporal,
    String? universityId,
  }) async {
    try {
      final response = await _supabase.rpc('match_nerds', params: {
        'query_embedding': queryEmbedding,
        'match_threshold': matchThreshold,
        'match_count': matchCount,
        'min_social': minSocial ?? 0.0,
        'max_social': maxSocial ?? 1.0,
        'min_temporal': minTemporal ?? 0.0,
        'max_temporal': maxTemporal ?? 1.0,
        'target_university_id': universityId,
      });

      return (response as List).map((e) => UserProfile.fromJson(e)).toList();
    } catch (e) {
      logger.error('Error finding nerd matches', error: e);
      return [];
    }
  }

  /// Update user's study style preferences
  Future<bool> updateStudyStyle({
    required double social,
    required double temporal,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('profiles').update({
        'study_style_social': social,
        'study_style_temporal': temporal,
      }).eq('user_id', userId);

      logger.info('Updated study style for $userId');
      return true;
    } catch (e) {
      logger.error('Error updating study style', error: e);
      return false;
    }
  }
}

final matchingService = MatchingService();

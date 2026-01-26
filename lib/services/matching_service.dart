import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/serendipity_match.dart';
import 'logger_service.dart';
import '../models/user_profile.dart';

class MatchingService {
  static final MatchingService _instance = MatchingService._internal();
  factory MatchingService() => _instance;
  MatchingService._internal();

  final _supabase = Supabase.instance.client;

  /// Suggest a match body using Atomic RPC
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

      logger.info('🚀 Suggesting match via RPC...');

      // CALL THE NEW ATOMIC RPC
      final response = await _supabase.rpc('suggest_match', params: {
        'target_user_id': otherUserId,
        'match_type': matchType,
        'message': message,
      });

      logger.info('RPC Response: $response');

      if (response['success'] == true) {
        // Determine if it was new or existing to log correctly
        final matchId = response['match_id'];
        final isNew = response['is_new'] == true;
        final diagCount = response['diag_request_count'] ?? 0;

        logger.info(
            '✅ Match handled (RPC). ID: $matchId, New: $isNew, Diag Request Count: $diagCount');

        // We need to fetch the actual match object to return it
        // (Or we could have returned it from RPC, but fetching is safe)
        final matchData = await _supabase
            .from('serendipity_matches')
            .select()
            .eq('id', matchId)
            .single();

        return SerendipityMatch.fromJson(matchData);
      } else {
        logger.error('❌ RPC Failed: ${response['error']}');
        return null;
      }
    } catch (e) {
      logger.error('Error suggesting match (RPC)', error: e);
      return null;
    }
  }

  /// Stage 1: Receiver expresses interest using Atomic RPC
  Future<bool> expressInterest(String matchId) async {
    try {
      logger.info("🚀 Expressing interest in match $matchId via RPC...");

      final response = await _supabase.rpc('express_interest', params: {
        'target_match_id': matchId,
      });

      logger.info('RPC Response: $response');

      if (response['success'] == true) {
        logger.info('✅ Interest expressed (Stage 1).');
        return true;
      } else {
        logger.error('❌ RPC Failed: ${response['error']}');
        return false;
      }
    } catch (e) {
      logger.error('Error expressing interest (RPC)', error: e);
      return false;
    }
  }

  /// Stage 2: Sender confirms match using Atomic RPC
  Future<bool> confirmMatch(String matchId) async {
    try {
      logger.info("🚀 Confirming match $matchId via RPC...");

      final response = await _supabase.rpc('confirm_match', params: {
        'target_match_id': matchId,
      });

      logger.info('RPC Response: $response');

      if (response['success'] == true) {
        logger.info('✅ Match confirmed & Connection created (Stage 2).');
        return true;
      } else {
        logger.error('❌ RPC Failed: ${response['error']}');
        return false;
      }
    } catch (e) {
      logger.error('Error confirming match (RPC)', error: e);
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

        // 3. UPDATE the collab_request to rejected (preserve history)
        try {
          await _supabase
              .from('collab_requests')
              .update({'status': 'rejected'})
              .or('and(sender_id.eq.$u1,receiver_id.eq.$u2),and(sender_id.eq.$u2,receiver_id.eq.$u1)')
              .eq('status', 'pending');
          logger.info('Marked collab_request as rejected');
        } catch (e) {
          logger.warning('Error updating collab_request to rejected', error: e);
        }
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
          final now = DateTime.now();
          final matches =
              data.map((e) => SerendipityMatch.fromJson(e)).where((m) {
            final isMyMatch = m.userA == userId || m.userB == userId;
            if (!isMyMatch) return false;

            // Include pending matches
            if (!m.accepted) return true;

            // ALSO include recent accepted matches (e.g. last 1 hour)
            // so we can show "Friend Found" in the UI
            if (now.difference(m.createdAt).inHours < 1) {
              return true;
            }

            return false;
          }).toList();
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

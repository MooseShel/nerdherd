import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/serendipity_match.dart';
import 'logger_service.dart';

class MatchingService {
  static final MatchingService _instance = MatchingService._internal();
  factory MatchingService() => _instance;
  MatchingService._internal();

  final _supabase = Supabase.instance.client;

  /// Suggest a match between two users
  Future<SerendipityMatch?> suggestMatch({
    required String otherUserId,
    required String matchType, // 'proximity', 'constellation', 'temporal'
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
          .maybeSingle();

      if (existing != null) {
        logger.info(
            'Match already exists between $currentUserId and $otherUserId');
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
      return true;
    } catch (e) {
      logger.error('Error accepting match $matchId', error: e);
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
}

final matchingService = MatchingService();

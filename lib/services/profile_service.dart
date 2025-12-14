import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'logger_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final _supabase = Supabase.instance.client;
  final Map<String, UserProfile> _cache = {};

  /// Gets a profile from cache, or fetches it if missing.
  Future<UserProfile?> getProfile(String userId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(userId)) {
      // logger.debug("User $userId found in cache");
      return _cache[userId];
    }

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        final profile = UserProfile.fromJson(data);
        _cache[userId] = profile;
        return profile;
      }
    } catch (e) {
      logger.error("Error fetching profile for $userId", error: e);
    }
    return null;
  }

  /// Fetches multiple profiles efficiently, using cache where possible.
  Future<List<UserProfile>> getProfiles(List<String> userIds) async {
    final List<UserProfile> results = [];
    final List<String> missingIds = [];

    // Check cache first
    for (var id in userIds) {
      if (_cache.containsKey(id)) {
        results.add(_cache[id]!);
      } else {
        missingIds.add(id);
      }
    }

    // Fetch missing
    if (missingIds.isNotEmpty) {
      try {
        final data = await _supabase
            .from('profiles')
            .select()
            .inFilter('user_id', missingIds);

        for (var item in data) {
          final profile = UserProfile.fromJson(item);
          _cache[profile.userId] = profile;
          results.add(profile);
        }
      } catch (e) {
        logger.error("Error fetching batch profiles", error: e);
      }
    }

    return results;
  }

  void clearCache() {
    _cache.clear();
  }
}

final profileService = ProfileService();

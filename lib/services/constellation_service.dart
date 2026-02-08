import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart'; // Used for LatLng
import '../models/struggle_signal.dart';
import '../models/user_profile.dart';
import '../services/logger_service.dart';
import '../services/matching_service.dart';
import '../services/blocking_service.dart';
import 'dart:math';

class ConstellationService {
  static final ConstellationService _instance =
      ConstellationService._internal();
  factory ConstellationService() => _instance;
  ConstellationService._internal();

  final _supabase = Supabase.instance.client;

  /// Scans for nearby users and suggests matches based on intelligence
  Future<void> scanForMatches(StruggleSignal signal, int radiusMeters) async {
    try {
      logger.info(
          '✨ Constellation: Scanning for matches for "${signal.subject}" within ${radiusMeters}m... (Signal Loc: ${signal.latitude}, ${signal.longitude})');

      // 0. Fetch blocked user IDs to exclude (bidirectional)
      final blockedIds = await blockingService.getBlockedUserIds();
      final blockedByIds = await blockingService.getBlockedByUserIds();
      final allBlockedIds = {...blockedIds, ...blockedByIds};
      logger.debug(
          '   -> Excluding ${allBlockedIds.length} blocked users (bidirectional)');

      // 1. Calculate staleness cutoff (24 hours ago)
      final staleCutoff =
          DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();

      // 2. Fetch Candidates (Nearby Profiles) with filters
      final response = await _supabase
          .from('profiles')
          .select('*, location:location_geom') // Alias for UserProfile parsing
          .not('location_geom', 'is', null) // Must have location
          .neq('user_id', signal.userId) // Exclude self
          .eq('is_active', true) // Only active users
          .gte('last_updated', staleCutoff); // Location updated within 24h

      final candidates = (response as List).map((json) {
        // Manual Parsing of Location to ensure we get coordinates
        // The alias 'location' might return a GeoJSON map OR a WKT string depending on Supabase version

        final profile = UserProfile.fromJson(json);

        // If profile.location is null, try to force parse it here
        if (profile.location == null && json['location'] != null) {
          try {
            double? lat, lng;
            final rawLoc = json['location'];

            if (rawLoc is Map && rawLoc['coordinates'] != null) {
              // GeoJSON: { type: Point, coordinates: [lon, lat] }
              final coords = rawLoc['coordinates'];
              lng = (coords[0] as num).toDouble();
              lat = (coords[1] as num).toDouble();
            } else if (rawLoc is String && rawLoc.startsWith('POINT')) {
              // WKT: POINT(lon lat)
              final parts =
                  rawLoc.replaceAll(RegExp(r'[^\d\.\-\s]'), '').split(' ');
              if (parts.length >= 2) {
                lng = double.tryParse(parts[0]);
                lat = double.tryParse(parts[1]);
              }
            }

            if (lat != null && lng != null) {
              // Return a copy with the valid location
              return profile.copyWith(location: LatLng(lat, lng));
            }
          } catch (e) {
            logger.warning(
                'Failed to manual parse location for ${profile.userId}',
                error: e);
          }
        }

        return profile;
      }).toList();

      logger.info(
          '✨ Constellation: Found ${candidates.length} potential candidates nearby.');

      // Collect valid matches
      List<Map<String, dynamic>> scoredCandidates = [];

      for (final candidate in candidates) {
        // Skip blocked users (bidirectional)
        if (allBlockedIds.contains(candidate.userId)) {
          logger.debug("   -> Skipping blocked user: ${candidate.fullName}");
          continue;
        }

        if (candidate.location == null) {
          logger.warning(
              "⚠️ Candidate ${candidate.userId} has NO LOCATION after parsing.");
          continue;
        }

        // Filter by Proximity
        final dist = _calculateDistance(signal.latitude, signal.longitude,
            candidate.location!.latitude, candidate.location!.longitude);

        if (dist > radiusMeters) {
          logger.debug("   -> Too far: ${candidate.fullName} ($dist m)");
          continue;
        }

        // Score this candidate
        final score =
            _calculateCompatibilityScore(signal, candidate, dist, radiusMeters);

        logger.debug(
            '   -> Candidate ${candidate.fullName} (${dist.toInt()}m): Score ${score.toStringAsFixed(2)}');

        // Production threshold (raised from 0.1 to 0.3)
        if (score >= 0.3) {
          scoredCandidates.add({
            'candidate': candidate,
            'score': score,
          });
        }
      }

      // Sort by Score Descending
      scoredCandidates.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      // Suggest Top 5 Matches
      final topMatches = scoredCandidates.take(5).toList();

      if (topMatches.isNotEmpty) {
        logger.info(
            '✨ Constellation: 🎯 Found ${topMatches.length} suitable matches!');

        for (final item in topMatches) {
          final candidate = item['candidate'] as UserProfile;
          final score = item['score'] as double;

          logger.info(
              '   -> Suggesting: ${candidate.fullName} (Score: ${score.toStringAsFixed(2)})');

          await matchingService.suggestMatch(
            otherUserId: candidate.userId,
            matchType: 'constellation',
            score: score,
          );
        }
      } else {
        logger.info('✨ Constellation: No suitable matches found this time.');
      }
    } catch (e) {
      logger.error('Constellation Scan Error', error: e);
    }
  }

  /// Calculates a 0.0 - 1.0 score based on compatibility
  double _calculateCompatibilityScore(StruggleSignal signal,
      UserProfile candidate, double distance, int radius) {
    double score = 0.0;

    // 1. Role Score (+0.5 for Tutors)
    if (candidate.isTutor) {
      score += 0.5;
    }

    // 2. Skill/Topic Match (+0.3)
    // Simple keyword matching against classes and intent
    final signalKeywords = _extractKeywords(signal.subject);
    bool skillMatch = false;

    // Check Candidate Classes
    for (final cls in candidate.currentClasses) {
      if (_matchesKeywords(cls, signalKeywords)) {
        skillMatch = true;
        break;
      }
    }
    // Check Candidate Intent
    if (!skillMatch && candidate.intentTag != null) {
      if (_matchesKeywords(candidate.intentTag!, signalKeywords)) {
        skillMatch = true;
      }
    }

    if (skillMatch) {
      score += 0.3;
    }

    // 3. Proximity Score (+0.2 max)
    // Linear decay: 0m = +0.2, Limit = +0.0
    if (radius > 0) {
      double proximityFactor = 1.0 - (distance / radius);
      if (proximityFactor < 0) proximityFactor = 0;
      score += (0.2 * proximityFactor);
    }

    logger.debug('''
    🧩 Score Breakdown for ${candidate.fullName}:
    - Role (+0.5): ${candidate.isTutor ? '✅' : '❌'}
    - Skill Match (+0.3): ${skillMatch ? '✅' : '❌'} (Keywords: $signalKeywords)
    - Proximity (+0.2 max): ${(score - (candidate.isTutor ? 0.5 : 0) - (skillMatch ? 0.3 : 0)).toStringAsFixed(2)}
    - Total: ${score.toStringAsFixed(2)}
    ''');

    return score;
  }

  List<String> _extractKeywords(String text) {
    return text.toLowerCase().split(' ').where((w) => w.length > 3).toList();
  }

  bool _matchesKeywords(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    for (final k in keywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // Meters
  }
}

final constellationService = ConstellationService();

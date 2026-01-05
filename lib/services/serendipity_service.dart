import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/struggle_signal.dart';
import 'logger_service.dart';

class SerendipityService {
  static final SerendipityService _instance = SerendipityService._internal();
  factory SerendipityService() => _instance;
  SerendipityService._internal();

  final _supabase = Supabase.instance.client;

  /// Create a new struggle signal
  /// Automatically cancels any existing active signal for the user
  Future<StruggleSignal?> createStruggleSignal({
    required String subject,
    String? topic,
    required int confidenceLevel,
    required LatLng location,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        logger.error('Cannot create struggle signal: User not authenticated');
        return null;
      }

      // Auto-cancel any existing active signal
      await cancelActiveSignal();

      final data = await _supabase
          .from('struggle_signals')
          .insert({
            'user_id': userId,
            'subject': subject,
            'topic': topic,
            'confidence_level': confidenceLevel,
            'location': 'POINT(${location.longitude} ${location.latitude})',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'is_active': true,
          })
          .select()
          .single();

      logger.info(
          'Created struggle signal: $subject (confidence: $confidenceLevel)');
      // Force the location to be what we passed in (Optimistic),
      // ensuring Constellation gets the correct coordinates even if DB parsing fails.
      return StruggleSignal.fromJson(data).copyWith(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (e) {
      logger.error('Error creating struggle signal', error: e);
      return null;
    }
  }

  /// Get all active struggle signals for a user
  Future<List<StruggleSignal>> getActiveSignals(String userId) async {
    try {
      final data = await _supabase
          .from('struggle_signals')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);

      return data.map((json) => StruggleSignal.fromJson(json)).toList();
    } catch (e) {
      logger.error('Error fetching active signals for user $userId', error: e);
      return [];
    }
  }

  /// Get the current user's active struggle signal (if any)
  Future<StruggleSignal?> getCurrentUserActiveSignal() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final signals = await getActiveSignals(userId);
      return signals.isNotEmpty ? signals.first : null;
    } catch (e) {
      logger.error('Error fetching current user active signal', error: e);
      return null;
    }
  }

  /// Manually expire a struggle signal
  Future<bool> expireSignal(String signalId) async {
    try {
      // Set to epoch to definitely expire it and mark as inactive
      final epoch =
          DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String();
      await _supabase.from('struggle_signals').update({
        'expires_at': epoch,
        'is_active': false,
      }).eq('id', signalId);

      logger.info('Expired struggle signal: $signalId');
      return true;
    } catch (e) {
      logger.error('Error expiring signal $signalId', error: e);
      return false;
    }
  }

  /// Cancel the current user's active struggle signal
  /// Sets is_active = false without deleting the signal (for analytics)
  Future<bool> cancelActiveSignal() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('struggle_signals')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('is_active', true)
          .select();

      if (response.isNotEmpty) {
        logger.info(
            'Canceled ${response.length} active signal(s) for user $userId');
      }
      return true;
    } catch (e) {
      logger.error('Error canceling active signal', error: e);
      return false;
    }
  }

  /// Delete a struggle signal
  Future<bool> deleteSignal(String signalId) async {
    try {
      await _supabase.from('struggle_signals').delete().eq('id', signalId);

      logger.info('Deleted struggle signal: $signalId');
      return true;
    } catch (e) {
      logger.error('Error deleting signal $signalId', error: e);
      return false;
    }
  }

  /// Check if serendipity is enabled for current user
  /// NOTE: Serendipity is now always-on, this method kept for backward compatibility
  @Deprecated('Serendipity is now always enabled')
  Future<bool> isSerendipityEnabled() async {
    return true; // Always enabled
  }

  /// Get serendipity radius for current user
  Future<int> getSerendipityRadius() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 100; // Default

      final data = await _supabase
          .from('profiles')
          .select('serendipity_radius_meters')
          .eq('user_id', userId)
          .maybeSingle();

      return data?['serendipity_radius_meters'] ?? 100;
    } catch (e) {
      logger.error('Error fetching serendipity radius', error: e);
      return 100; // Default
    }
  }

  /// Update serendipity settings for current user
  /// NOTE: 'enabled' parameter is deprecated as Serendipity is now always-on
  Future<bool> updateSettings({
    @Deprecated('Serendipity is now always enabled') bool? enabled,
    int? radiusMeters,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        logger.error('Cannot update settings: User not authenticated');
        return false;
      }

      final updates = <String, dynamic>{};
      // Ignore 'enabled' parameter - Serendipity is always on
      if (radiusMeters != null) {
        updates['serendipity_radius_meters'] = radiusMeters;
      }

      if (updates.isEmpty) return true;

      await _supabase.from('profiles').update(updates).eq('user_id', userId);

      logger.info('Updated serendipity settings: $updates');
      return true;
    } catch (e) {
      logger.error('Error updating serendipity settings', error: e);
      return false;
    }
  }

  /// Get nearby struggle signals (for future proximity matching)
  Future<List<StruggleSignal>> getNearbySignals({
    required LatLng location,
    required double radiusMeters,
    String? excludeUserId,
  }) async {
    try {
      // Use PostGIS ST_DWithin for spatial query
      // Note: This requires a PostGIS extension and proper indexing
      final query = _supabase
          .from('struggle_signals')
          .select()
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());

      // If we need to exclude current user
      if (excludeUserId != null) {
        query.neq('user_id', excludeUserId);
      }

      final data = await query;

      // Filter by distance (client-side for now, can optimize with PostGIS later)
      final signals =
          data.map((json) => StruggleSignal.fromJson(json)).toList();

      return signals.where((signal) {
        final distance = _calculateDistance(
          location.latitude,
          location.longitude,
          signal.latitude,
          signal.longitude,
        );
        return distance <= radiusMeters;
      }).toList();
    } catch (e) {
      logger.error('Error fetching nearby signals', error: e);
      return [];
    }
  }

  /// Calculate distance between two points (Haversine formula)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }
}

final serendipityService = SerendipityService();

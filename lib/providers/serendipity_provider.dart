import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/struggle_signal.dart';
import '../services/serendipity_service.dart';
import '../services/matching_service.dart';
import '../models/serendipity_match.dart';
import '../services/logger_service.dart';

// Provider for UI state to block map interaction
final isModalOpenProvider = StateProvider<bool>((ref) => false);

// NOTE: serendipityEnabledProvider removed - Serendipity is now always-on
// Users interact with it only when they create a signal

// Provider for serendipity radius
final serendipityRadiusProvider =
    AsyncNotifierProvider<SerendipityRadiusNotifier, int>(() {
  return SerendipityRadiusNotifier();
});

class SerendipityRadiusNotifier extends AsyncNotifier<int> {
  @override
  FutureOr<int> build() async {
    return await serendipityService.getSerendipityRadius();
  }

  Future<void> setRadius(int meters) async {
    state = const AsyncValue.loading();
    final success =
        await serendipityService.updateSettings(radiusMeters: meters);
    if (success) {
      state = AsyncValue.data(meters);
    } else {
      state = AsyncValue.error('Failed to update radius', StackTrace.current);
    }
  }
}

// Provider for current user's active struggle signal
final activeStruggleSignalProvider =
    AsyncNotifierProvider<ActiveStruggleSignalNotifier, StruggleSignal?>(() {
  return ActiveStruggleSignalNotifier();
});

class ActiveStruggleSignalNotifier extends AsyncNotifier<StruggleSignal?> {
  Timer? _expirationTimer;

  @override
  FutureOr<StruggleSignal?> build() async {
    // Serendipity is now always-on, no need to check enabled status
    // Cancel any existing timer
    _expirationTimer?.cancel();

    // 1. Fetch from DB
    final signal = await serendipityService.getCurrentUserActiveSignal();

    if (signal != null) {
      logger.debug(
          "📡 Found active signal in DB: ${signal.id} - Expires: ${signal.expiresAt}");

      // 2. CLIENT-SIDE FILTER: Ensure we don't return an expired signal due to clock drift
      if (signal.isExpired) {
        logger.info(
            "💡 Signal ${signal.id} is logically expired. Returning null.");
        return null;
      }

      // 3. EXTRA SAFETY: If a signal is definitively stale (e.g. > 2 hours old), auto-expire it.
      // This helps clear out test data from previous builds.
      final age = DateTime.now().toUtc().difference(signal.createdAt.toUtc());
      if (age.inHours >= 2) {
        logger.info(
            "🗑️ Auto-expiring definitively stale signal: ${signal.id} (Age: ${age.inHours}h)");
        await serendipityService.expireSignal(signal.id);
        return null;
      }

      logger.debug("✅ Signal ${signal.id} is active and valid.");
      // Set up auto-refresh when signal expires
      _scheduleRefresh(signal.timeRemaining);
    } else {
      logger.debug("📡 No active struggle signal found for user.");
    }

    return signal;
  }

  void _scheduleRefresh(Duration delay) {
    _expirationTimer?.cancel();
    _expirationTimer = Timer(delay, () {
      // Refresh the state when signal expires
      ref.invalidateSelf();
    });
  }

  Future<void> createSignal({
    required String subject,
    String? topic,
    required int confidenceLevel,
    required LatLng location,
  }) async {
    state = const AsyncValue.loading();

    final signal = await serendipityService.createStruggleSignal(
      subject: subject,
      topic: topic,
      confidenceLevel: confidenceLevel,
      location: location,
    );

    if (signal != null) {
      state = AsyncValue.data(signal);
      _scheduleRefresh(signal.timeRemaining);
    } else {
      state = AsyncValue.error('Failed to create signal', StackTrace.current);
    }
  }

  Future<void> expireSignal() async {
    final currentSignal = state.value;
    if (currentSignal == null) return;

    state = const AsyncValue.loading();
    final success = await serendipityService.cancelActiveSignal();

    if (success) {
      state = const AsyncValue.data(null);
      _expirationTimer?.cancel();
    } else {
      state = AsyncValue.error('Failed to cancel signal', StackTrace.current);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// Provider for nearby struggle signals (for future proximity matching)
final nearbySignalsProvider =
    FutureProvider.family<List<StruggleSignal>, NearbySignalsParams>(
  (ref, params) async {
    return await serendipityService.getNearbySignals(
      location: params.location,
      radiusMeters: params.radiusMeters,
      excludeUserId: params.excludeUserId,
    );
  },
);

class NearbySignalsParams {
  final LatLng location;
  final double radiusMeters;
  final String? excludeUserId;

  NearbySignalsParams({
    required this.location,
    required this.radiusMeters,
    this.excludeUserId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NearbySignalsParams &&
        other.location.latitude == location.latitude &&
        other.location.longitude == location.longitude &&
        other.radiusMeters == radiusMeters &&
        other.excludeUserId == excludeUserId;
  }

  @override
  int get hashCode {
    return Object.hash(
      location.latitude,
      location.longitude,
      radiusMeters,
      excludeUserId,
    );
  }
}

// Provider for pending matches (Real-time)
final pendingMatchesProvider = StreamProvider<List<SerendipityMatch>>((ref) {
  return matchingService.streamPendingMatches();
});

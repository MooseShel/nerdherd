import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/struggle_signal.dart';
import '../services/serendipity_service.dart';
import '../services/matching_service.dart';
import '../models/serendipity_match.dart';

// Provider for serendipity enabled state
final serendipityEnabledProvider =
    AsyncNotifierProvider<SerendipityEnabledNotifier, bool>(() {
  return SerendipityEnabledNotifier();
});

// Provider for UI state to block map interaction
final isModalOpenProvider = StateProvider<bool>((ref) => false);

class SerendipityEnabledNotifier extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() async {
    return await serendipityService.isSerendipityEnabled();
  }

  Future<void> setEnabled(bool value) async {
    state = const AsyncValue.loading();
    final success = await serendipityService.updateSettings(enabled: value);
    if (success) {
      state = AsyncValue.data(value);
    } else {
      state = AsyncValue.error('Failed to update settings', StackTrace.current);
    }
  }
}

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
    // Cancel any existing timer
    _expirationTimer?.cancel();

    final signal = await serendipityService.getCurrentUserActiveSignal();

    // Set up auto-refresh when signal expires
    if (signal != null && !signal.isExpired) {
      _scheduleRefresh(signal.timeRemaining);
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
    final success = await serendipityService.expireSignal(currentSignal.id);

    if (success) {
      state = const AsyncValue.data(null);
      _expirationTimer?.cancel();
    } else {
      state = AsyncValue.error('Failed to expire signal', StackTrace.current);
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

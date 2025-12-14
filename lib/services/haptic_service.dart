import 'package:flutter/services.dart';
import 'logger_service.dart';

/// Service to handle haptic feedback (vibrations) for a tactile user experience.
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  /// Trigger a light impact vibration.
  /// Use for: Button taps, tab switches, minor interactions.
  Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Haptics might fail on some devices/emulators, ignore to prevents crashes
      logger.debug("Haptic feedback failed", error: e);
    }
  }

  /// Trigger a medium impact vibration.
  /// Use for: Important actions, primary buttons (e.g., "Send", "Accept").
  Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      logger.debug("Haptic feedback failed", error: e);
    }
  }

  /// Trigger a heavy impact vibration.
  /// Use for: Distinct events, changing modes.
  Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      logger.debug("Haptic feedback failed", error: e);
    }
  }

  /// Trigger a success vibration.
  /// Use for: Completed tasks, successful requests.
  Future<void> success() async {
    try {
      // Use heavy impact or a custom pattern if available?
      // Flutter's HapticFeedback only has impacts and selection.
      // We'll simulate "success" with a medium impact for now.
      await HapticFeedback.mediumImpact();
    } catch (e) {
      logger.debug("Haptic feedback failed", error: e);
    }
  }

  /// Trigger a selection vibration.
  /// Use for: Scroll ticks, pickers, sliders.
  Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      logger.debug("Haptic feedback failed", error: e);
    }
  }
}

final hapticService = HapticService();

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// False = Visible (Study Mode), True = Invisible (Ghost Mode)
final ghostModeProvider = AsyncNotifierProvider<GhostModeNotifier, bool>(() {
  return GhostModeNotifier();
});

class GhostModeNotifier extends AsyncNotifier<bool> {
  static const _key = 'ghost_mode';

  @override
  FutureOr<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setGhostMode(bool value) async {
    state = AsyncValue.data(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

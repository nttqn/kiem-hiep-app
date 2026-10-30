import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../render/quality.dart';

/// Chế độ máy yếu, for phones that stutter in battle: no soft glows, no
/// screen shake, fewer decorative effects. Remembered on the device.
class LiteMode {
  LiteMode._();
  static final LiteMode instance = LiteMode._();

  final ValueNotifier<bool> on = ValueNotifier(false);

  /// Whether the player was already offered it after a slow battle.
  bool offered = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apply(prefs.getBool('lite_mode') ?? false);
      offered = prefs.getBool('lite_offered') ?? false;
    } catch (_) {}
  }

  /// Offered once per install, whatever the answer.
  bool get shouldOffer => !on.value && !offered;

  Future<void> markOffered() async {
    offered = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('lite_offered', true);
    } catch (_) {}
  }

  Future<void> toggle() async {
    _apply(!on.value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('lite_mode', on.value);
    } catch (_) {}
  }

  void _apply(bool v) {
    on.value = v;
    liteGraphics = v;
  }
}

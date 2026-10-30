import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../render/quality.dart';

/// Chế độ máy yếu, for phones that stutter in battle: no soft glows, no
/// screen shake, fewer decorative effects. Remembered on the device.
class LiteMode {
  LiteMode._();
  static final LiteMode instance = LiteMode._();

  final ValueNotifier<bool> on = ValueNotifier(false);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apply(prefs.getBool('lite_mode') ?? false);
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

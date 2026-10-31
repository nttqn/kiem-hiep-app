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

/// Tầm nhìn: how much of the map a battle shows. Gần was the only view
/// before 1.2.8; players on long screens found it narrow.
class ViewRange {
  ViewRange._();
  static final ViewRange instance = ViewRange._();

  static const names = ['Gần', 'Vừa', 'Xa'];
  static const spans = [400.0, 460.0, 520.0];

  final ValueNotifier<int> level = ValueNotifier(1);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apply(prefs.getInt('view_range') ?? 1);
    } catch (_) {}
  }

  /// Gần → Vừa → Xa → Gần.
  Future<void> next() async {
    _apply((level.value + 1) % spans.length);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('view_range', level.value);
    } catch (_) {}
  }

  void _apply(int v) {
    level.value = v.clamp(0, spans.length - 1);
    viewSpan = spans[level.value];
  }
}

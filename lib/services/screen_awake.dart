import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the phone's screen on while a fight is shown (1.13.0): a review
/// said the screen dimmed and slept during auto-fight, which pauses the
/// game. Counted, because a fight replacing another starts before the old
/// one is gone.
class ScreenAwake {
  ScreenAwake._();

  static const _ch = MethodChannel('kh/screen');
  static int _holds = 0;

  static void hold() {
    if (_holds++ == 0) _set(true);
  }

  static void release() {
    if (_holds == 0) return;
    if (--_holds == 0) _set(false);
  }

  static int get holds => _holds;

  static Future<void> _set(bool on) async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod<void>('keepOn', on);
    } catch (_) {
      // Desktop, tests, or an old native side: the screen just behaves as
      // the phone says.
    }
  }
}

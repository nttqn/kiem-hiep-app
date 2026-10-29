import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/funnel.dart';
import '../core/hero.dart';
import '../core/world_boss.dart' show vnDayKey;

/// Firebase Analytics: where players get to and where they stop. No user ID
/// is set, so events stay tied to an app-instance ID only. Everything is a
/// no-op on web, in tests, or when Firebase is not configured.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  FirebaseAnalytics? get _fa {
    if (kIsWeb) return null;
    try {
      return Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa?.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('analytics $name: $e');
    }
  }

  /// Last progress seen per save slot: level, rebirths, tower, main quest.
  final Map<int, List<int>> _seen = {};

  /// Called on every save: logs whatever progressed since the last one.
  void track(int slot, HeroData h) {
    final now = [h.level, h.rebirths, h.towerBest, h.mainQuest];
    final was = _seen[slot];
    _seen[slot] = now;
    final sect = h.sect.name;
    // New-player funnel: each step once per hero (kept in the save), with
    // the play time it took; also on the first save of a session, so a
    // "came back on day N" step is sent when they open the game.
    for (final step in funnelDue(h, vnDayKey())) {
      h.funnel.add(step);
      log(step, {'min': h.playSeconds ~/ 60, 'sect': sect});
    }
    if (was == null) return;
    if (now[1] > was[1]) {
      log('rebirth', {'count': now[1], 'sect': sect});
    } else if (now[0] > was[0]) {
      try {
        _fa?.logLevelUp(level: now[0], character: sect);
      } catch (_) {}
    }
    if (now[2] > was[2]) log('tower_floor', {'floor': now[2], 'level': h.level});
    if (now[3] > was[3]) log('main_quest', {'index': now[3], 'level': h.level});
  }
}

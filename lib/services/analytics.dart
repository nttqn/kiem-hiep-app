import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/funnel.dart';
import '../core/hero.dart';
import '../core/world_boss.dart' show vnDayKey;
import 'save.dart';

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

  /// Sets the `lang` user property (1.22): every report in Firebase can
  /// then be filtered to the players of one language.
  Future<void> setLang(String code) async {
    try {
      await _fa?.setUserProperty(name: 'lang', value: code);
    } catch (e) {
      debugPrint('analytics lang: $e');
    }
  }

  Future<void> log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa?.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('analytics $name: $e');
    }
  }

  static const _sentKey = 'funnel_sent';
  Set<String>? _sent;
  bool _loading = false;

  Future<void> _loadSent() async {
    if (_loading) return;
    _loading = true;
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_sentKey);
      if (list != null) {
        _sent = list.toSet();
      } else {
        final s = seedDeviceFunnel(SaveService.instance.slots);
        _sent = s;
        await p.setStringList(_sentKey, s.toList());
      }
    } catch (_) {
      _loading = false; // tried again on a later save
    }
  }

  void _saveSent(Set<String> s) {
    SharedPreferences.getInstance().then((p) => p.setStringList(_sentKey, s.toList())).catchError((_) => false);
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
    // Sent once per phone (1.16.2); until the phone's set is read, steps
    // wait in the save for the next one.
    final sent = _sent;
    if (sent == null) {
      _loadSent();
    } else {
      var grew = false;
      for (final step in funnelDue(h, vnDayKey())) {
        h.funnel.add(step);
        if (sent.add(step)) {
          grew = true;
          log(step, {'min': h.playSeconds ~/ 60, 'sect': sect});
        }
      }
      if (grew) _saveSent(sent);
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

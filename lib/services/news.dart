import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';
import '../core/news.dart';
import '../core/world_boss.dart' show vnDayKey;
import 'analytics.dart';
import 'cloud.dart';

/// Bảng tin (1.16.3): listens to `news` (Firebase console) for as long as
/// the app runs, like Hòm thư, and remembers on this phone which notices
/// were read. No sign-in needed.
class NewsService extends ChangeNotifier {
  NewsService._();
  static final NewsService instance = NewsService._();

  static bool get _ios => !kIsWeb && Platform.isIOS;

  /// Notices to show instead of Firestore (dev build screenshots).
  List<NewsDef>? debugNews;

  /// Documents as last heard; read in the playing language on use.
  List<(String, Map<String, dynamic>)> _docs = const [];
  List<NewsDef> _parsed = const [];
  Lang? _parsedFor;
  List<NewsDef> get _all {
    if (_parsedFor != currentLang) {
      _parsedFor = currentLang;
      _parsed = [for (final (id, m) in _docs) ?NewsDef.fromMap(id, m)];
    }
    return _parsed;
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Set<String> _read = {};
  Set<String> _popped = {};
  bool _prefsLoaded = false;
  final Completer<void> _first = Completer<void>();

  /// What the board shows today, pinned first.
  List<NewsDef> get news => NewsDef.visible(debugNews ?? _all, vnDayKey(), ios: _ios);

  bool isRead(NewsDef n) => _read.contains(n.id);

  int get unread => news.where((n) => !_read.contains(n.id)).length;

  Future<void> refresh() async {
    await _loadPrefs();
    if (debugNews != null || !CloudSave.instance.available) return;
    // Keep the collection small (delete old notices): each start of the
    // listener reads every document.
    _sub ??= FirebaseFirestore.instance.collection('news').limit(20).snapshots().listen(
      (snap) {
        _docs = [for (final d in snap.docs) (d.id, _days(d.data()))];
        _parsedFor = null;
        if (!_first.isCompleted) _first.complete();
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('news listen failed: $e');
        _sub = null; // the next refresh tries again
      },
    );
  }

  static Map<String, dynamic> _days(Map<String, dynamic> m) => {
        for (final e in m.entries) e.key: e.value is Timestamp ? vnDayKey((e.value as Timestamp).toDate()) : e.value,
      };

  Future<void> _loadPrefs() async {
    if (_prefsLoaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      _read = {...?p.getStringList('news_read')};
      _popped = {...?p.getStringList('news_popped')};
      _prefsLoaded = true;
    } catch (_) {}
  }

  /// Ids kept on the phone: only those still posted, so the lists stay short.
  List<String> _trim(Set<String> ids) {
    final live = {for (final n in debugNews ?? _all) n.id};
    return [for (final id in ids) if (live.isEmpty || live.contains(id)) id];
  }

  Future<void> markRead(NewsDef n) async {
    if (!_read.add(n.id)) return;
    Analytics.instance.log('news_open', {'id': n.id});
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('news_read', _trim(_read));
    } catch (_) {}
  }

  /// The first unread notice marked `popup` not yet popped on this phone;
  /// taking it marks it popped.
  Future<NewsDef?> takePopup() async {
    await _loadPrefs();
    if (debugNews == null && _sub != null) {
      // The listener may not have heard back yet on a cold start.
      await _first.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    }
    for (final n in news) {
      if (n.popup && !_read.contains(n.id) && !_popped.contains(n.id)) {
        _popped.add(n.id);
        try {
          final p = await SharedPreferences.getInstance();
          await p.setStringList('news_popped', _trim(_popped));
        } catch (_) {}
        return n;
      }
    }
    return null;
  }

  static const _channel = MethodChannel('kh/screen');

  /// Opens the notice's button link (store page or web page) outside the
  /// game; false when nothing could open it.
  Future<bool> open(NewsDef n) async {
    final url = n.linkFor(ios: _ios);
    if (url.isEmpty) return false;
    Analytics.instance.log('news_click', {'id': n.id});
    try {
      return await _channel.invokeMethod<bool>('openUrl', url) ?? false;
    } catch (e) {
      debugPrint('open url: $e');
      return false;
    }
  }
}

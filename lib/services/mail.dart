import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/hero.dart';
import '../core/i18n.dart';
import '../core/live_event.dart';
import '../core/mail.dart';
import '../core/world_boss.dart';
import 'cloud.dart';
import 'language.dart';

/// Hòm thư and Sự kiện: reads the gifts posted in `mail` and the boosts in
/// `events` (Firebase console). No sign-in needed.
///
/// 1.9.1: one listener for each, for as long as the app runs, instead of
/// reading every document again every ten minutes: Firestore then bills
/// the documents once, and after that only the ones that change.
class MailService extends ChangeNotifier {
  MailService._();
  static final MailService instance = MailService._();

  List<MailDef> mails = const [];

  /// Every mail document as last heard, before the day and player filter.
  List<MailDef> get _all {
    if (_parsedFor != currentLang) {
      _parsedFor = currentLang;
      _parsed = [for (final (id, m) in _docs) ?MailDef.fromMap(id, m)];
    }
    return _parsed;
  }

  /// Documents as last heard; read in the playing language on use.
  List<(String, Map<String, dynamic>)> _docs = const [];
  List<MailDef> _parsed = const [];
  Lang? _parsedFor;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mailSub, _eventSub;

  /// Event documents as last heard, read again when the language changes.
  List<(String, Map<String, dynamic>)> _eventDocs = const [];
  bool _langHooked = false;

  void _parseEvents() {
    liveEvents = [for (final (id, m) in _eventDocs) ?LiveEvent.fromMap(id, m)];
  }

  /// Mails to show instead of Firestore (dev build screenshots).
  List<MailDef>? debugMails;

  /// Starts listening if not yet, and filters the open mails, newest first,
  /// for today and the player signed in now.
  Future<void> refresh() async {
    final dbg = debugMails;
    if (dbg != null) {
      if (!identical(mails, dbg)) {
        mails = dbg;
        notifyListeners();
      }
      return;
    }
    if (!CloudSave.instance.available) return;
    _listen();
    _filter();
  }

  void _listen() {
    final db = FirebaseFirestore.instance;
    // Keep the collection small (delete old mails): each listener start
    // reads every document. `until` may be typed in the console as text
    // or as a timestamp, so dates are filtered here, not in the query.
    _mailSub ??= db.collection('mail').limit(30).snapshots().listen(
      (snap) {
        _docs = [for (final d in snap.docs) (d.id, _days(d.data()))];
        _parsedFor = null;
        _filter();
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('mail listen failed: $e');
        _mailSub = null; // the next refresh tries again
      },
    );
    _eventSub ??= db.collection('events').limit(10).snapshots().listen(
      (snap) {
        _eventDocs = [for (final d in snap.docs) (d.id, _days(d.data()))];
        _parseEvents();
        if (!_langHooked) {
          _langHooked = true;
          LanguageService.instance.lang.addListener(() {
            _parseEvents();
            notifyListeners();
          });
        }
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('events listen failed: $e');
        _eventSub = null;
      },
    );
  }

  void _filter() {
    final today = vnDayKey();
    final uid = CloudSave.instance.user?.uid;
    mails = [
      for (final m in _all)
        if (m.openOn(today) && (m.uid.isEmpty || m.uid == uid)) m,
    ]..sort((a, b) => b.from.compareTo(a.from));
  }

  /// [m] with console timestamps in `from` / `until` turned into Vietnam
  /// days.
  static Map<String, dynamic> _days(Map<String, dynamic> m) => {
        for (final e in m.entries) e.key: e.value is Timestamp ? vnDayKey((e.value as Timestamp).toDate()) : e.value,
      };

  /// Gifts [h] can take today.
  List<MailDef> open(HeroData h) {
    final day = vnDayKey();
    return [for (final m in mails) if (h.canClaimMail(m, day)) m];
  }
}

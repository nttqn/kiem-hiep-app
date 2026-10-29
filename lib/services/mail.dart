import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/hero.dart';
import '../core/live_event.dart';
import '../core/mail.dart';
import '../core/world_boss.dart';
import 'cloud.dart';

/// Hòm thư and Sự kiện: reads the gifts posted in `mail` and the boosts in
/// `events` (Firebase console). No sign-in needed; a handful of reads at
/// most every ten minutes, from the town.
class MailService extends ChangeNotifier {
  MailService._();
  static final MailService instance = MailService._();

  List<MailDef> mails = const [];
  DateTime? _fetched;
  bool _busy = false;

  /// Mails to show instead of Firestore (dev build screenshots).
  List<MailDef>? debugMails;

  /// The open mails, newest first, after a fetch at most every [every].
  Future<void> refresh({Duration every = const Duration(minutes: 10)}) async {
    final dbg = debugMails;
    if (dbg != null) {
      if (!identical(mails, dbg)) {
        mails = dbg;
        notifyListeners();
      }
      return;
    }
    if (_busy || !CloudSave.instance.available) return;
    final last = _fetched;
    if (last != null && DateTime.now().difference(last) < every) return;
    _busy = true;
    try {
      final today = vnDayKey();
      // Every mail document (keep the collection small: delete old ones).
      // `until` may be typed in the console as text or as a timestamp, so
      // dates are filtered here rather than in the query.
      final snap = await FirebaseFirestore.instance
          .collection('mail')
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 10));
      final out = [for (final d in snap.docs) ?MailDef.fromMap(d.id, _days(d.data()))]
        ..removeWhere((m) => !m.openOn(today))
        ..sort((a, b) => b.from.compareTo(a.from));
      mails = out;
    } catch (e) {
      debugPrint('mail fetch failed: $e');
    }
    // Sự kiện (`events`), read alongside: a few documents at most.
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .limit(10)
          .get()
          .timeout(const Duration(seconds: 10));
      liveEvents = [for (final d in snap.docs) ?LiveEvent.fromMap(d.id, _days(d.data()))];
    } catch (e) {
      debugPrint('events fetch failed: $e');
    }
    // Try again at the next interval, whether it worked or not.
    _fetched = DateTime.now();
    _busy = false;
    notifyListeners();
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

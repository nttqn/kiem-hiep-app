import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/hero.dart';
import '../core/mail.dart';
import '../core/world_boss.dart';
import 'cloud.dart';

/// Hòm thư: reads the gifts posted in `mail` (Firebase console) that are
/// still open. No sign-in needed; a handful of reads at most every few
/// minutes, from the town.
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
      final snap = await FirebaseFirestore.instance
          .collection('mail')
          .where('until', isGreaterThanOrEqualTo: today)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 10));
      final out = [for (final d in snap.docs) ?MailDef.fromMap(d.id, d.data())]
        ..removeWhere((m) => !m.openOn(today))
        ..sort((a, b) => b.from.compareTo(a.from));
      mails = out;
      _fetched = DateTime.now();
      notifyListeners();
    } catch (e) {
      // Try again at the next interval, not on every save.
      _fetched = DateTime.now();
      debugPrint('mail fetch failed: $e');
    }
    _busy = false;
  }

  /// Gifts [h] can take today.
  List<MailDef> open(HeroData h) {
    final day = vnDayKey();
    return [for (final m in mails) if (h.canClaimMail(m, day)) m];
  }
}

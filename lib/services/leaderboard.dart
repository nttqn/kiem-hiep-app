import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/arena.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/world_boss.dart';
import 'cloud.dart';

/// One row of the public leaderboard: a hero of a signed-in player.
class LbEntry {
  const LbEntry({
    required this.id,
    required this.name,
    required this.hanh,
    required this.level,
    required this.rebirths,
    required this.power,
    required this.tower,
    this.title = '',
  });

  /// `{uid}_{slot}`.
  final String id;
  final String name;
  final int hanh;
  final int level;
  final int rebirths;
  final int power;
  final int tower;
  final String title;

  /// Rebirths outrank levels: 1 rebirth at level 10 beats level 99.
  int get rank => rebirths * 100 + level;

  static LbEntry? fromDoc(String id, Map<String, dynamic> m) {
    try {
      return LbEntry(
        id: id,
        name: m['name'] as String,
        hanh: (m['hanh'] as num).toInt().clamp(0, 4),
        level: (m['level'] as num).toInt(),
        rebirths: (m['rebirths'] as num?)?.toInt() ?? 0,
        power: (m['power'] as num).toInt(),
        tower: (m['tower'] as num?)?.toInt() ?? 0,
        title: m['title'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

enum LbBoard { power, tower, rank }

extension LbBoardField on LbBoard {
  String get field => switch (this) {
        LbBoard.power => 'power',
        LbBoard.tower => 'tower',
        LbBoard.rank => 'rank',
      };

  int valueOf(LbEntry e) => switch (this) {
        LbBoard.power => e.power,
        LbBoard.tower => e.tower,
        LbBoard.rank => e.rank,
      };
}

/// Public leaderboard in Firestore (`leaderboard/{uid}_{slot}`), fed by the
/// cloud uploads of signed-in players who have not hidden themselves.
class Leaderboard extends ChangeNotifier {
  Leaderboard._();
  static final Leaderboard instance = Leaderboard._();

  bool hidden = false;

  /// Rows to show instead of Firestore (dev build screenshots).
  List<LbEntry>? debugEntries;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hidden = prefs.getBool('lb_hidden') ?? false;
    } catch (_) {}
  }

  CloudSave get _cloud => CloudSave.instance;
  bool get available => debugEntries != null || (_cloud.available && _cloud.user != null);
  String? get myUid => _cloud.user?.uid;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('leaderboard');

  /// Writes [h] (in [slot]) to the board. Called with every cloud upload.
  Future<void> submit(int slot, HeroData h) async {
    final uid = myUid;
    if (hidden || uid == null || debugEntries != null) return;
    try {
      await _col.doc('${uid}_$slot').set({
        'uid': uid,
        'name': h.name.length > 24 ? h.name.substring(0, 24) : h.name,
        'hanh': h.hanh.index,
        'level': h.level,
        'rebirths': h.rebirths,
        'rank': h.rebirths * 100 + h.level,
        'power': h.power,
        'tower': h.towerBest,
        'title': h.title.length > 40 ? h.title.substring(0, 40) : h.title,
        'updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('leaderboard submit failed: $e');
    }
  }

  // ------------------------------------------------------------ boss

  /// The day's Boss Thế Giới board: `worldboss/{yyyymmdd}/hits/{uid}_{slot}`.
  CollectionReference<Map<String, dynamic>> _boss(String day) =>
      FirebaseFirestore.instance.collection('worldboss').doc(day).collection('hits');

  /// Rows to show for the boss board in the dev build.
  List<LbEntry>? debugBoss;

  /// Writes [h]'s damage total for its Boss Thế Giới day.
  Future<void> submitBoss(int slot, HeroData h) async {
    final uid = myUid;
    if (hidden || uid == null || debugBoss != null || h.wbDay.isEmpty) return;
    try {
      await _boss(h.wbDay).doc('${uid}_$slot').set({
        'uid': uid,
        'name': h.name.length > 24 ? h.name.substring(0, 24) : h.name,
        'hanh': h.hanh.index,
        'level': h.level,
        'rebirths': h.rebirths,
        'dmg': h.wbTotal,
        'updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('boss submit failed: $e');
    }
  }

  /// The day's top [limit] damage totals (damage carried in [LbEntry.power]).
  Future<List<LbEntry>> topBoss(String day, {int limit = 30}) async {
    final dbg = debugBoss;
    if (dbg != null) {
      return (List<LbEntry>.of(dbg)..sort((a, b) => b.power.compareTo(a.power))).take(limit).toList();
    }
    final snap = await _boss(day).orderBy('dmg', descending: true).limit(limit).get().timeout(
          const Duration(seconds: 15),
        );
    return [
      for (final d in snap.docs) ?LbEntry.fromDoc(d.id, {...d.data(), 'power': d.data()['dmg']}),
    ];
  }

  Future<int?> placeBoss(String day, int dmg) async {
    final dbg = debugBoss;
    if (dbg != null) return dbg.where((e) => e.power > dmg).length + 1;
    try {
      final agg = await _boss(day).where('dmg', isGreaterThan: dmg).count().get();
      return (agg.count ?? 0) + 1;
    } catch (_) {
      return null;
    }
  }

  /// Removes this player's rows (hiding, deleting a slot or the account).
  Future<void> withdraw({int? slot}) async {
    final uid = myUid;
    if (uid == null) return;
    for (var i = 0; i < 3; i++) {
      if (slot != null && i != slot) continue;
      try {
        await _col.doc('${uid}_$i').delete();
        await _boss(vnDayKey()).doc('${uid}_$i').delete();
      } catch (_) {}
    }
  }

  Future<void> setHidden(bool v) async {
    hidden = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('lb_hidden', v);
    } catch (_) {}
    if (v) await withdraw();
  }

  /// The best [limit] rows of [board].
  Future<List<LbEntry>> top(LbBoard board, {int limit = 50}) async {
    final dbg = debugEntries;
    if (dbg != null) {
      return (List<LbEntry>.of(dbg)..sort((a, b) => board.valueOf(b).compareTo(board.valueOf(a))))
          .take(limit)
          .toList();
    }
    final snap = await _col.orderBy(board.field, descending: true).limit(limit).get().timeout(
          const Duration(seconds: 15),
        );
    return [
      for (final d in snap.docs) ?LbEntry.fromDoc(d.id, d.data()),
    ];
  }

  /// Other players' heroes with power near [power], as Lôi đài challengers.
  /// Needs Firebase but not a sign-in (the board is public).
  Future<List<ArenaRival>> arenaPool(int power) async {
    final dbg = debugEntries;
    final me = myUid;
    List<LbEntry> rows;
    if (dbg != null) {
      rows = dbg;
    } else {
      if (!_cloud.available) return const [];
      final snap = await _col
          .where('power', isGreaterThanOrEqualTo: (power * 0.6).round())
          .where('power', isLessThanOrEqualTo: (power * 1.5).round())
          .orderBy('power')
          .limit(40)
          .get()
          .timeout(const Duration(seconds: 10));
      rows = [for (final d in snap.docs) ?LbEntry.fromDoc(d.id, d.data())];
    }
    return [
      for (final e in rows)
        if (me == null || !e.id.startsWith('${me}_'))
          ArenaRival(
            name: e.name,
            hanh: Hanh.values[e.hanh],
            level: e.level,
            rebirths: e.rebirths,
            power: e.power,
            title: e.title,
            female: e.id.hashCode.isOdd,
          ),
    ];
  }

  /// 1-based place a value of [value] would hold on [board].
  Future<int?> placeOf(LbBoard board, int value) async {
    final dbg = debugEntries;
    if (dbg != null) return dbg.where((e) => board.valueOf(e) > value).length + 1;
    try {
      final agg = await _col.where(board.field, isGreaterThan: value).count().get();
      return (agg.count ?? 0) + 1;
    } catch (_) {
      return null;
    }
  }
}

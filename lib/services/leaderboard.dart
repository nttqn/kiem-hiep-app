import 'dart:math' as math;

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
    this.arenaS = 0,
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

  /// Lôi đài season and points as one number ([arenaSeasonScore]); 0 when
  /// they have not fought this season.
  final int arenaS;

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
        arenaS: (m['arenaS'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A page of a board, and where the next one starts (null at the end).
class LbPage {
  const LbPage(this.rows, this.next);
  final List<LbEntry> rows;
  final Object? next;
}

enum LbBoard { power, tower, rank, arena }

extension LbBoardField on LbBoard {
  String get field => switch (this) {
        LbBoard.power => 'power',
        LbBoard.tower => 'tower',
        LbBoard.rank => 'rank',
        LbBoard.arena => 'arenaS',
      };

  int valueOf(LbEntry e) => switch (this) {
        LbBoard.power => e.power,
        LbBoard.tower => e.tower,
        LbBoard.rank => e.rank,
        LbBoard.arena => e.arenaS,
      };
}

/// This hero's Lôi đài board value: 0 until they fight this season.
int arenaBoardValue(HeroData h) =>
    h.arenaSeason > 0 && h.arenaSeasonFights > 0 ? arenaSeasonScore(h.arenaSeason, h.arenaPoints) : 0;

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

  /// What was last written per row, so unchanged heroes cost no writes.
  final Map<String, String> _sent = {};

  /// Writes [h] (in [slot]) to the board. Called with every cloud upload;
  /// skips the write when nothing on the row changed.
  Future<void> submit(int slot, HeroData h) async {
    final uid = myUid;
    if (hidden || uid == null || debugEntries != null) return;
    final id = '${uid}_$slot';
    final row = <String, Object>{
      'uid': uid,
      'name': h.name.length > 24 ? h.name.substring(0, 24) : h.name,
      'hanh': h.hanh.index,
      'level': h.level,
      'rebirths': h.rebirths,
      'rank': h.rebirths * 100 + h.level,
      'power': h.power,
      'tower': h.towerBest,
      'title': h.title.length > 40 ? h.title.substring(0, 40) : h.title,
      'arenaS': arenaBoardValue(h),
    };
    final key = row.toString();
    if (_sent[id] == key) return;
    try {
      // A write only completes once the server takes it, which can be never
      // when offline or over quota; don't hold the caller that long.
      await _col.doc(id).set({...row, 'updated': FieldValue.serverTimestamp()}).timeout(
            const Duration(seconds: 8),
          );
      _sent[id] = key;
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
      }).timeout(const Duration(seconds: 8));
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
      final agg =
          await _boss(day).where('dmg', isGreaterThan: dmg).count().get().timeout(const Duration(seconds: 10));
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

  /// Rows per page of [top].
  static const int pageSize = 50;

  /// The Lôi đài board lists this season only.
  int _floor(LbBoard board) => board == LbBoard.arena ? arenaSeasonScore(arenaSeasonOf(vnDayKey()), 0) : 0;

  List<LbEntry> _debugSorted(LbBoard board) {
    final floor = _floor(board);
    return debugEntries!.where((e) => board.valueOf(e) >= floor).toList()
      ..sort((a, b) => board.valueOf(b).compareTo(board.valueOf(a)));
  }

  /// One page of [board] from the top: the first [pageSize] rows, or the
  /// ones after [after] (the [LbPage.next] of the page before).
  Future<LbPage> top(LbBoard board, {Object? after, int limit = pageSize}) async {
    final floor = _floor(board);
    final dbg = debugEntries;
    if (dbg != null) {
      final all = _debugSorted(board);
      final from = after as int? ?? 0;
      final rows = all.skip(from).take(limit).toList();
      return LbPage(rows, from + rows.length < all.length ? from + rows.length : null);
    }
    Query<Map<String, dynamic>> q = _col;
    if (floor > 0) q = q.where(board.field, isGreaterThanOrEqualTo: floor);
    q = q.orderBy(board.field, descending: true);
    if (after is DocumentSnapshot) q = q.startAfterDocument(after);
    final snap = await q.limit(limit).get().timeout(const Duration(seconds: 15));
    return LbPage(
      [for (final d in snap.docs) ?LbEntry.fromDoc(d.id, d.data())],
      snap.docs.length == limit ? snap.docs.last : null,
    );
  }

  /// The rows around a value of [value] on [board]: up to [span] above it,
  /// then it and up to [span] below. The caller numbers them from its place.
  Future<(List<LbEntry> above, List<LbEntry> rest)> around(LbBoard board, int value, {int span = 10}) async {
    final floor = _floor(board);
    final dbg = debugEntries;
    if (dbg != null) {
      final all = _debugSorted(board);
      final above = all.where((e) => board.valueOf(e) > value).toList();
      final rest = all.where((e) => board.valueOf(e) <= value).take(span + 1).toList();
      return (above.sublist(math.max(0, above.length - span)), rest);
    }
    final up = await _col
        .where(board.field, isGreaterThan: value)
        .orderBy(board.field)
        .limit(span)
        .get()
        .timeout(const Duration(seconds: 15));
    Query<Map<String, dynamic>> q = _col.where(board.field, isLessThanOrEqualTo: value);
    if (floor > 0) q = q.where(board.field, isGreaterThanOrEqualTo: floor);
    final down = await q.orderBy(board.field, descending: true).limit(span + 1).get().timeout(
          const Duration(seconds: 15),
        );
    return (
      [for (final d in up.docs.reversed) ?LbEntry.fromDoc(d.id, d.data())],
      [for (final d in down.docs) ?LbEntry.fromDoc(d.id, d.data())],
    );
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
      final agg = await _col
          .where(board.field, isGreaterThan: value)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return (agg.count ?? 0) + 1;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/arena.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/hung_thu.dart';
import '../core/ma_vuc.dart';
import '../core/weekly_hunt.dart';
import '../core/world_boss.dart';
import 'cloud.dart';
import 'save.dart' show slotCount;

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
    this.wk = 0,
    this.dhC = 0,
    this.tm = 0,
    this.mv = 0,
    this.ht = 0,
    this.mount,
    this.mountLv = 1,
    this.skin = '',
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

  /// Săn quái tuần: week and kills as one number ([huntScore]).
  final int wk;

  /// Võ Lâm Đại Hội titles won.
  final int dhC;

  /// Tâm Ma Ảo Cảnh best floor; Ma Vực week and floor ([maVucScore]);
  /// Hung Thú week, difficulty and speed ([beastScore]) (1.8.0+).
  final int tm, mv, ht;

  /// The mount ridden, for Lôi đài copies; '' on foot, null when the row
  /// was written by an app older than 1.4.0, which did not send it.
  final String? mount;
  final int mountLv;

  /// Mount look (1.7.0+).
  final String skin;

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
        wk: (m['wk'] as num?)?.toInt() ?? 0,
        dhC: (m['dhC'] as num?)?.toInt() ?? 0,
        tm: (m['tm'] as num?)?.toInt() ?? 0,
        mv: (m['mv'] as num?)?.toInt() ?? 0,
        ht: (m['ht'] as num?)?.toInt() ?? 0,
        mount: m['mount'] as String?,
        mountLv: (m['mountLv'] as num?)?.toInt() ?? 1,
        skin: m['skin'] as String? ?? '',
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

enum LbBoard { power, tower, rank, arena, hunt, daiHoi, tamMa, maVuc, beast }

extension LbBoardField on LbBoard {
  String get field => switch (this) {
        LbBoard.power => 'power',
        LbBoard.tower => 'tower',
        LbBoard.rank => 'rank',
        LbBoard.arena => 'arenaS',
        LbBoard.hunt => 'wk',
        LbBoard.daiHoi => 'dhC',
        LbBoard.tamMa => 'tm',
        LbBoard.maVuc => 'mv',
        LbBoard.beast => 'ht',
      };

  int valueOf(LbEntry e) => switch (this) {
        LbBoard.power => e.power,
        LbBoard.tower => e.tower,
        LbBoard.rank => e.rank,
        LbBoard.arena => e.arenaS,
        LbBoard.hunt => e.wk,
        LbBoard.daiHoi => e.dhC,
        LbBoard.tamMa => e.tm,
        LbBoard.maVuc => e.mv,
        LbBoard.beast => e.ht,
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

  /// Accounts banned by hand (`lbBans/{uid}` in the console): their rows
  /// are left out of every board and of Lôi đài (1.9.1), so a ban no longer
  /// needs their rows deleted too. Read at most every half hour.
  Set<String> _banned = const {};
  DateTime? _bannedAt;

  Future<Set<String>> _bans() async {
    final at = _bannedAt;
    if (at != null && DateTime.now().difference(at) < const Duration(minutes: 30)) return _banned;
    _bannedAt = DateTime.now();
    try {
      final snap = await FirebaseFirestore.instance.collection('lbBans').limit(500).get().timeout(
            const Duration(seconds: 8),
          );
      _banned = {for (final d in snap.docs) d.id};
    } catch (e) {
      debugPrint('lbBans read failed: $e');
    }
    return _banned;
  }

  /// Whether row [id] (`{uid}_{slot}`) belongs to a banned account.
  static bool bannedRow(Set<String> bans, String id) {
    if (bans.isEmpty) return false;
    final i = id.lastIndexOf('_');
    return bans.contains(i > 0 ? id.substring(0, i) : id);
  }

  /// Day boards of Boss Thế Giới read lately (1.9.1), cleared on this
  /// player's own write.
  final Map<String, (DateTime, List<LbEntry>)> _bossCache = {};
  static const Duration _bossFresh = Duration(minutes: 3);

  /// What was last written per row, so unchanged heroes cost no writes.
  final Map<String, String> _sent = {};
  final Map<String, int> _sentPower = {};
  final Map<String, int> _sentHunt = {};
  final Map<String, DateTime> _sentAt = {};
  static const Duration _powerQuiet = Duration(minutes: 30);

  /// Writes [h] (in [slot]) to the board. Called with every cloud upload;
  /// skips the write when nothing on the row changed, unless [force]d (the
  /// player opening the board wants to see their latest numbers).
  Future<void> submit(int slot, HeroData h, {bool force = false}) async {
    final uid = myUid;
    if (hidden || uid == null || debugEntries != null) return;
    h.huntRollDay(vnDayKey());
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
      if (h.arenaLastScore > 0) 'arenaLast': h.arenaLastScore,
      'wk': h.huntBoardValue,
      if (h.huntLastScore > 0) 'wkLast': h.huntLastScore,
      if (h.dhChamps > 0) 'dhC': h.dhChamps,
      if (h.tmBest > 0) 'tm': h.tmBest,
      if (h.maVucBoardValue > 0) 'mv': h.maVucBoardValue,
      if (h.beastBoardValue > 0) 'ht': h.beastBoardValue,
      'mount': h.ridingMount?.id ?? '',
      'mountLv': h.mountLevels[h.activeMount] ?? 1,
      'skin': h.ridingMount == null ? '' : h.mountSkin[h.activeMount] ?? '',
    };
    // Play time goes along for the rules' sanity check, but on its own
    // does not call for a write; nor do lực chiến creeping up by a little
    // (a new gem, a pet level) or this week's kills, more than every
    // [_powerQuiet].
    final key = (Map.of(row)
          ..remove('power')
          ..remove('wk'))
        .toString();
    final last = _sentPower[id];
    final now = DateTime.now();
    final at = _sentAt[id];
    final quiet = at != null && now.difference(at) < _powerQuiet;
    final same = _sent[id] == key && last == h.power && _sentHunt[id] == h.huntBoardValue;
    // Forced or not, a row identical to the one sent is not sent again
    // (1.9.1: opening the board used to write every time).
    if (same ||
        (!force &&
            _sent[id] == key &&
            last != null &&
            ((h.power - last).abs() < last * 0.03 && quiet) &&
            (_sentHunt[id] == h.huntBoardValue || quiet))) {
      return;
    }
    try {
      // A write only completes once the server takes it, which can be never
      // when offline or over quota; don't hold the caller that long.
      await _col
          .doc(id)
          .set({
            ...row,
            'play': h.playSeconds.round(),
            'pts': h.potentialTotal,
            'updated': FieldValue.serverTimestamp(),
          }).timeout(
            const Duration(seconds: 8),
          );
      _sent[id] = key;
      _sentPower[id] = h.power;
      _sentHunt[id] = h.huntBoardValue;
      _sentAt[id] = now;
      _topCache.clear(); // show this player's new numbers next time
    } catch (e) {
      debugPrint('leaderboard submit failed: $e');
    }
  }

  /// Reports [e] as cheating (`lbReports/{row}_{uid}`, read in the
  /// console). Once per row and player.
  Future<bool> report(LbEntry e) async {
    final uid = myUid;
    if (uid == null || debugEntries != null) return debugEntries != null;
    try {
      await FirebaseFirestore.instance.collection('lbReports').doc('${e.id}_$uid').set({
        'row': e.id,
        'uid': uid,
        'name': e.name,
        'at': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      return true;
    } catch (err) {
      debugPrint('leaderboard report failed: $err');
      return false;
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
    final sentKey = '${h.wbDay}/${uid}_$slot';
    if (_bossSent[sentKey] == h.wbTotal) return; // nothing new to write
    try {
      await _boss(h.wbDay).doc('${uid}_$slot').set({
        'uid': uid,
        'name': h.name.length > 24 ? h.name.substring(0, 24) : h.name,
        'hanh': h.hanh.index,
        'level': h.level,
        'rebirths': h.rebirths,
        'dmg': h.wbTotal,
        'pts': h.potentialTotal,
        'updated': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8));
      _bossSent[sentKey] = h.wbTotal;
      _bossCache.remove(h.wbDay);
    } catch (e) {
      debugPrint('boss submit failed: $e');
    }
  }

  final Map<String, int> _bossSent = {};

  /// The day's top [limit] damage totals (damage carried in [LbEntry.power]).
  Future<List<LbEntry>> topBoss(String day, {int limit = 30}) async {
    final dbg = debugBoss;
    if (dbg != null) {
      return (List<LbEntry>.of(dbg)..sort((a, b) => b.power.compareTo(a.power))).take(limit).toList();
    }
    final cached = _bossCache['$day/$limit'];
    if (cached != null && DateTime.now().difference(cached.$1) < _bossFresh) return cached.$2;
    final bans = await _bans();
    // Rows past what anyone could deal in a day are left out (1.8.2: an
    // edited client posted 838 billion before the rules capped it).
    final snap = await _boss(day)
        .where('dmg', isLessThanOrEqualTo: worldBossDayCap(maxRebirths))
        .orderBy('dmg', descending: true)
        .limit(limit)
        .get()
        .timeout(const Duration(seconds: 15));
    final rows = [
      for (final d in snap.docs)
        if (_plausibleBoss(d.data()) && !bannedRow(bans, d.id))
          ?LbEntry.fromDoc(d.id, {...d.data(), 'power': d.data()['dmg']}),
    ];
    _bossCache['$day/$limit'] = (DateTime.now(), rows);
    return rows;
  }

  static bool _plausibleBoss(Map<String, dynamic> m) {
    final dmg = m['dmg'], cs = m['rebirths'], lv = m['level'];
    return dmg is num && cs is num && lv is num && dmg <= worldBossDayCap(cs.toInt(), lv.toInt());
  }

  Future<int?> placeBoss(String day, int dmg) async {
    final dbg = debugBoss;
    if (dbg != null) return dbg.where((e) => e.power > dmg).length + 1;
    try {
      final agg = await _boss(day)
          .where('dmg', isGreaterThan: dmg)
          .where('dmg', isLessThanOrEqualTo: worldBossDayCap(maxRebirths))
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return (agg.count ?? 0) + 1;
    } catch (_) {
      return null;
    }
  }

  /// Removes this player's rows (hiding, deleting a slot or the account).
  Future<void> withdraw({int? slot}) async {
    final uid = myUid;
    if (uid == null) return;
    for (var i = 0; i < slotCount; i++) {
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

  /// First pages of [top] read lately, so flipping between boards does not
  /// read the same rows again (1.9.1). Cleared when this player's row is
  /// written.
  final Map<String, (DateTime, LbPage)> _topCache = {};
  static const Duration _topFresh = Duration(minutes: 3);

  /// Lôi đài challengers read lately, reused while lực chiến stays close.
  (DateTime, int, List<ArenaRival>)? _poolCache;
  static const Duration _poolFresh = Duration(minutes: 15);

  /// The Lôi đài board lists this season only.
  int _floor(LbBoard board) => switch (board) {
        LbBoard.arena => arenaSeasonScore(arenaSeasonOf(vnDayKey()), 0),
        LbBoard.hunt => huntScore(huntWeekOf(vnDayKey()), 0),
        LbBoard.daiHoi => 1,
        LbBoard.tamMa => 1,
        LbBoard.maVuc => maVucScore(huntWeekOf(vnDayKey()), 1),
        LbBoard.beast => beastScore(huntWeekOf(vnDayKey()), 1, beastTime),
        _ => 0,
      };

  /// ...and nothing from a later one: a phone whose clock runs ahead files
  /// its score under next week (or season), which would top this one.
  int _ceiling(LbBoard board) => switch (board) {
        LbBoard.arena => arenaSeasonScore(arenaSeasonOf(vnDayKey()) + 1, 0),
        LbBoard.hunt => huntScore(huntWeekOf(vnDayKey()) + 1, 0),
        LbBoard.maVuc => maVucScore(huntWeekOf(vnDayKey()) + 1, 0),
        LbBoard.beast => beastScore(huntWeekOf(vnDayKey()) + 1, 0, 999),
        _ => 0,
      };

  List<LbEntry> _debugSorted(LbBoard board) {
    final floor = _floor(board);
    final ceiling = _ceiling(board);
    return debugEntries!
        .where((e) => board.valueOf(e) >= floor && (ceiling == 0 || board.valueOf(e) < ceiling))
        .toList()
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
    final key = '${board.name}/$limit/$floor';
    final cached = after == null ? _topCache[key] : null;
    if (cached != null && DateTime.now().difference(cached.$1) < _topFresh) return cached.$2;
    final ceiling = _ceiling(board);
    Query<Map<String, dynamic>> q = _col;
    if (floor > 0) q = q.where(board.field, isGreaterThanOrEqualTo: floor);
    if (ceiling > 0) q = q.where(board.field, isLessThan: ceiling);
    q = q.orderBy(board.field, descending: true);
    if (after is DocumentSnapshot) q = q.startAfterDocument(after);
    final bans = await _bans();
    final snap = await q.limit(limit).get().timeout(const Duration(seconds: 15));
    final page = LbPage(
      [for (final d in snap.docs) if (!bannedRow(bans, d.id)) ?LbEntry.fromDoc(d.id, d.data())],
      snap.docs.length == limit ? snap.docs.last : null,
    );
    if (after == null) _topCache[key] = (DateTime.now(), page);
    return page;
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
    final ceiling = _ceiling(board);
    Query<Map<String, dynamic>> uq = _col.where(board.field, isGreaterThan: value);
    if (ceiling > 0) uq = uq.where(board.field, isLessThan: ceiling);
    final bans = await _bans();
    final up = await uq
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
      [for (final d in up.docs.reversed) if (!bannedRow(bans, d.id)) ?LbEntry.fromDoc(d.id, d.data())],
      [for (final d in down.docs) if (!bannedRow(bans, d.id)) ?LbEntry.fromDoc(d.id, d.data())],
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
      final c = _poolCache;
      if (c != null && DateTime.now().difference(c.$1) < _poolFresh && (power - c.$2).abs() <= c.$2 * 0.1) {
        return c.$3;
      }
      final bans = await _bans();
      final snap = await _col
          .where('power', isGreaterThanOrEqualTo: (power * 0.6).round())
          .where('power', isLessThanOrEqualTo: (power * 1.5).round())
          .orderBy('power')
          .limit(40)
          .get()
          .timeout(const Duration(seconds: 10));
      rows = [for (final d in snap.docs) if (!bannedRow(bans, d.id)) ?LbEntry.fromDoc(d.id, d.data())];
    }
    final out = [
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
            // Until they update, a mount that fits their level (looks and
            // speed only: its stat is already in their lực chiến).
            mount: e.mount ?? botMount(e.level, e.rebirths, math.Random(e.id.hashCode)).$1,
            mountLv: e.mount != null ? e.mountLv : 1 + e.level ~/ 6,
            skin: e.skin,
          ),
    ];
    if (dbg == null) _poolCache = (DateTime.now(), power, out);
    return out;
  }

  /// 1-based place a value of [value] would hold on [board].
  Future<int?> placeOf(LbBoard board, int value) async {
    final dbg = debugEntries;
    if (dbg != null) return dbg.where((e) => board.valueOf(e) > value).length + 1;
    try {
      final ceiling = _ceiling(board);
      Query<Map<String, dynamic>> q = _col.where(board.field, isGreaterThan: value);
      if (ceiling > 0) q = q.where(board.field, isLessThan: ceiling);
      final agg = await q
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return (agg.count ?? 0) + 1;
    } catch (_) {
      return null;
    }
  }

  /// 1-based place of [score] (an [arenaSeasonScore]) in its finished
  /// season. Players who have not opened the game since still carry it as
  /// `arenaS`; those who have, as `arenaLast`; each is counted once.
  Future<int?> placeLastSeason(int score) => _placeLast(score, 100000, 'arenaS', 'arenaLast');

  /// 1-based place of [score] (a [huntScore]) in its finished week, the
  /// same way.
  Future<int?> placeLastWeek(int score) => _placeLast(score, 1000000, 'wk', 'wkLast');

  Future<int?> _placeLast(int score, int unit, String current, String last) async {
    if (debugEntries != null) return 2;
    final top = (score ~/ unit + 1) * unit;
    Future<int> above(String field) async {
      final agg = await _col
          .where(field, isGreaterThan: score)
          .where(field, isLessThan: top)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return agg.count ?? 0;
    }

    try {
      final counts = await Future.wait([above(current), above(last)]);
      return counts[0] + counts[1] + 1;
    } catch (_) {
      return null;
    }
  }
}

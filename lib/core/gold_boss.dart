import 'dart:math' as math;

import 'clock.dart';
import 'content.dart';
import 'hanh.dart';
import 'hero.dart';
import 'tam_ma.dart';
import 'world_boss.dart';

/// Boss Hoàng Kim (1.12.0): a great boss that comes down twice a day, at
/// fixed hours, for everyone at once. Like Boss Thế Giới it cannot die and
/// the score is damage; every session a hero deals damage in pays a few
/// Mảnh Hoàng Kim, and the day's damage board pays its top 50 the next
/// day. Which boss comes goes by the weekday.
const int goldBossOpenLevel = 60;
const double goldBossTime = 60;

/// Runs a hero may make in one session.
const int goldBossRuns = 5;

/// Sessions, Vietnam time: (start hour, start minute, minutes open).
const goldBossSessions = <(int, int, int)>[(12, 0, 30), (21, 0, 30)];

/// Mảnh Hoàng Kim for dealing damage in a session.
const int goldBossJoinShards = 3;

/// Whose day it is: Mon/Wed/Fri, Tue/Thu/Sat, Sunday.
const goldBossMobs = <MobDef>[
  MobDef(
      id: 'gbSpear', name: 'Kim Thương Bá Vương', hanh: Hanh.kim,
      body: Body.human, c1: 0xFFE8B83A, c2: 0xFF5A1A14, c3: 0xFFFFF4C8,
      variant: 'gbSpear', size: 1.8, hp: 20, atk: 1.8, def: 1.7,
      speed: 105, exp: 15, boss: true),
  MobDef(
      id: 'gbBandit', name: 'Hắc Phong Lục Lâm Vương', hanh: Hanh.tho,
      body: Body.human, c1: 0xFF3A2A1E, c2: 0xFFB3261E, c3: 0xFFE8C547,
      variant: 'gbBandit', size: 1.85, hp: 20, atk: 1.85, def: 1.7,
      speed: 100, exp: 15, boss: true),
  MobDef(
      id: 'gbLady', name: 'Hàn Mai Tiên Tử', hanh: Hanh.thuy,
      body: Body.human, c1: 0xFFE8F4FF, c2: 0xFF3A6AA8, c3: 0xFF9FE8FF,
      variant: 'gbLady', size: 1.7, hp: 20, atk: 1.8, def: 1.6,
      speed: 115, exp: 15, boss: true),
];

/// The boss on Vietnam date [vn] (by its weekday).
MobDef goldBossOn(DateTime vn) => switch (vn.weekday) {
      DateTime.sunday => goldBossMobs[2],
      DateTime.monday || DateTime.wednesday || DateTime.friday => goldBossMobs[0],
      _ => goldBossMobs[1],
    };

MobDef goldBossOf([DateTime? now]) => goldBossOn(vnNow(now ?? GameClock.now()));

/// The session open at [now] (0 noon, 1 evening), or -1.
int goldBossSessionAt([DateTime? now]) {
  final vn = vnNow(now ?? GameClock.now());
  final m = vn.hour * 60 + vn.minute;
  for (var i = 0; i < goldBossSessions.length; i++) {
    final (h, mi, len) = goldBossSessions[i];
    final start = h * 60 + mi;
    if (m >= start && m < start + len) return i;
  }
  return -1;
}

/// Time until the next session opens (zero while one is open), and which.
(Duration, int) goldBossNext([DateTime? now]) {
  final vn = vnNow(now ?? GameClock.now());
  if (goldBossSessionAt(now) >= 0) return (Duration.zero, goldBossSessionAt(now));
  final day = DateTime.utc(vn.year, vn.month, vn.day);
  for (var add = 0; add < 2; add++) {
    for (var i = 0; i < goldBossSessions.length; i++) {
      final (h, mi, _) = goldBossSessions[i];
      final at = day.add(Duration(days: add, hours: h, minutes: mi));
      if (at.isAfter(vn)) return (at.difference(vn), i);
    }
  }
  return (const Duration(hours: 12), 0);
}

/// Time left in the open session.
Duration goldBossLeft([DateTime? now]) {
  final s = goldBossSessionAt(now);
  if (s < 0) return Duration.zero;
  final vn = vnNow(now ?? GameClock.now());
  final (h, mi, len) = goldBossSessions[s];
  final end = DateTime.utc(vn.year, vn.month, vn.day, h, mi).add(Duration(minutes: len));
  return end.difference(vn);
}

String goldBossSessionLabel(int i) {
  final (h, mi, len) = goldBossSessions[i];
  String two(int v) => v.toString().padLeft(2, '0');
  final end = h * 60 + mi + len;
  return '${two(h)}:${two(mi)}–${two(end ~/ 60)}:${two(end % 60)}';
}

DungeonDef goldBossDef([DateTime? now]) {
  final boss = goldBossOf(now);
  return DungeonDef(
    id: 'goldboss',
    name: 'Boss Hoàng Kim · ${boss.name}',
    mapId: huyetHaiMap.id,
    level: 99,
    waves: const [],
    timeLimit: goldBossTime,
    worldBoss: boss.id,
    golden: true,
  );
}

/// Most damage a day's runs can add up to: Boss Thế Giới's cap, as up to
/// ten runs a day here against its seven (firestore.rules, goldboss).
int goldBossDayCap(int rebirths, [int level = 99]) => worldBossDayCap(rebirths, level) * 2;

/// The day's board rewards by place.
class GoldRankReward {
  const GoldRankReward(this.shards, this.iron, [this.title = '']);
  final int shards, iron;
  final String title;
}

GoldRankReward? goldRankReward(int place) => switch (place) {
      < 1 => null,
      1 => const GoldRankReward(40, 10, 'Hoàng Kim Bá Chủ'),
      <= 3 => const GoldRankReward(30, 6),
      <= 10 => const GoldRankReward(20, 4),
      <= 20 => const GoldRankReward(12, 2),
      <= 50 => const GoldRankReward(6, 1),
      _ => null,
    };

/// The brackets as shown on the screen.
const goldRankBrackets = <(String, int)>[('Hạng 1', 1), ('Hạng 2–3', 3), ('Hạng 4–10', 10), ('Hạng 11–20', 20), ('Hạng 21–50', 50)];

extension GoldBoss on HeroData {
  bool get goldBossOpen => level >= goldBossOpenLevel || rebirths > 0;

  /// A new day: the old one's total waits for its board place.
  void gbRollDay(String day) {
    if (gbDay == day) return;
    if (gbDay.isNotEmpty && gbTotal > 0) {
      gbLastDay = gbDay;
      gbLastTotal = gbTotal;
      gbRankDue = true;
    }
    gbDay = day;
    gbRuns0 = 0;
    gbRuns1 = 0;
    gbTotal = 0;
    gbBest = 0;
    gbPaid = 0;
  }

  int gbRunsIn(int session) => session == 0 ? gbRuns0 : gbRuns1;

  /// Runs left in the open session (0 when none is open).
  int get gbRunsLeft {
    final s = goldBossSessionAt();
    return s < 0 ? 0 : goldBossRuns - gbRunsIn(s);
  }

  /// Uses a run of the open session; false outside one or when spent.
  bool gbStartRun(String day) {
    gbRollDay(day);
    final s = goldBossSessionAt();
    if (s < 0 || !goldBossOpen || gbRunsIn(s) >= goldBossRuns) return false;
    if (s == 0) {
      gbRuns0++;
    } else {
      gbRuns1++;
    }
    gbSession = s;
    return true;
  }

  /// Pays one run: gold as Boss Thế Giới, the session's shards on its
  /// first damage, and the damage to the day's total.
  List<String> goldBossReward(int damage) {
    gbTotal += damage;
    gbBest = math.max(gbBest, damage);
    final g = worldBossGold(damage);
    gold += g;
    lastDungeonGold = g;
    lastDungeonExp = 0;
    final lines = ['Sát thương: ${fmtThousands(damage)}', '+${fmtThousands(g)} lượng'];
    final bit = 1 << gbSession.clamp(0, 1);
    if (damage > 0 && gbPaid & bit == 0) {
      gbPaid |= bit;
      goldShards += goldBossJoinShards;
      lines.add('+$goldBossJoinShards Mảnh Hoàng Kim (tham gia)');
    }
    return lines;
  }

  /// Pays the finished day's board [place] once (0: not on the board).
  List<String> payGoldRank(int place) {
    if (!gbRankDue) return const [];
    gbRankDue = false;
    final r = goldRankReward(place);
    if (r == null) return const [];
    goldShards += r.shards;
    divineIron += r.iron;
    final lines = ['Hạng $place Boss Hoàng Kim hôm qua:', '+${r.shards} Mảnh Hoàng Kim', '+${r.iron} Thần Thiết'];
    if (r.title.isNotEmpty && seasonTitles.add(r.title)) lines.add('Danh hiệu « ${r.title} »');
    return lines;
  }
}

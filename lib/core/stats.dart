/// Thống kê: one line per battle (a trip to a field map, a dungeon, a bí
/// cảnh, a duel), and the hero's personal records.
enum RunResult { left, won, lost }

class RunLog {
  RunLog({
    required this.name,
    required this.kind,
    required this.sec,
    required this.kills,
    required this.dmg,
    required this.bestHit,
    required this.dps,
    required this.gold,
    required this.levels,
    required this.result,
    required this.at,
  });

  final String name;

  /// field, dungeon, realm, tower, arena, boss, nightmare, daihoi.
  final String kind;
  final int sec, kills;
  final double dmg, bestHit, dps;
  final int gold, levels;
  final RunResult result;

  /// When it ended (GameClock ms).
  final int at;

  List<Object> toJson() =>
      [name, kind, sec, kills, dmg.round(), bestHit.round(), dps.round(), gold, levels, result.index, at];

  static RunLog? fromJson(Object? raw) {
    if (raw is! List || raw.length < 11) return null;
    try {
      final r = raw[9] as int;
      return RunLog(
        name: raw[0] as String,
        kind: raw[1] as String,
        sec: raw[2] as int,
        kills: raw[3] as int,
        dmg: (raw[4] as num).toDouble(),
        bestHit: (raw[5] as num).toDouble(),
        dps: (raw[6] as num).toDouble(),
        gold: raw[7] as int,
        levels: raw[8] as int,
        result: RunResult.values[r.clamp(0, RunResult.values.length - 1)],
        at: raw[10] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Battles kept in the log.
const int runLogSize = 15;

/// Shorter outings than this (seconds) are not logged: walking through a
/// map to the next one is not a battle.
const int runLogMinSec = 15;

/// DPS needs this many seconds of fighting before it can set a record, so
/// one lucky crit on a single mob does not.
const double dpsRecordMinCombat = 20;

class HeroRecords {
  double bestDps = 0;
  String bestDpsWhere = '';
  double bestHit = 0;
  int bestRunKills = 0;
  double totalDmg = 0;
  int runs = 0;
  int wins = 0;

  List<Object> toJson() => [bestDps.round(), bestDpsWhere, bestHit.round(), bestRunKills, totalDmg.round(), runs, wins];

  static HeroRecords fromJson(Object? raw) {
    final r = HeroRecords();
    if (raw is! List || raw.length < 7) return r;
    try {
      r.bestDps = (raw[0] as num).toDouble();
      r.bestDpsWhere = raw[1] as String;
      r.bestHit = (raw[2] as num).toDouble();
      r.bestRunKills = raw[3] as int;
      r.totalDmg = (raw[4] as num).toDouble();
      r.runs = raw[5] as int;
      r.wins = raw[6] as int;
    } catch (_) {}
    return r;
  }
}

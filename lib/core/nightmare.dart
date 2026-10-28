import 'dart:math' as math;

import 'activity.dart';
import 'content.dart';
import 'gems.dart' show maxGemTier;
import 'hero.dart' show mobHpAt;

/// Ải Ác Mộng: the eighteen dungeons again for heroes past level 60, as a
/// ladder from monster level 60 to 99 with tougher packs, a boss that calls
/// for help, and a weekly ma khí twist. Opened one by one; the first few
/// clears a day pay Hoàng Kim shards, gems and bí kíp pages.
const int nightmareOpenLevel = 60;
const int nightmarePaidRuns = 5;
const double nightmareTime = 200;

enum NmAffix { frenzy, fortified, volatile, chill }

class NmAffixDef {
  const NmAffixDef(this.name, this.desc);
  final String name, desc;
}

const nmAffixes = {
  NmAffix.frenzy: NmAffixDef('Cuồng bạo', 'Quái +25% công lực và tốc chạy'),
  NmAffix.fortified: NmAffixDef('Kiên cố', 'Quái +60% sinh lực'),
  NmAffix.volatile: NmAffixDef('Bạo liệt', 'Quái chết nổ tung sau 1 giây, tránh xa xác'),
  NmAffix.chill: NmAffixDef('Hàn khí', 'Đòn đánh của quái làm chậm'),
};

int get nightmareCount => dungeons.length;

/// Monster level of nightmare [i] (0-based): 60 for the first, 99 for the last.
int nightmareLevel(int i) => 60 + (i * 39 / (nightmareCount - 1)).round();

/// Each nightmare asks for this much more lực chiến than the one before.
const double nightmareGrowth = 1.27;

/// Lực chiến a nightmare is tuned for: about 20k for the first, over a
/// million for the last, so the ladder keeps up with gems, Hoàng Kim gear
/// and rebirths instead of being one-shot by a strong hero.
int nightmarePower(int i) => (20000 * math.pow(nightmareGrowth, i) / 1000).round() * 1000;

/// HP and attack multiplier on top of the level: the monster grows with
/// [nightmarePower], less what its level already adds.
double nightmareMul(int i) =>
    1.4 * math.pow(nightmareGrowth, i) * mobHpAt(nightmareLevel(0)) / mobHpAt(nightmareLevel(i));

/// Ma khí of nightmare [i] in the week starting [weekKey] (a Monday,
/// `20261026` style), so each one changes every Monday.
NmAffix nightmareAffix(int i, String weekKey) {
  final d = DateTime.utc(int.parse(weekKey.substring(0, 4)), int.parse(weekKey.substring(4, 6)),
      int.parse(weekKey.substring(6, 8)));
  final week = d.millisecondsSinceEpoch ~/ (7 * Duration.millisecondsPerDay);
  return NmAffix.values[(i + week) % NmAffix.values.length];
}

String nightmareWeek(String dayKey) => weekKeyOf(dayKey);

DungeonDef nightmareDef(int i, NmAffix affix) {
  final d = dungeons[i];
  return DungeonDef(
    id: 'nm${i + 1}',
    name: '${d.name} · Ác Mộng',
    mapId: d.mapId,
    level: nightmareLevel(i),
    waves: [for (final n in d.waves) n + 2],
    timeLimit: nightmareTime,
    mul: nightmareMul(i),
    nightmare: i + 1,
    affix: affix.index,
  );
}

/// Boss HP fractions at which it calls [nightmareAdds] monsters to its side.
const nightmareSummonAt = [0.7, 0.35];
const int nightmareAdds = 4;

// Rewards climb with the tier so the hard end of the ladder is worth it:
// nightmare 18 pays about 20x the gold of nightmare 1, three times the
// shards, top-tier gems and near-certain pages.

/// Gold for a paid clear of nightmare [i].
int nightmareGold(int i, int stars) =>
    ((400 + nightmareLevel(i) * 40) * math.pow(1.2, i) * (0.7 + stars * 0.1)).round();

/// Share of a level's EXP a paid clear gives.
double nightmareExpShare(int i) => 0.04 + 0.004 * i;

/// Mảnh Hoàng Kim for a paid clear.
int nightmareShards(int i, int stars) => 1 + (stars >= 3 ? 1 : 0) + i ~/ 4;

/// Gem tier a paid clear may drop.
int nightmareGemTier(int i) => math.min(maxGemTier, 3 + i ~/ 4);

double nightmareGemChance(int i) => 0.3 + 0.03 * i;
double nightmarePageChance(int i) => 0.35 + 0.03 * i;

/// From nightmare 13 on, a chance at a second bí kíp page.
double nightmareExtraPageChance(int i) => i < 12 ? 0 : 0.1 * (i - 11);

/// First clear of nightmare [i] adds these shards.
int nightmareFirstShards(int i) => 5 + i ~/ 3;

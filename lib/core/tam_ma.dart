import 'dart:math' as math;

import 'arena.dart';
import 'content.dart';
import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'pass_extras.dart';
import 'premium.dart';
import 'world_boss.dart';

/// Tâm Ma Ảo Cảnh (1.8.0): a duel with the hero's own shadow, its sect,
/// skills and mount. Each floor's shadow has a fixed lực chiến that grows
/// by [tamMaGrowth], so better gear climbs higher, and from floor 3 a tâm
/// ma twist ([TmAffix]). A lost duel costs one of the day's tries; a won
/// one climbs on for free. The first clear of a floor pays Tinh Thạch.
const int tamMaOpenPower = 300000;
const double tamMaTime = 120;
const int tamMaFreeTries = 3;
const int tamMaAdTries = 2;

/// Lực chiến of the floor-1 shadow, and the rise per floor.
const int tamMaBase = 400000;
const double tamMaGrowth = 1.05;

int tamMaPower(int floor) => (tamMaBase * math.pow(tamMaGrowth, floor - 1) / 1000).round() * 1000;

/// The strongest shadow, against the hero's own lực chiến, that a board row
/// may claim to have beaten (1.13.3). Real top climbers stand near 1.7x
/// (2.8M on floor 52, 4M on 59); a 600k row on floor 104 (61M, 100x) was
/// an edited save. The same check is in firestore.rules.
const double tamMaMaxRatio = 8;

bool tamMaPlausible(int floor, int power) => floor <= 1 || tamMaBase * math.pow(tamMaGrowth, floor - 1) <= power * tamMaMaxRatio;

enum TmAffix { regen, thorns, guard, rage, iron }

class TmAffixDef {
  const TmAffixDef(this.name, this.desc);
  final String name, desc;
}

const tmAffixes = {
  TmAffix.regen: TmAffixDef('Bất diệt', 'Tâm Ma hồi 1,5% sinh lực mỗi giây'),
  TmAffix.thorns: TmAffixDef('Phản chấn', 'Phản lại 10% sát thương nhận được'),
  TmAffix.guard: TmAffixDef('Hộ thể', 'Cứ 10 giây chặn 60% sát thương trong 3 giây'),
  TmAffix.rage: TmAffixDef('Cuồng nộ', 'Dưới 40% sinh lực: +50% công lực, chạy nhanh hơn'),
  TmAffix.iron: TmAffixDef('Kim thân', 'Chịu ít hơn 25% sát thương'),
};

/// The twists on [floor]: none on the first two, one after, and two on
/// every tenth floor.
List<TmAffix> tamMaAffixes(int floor) {
  if (floor < 3) return const [];
  const n = 5;
  final a = TmAffix.values[(floor * 3) % n];
  if (floor % 10 != 0) return [a];
  return [a, TmAffix.values[(floor * 3 + 2) % n]];
}

/// The hero's shadow on [floor].
ArenaRival tamMaRival(HeroData h, int floor) {
  final m = h.ridingMount;
  return ArenaRival(
    name: 'Tâm Ma',
    hanh: h.hanh,
    level: h.level,
    rebirths: h.rebirths,
    power: tamMaPower(floor),
    female: h.female,
    title: h.title,
    mount: m?.id ?? '',
    mountLv: m == null ? 1 : h.mountLevels[m.id] ?? 1,
    skin: m == null ? '' : h.mountSkin[m.id] ?? '',
  );
}

DungeonDef tamMaDef(HeroData h, int floor) => DungeonDef(
      id: 'tamma',
      name: 'Tâm Ma Ảo Cảnh · Tầng $floor',
      mapId: huyetHaiMap.id,
      level: h.level,
      waves: const [],
      timeLimit: tamMaTime,
      rival: tamMaRival(h, floor),
      tamMa: floor,
      tmAffixes: [for (final a in tamMaAffixes(floor)) a.index],
    );

/// Tinh Thạch for the first clear of [floor].
int tamMaStones(int floor) => 3 + floor ~/ 4;
int tamMaGold(int floor) => 20000 * floor;

/// Every fifth floor adds a gem of this tier; every tenth, a Tinh Phách.
int tamMaGemTier(int floor) => math.min(maxRewardGemTier, 4 + floor ~/ 10);

extension TamMa on HeroData {
  bool get tamMaOpen => power >= tamMaOpenPower || tmBest > 0;

  void tmRollDay(String day) {
    if (tmDay == day) return;
    tmDay = day;
    tmTries = 0;
    tmAds = 0;
  }

  int get tmFreeTries => tamMaFreeTries + (cardActive(vnDayKey()) ? monthCardExtraRuns : 0);

  /// Duels that may still be lost today.
  int get tmTriesLeft => math.max(0, tmFreeTries + tmAds - tmTries);

  bool tmAddAdTry(String day) {
    tmRollDay(day);
    if (tmAds >= tamMaAdTries) return false;
    tmAds++;
    return true;
  }

  /// The end of the duel on [floor]: a loss costs a try, a first clear pays.
  List<String> tamMaResult(bool won, int floor, math.Random rng) {
    tmRollDay(vnDayKey());
    if (!won) {
      tmTries++;
      return ['Mất 1 lượt khiêu chiến (còn $tmTriesLeft hôm nay)'];
    }
    if (floor <= tmBest) return const ['Tầng đã vượt trước đây'];
    tmBest = floor;
    passCount(vnDayKey(), 'tamMa');
    final stones = tamMaStones(floor);
    final g = tamMaGold(floor);
    starStones += stones;
    gold += g;
    final lines = ['+$stones Tinh Thạch', '+${fmtThousands(g)} lượng'];
    if (floor % 5 == 0) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], tamMaGemTier(floor));
      addGem(gem);
      lines.add(gem.name);
    }
    if (floor % 10 == 0) {
      beastSouls++;
      lines.add('+1 Hung Thú Tinh Phách');
    }
    return lines;
  }
}

/// 1234567 → "1.234.567".
String fmtThousands(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

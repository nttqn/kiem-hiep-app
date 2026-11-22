import 'dart:math' as math;

import 'hanh.dart';
import 'items.dart';
import 'sects.dart';
import 'i18n.dart';

/// Ngũ hành gems: socketed into gear, one stat each. Monsters drop tiers up
/// to [maxDropTier]; Tiên and Thánh come only from fusing and the tower.
const int maxGemTier = 8;
const int maxDropTier = 5;

/// The best tier any reward pays (towers, bosses, mail…); Thiên (8, 1.9.0)
/// comes only from fusing three Thánh with a Hung Thú Tinh Phách.
const int maxRewardGemTier = 7;
const gemTierNames = ['Thô', 'Hoàn', 'Tinh', 'Bảo', 'Thần', 'Tiên', 'Thánh', 'Thiên'];

/// Tinh Phách a fuse into tier [tier] + 1 takes besides the three gems.
int fuseSouls(int tier) => tier + 1 >= 8 ? 1 : 0;

/// How strong a gem of [tier] is, in tier units: Thiên counts as 9.5.
double gemPower(int tier) => tier >= 8 ? 9.5 : tier.toDouble();

class Gem {
  const Gem(this.hanh, this.tier);
  final Hanh hanh;

  /// 1..[maxGemTier].
  final int tier;

  String get key => '${hanh.index}:$tier';
  String get name => tr('{hanhLabel} Ngọc {p0}', {'hanhLabel': tr(hanh.label), 'p0': tr(gemTierNames[tier - 1])});

  static Gem? parse(Object? key) {
    if (key is! String) return null;
    final p = key.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), t = int.tryParse(p[1]);
    if (h == null || t == null || h < 0 || h > 4 || t < 1 || t > maxGemTier) return null;
    return Gem(Hanh.values[h], t);
  }

  @override
  bool operator ==(Object other) => other is Gem && other.hanh == hanh && other.tier == tier;

  @override
  int get hashCode => key.hashCode;
}

/// Gems of the hero's own phase (bản mệnh) are half again as strong.
const double banMenhBonus = 1.5;

/// What one gem adds, before the bản mệnh multiplier.
Map<Bonus, double> gemEffect(Gem g) {
  final t = gemPower(g.tier);
  return switch (g.hanh) {
    Hanh.kim => {Bonus.atkPct: 0.025 * t},
    Hanh.moc => {Bonus.crit: 0.008 * t},
    Hanh.thuy => {Bonus.mpPct: 0.04 * t, Bonus.skillDmg: 0.01 * t},
    Hanh.hoa => {Bonus.critDmg: 0.05 * t},
    Hanh.tho => {Bonus.hpPct: 0.03 * t},
  };
}

/// Short description of a gem's effect for the UI.
String gemEffectText(Gem g, {bool banMenh = false}) {
  final m = banMenh ? banMenhBonus : 1.0;
  String pct(double v) => '+${(v * m * 100).toStringAsFixed(v * m * 100 < 10 ? 1 : 0)}%';
  final e = gemEffect(g);
  return switch (g.hanh) {
    Hanh.kim => tr('Công lực {p0}', {'p0': pct(e[Bonus.atkPct]!)}),
    Hanh.moc => tr('Chí mạng {p0}', {'p0': pct(e[Bonus.crit]!)}),
    Hanh.thuy => tr('Nội lực {p0}, uy lực kỹ năng {p1}', {'p0': pct(e[Bonus.mpPct]!), 'p1': pct(e[Bonus.skillDmg]!)}),
    Hanh.hoa => tr('ST chí mạng {p0}', {'p0': pct(e[Bonus.critDmg]!)}),
    Hanh.tho => tr('Sinh lực {p0}', {'p0': pct(e[Bonus.hpPct]!)}),
  };
}

/// Sockets an item has, by rarity.
int socketsFor(Rarity r) => const [0, 1, 2, 2, 3][r.index];

/// Set bonus for the number of different phases socketed across worn gear.
Map<Bonus, double> setBonus(int distinct) {
  if (distinct >= 5) return {Bonus.atkPct: 0.08, Bonus.hpPct: 0.08};
  if (distinct >= 3) return {Bonus.atkPct: 0.03, Bonus.hpPct: 0.03};
  return const {};
}

String setBonusText(int distinct) {
  if (distinct >= 5) return tr('Ngũ Hành Viên Mãn: công lực +8%, sinh lực +8%');
  if (distinct >= 3) return tr('Tam Hành Hội Tụ: công lực +3%, sinh lực +3%');
  return tr('Khảm đủ 3 hệ khác nhau để kích hoạt Tam Hành Hội Tụ');
}

/// Gold to fuse three tier-[tier] gems into one of the next tier.
int fuseCost(int tier) => 300 * tier * tier;

/// Tier of a gem dropped by a monster of [level]; bosses one higher.
int dropTier(int level, {bool boss = false}) =>
    math.min(maxDropTier, 1 + level ~/ 20 + (boss ? 1 : 0));

/// Chance a normal monster drops a gem.
const double gemDropChance = 0.025;

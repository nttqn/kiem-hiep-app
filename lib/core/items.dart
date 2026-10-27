import 'dart:math' as math;

import 'gems.dart';
import 'sects.dart';

enum Slot { weapon, hat, armor, belt, boots, amulet, ring }

extension SlotInfo on Slot {
  String get label => const [
        'Vũ khí',
        'Nón',
        'Áo',
        'Đai lưng',
        'Hài',
        'Ngọc bội',
        'Nhẫn',
      ][index];
}

enum Rarity { common, fine, rare, epic, legend }

extension RarityInfo on Rarity {
  String get label =>
      const ['Thường', 'Tinh xảo', 'Quý', 'Hiếm', 'Truyền thuyết'][index];

  int get color => const [
        0xFFE8E2D4,
        0xFF5AA9F0,
        0xFFF0C24B,
        0xFFB57BF0,
        0xFFFF8A3D,
      ][index];

  double get baseMul => const [1.0, 1.15, 1.3, 1.5, 1.8][index];
  int get affixes => index;
}

/// Everything an item can carry.
enum Stat { str, dex, vit, ene, hp, mp, atk, def, crit, critDmg, dodge, aspd, move }

extension StatInfo on Stat {
  String get label => const [
        'Sức mạnh',
        'Thân pháp',
        'Sinh khí',
        'Nội công',
        'Sinh lực',
        'Nội lực',
        'Công lực',
        'Phòng thủ',
        'Chí mạng',
        'ST chí mạng',
        'Né tránh',
        'Tốc đánh',
        'Tốc chạy',
      ][index];

  bool get isPercent =>
      this == Stat.crit ||
      this == Stat.critDmg ||
      this == Stat.dodge ||
      this == Stat.aspd;

  String format(double v) => isPercent
      ? '+${(v * 100).toStringAsFixed(1)}%'
      : '+${v.round()}';
}

class Item {
  Item({
    required this.slot,
    required this.level,
    required this.rarity,
    required this.base,
    required this.bonus,
    required this.name,
    this.plus = 0,
    this.set = '',
    List<Gem?>? gems,
  }) : gems = List<Gem?>.generate(
            socketsFor(rarity), (i) => gems != null && i < gems.length ? gems[i] : null);

  final Slot slot;
  final int level;
  final Rarity rarity;
  final Map<Stat, double> base;
  final Map<Stat, double> bonus;
  final String name;

  /// Cường hóa level, 0..[maxPlus].
  int plus;

  /// Socketed ngũ hành gems; length is the item's socket count.
  final List<Gem?> gems;

  /// Hoàng Kim set id, '' for an ordinary item.
  final String set;

  bool get golden => set.isNotEmpty;
  int get color => golden ? goldItemColor : rarity.color;
  String get rarityLabel => golden ? 'Hoàng Kim' : rarity.label;

  String get title => plus > 0 ? '$name +$plus' : name;

  /// Every stat this item gives right now, base scaled by enhancement.
  Map<Stat, double> get totals {
    final out = <Stat, double>{};
    final mul = 1 + 0.1 * plus;
    base.forEach((k, v) => out[k] = (out[k] ?? 0) + v * mul);
    bonus.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    return out;
  }

  int get sellPrice =>
      ((3 + level * 1.2) * (1 + rarity.index * 1.2) * (1 + plus * 0.3) * (golden ? 3 : 1)).round();

  /// A rough single number for "is this better", used by auto-equip.
  double get score {
    var s = 0.0;
    totals.forEach((k, v) => s += v * statWeight(k));
    return s;
  }

  Map<String, dynamic> toJson() => {
        's': slot.index,
        'l': level,
        'r': rarity.index,
        'p': plus,
        'n': name,
        if (golden) 'k': set,
        if (gems.any((g) => g != null)) 'g': [for (final g in gems) g?.key],
        'b': {for (final e in base.entries) '${e.key.index}': e.value},
        'x': {for (final e in bonus.entries) '${e.key.index}': e.value},
      };

  static Item fromJson(Map<String, dynamic> m) {
    Map<Stat, double> stats(Object? o) {
      final out = <Stat, double>{};
      if (o is Map) {
        o.forEach((k, v) {
          final i = int.tryParse('$k') ?? -1;
          if (i >= 0 && i < Stat.values.length && v is num) {
            out[Stat.values[i]] = v.toDouble();
          }
        });
      }
      return out;
    }

    return Item(
      slot: Slot.values[(m['s'] as int).clamp(0, Slot.values.length - 1)],
      level: m['l'] as int,
      rarity:
          Rarity.values[(m['r'] as int).clamp(0, Rarity.values.length - 1)],
      plus: (m['p'] as int? ?? 0).clamp(0, maxPlus),
      gems: [for (final g in (m['g'] as List? ?? const [])) Gem.parse(g)],
      name: m['n'] as String,
      set: m['k'] as String? ?? '',
      base: stats(m['b']),
      bonus: stats(m['x']),
    );
  }
}

const int maxPlus = 10;

/// Hoàng Kim items' colour, above Truyền thuyết.
const int goldItemColor = 0xFFFFD34A;

/// How much one unit of each stat is worth, roughly in attack points.
double statWeight(Stat s) => switch (s) {
      Stat.str || Stat.dex || Stat.vit || Stat.ene => 1.6,
      Stat.hp => 0.12,
      Stat.mp => 0.1,
      Stat.atk => 1.0,
      Stat.def => 0.8,
      Stat.crit => 120,
      Stat.critDmg => 60,
      Stat.dodge => 120,
      Stat.aspd => 120,
      Stat.move => 0.6,
    };

/// Base stats of a [slot] item at item level [l], before rarity.
Map<Stat, double> slotBase(Slot slot, int l) => switch (slot) {
      Slot.weapon => {Stat.atk: 6 + 3.2 * l},
      Slot.hat => {Stat.def: 2 + 0.9 * l, Stat.hp: 10 + 5.0 * l},
      Slot.armor => {Stat.def: 4 + 1.6 * l, Stat.hp: 20 + 8.0 * l},
      Slot.belt => {Stat.hp: 18 + 10.0 * l},
      Slot.boots => {Stat.def: 2 + 0.7 * l, Stat.move: 6 + 0.25 * l},
      Slot.amulet => {Stat.mp: 10 + 4.0 * l, Stat.atk: 3 + 1.2 * l},
      Slot.ring => {Stat.atk: 3 + 1.4 * l, Stat.crit: 0.01 + 0.0004 * l},
    };

/// An average extra line of [s] at item level [l].
double _affixBase(Stat s, int l) => switch (s) {
      Stat.str || Stat.dex || Stat.vit || Stat.ene => 2 + 0.35 * l,
      Stat.hp => 12 + 6.0 * l,
      Stat.mp => 6 + 3.0 * l,
      Stat.atk => 2 + 1.1 * l,
      Stat.def => 2 + 0.9 * l,
      Stat.crit => 0.015 + 0.0005 * l,
      Stat.critDmg => 0.05 + 0.002 * l,
      Stat.dodge => 0.01 + 0.0004 * l,
      Stat.aspd => 0.02 + 0.0006 * l,
      Stat.move => 5 + 0.15 * l,
    };

double _roundStat(Stat s, double v) => s.isPercent ? (v * 1000).round() / 1000 : v.roundToDouble();

double _affixValue(Stat s, int l, math.Random r) =>
    _roundStat(s, _affixBase(s, l) * (0.6 + r.nextDouble() * 0.6));

/// Extra lines rolled at level [from], kept as good relative to level [to].
Map<Stat, double> rescaleAffixes(Map<Stat, double> lines, int from, int to) =>
    lines.map((k, v) => MapEntry(k, _roundStat(k, v * _affixBase(k, to) / _affixBase(k, from))));

/// Material names by level band, used as the first word of an item name.
const _tiers = [
  'Thiết',
  'Thanh Đồng',
  'Tinh Cương',
  'Hàn Ngọc',
  'Huyền Thiết',
  'Long Văn',
  'Thiên Tinh',
  'Hỗn Nguyên',
  'Thái Cực',
  'Tiên Thiên',
];

String tierName(int level) =>
    _tiers[(level ~/ 10).clamp(0, _tiers.length - 1)];

String slotNoun(Slot slot, SectDef sect) => switch (slot) {
      Slot.weapon => sect.weaponName,
      Slot.hat => 'Mão',
      Slot.armor => 'Chiến Bào',
      Slot.belt => 'Yêu Đái',
      Slot.boots => 'Hài',
      Slot.amulet => 'Ngọc Bội',
      Slot.ring => 'Giới Chỉ',
    };

const _legendNames = [
  'Bá Vương',
  'Kinh Hồng',
  'Thiên Cơ',
  'Phong Vân',
  'Lăng Tiêu',
  'Vô Song',
];

Item makeItem({
  required Slot slot,
  required int level,
  required Rarity rarity,
  required SectDef sect,
  required math.Random rng,
}) {
  final base = slotBase(slot, level)
      .map((k, v) => MapEntry(k, k.isPercent
          ? (v * rarity.baseMul * 1000).round() / 1000
          : (v * rarity.baseMul).roundToDouble()));
  final pool = List<Stat>.of(Stat.values)..shuffle(rng);
  final bonus = <Stat, double>{};
  for (final s in pool.take(rarity.affixes)) {
    bonus[s] = _affixValue(s, level, rng);
  }
  var name = '${tierName(level)} ${slotNoun(slot, sect)}';
  if (rarity == Rarity.legend) {
    name = '${_legendNames[rng.nextInt(_legendNames.length)]} '
        '${slotNoun(slot, sect)}';
  }
  return Item(
    slot: slot,
    level: level,
    rarity: rarity,
    base: base,
    bonus: bonus,
    name: name,
  );
}

/// Tẩy luyện: gold to reroll [it]'s extra lines keeping [locks] of them.
int refineCost(Item it, int locks) =>
    ((300 + it.level * 60) * (1 + it.rarity.index * 0.5) * (1 + locks * 1.5)).round();

/// Rerolls every extra line of [it] not in [locked]: new stats (never a
/// duplicate of a kept one) with fresh values for the item's level.
void rerollAffixes(Item it, Set<Stat> locked, math.Random rng) {
  final n = it.bonus.length;
  it.bonus.removeWhere((k, _) => !locked.contains(k));
  final pool = Stat.values.where((s) => !it.bonus.containsKey(s)).toList()..shuffle(rng);
  for (final s in pool.take(n - it.bonus.length)) {
    it.bonus[s] = _affixValue(s, it.level, rng);
  }
}

/// Rarity of a random drop. Bosses never drop below [Rarity.rare].
Rarity rollRarity(math.Random r, {bool boss = false}) {
  final x = r.nextDouble();
  if (boss) {
    if (x < 0.12) return Rarity.legend;
    if (x < 0.5) return Rarity.epic;
    return Rarity.rare;
  }
  if (x < 0.005) return Rarity.legend;
  if (x < 0.03) return Rarity.epic;
  if (x < 0.13) return Rarity.rare;
  if (x < 0.42) return Rarity.fine;
  return Rarity.common;
}

/// Gold and success chance of enhancing an item from [plus] to plus+1.
int enhanceCost(Item it) =>
    ((20 + it.level * 8) * (1 + it.plus * 0.6) * (1 + it.rarity.index * 0.3))
        .round();

double enhanceChance(int plus) =>
    const [1.0, 1.0, 0.95, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3][plus];

/// Heal potions restore a share of max HP/MP, so one kind works at every
/// level; the price follows the hero's level.
const double potionHeal = 0.35;
const double potionCooldown = 2.5;
int potionPrice(int heroLevel) => 8 + heroLevel * 2;

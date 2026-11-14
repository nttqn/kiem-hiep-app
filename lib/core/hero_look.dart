import 'hero.dart';
import 'items.dart';

/// What a board row carries of [h]'s looks and worn gear (1.12.1), for
/// others to see in "Xem thông tin" and on their copies in duels: per item
/// slot, name, level, rarity, cường hóa, stars, Khai Quang, Hoàng Kim set,
/// gems socketed and Tiên khí phẩm.
Map<String, Object> lookRow(HeroData h) => {
      'f': h.female,
      if (h.hideHat) 'hh': true,
      if (h.costume.isNotEmpty) 'c': h.costume,
      if (h.divine > 0) 'dv': h.divine,
      'eq': [
        for (final e in h.equip.entries)
          {
            's': e.key.index,
            'n': e.value.name.length > 40 ? e.value.name.substring(0, 40) : e.value.name,
            'l': e.value.level,
            'r': e.value.rarity.index,
            if (e.value.plus > 0) 'p': e.value.plus,
            if (e.value.star > 0) 't': e.value.star,
            if (e.value.glow > 0) 'g': e.value.glow,
            if (e.value.set.isNotEmpty) 'set': e.value.set,
            if (e.value.gems.any((g) => g != null)) 'gm': e.value.gems.where((g) => g != null).length,
            if (e.value.tien > 0) 'tq': e.value.tien,
          },
      ],
      if (h.activePet.isNotEmpty) 'pet': h.activePet,
      if (h.activePet.isNotEmpty) 'pl': h.petLevels[h.activePet] ?? 1,
    };

/// [h]'s main stats on a board row: HP, nội lực, attack, defence, then
/// crit, crit damage, dodge and attack speed in thousandths.
List<int> statRow(HeroData h) {
  final s = h.stats;
  return [
    s.maxHp.round(),
    s.maxMp.round(),
    s.atk.round(),
    s.def.round(),
    (s.crit * 1000).round(),
    (s.critDmg * 1000).round(),
    (s.dodge * 1000).round(),
    (s.aspd * 1000).round(),
  ];
}

/// The worn items of a [lookRow] rebuilt (looks only: no stats on them),
/// by slot.
List<Item> lookItems(Map<String, dynamic>? look) {
  final eq = look?['eq'];
  if (eq is! List) return const [];
  final out = <Item>[];
  for (final raw in eq) {
    if (raw is! Map) continue;
    try {
      int n(String k, [int d = 0]) => (raw[k] as num?)?.toInt() ?? d;
      out.add(Item(
        slot: Slot.values[n('s').clamp(0, Slot.values.length - 1)],
        level: n('l', 1).clamp(1, 99),
        rarity: Rarity.values[n('r').clamp(0, Rarity.values.length - 1)],
        base: const {},
        bonus: const {},
        name: raw['n'] as String? ?? '',
        plus: n('p').clamp(0, maxPlus),
        star: n('t').clamp(0, maxStar),
        glow: n('g').clamp(0, maxGlow),
        set: raw['set'] as String? ?? '',
        tien: n('tq').clamp(0, maxTien),
      ));
    } catch (_) {}
  }
  out.sort((a, b) => a.slot.index.compareTo(b.slot.index));
  return out;
}

/// Gems socketed in the [slot] piece of a [lookRow].
int lookGems(Map<String, dynamic>? look, Slot slot) {
  final eq = look?['eq'];
  if (eq is! List) return 0;
  for (final raw in eq) {
    if (raw is Map && (raw['s'] as num?)?.toInt() == slot.index) return (raw['gm'] as num?)?.toInt() ?? 0;
  }
  return 0;
}

/// A hero's mark on the boards (1.13.6): [HeroData.seed], set when the
/// hero was made and kept by every copy of the save, mixed so the seed
/// itself (it drives the hero's own rolls) is not shown. 0 for no seed.
int heroTag(int seed) => seed == 0 ? 0 : (((seed ^ 0x2545F491) & 0x7fffffff) * 31 + 7) & 0x7fffffff;

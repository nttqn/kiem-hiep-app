import 'dart:math' as math;

import 'hanh.dart';
import 'items.dart';
import 'sects.dart';

/// Trang bị Hoàng Kim: five sets, one per phase, forged at the smithy from
/// Mảnh Hoàng Kim. Worn pieces of one set add its bonuses at 2, 4 and 7
/// pieces; the full set also lets basic hits now and then unleash the set's
/// phase burst around the target.
class GoldSetDef {
  const GoldSetDef({
    required this.id,
    required this.name,
    required this.hanh,
    required this.word,
    required this.two,
    required this.four,
    required this.seven,
    required this.burst,
    required this.burstFx,
  });

  final String id, name;
  final Hanh hanh;

  /// First word of each piece's name.
  final String word;
  final Map<Bonus, double> two, four, seven;

  /// The full set's burst and the ground effect it draws.
  final String burst, burstFx;

  /// The bonus that [mark] (2, 4 or 7) pieces add.
  Map<Bonus, double> bonusAt(int mark) => switch (mark) {
        2 => two,
        4 => four,
        _ => seven,
      };
}

const int goldOpenLevel = 60;

/// Pieces worn for each tier of a set's bonus.
const goldSetMarks = [2, 4, 7];

/// Base stats against a Truyền thuyết piece's 1.8.
const double goldBaseMul = 2.1;

// The full set's burst: chance per basic hit, cooldown, damage (times
// attack, as a skill) and radius.
const double goldBurstChance = 0.15;
const double goldBurstCd = 1.2;
const double goldBurstPower = 1.6;
const double goldBurstRadius = 130;

/// Mảnh Hoàng Kim to forge a piece, and to forge it again at the hero's
/// level (keeping plus, gems and extra lines).
int goldPieceCost(Slot s) => s == Slot.weapon ? 40 : 25;
int goldReforgeCost(Slot s) => goldPieceCost(s) * 2 ~/ 5;

// Where Mảnh Hoàng Kim come from (besides Lôi đài seasons and the weekly
// Năng động chests): Boss Thế Giới damage milestones, first clears of tower
// floors from 40 up, and now and then a boss or elite of level 60+.
const worldBossGoldShards = [0, 1, 2, 3, 5];
int towerGoldShards(int floor) => floor < 40 ? 0 : (floor % 10 == 0 ? 6 : 2);
const double bossShardChance = 0.1;
const int bossShardLevel = 60;

const goldSets = <GoldSetDef>[
  GoldSetDef(
    id: 'kim', name: 'Kim Cang Hộ Pháp', hanh: Hanh.kim, word: 'Hộ Pháp',
    two: {Bonus.defPct: 0.10}, four: {Bonus.hpPct: 0.12}, seven: {Bonus.atkPct: 0.10},
    burst: 'Như Lai Ấn', burstFx: 'buddhaPalm',
  ),
  GoldSetDef(
    id: 'moc', name: 'Vạn Độc Thiên Thù', hanh: Hanh.moc, word: 'Thiên Thù',
    two: {Bonus.dotPct: 0.25}, four: {Bonus.crit: 0.05}, seven: {Bonus.atkPct: 0.10},
    burst: 'Độc Vụ Thiên La', burstFx: 'poisonCloud',
  ),
  GoldSetDef(
    id: 'thuy', name: 'Bích Hải Triều Âm', hanh: Hanh.thuy, word: 'Triều Âm',
    two: {Bonus.cdr: 0.06}, four: {Bonus.skillDmg: 0.12}, seven: {Bonus.atkPct: 0.10},
    burst: 'Hàn Băng Kết Giới', burstFx: 'iceField',
  ),
  GoldSetDef(
    id: 'hoa', name: 'Liệt Diệm Phần Thiên', hanh: Hanh.hoa, word: 'Phần Thiên',
    two: {Bonus.critDmg: 0.25}, four: {Bonus.atkPct: 0.10}, seven: {Bonus.skillDmg: 0.10},
    burst: 'Thiên Hỏa Lưu Tinh', burstFx: 'meteor',
  ),
  GoldSetDef(
    id: 'tho', name: 'Hậu Thổ Trấn Nhạc', hanh: Hanh.tho, word: 'Trấn Nhạc',
    two: {Bonus.hpPct: 0.10}, four: {Bonus.defPct: 0.12}, seven: {Bonus.atkPct: 0.10},
    burst: 'Địa Chấn Sơn Hà', burstFx: 'spikes',
  ),
];

final Map<String, GoldSetDef> goldSetById = {for (final s in goldSets) s.id: s};

/// A Hoàng Kim piece of [set] for [slot] at item level [level]: Truyền
/// thuyết extra lines and sockets over stronger base stats.
Item makeGoldItem({
  required GoldSetDef set,
  required Slot slot,
  required int level,
  required SectDef sect,
  required math.Random rng,
}) {
  final legend = makeItem(slot: slot, level: level, rarity: Rarity.legend, sect: sect, rng: rng);
  return Item(
    slot: slot,
    level: level,
    rarity: Rarity.legend,
    base: goldBase(slot, level),
    bonus: legend.bonus,
    name: '${set.word} ${slotNoun(slot, sect)}',
    set: set.id,
  );
}

Map<Stat, double> goldBase(Slot slot, int level) => slotBase(slot, level).map((k, v) =>
    MapEntry(k, k.isPercent ? (v * goldBaseMul * 1000).round() / 1000 : (v * goldBaseMul).roundToDouble()));

/// [it] forged again at [level]: same set, name, extra lines (rescaled),
/// plus and gems.
Item reforgedGold(Item it, int level) => Item(
      slot: it.slot,
      level: level,
      rarity: it.rarity,
      base: goldBase(it.slot, level),
      bonus: rescaleAffixes(it.bonus, it.level, level),
      name: it.name,
      plus: it.plus,
      set: it.set,
      gems: it.gems,
    );

/// Worn pieces per set id.
Map<String, int> goldPieces(Iterable<Item> worn) {
  final out = <String, int>{};
  for (final it in worn) {
    if (goldSetById.containsKey(it.set)) out[it.set] = (out[it.set] ?? 0) + 1;
  }
  return out;
}

/// Every set bonus earned by [pieces].
Map<Bonus, double> goldSetBonuses(Map<String, int> pieces) {
  final out = <Bonus, double>{};
  pieces.forEach((id, n) {
    final s = goldSetById[id]!;
    for (final mark in goldSetMarks) {
      if (n >= mark) s.bonusAt(mark).forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    }
  });
  return out;
}

/// The set worn in full, if any.
GoldSetDef? fullGoldSet(Map<String, int> pieces) {
  for (final e in pieces.entries) {
    if (e.value >= goldSetMarks.last) return goldSetById[e.key];
  }
  return null;
}

String bonusLabel(Bonus b) => switch (b) {
      Bonus.hpPct => 'Sinh lực',
      Bonus.mpPct => 'Nội lực',
      Bonus.atkPct => 'Công lực',
      Bonus.defPct => 'Phòng thủ',
      Bonus.crit => 'Chí mạng',
      Bonus.critDmg => 'ST chí mạng',
      Bonus.dodge => 'Né tránh',
      Bonus.aspd => 'Tốc đánh',
      Bonus.move => 'Tốc chạy',
      Bonus.regen => 'Hồi sinh lực',
      Bonus.skillDmg => 'Uy lực kỹ năng',
      Bonus.cdr => 'Giảm hồi chiêu',
      Bonus.dotPct => 'Uy lực độc/thiêu',
    };

/// "Phòng thủ +10%" lines for one bonus map.
String bonusText(Map<Bonus, double> m) =>
    [for (final e in m.entries) '${bonusLabel(e.key)} +${(e.value * 100).round()}%'].join(', ');

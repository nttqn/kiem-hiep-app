import 'dart:math' as math;

import 'content.dart';
import 'hanh.dart';
import 'sects.dart';

/// Companion spirit beasts (linh thú): one follows the hero at a time,
/// spits a bolt of its phase at nearby monsters and raises one stat.
class PetDef {
  const PetDef({
    required this.id,
    required this.name,
    required this.hanh,
    required this.desc,
    required this.bonus,
    required this.base,
    required this.perLv,
    required this.look,
    this.price = 0,
    this.boss = '',
  });

  final String id;
  final String name;
  final Hanh hanh;
  final String desc;
  final Bonus bonus;
  final double base, perLv;

  /// Drawing style: crane, tiger, turtle, fox, kylin, dragon.
  final String look;

  /// Gold price in the shop, or 0 when it only drops from [boss].
  final int price;
  final String boss;

  double bonusAt(int lv) => base + perLv * (lv - 1);

  String get bonusName => switch (bonus) {
        Bonus.move => 'Tốc chạy',
        Bonus.crit => 'Chí mạng',
        Bonus.defPct => 'Phòng thủ',
        Bonus.skillDmg => 'Uy lực kỹ năng',
        Bonus.atkPct => 'Công lực',
        Bonus.aspd => 'Tốc đánh',
        _ => bonus.name,
      };

  String bonusText(int lv) => '$bonusName +${(bonusAt(lv) * 100).toStringAsFixed(1)}%';
}

const int maxPetLevel = 20;

const pets = <PetDef>[
  PetDef(
      id: 'crane', name: 'Bạch Hạc', hanh: Hanh.kim, look: 'crane',
      desc: 'Hạc trắng tiên cảnh, cõng chủ nhân lướt nhanh như gió.',
      bonus: Bonus.move, base: 0.06, perLv: 0.004, price: 6000),
  PetDef(
      id: 'tiger', name: 'Hắc Hổ', hanh: Hanh.moc, look: 'tiger',
      desc: 'Mãnh hổ rừng sâu, vồ mồi không bao giờ trượt.',
      bonus: Bonus.crit, base: 0.03, perLv: 0.0025, boss: 'banditBoss'),
  PetDef(
      id: 'turtle', name: 'Huyền Quy', hanh: Hanh.tho, look: 'turtle',
      desc: 'Rùa thần ngàn năm, mai cứng hơn sắt thép.',
      bonus: Bonus.defPct, base: 0.06, perLv: 0.006, boss: 'scorpionKing'),
  PetDef(
      id: 'fox', name: 'Tuyết Hồ', hanh: Hanh.thuy, look: 'fox',
      desc: 'Hồ ly tuyết linh, khuếch đại nội công của chủ.',
      bonus: Bonus.skillDmg, base: 0.05, perLv: 0.005, boss: 'yetiKing'),
  PetDef(
      id: 'kylin', name: 'Kỳ Lân Con', hanh: Hanh.hoa, look: 'kylin',
      desc: 'Hậu duệ Hỏa Kỳ Lân, hơi thở nóng như dung nham.',
      bonus: Bonus.atkPct, base: 0.05, perLv: 0.005, boss: 'kylin'),
  PetDef(
      id: 'dragon', name: 'Tiểu Bạch Long', hanh: Hanh.kim, look: 'dragon',
      desc: 'Rồng con của Bạch Long Vương, ra đòn nhanh như chớp.',
      bonus: Bonus.aspd, base: 0.04, perLv: 0.003, boss: 'whiteDragon'),
];

final Map<String, PetDef> petById = {for (final p in pets) p.id: p};

/// Gold to raise a pet from [lv] to lv+1.
int petLevelCost(int lv) => (400 * math.pow(lv, 1.6)).round();

/// Bolt damage as a multiple of the hero's attack.
double petPower(int lv) => 0.3 + 0.03 * (lv - 1);
const double petAttackInterval = 1.5;
const double petRange = 280;

/// Pet that drops from boss [mobId], if any.
PetDef? petFromBoss(String mobId) {
  for (final p in pets) {
    if (p.boss == mobId) return p;
  }
  return null;
}

/// A boss drops its pet 20% of the time, and surely by the fifth kill.
const double petDropChance = 0.2;
const int petPity = 5;

String petSource(PetDef p) =>
    p.price > 0 ? 'Mua tại tiệm: ${p.price} lượng' : 'Rơi từ ${mobById[p.boss]!.name}';

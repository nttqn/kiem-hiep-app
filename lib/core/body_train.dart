import 'hero.dart';
import 'premium.dart';
import 'sects.dart';

/// Luyện thể (1.7.0): tempering the body for heroes who have done the
/// rest. Five parts, each trained level by level with Thần Thiết and gold;
/// levels 11 and 21 are thresholds that also take Linh Phách Đơn and a
/// higher rebirth. The sum of all levels climbs the cảnh giới, which add a
/// bonus of their own.
class BodyPart {
  const BodyPart(this.name, this.bonus, this.per, this.label, this.desc);
  final String name;
  final Bonus bonus;

  /// Bonus per level.
  final double per;
  final String label;
  final String desc;

  double valueAt(int lv) => per * lv;
}

const bodyParts = <BodyPart>[
  BodyPart('Luyện Bì', Bonus.defPct, 0.008, 'Phòng thủ', 'Da dày như giáp, đao kiếm khó vào.'),
  BodyPart('Luyện Nhục', Bonus.hpPct, 0.012, 'Sinh lực', 'Cơ thịt rắn chắc, chịu đòn bền bỉ.'),
  BodyPart('Luyện Cân', Bonus.aspd, 0.003, 'Tốc đánh', 'Gân cốt dẻo dai, ra chiêu nhanh hơn.'),
  BodyPart('Luyện Cốt', Bonus.critDmg, 0.015, 'Sát thương chí mạng', 'Xương cứng như thép, đòn hiểm nặng tay.'),
  BodyPart('Luyện Tủy', Bonus.atkPct, 0.01, 'Công lực', 'Tủy sinh nội lực, công lực dồi dào.'),
];

const int bodyMax = 30;

/// Rebirths that open Luyện thể, and the two thresholds above it.
const int bodyOpenRebirths = 3;
const bodyTiers = <(int from, int rebirths, int pills)>[
  (10, 5, 10),
  (20, 6, 20),
];

int bodyIronCost(int lv) => 2 + lv ~/ 3;
int bodyGoldCost(int lv) => 15000 * (lv + 1);

/// Linh Phách Đơn for going from [lv] to lv + 1 (only at a threshold).
int bodyPillCost(int lv) {
  for (final t in bodyTiers) {
    if (lv == t.$1) return t.$3;
  }
  return 0;
}

/// Rebirths needed to go from [lv] to lv + 1.
int bodyRebirthsFor(int lv) {
  var need = bodyOpenRebirths;
  for (final t in bodyTiers) {
    if (lv >= t.$1) need = t.$2;
  }
  return need;
}

/// Cảnh giới by the sum of all part levels.
class BodyRealm {
  const BodyRealm(this.name, this.at, this.bonus, this.color);
  final String name;
  final int at;
  final Map<Bonus, double> bonus;
  final int color;
}

const bodyRealms = <BodyRealm>[
  BodyRealm('Đồng Bì', 30, {Bonus.hpPct: 0.05}, 0xFFD89A5A),
  BodyRealm('Thiết Cốt', 60, {Bonus.defPct: 0.06}, 0xFFB8C8D8),
  BodyRealm('Kim Cương Thân', 100, {Bonus.atkPct: 0.08, Bonus.critDmg: 0.1}, 0xFFFFD34A),
  BodyRealm('Bất Hoại Kim Thân', 150, {Bonus.hpPct: 0.1, Bonus.atkPct: 0.1}, 0xFFFFF4C8),
];

BodyRealm? bodyRealmOf(int total) {
  BodyRealm? out;
  for (final r in bodyRealms) {
    if (total >= r.at) out = r;
  }
  return out;
}

Map<Bonus, double> bodyBonuses(List<int> lv) {
  final out = <Bonus, double>{};
  var total = 0;
  for (var i = 0; i < bodyParts.length && i < lv.length; i++) {
    total += lv[i];
    if (lv[i] > 0) {
      final p = bodyParts[i];
      out[p.bonus] = (out[p.bonus] ?? 0) + p.valueAt(lv[i]);
    }
  }
  for (final r in bodyRealms) {
    if (total < r.at) break;
    r.bonus.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
  }
  return out;
}

enum BodyBlock { closed, maxed, rebirth, iron, gold, pills }

extension BodyTrain on HeroData {
  bool get bodyOpen => rebirths >= bodyOpenRebirths;

  int get bodyTotal => bodyLv.fold(0, (a, b) => a + b);

  /// Why part [i] can't go up a level now, or null when it can.
  BodyBlock? bodyBlock(int i) {
    if (!bodyOpen) return BodyBlock.closed;
    final lv = bodyLv[i];
    if (lv >= bodyMax) return BodyBlock.maxed;
    if (rebirths < bodyRebirthsFor(lv)) return BodyBlock.rebirth;
    final (iron, cost) = bodyCost(i);
    if (divineIron < iron) return BodyBlock.iron;
    if (gold < cost) return BodyBlock.gold;
    if (soulPills < bodyPillCost(lv)) return BodyBlock.pills;
    return null;
  }

  bool trainBody(int i) {
    if (bodyBlock(i) != null) return false;
    final lv = bodyLv[i];
    final (iron, cost) = bodyCost(i);
    divineIron -= iron;
    gold -= cost;
    bodyBoost = false;
    soulPills -= bodyPillCost(lv);
    bodyLv[i]++;
    recompute();
    return true;
  }
}

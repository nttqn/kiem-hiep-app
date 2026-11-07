import 'dart:math' as math;

import 'hanh.dart';
import 'sects.dart';

/// Lưu phái (1.11.0): after the first rebirth each sect splits into two
/// schools. A school reshapes two or three of the sect's skills and carries
/// its own nội công, a bonus that grows with Tu vi (levels 1..[maxBranchLevel]
/// bought with gold and Thần Thiết). Changing school keeps the Tu vi.
const int branchOpenRebirths = 1;
const int maxBranchLevel = 10;

/// One skill's change under a school.
class BranchMod {
  const BranchMod(this.skill, {this.power = 1, this.cooldown = 1, this.radius = 1, this.count = 0,
      this.duration = 1, this.statusPower = 1, this.statusTime = 1, this.note = ''});

  final String skill;
  final double power, cooldown, radius, duration, statusPower, statusTime;
  final int count;

  /// Short text for the card, e.g. '+25% uy lực'.
  final String note;

  SkillDef apply(SkillDef s) => s.copyWith(
        power: s.power * power,
        powerPerLv: s.powerPerLv * power,
        cooldown: s.cooldown * cooldown,
        radius: s.radius * radius,
        range: s.kind == SkillKind.dash ? s.range : s.range * radius,
        count: s.count + count,
        spread: count > 0 && s.kind == SkillKind.projectile && s.count == 1 ? 0.3 : s.spread,
        duration: s.duration * duration,
        statusPower: s.statusPower * statusPower,
        statusTime: s.statusTime * statusTime,
      );
}

class BranchDef {
  const BranchDef(this.id, this.name, this.role, this.desc, this.mods, this.bonus);

  final String id, name;

  /// 'Công', 'Thủ'… one word on the card.
  final String role;
  final String desc;
  final List<BranchMod> mods;

  /// Nội công at Tu vi 1.
  final Map<Bonus, double> bonus;
}

/// Tu vi [lv] multiplies the nội công: x1 at 1, x2.35 at 10.
double branchMul(int lv) => 1 + 0.15 * (math.max(1, lv) - 1);

/// Gold and Thần Thiết for Tu vi [lv] → lv+1.
int branchGoldCost(int lv) => (300000 * math.pow(lv, 1.5)).round();
int branchIronCost(int lv) => 3 * lv;

/// Gold to change school (the first pick is free).
int branchSwitchCost(int rebirths) => 500000 * math.max(1, rebirths);

const branchesBySect = <Hanh, List<BranchDef>>{
  Hanh.kim: [
    BranchDef('kimA', 'Hàng Ma Đường', 'Công',
        'Côn pháp và La Hán Trận dồn lực trấn ma, đánh lan rộng hơn.', [
      BranchMod('kim1', power: 1.25, radius: 1.15, note: '+25% uy lực, +15% vùng đánh'),
      BranchMod('kim3', power: 1.2, note: '+20% uy lực'),
      BranchMod('kim5', cooldown: 0.85, note: '−15% hồi chiêu'),
    ], {Bonus.atkPct: 0.04, Bonus.crit: 0.02}),
    BranchDef('kimB', 'Hộ Pháp Đường', 'Thủ',
        'Kim Chung Tráo bền lâu, thân như đồng tượng giữ cửa chùa.', [
      BranchMod('kim2', power: 1.15, duration: 1.3, note: '+15% giảm sát thương, +30% thời gian'),
      BranchMod('kim5', power: 1.1, note: '+10% uy lực'),
    ], {Bonus.hpPct: 0.06, Bonus.defPct: 0.05}),
  ],
  Hanh.moc: [
    BranchDef('mocA', 'Ám Khí Đường', 'Bạo',
        'Phi đao và Bạo Vũ Lê Hoa bắn nhiều hơn, chí mạng hiểm hơn.', [
      BranchMod('moc1', power: 1.15, count: 1, note: '+1 phi đao, +15% uy lực'),
      BranchMod('moc5', count: 2, note: '+2 kim châm'),
    ], {Bonus.crit: 0.03, Bonus.critDmg: 0.12}),
    BranchDef('mocB', 'Độc Công Đường', 'Độc',
        'Độc chưởng và độc vụ ngấm sâu, kẻ địch chết dần trong khói.', [
      BranchMod('moc2', statusPower: 1.35, statusTime: 1.2, note: '+35% độc, +20% thời gian'),
      BranchMod('moc3', power: 1.3, radius: 1.15, note: '+30% uy lực, +15% vùng'),
    ], {Bonus.dotPct: 0.15, Bonus.hpPct: 0.03}),
  ],
  Hanh.thuy: [
    BranchDef('thuyA', 'Băng Phách Phái', 'Công',
        'Băng Tâm Kiếm sắc lạnh hơn, Hàn Băng Trận phủ rộng làm chậm cả đàn.', [
      BranchMod('thuy1', power: 1.2, statusPower: 1.2, note: '+20% uy lực, làm chậm mạnh hơn'),
      BranchMod('thuy3', power: 1.1, radius: 1.2, note: '+20% vùng, +10% uy lực'),
    ], {Bonus.skillDmg: 0.06, Bonus.atkPct: 0.02}),
    BranchDef('thuyB', 'Thanh Tâm Phái', 'Hồi',
        'Thanh Tâm Chú hồi nhiều và nhanh, nội lực dồi dào, đánh lâu không ngã.', [
      BranchMod('thuy2', power: 1.3, cooldown: 0.85, note: '+30% hồi máu, −15% hồi chiêu'),
      BranchMod('thuy5', duration: 1.25, note: '+25% thời gian'),
    ], {Bonus.hpPct: 0.05, Bonus.defPct: 0.03, Bonus.mpPct: 0.1}),
  ],
  Hanh.hoa: [
    BranchDef('hoaA', 'Bạo Viêm Đường', 'Bạo',
        'Liệt Diễm Đao và Phần Thiên Liệt Địa dồn hết sức vào một đòn.', [
      BranchMod('hoa1', power: 1.2, note: '+20% uy lực'),
      BranchMod('hoa5', power: 1.25, note: '+25% uy lực'),
    ], {Bonus.critDmg: 0.15, Bonus.atkPct: 0.03}),
    BranchDef('hoaB', 'Hộ Hỏa Đường', 'Bền',
        'Lửa bám dai và lan rộng, Hỏa Long Xung hồi nhanh để thoát vây.', [
      BranchMod('hoa2', cooldown: 0.8, note: '−20% hồi chiêu'),
      BranchMod('hoa3', radius: 1.2, note: '+20% vùng'),
      BranchMod('hoa5', statusPower: 1.3, statusTime: 1.2, note: '+30% thiêu đốt, +20% thời gian'),
    ], {Bonus.hpPct: 0.06, Bonus.dotPct: 0.1}),
  ],
  Hanh.tho: [
    BranchDef('thoA', 'Kiếm Tông', 'Công',
        'Kiếm khí bắn nhiều luồng, Lưỡng Nghi Kiếm Trận chém nhanh hơn.', [
      BranchMod('tho1', power: 1.15, count: 1, note: '+1 kiếm khí, +15% uy lực'),
      BranchMod('tho5', power: 1.2, note: '+20% uy lực'),
    ], {Bonus.aspd: 0.05, Bonus.atkPct: 0.03}),
    BranchDef('thoB', 'Khí Tông', 'Thủ',
        'Thổ Linh Hộ Thể dày hơn, Địa Chấn Quyết thêm một nhịp, chiêu hồi nhanh.', [
      BranchMod('tho2', power: 1.3, duration: 1.2, note: '+30% khiên, +20% thời gian'),
      BranchMod('tho3', count: 1, radius: 1.1, note: '+1 nhịp chấn, +10% vùng'),
    ], {Bonus.hpPct: 0.04, Bonus.defPct: 0.04, Bonus.cdr: 0.04}),
  ],
};

List<BranchDef> branchesOf(Hanh h) => branchesBySect[h]!;

/// Nội công of [b] at Tu vi [lv].
Map<Bonus, double> branchBonus(BranchDef b, int lv) =>
    {for (final e in b.bonus.entries) e.key: e.value * branchMul(lv)};

/// [s] as school [b] fights it (unchanged if [b] does not touch it).
SkillDef applyBranch(SkillDef s, BranchDef? b) {
  if (b == null) return s;
  var out = s;
  for (final m in b.mods) {
    if (m.skill == s.id) out = m.apply(out);
  }
  return out;
}

/// The bonus label as the card shows it.
String branchBonusLabel(Bonus b, double v) {
  final pct = '+${(v * 100).toStringAsFixed(1)}%';
  return switch (b) {
    Bonus.hpPct => 'Sinh lực $pct',
    Bonus.mpPct => 'Nội lực $pct',
    Bonus.atkPct => 'Công lực $pct',
    Bonus.defPct => 'Phòng thủ $pct',
    Bonus.crit => 'Chí mạng $pct',
    Bonus.critDmg => 'ST chí mạng $pct',
    Bonus.skillDmg => 'ST kỹ năng $pct',
    Bonus.aspd => 'Tốc đánh $pct',
    Bonus.dotPct => 'ST độc/đốt $pct',
    Bonus.cdr => 'Giảm hồi chiêu $pct',
    _ => '${b.name} $pct',
  };
}

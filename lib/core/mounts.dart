import 'dart:math' as math;

import 'sects.dart';

/// Thú cưỡi: the hero rides one on every map. Each mount adds running speed
/// and one stat; feeding (gold) raises its level and both bonuses.
enum MountSource { gold, tower, arena, rebirth, abyss }

class MountDef {
  const MountDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.look,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.move,
    required this.bonus,
    required this.base,
    required this.perLv,
    required this.source,
    required this.need,
  });

  final String id, name, desc;

  /// Drawing: horse, deer, tiger, kylin.
  final String look;

  /// Body, mane (or stripes) and saddle colours.
  final int c1, c2, c3;

  /// Running speed bonus at level 1 (grows 1% a level).
  final double move;
  final Bonus bonus;
  final double base, perLv;
  final MountSource source;

  /// Gold price, tower floor, Uy danh price or rebirth count, by [source].
  final int need;

  double moveAt(int lv) => move + 0.01 * (lv - 1);
  double bonusAt(int lv) => base + perLv * (lv - 1);

  String get bonusName => switch (bonus) {
        Bonus.hpPct => 'Sinh lực',
        Bonus.defPct => 'Phòng thủ',
        Bonus.atkPct => 'Công lực',
        Bonus.crit => 'Chí mạng',
        Bonus.skillDmg => 'Uy lực kỹ năng',
        _ => bonus.name,
      };

  String bonusText(int lv) => 'Tốc chạy +${(moveAt(lv) * 100).round()}% · '
      '$bonusName +${(bonusAt(lv) * 100).toStringAsFixed(1)}%';

  String get howTo => switch (source) {
        MountSource.gold => 'Mua: ${_thousands(need)} lượng',
        MountSource.tower => 'Vượt Tháp Thử Luyện tầng $need',
        MountSource.arena => 'Đổi ${_thousands(need)} Uy danh ở Lôi đài',
        MountSource.rebirth => 'Chuyển sinh lần $need',
        MountSource.abyss => 'Hạ Cửu U Ma Tôn $need lần (Cửu U Ma Vực)',
      };
}

String _thousands(int n) {
  final s = '$n';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

const int maxMountLevel = 10;

/// Hero level that lets them ride.
const int mountOpenLevel = 10;

const mounts = <MountDef>[
  MountDef(
      id: 'nau', name: 'Ngựa Nâu', look: 'horse', desc: 'Ngựa thồ chân chắc, bạn đồng hành của khách giang hồ.',
      c1: 0xFF8A5A34, c2: 0xFF3A2416, c3: 0xFFB3261E,
      move: 0.15, bonus: Bonus.hpPct, base: 0.03, perLv: 0.003, source: MountSource.gold, need: 5000),
  MountDef(
      id: 'bachma', name: 'Bạch Mã', look: 'horse', desc: 'Tuấn mã lông trắng như tuyết, phi nước đại không mỏi.',
      c1: 0xFFF2F0EA, c2: 0xFFC8C4BC, c3: 0xFF2A5A9A,
      move: 0.2, bonus: Bonus.defPct, base: 0.05, perLv: 0.004, source: MountSource.gold, need: 60000),
  MountDef(
      id: 'hanhuyet', name: 'Hãn Huyết Bảo Mã', look: 'horse', desc: 'Mồ hôi đỏ như máu, ngày đi nghìn dặm.',
      c1: 0xFFB8402A, c2: 0xFF5A1A10, c3: 0xFFE8C547,
      move: 0.25, bonus: Bonus.atkPct, base: 0.05, perLv: 0.004, source: MountSource.tower, need: 40),
  MountDef(
      id: 'bachho', name: 'Bạch Hổ', look: 'tiger', desc: 'Hổ trắng lôi đài, chỉ theo kẻ mạnh nhất.',
      c1: 0xFFF0EEE8, c2: 0xFF2A2A2E, c3: 0xFF3A6AA8,
      move: 0.25, bonus: Bonus.crit, base: 0.03, perLv: 0.002, source: MountSource.arena, need: 4000),
  MountDef(
      id: 'thanloc', name: 'Thần Lộc', look: 'deer', desc: 'Hươu thần chốn tiên sơn, sừng tỏa linh quang.',
      c1: 0xFFC89A5A, c2: 0xFFF4E8D0, c3: 0xFF3AA87A,
      move: 0.28, bonus: Bonus.skillDmg, base: 0.05, perLv: 0.004, source: MountSource.rebirth, need: 2),
  MountDef(
      id: 'kylan', name: 'Hỏa Kỳ Lân', look: 'kylin', desc: 'Thần thú lửa, chỉ phục tùng bậc tứ chuyển.',
      c1: 0xFFD8402E, c2: 0xFFFFC34A, c3: 0xFF3AD0C0,
      move: 0.3, bonus: Bonus.atkPct, base: 0.08, perLv: 0.005, source: MountSource.rebirth, need: 4),
  MountDef(
      id: 'huyenminh', name: 'Huyền Minh Kỳ Lân', look: 'kylin',
      desc: 'Kỳ lân đen của vực Cửu U, chỉ cúi đầu trước kẻ hạ được Ma Tôn.',
      c1: 0xFF2A1A3A, c2: 0xFFB04AFF, c3: 0xFFFF3A5A,
      move: 0.32, bonus: Bonus.atkPct, base: 0.1, perLv: 0.006, source: MountSource.abyss, need: 30),
];

final Map<String, MountDef> mountById = {for (final m in mounts) m.id: m};

/// Gold to feed a mount from [lv] to lv+1.
int mountLevelCost(int lv) => (1500 * math.pow(lv, 1.7)).round();

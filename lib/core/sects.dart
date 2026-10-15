import 'hanh.dart';

/// How an active skill is delivered.
enum SkillKind {
  /// Cone in front of the hero.
  arc,

  /// Circle around the hero.
  nova,

  /// [count] missiles fanned over [spread] radians toward the target.
  projectile,

  /// [count] missiles in every direction.
  radial,

  /// Circle at the target that lands after [delay]; with [ticks] > 1 it is
  /// a lingering cloud hitting every [duration]/[ticks] seconds.
  ground,

  /// A row of [count] bursts walking forward from the hero.
  line,

  /// The hero lunges [range] forward, hitting everything on the way.
  dash,

  /// Damage ticks around the hero for [duration] seconds.
  aura,

  /// Takes [power] (fraction) off incoming damage for [duration].
  guard,

  /// Restores [power] of max HP at once and the same again over [duration].
  heal,

  /// Absorbs damage worth [power] of max HP for [duration].
  shield,

  passive,
}

enum Status { none, slow, stun, poison, burn }

/// Keys for everything a passive, an item or a buff can raise.
enum Bonus {
  hpPct,
  mpPct,
  atkPct,
  defPct,
  crit,
  critDmg,
  dodge,
  aspd,
  move,
  regen,
  skillDmg,
  cdr,
  dotPct,
}

class SkillDef {
  const SkillDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.kind,
    required this.unlock,
    this.cooldown = 0,
    this.mp = 0,
    this.power = 0,
    this.powerPerLv = 0,
    this.range = 0,
    this.radius = 0,
    this.count = 1,
    this.spread = 0,
    this.pierce = false,
    this.status = Status.none,
    this.statusPower = 0,
    this.statusTime = 0,
    this.duration = 0,
    this.delay = 0,
    this.ticks = 1,
    this.knock = 0,
    this.passive = const {},
    this.fx = '',
  });

  final String id;
  final String name;
  final String desc;
  final SkillKind kind;

  /// Hero level needed before a point can go in.
  final int unlock;
  final double cooldown;
  final double mp;

  /// Damage as a multiple of attack (or fraction for guard/heal/shield).
  final double power;
  final double powerPerLv;
  final double range;
  final double radius;
  final int count;
  final double spread;
  final bool pierce;
  final Status status;

  /// Slow fraction, or DoT per second as a multiple of attack.
  final double statusPower;
  final double statusTime;
  final double duration;
  final double delay;
  final int ticks;
  final double knock;

  /// Per skill level.
  final Map<Bonus, double> passive;

  /// Which effect the renderer draws.
  final String fx;

  bool get isPassive => kind == SkillKind.passive;

  double powerAt(int lv) => power + powerPerLv * (lv - 1);

  /// MP cost grows slowly with the skill's level.
  double mpAt(int lv) => mp * (1 + 0.08 * (lv - 1));
}

const int maxSkillLevel = 10;

enum BasicKind { melee, ranged }

class SectDef {
  const SectDef({
    required this.hanh,
    required this.name,
    required this.tagline,
    required this.desc,
    required this.role,
    required this.difficulty,
    required this.base,
    required this.atkWeights,
    required this.hpMul,
    required this.basic,
    required this.basicRange,
    required this.basicFx,
    required this.weaponName,
    required this.skills,
    required this.autoBuild,
  });

  final Hanh hanh;
  final String name;
  final String tagline;
  final String desc;
  final String role;

  /// 1 easy … 3 hard.
  final int difficulty;

  /// Starting str, dex, vit, ene.
  final List<int> base;

  /// Attack gained per point of str, dex, vit, ene.
  final List<double> atkWeights;
  final double hpMul;
  final BasicKind basic;
  final double basicRange;
  final String basicFx;

  /// "Côn", "Đao"… used to name dropped weapons.
  final String weaponName;
  final List<SkillDef> skills;

  /// Share of free points the "tự cộng" button gives str, dex, vit, ene.
  final List<int> autoBuild;
}

const sects = <SectDef>[
  SectDef(
    hanh: Hanh.kim,
    name: 'Kim Cang Tự',
    tagline: 'Côn pháp cương mãnh, thân như đồng thép',
    desc: 'Tăng nhân luyện côn và ngạnh công. Máu trâu, phòng thủ cao, '
        'càn quét quái vây quanh. Dễ chơi nhất cho người mới.',
    role: 'Cận chiến · Đỡ đòn',
    difficulty: 1,
    base: [12, 5, 11, 4],
    atkWeights: [2.0, 0.4, 0, 0.3],
    hpMul: 1.2,
    basic: BasicKind.melee,
    basicRange: 78,
    basicFx: 'staff',
    weaponName: 'Côn',
    autoBuild: [2, 1, 2, 0],
    skills: [
      SkillDef(
        id: 'kim1',
        name: 'Phục Hổ Côn',
        desc: 'Quét côn hình quạt trước mặt.',
        kind: SkillKind.arc,
        unlock: 1,
        cooldown: 2.2,
        mp: 6,
        power: 1.7,
        powerPerLv: 0.14,
        range: 120,
        spread: 2.2,
        knock: 70,
        fx: 'arcGold',
      ),
      SkillDef(
        id: 'kim2',
        name: 'Kim Chung Tráo',
        desc: 'Chuông vàng hộ thể, giảm sát thương phải chịu.',
        kind: SkillKind.guard,
        unlock: 5,
        cooldown: 22,
        mp: 15,
        power: 0.3,
        powerPerLv: 0.03,
        duration: 10,
        fx: 'bell',
      ),
      SkillDef(
        id: 'kim3',
        name: 'La Hán Trận',
        desc: 'Dậm đất chấn động, đánh bật quái xung quanh.',
        kind: SkillKind.nova,
        unlock: 10,
        cooldown: 6,
        mp: 14,
        power: 2.2,
        powerPerLv: 0.18,
        radius: 155,
        knock: 120,
        fx: 'quake',
      ),
      SkillDef(
        id: 'kim4',
        name: 'Kim Cương Bất Hoại',
        desc: 'Nội tại: tăng sinh lực và phòng thủ.',
        kind: SkillKind.passive,
        unlock: 15,
        passive: {Bonus.hpPct: 0.04, Bonus.defPct: 0.03},
      ),
      SkillDef(
        id: 'kim5',
        name: 'Phật Quang Phổ Chiếu',
        desc: 'Phật quang bùng nổ diện rộng, làm choáng kẻ địch.',
        kind: SkillKind.nova,
        unlock: 25,
        cooldown: 12,
        mp: 30,
        power: 3.4,
        powerPerLv: 0.28,
        radius: 230,
        status: Status.stun,
        statusTime: 1.2,
        fx: 'buddha',
      ),
      SkillDef(
        id: 'kim6',
        name: 'Dịch Cân Kinh',
        desc: 'Nội tại: tăng công lực và hồi phục.',
        kind: SkillKind.passive,
        unlock: 35,
        passive: {Bonus.atkPct: 0.03, Bonus.regen: 0.002},
      ),
    ],
  ),
  SectDef(
    hanh: Hanh.moc,
    name: 'Bách Độc Môn',
    tagline: 'Ám khí như mưa, độc dược vô hình',
    desc: 'Cao thủ phi tiêu và độc công. Đánh từ xa, độc ngấm dần làm '
        'quái mất máu. Thân pháp nhanh, chí mạng cao.',
    role: 'Tầm xa · Sát thương theo thời gian',
    difficulty: 2,
    base: [6, 12, 7, 5],
    atkWeights: [0.9, 1.4, 0, 0.3],
    hpMul: 0.95,
    basic: BasicKind.ranged,
    basicRange: 300,
    basicFx: 'dart',
    weaponName: 'Phi Tiêu',
    autoBuild: [1, 2, 1, 0],
    skills: [
      SkillDef(
        id: 'moc1',
        name: 'Phi Đao Thuật',
        desc: 'Phóng ba lưỡi phi đao hình quạt.',
        kind: SkillKind.projectile,
        unlock: 1,
        cooldown: 2.4,
        mp: 6,
        power: 1.25,
        powerPerLv: 0.1,
        range: 340,
        count: 3,
        spread: 0.5,
        fx: 'knife',
      ),
      SkillDef(
        id: 'moc2',
        name: 'Vạn Độc Chưởng',
        desc: 'Chưởng độc xuyên thấu, trúng độc mất máu liên tục.',
        kind: SkillKind.projectile,
        unlock: 5,
        cooldown: 5,
        mp: 12,
        power: 1.2,
        powerPerLv: 0.1,
        range: 360,
        pierce: true,
        radius: 22,
        status: Status.poison,
        statusPower: 0.45,
        statusTime: 4,
        fx: 'poisonPalm',
      ),
      SkillDef(
        id: 'moc3',
        name: 'Độc Vụ Trận',
        desc: 'Thả màn sương độc, quái đứng trong đó mất máu.',
        kind: SkillKind.ground,
        unlock: 10,
        cooldown: 9,
        mp: 18,
        power: 0.75,
        powerPerLv: 0.07,
        range: 330,
        radius: 140,
        duration: 5,
        ticks: 10,
        status: Status.slow,
        statusPower: 0.3,
        statusTime: 0.8,
        fx: 'poisonCloud',
      ),
      SkillDef(
        id: 'moc4',
        name: 'Thân Pháp Như Phong',
        desc: 'Nội tại: tăng né tránh và tốc chạy.',
        kind: SkillKind.passive,
        unlock: 15,
        passive: {Bonus.dodge: 0.012, Bonus.move: 0.02},
      ),
      SkillDef(
        id: 'moc5',
        name: 'Bạo Vũ Lê Hoa',
        desc: 'Tung ám khí ra mọi hướng như mưa hoa lê.',
        kind: SkillKind.radial,
        unlock: 25,
        cooldown: 10,
        mp: 28,
        power: 1.7,
        powerPerLv: 0.14,
        range: 330,
        count: 16,
        pierce: true,
        fx: 'needle',
      ),
      SkillDef(
        id: 'moc6',
        name: 'Độc Tâm Quyết',
        desc: 'Nội tại: tăng chí mạng và uy lực độc.',
        kind: SkillKind.passive,
        unlock: 35,
        passive: {Bonus.crit: 0.01, Bonus.dotPct: 0.06},
      ),
    ],
  ),
  SectDef(
    hanh: Hanh.thuy,
    name: 'Bích Thủy Am',
    tagline: 'Băng tâm như ngọc, kiếm khí lạnh thấu xương',
    desc: 'Nữ hiệp tu băng pháp. Đóng băng và làm chậm quái, có kỹ năng '
        'tự trị thương. Mạnh về pháp thuật diện rộng.',
    role: 'Pháp thuật · Khống chế · Hồi phục',
    difficulty: 2,
    base: [4, 7, 8, 11],
    atkWeights: [0.3, 0.3, 0, 2.0],
    hpMul: 0.92,
    basic: BasicKind.ranged,
    basicRange: 280,
    basicFx: 'waterOrb',
    weaponName: 'Kiếm',
    autoBuild: [0, 1, 1, 2],
    skills: [
      SkillDef(
        id: 'thuy1',
        name: 'Băng Tâm Kiếm',
        desc: 'Kiếm khí băng xuyên thấu, làm chậm kẻ trúng.',
        kind: SkillKind.projectile,
        unlock: 1,
        cooldown: 2.4,
        mp: 7,
        power: 1.7,
        powerPerLv: 0.14,
        range: 360,
        pierce: true,
        radius: 20,
        status: Status.slow,
        statusPower: 0.4,
        statusTime: 2,
        fx: 'iceBlade',
      ),
      SkillDef(
        id: 'thuy2',
        name: 'Thanh Tâm Chú',
        desc: 'Niệm chú trị thương, hồi sinh lực tức thì và dần dần.',
        kind: SkillKind.heal,
        unlock: 5,
        cooldown: 16,
        mp: 18,
        power: 0.18,
        powerPerLv: 0.015,
        duration: 5,
        fx: 'healWater',
      ),
      SkillDef(
        id: 'thuy3',
        name: 'Hàn Băng Trận',
        desc: 'Băng trận giáng xuống, đóng băng quái trong vùng.',
        kind: SkillKind.ground,
        unlock: 10,
        cooldown: 8,
        mp: 18,
        power: 2.1,
        powerPerLv: 0.18,
        range: 320,
        radius: 145,
        delay: 0.35,
        status: Status.stun,
        statusTime: 1.3,
        fx: 'iceField',
      ),
      SkillDef(
        id: 'thuy4',
        name: 'Băng Cơ Ngọc Cốt',
        desc: 'Nội tại: tăng nội lực và phòng thủ.',
        kind: SkillKind.passive,
        unlock: 15,
        passive: {Bonus.mpPct: 0.05, Bonus.defPct: 0.03},
      ),
      SkillDef(
        id: 'thuy5',
        name: 'Thiên Sơn Tuyết Vũ',
        desc: 'Ba đợt mưa băng trút xuống quanh thân.',
        kind: SkillKind.aura,
        unlock: 25,
        cooldown: 12,
        mp: 30,
        power: 1.5,
        powerPerLv: 0.12,
        radius: 235,
        duration: 1.5,
        ticks: 3,
        status: Status.slow,
        statusPower: 0.5,
        statusTime: 2,
        fx: 'snowStorm',
      ),
      SkillDef(
        id: 'thuy6',
        name: 'Thủy Nguyệt Tâm Kinh',
        desc: 'Nội tại: tăng uy lực kỹ năng, giảm thời gian hồi chiêu.',
        kind: SkillKind.passive,
        unlock: 35,
        passive: {Bonus.skillDmg: 0.04, Bonus.cdr: 0.02},
      ),
    ],
  ),
  SectDef(
    hanh: Hanh.hoa,
    name: 'Liệt Hỏa Bang',
    tagline: 'Đao lửa cuồng bạo, một chém rung trời',
    desc: 'Đao khách luyện hỏa công. Sát thương cận chiến cao nhất, có '
        'chiêu lướt tới và đốt cháy. Máu vừa phải, cần đánh nhanh.',
    role: 'Cận chiến · Sát thương bùng nổ',
    difficulty: 3,
    base: [12, 8, 8, 4],
    atkWeights: [1.75, 0.5, 0, 0.2],
    hpMul: 1.05,
    basic: BasicKind.melee,
    basicRange: 80,
    basicFx: 'saber',
    weaponName: 'Đao',
    autoBuild: [3, 1, 2, 0],
    skills: [
      SkillDef(
        id: 'hoa1',
        name: 'Liệt Diễm Đao',
        desc: 'Chém đao rực lửa hình quạt, gây bỏng.',
        kind: SkillKind.arc,
        unlock: 1,
        cooldown: 2,
        mp: 6,
        power: 1.6,
        powerPerLv: 0.13,
        range: 125,
        spread: 2.6,
        status: Status.burn,
        statusPower: 0.3,
        statusTime: 3,
        fx: 'arcFire',
      ),
      SkillDef(
        id: 'hoa2',
        name: 'Hỏa Long Xung',
        desc: 'Hóa thành rồng lửa lao tới, thiêu đốt mọi thứ trên đường.',
        kind: SkillKind.dash,
        unlock: 5,
        cooldown: 6,
        mp: 12,
        power: 2.0,
        powerPerLv: 0.17,
        range: 240,
        radius: 60,
        fx: 'fireDash',
      ),
      SkillDef(
        id: 'hoa3',
        name: 'Hỏa Liên Trận',
        desc: 'Vòng sen lửa bùng quanh thân, gây bỏng diện rộng.',
        kind: SkillKind.nova,
        unlock: 10,
        cooldown: 7,
        mp: 16,
        power: 2.4,
        powerPerLv: 0.2,
        radius: 150,
        status: Status.burn,
        statusPower: 0.35,
        statusTime: 3,
        fx: 'fireRing',
      ),
      SkillDef(
        id: 'hoa4',
        name: 'Cuồng Huyết',
        desc: 'Nội tại: tăng công lực và sát thương chí mạng.',
        kind: SkillKind.passive,
        unlock: 15,
        passive: {Bonus.atkPct: 0.03, Bonus.critDmg: 0.05},
      ),
      SkillDef(
        id: 'hoa5',
        name: 'Phần Thiên Liệt Địa',
        desc: 'Gọi thiên thạch lửa giáng xuống, uy lực cực lớn.',
        kind: SkillKind.ground,
        unlock: 25,
        cooldown: 13,
        mp: 32,
        power: 4.6,
        powerPerLv: 0.38,
        range: 300,
        radius: 185,
        delay: 0.6,
        knock: 90,
        status: Status.burn,
        statusPower: 0.4,
        statusTime: 3,
        fx: 'meteor',
      ),
      SkillDef(
        id: 'hoa6',
        name: 'Hỏa Thần Hộ Thể',
        desc: 'Nội tại: tăng tốc đánh và sinh lực.',
        kind: SkillKind.passive,
        unlock: 35,
        passive: {Bonus.aspd: 0.03, Bonus.hpPct: 0.02},
      ),
    ],
  ),
  SectDef(
    hanh: Hanh.tho,
    name: 'Huyền Thổ Quán',
    tagline: 'Thái cực sinh lưỡng nghi, kiếm khí trấn sơn hà',
    desc: 'Đạo sĩ luyện kiếm khí và thổ pháp. Đánh tầm trung, có khiên '
        'hộ thể và chiêu địa chấn làm choáng. Công thủ cân bằng.',
    role: 'Tầm trung · Cân bằng · Khống chế',
    difficulty: 1,
    base: [6, 7, 10, 9],
    atkWeights: [0.6, 0.3, 0, 1.7],
    hpMul: 1.08,
    basic: BasicKind.ranged,
    basicRange: 250,
    basicFx: 'swordQi',
    weaponName: 'Trường Kiếm',
    autoBuild: [0, 1, 2, 2],
    skills: [
      SkillDef(
        id: 'tho1',
        name: 'Thái Cực Kiếm Khí',
        desc: 'Kiếm khí hình bán nguyệt xuyên qua hàng quái.',
        kind: SkillKind.projectile,
        unlock: 1,
        cooldown: 2.4,
        mp: 6,
        power: 1.6,
        powerPerLv: 0.13,
        range: 330,
        pierce: true,
        radius: 34,
        fx: 'taiji',
      ),
      SkillDef(
        id: 'tho2',
        name: 'Thổ Linh Hộ Thể',
        desc: 'Khiên đất hấp thụ sát thương.',
        kind: SkillKind.shield,
        unlock: 5,
        cooldown: 20,
        mp: 16,
        power: 0.3,
        powerPerLv: 0.03,
        duration: 12,
        fx: 'earthShield',
      ),
      SkillDef(
        id: 'tho3',
        name: 'Địa Chấn Quyết',
        desc: 'Gai đá trồi lên thành hàng, làm choáng quái.',
        kind: SkillKind.line,
        unlock: 10,
        cooldown: 8,
        mp: 18,
        power: 2.2,
        powerPerLv: 0.18,
        range: 330,
        radius: 70,
        count: 6,
        status: Status.stun,
        statusTime: 0.9,
        fx: 'spikes',
      ),
      SkillDef(
        id: 'tho4',
        name: 'Đạo Pháp Tự Nhiên',
        desc: 'Nội tại: tăng sinh lực và hồi phục.',
        kind: SkillKind.passive,
        unlock: 15,
        passive: {Bonus.hpPct: 0.035, Bonus.regen: 0.002},
      ),
      SkillDef(
        id: 'tho5',
        name: 'Lưỡng Nghi Kiếm Trận',
        desc: 'Phi kiếm xoay quanh thân, liên tục chém quái lại gần.',
        kind: SkillKind.aura,
        unlock: 25,
        cooldown: 14,
        mp: 30,
        power: 0.85,
        powerPerLv: 0.07,
        radius: 150,
        duration: 6,
        ticks: 15,
        fx: 'swordOrbit',
      ),
      SkillDef(
        id: 'tho6',
        name: 'Thái Cực Tâm Pháp',
        desc: 'Nội tại: tăng phòng thủ và chí mạng.',
        kind: SkillKind.passive,
        unlock: 35,
        passive: {Bonus.defPct: 0.04, Bonus.crit: 0.008},
      ),
    ],
  ),
];

SectDef sectOf(Hanh h) => sects[h.index];

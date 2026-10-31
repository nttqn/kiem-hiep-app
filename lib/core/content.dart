import 'arena.dart';
import 'hanh.dart';
import 'luan_hoi.dart';

/// Body plans the renderer knows how to draw.
enum Body { quad, human, serpent, bug, flyer, brute }

class MobDef {
  const MobDef({
    required this.id,
    required this.name,
    required this.hanh,
    required this.body,
    required this.c1,
    required this.c2,
    this.c3 = 0xFF222222,
    this.variant = '',
    this.size = 1,
    this.hp = 1,
    this.atk = 1,
    this.def = 1,
    this.speed = 95,
    this.ranged = false,
    this.range = 0,
    this.attackCd = 1.4,
    this.exp = 1,
    this.boss = false,
  });

  final String id;
  final String name;
  final Hanh hanh;
  final Body body;

  /// Main, secondary and accent colours (ARGB).
  final int c1, c2, c3;

  /// Body-plan specific detail: 'tusks', 'saber', 'zombie'…
  final String variant;
  final double size;
  final double hp, atk, def;
  final double speed;
  final bool ranged;

  /// Reach of a ranged attack (melee reach comes from size).
  final double range;
  final double attackCd;
  final double exp;
  final bool boss;
}

const mobs = <MobDef>[
  // Ngoại Thành
  MobDef(
      id: 'wolf', name: 'Sói Xám', hanh: Hanh.kim, body: Body.quad,
      c1: 0xFF8D8D8D, c2: 0xFFCFCFCF, variant: 'wolf', speed: 115,
      hp: 0.85, atk: 0.9),
  MobDef(
      id: 'boar', name: 'Lợn Rừng', hanh: Hanh.tho, body: Body.quad,
      c1: 0xFF6B4A33, c2: 0xFF4A3222, c3: 0xFFF2E6C8, variant: 'boar',
      speed: 90, hp: 1.15, def: 1.2),
  MobDef(
      id: 'bandit', name: 'Sơn Tặc', hanh: Hanh.hoa, body: Body.human,
      c1: 0xFF7A3B2A, c2: 0xFF3B2A20, c3: 0xFFB0B0B0, variant: 'saber',
      atk: 1.1),
  MobDef(
      id: 'banditBoss', name: 'Hắc Hổ Trại Chủ', hanh: Hanh.hoa,
      body: Body.human, c1: 0xFF2B2B2B, c2: 0xFFB3261E, c3: 0xFFD8D8D8,
      variant: 'bigSaber', size: 1.55, hp: 12, atk: 1.6, def: 1.3,
      speed: 85, exp: 12, boss: true),
  // Trúc Lâm
  MobDef(
      id: 'snake', name: 'Rắn Lục', hanh: Hanh.moc, body: Body.serpent,
      c1: 0xFF4F8F3A, c2: 0xFFC9D86A, speed: 85, hp: 0.8, atk: 1.1,
      attackCd: 1.2),
  MobDef(
      id: 'ape', name: 'Hắc Viên', hanh: Hanh.tho, body: Body.brute,
      c1: 0xFF3A3330, c2: 0xFF8C6F5A, variant: 'ape', size: 1.15,
      hp: 1.3, atk: 1.05, speed: 100),
  MobDef(
      id: 'bambooAssassin', name: 'Thích Khách Trúc Lâm', hanh: Hanh.moc,
      body: Body.human, c1: 0xFF2F5D3A, c2: 0xFF1E2A22, c3: 0xFF9AD27A,
      variant: 'darts', ranged: true, range: 240, hp: 0.75, atk: 0.95,
      attackCd: 1.8),
  MobDef(
      id: 'snakeKing', name: 'Thanh Xà Vương', hanh: Hanh.moc,
      body: Body.serpent, c1: 0xFF2E7D4F, c2: 0xFFE3E07A, c3: 0xFFE84B3A,
      size: 1.9, hp: 13, atk: 1.6, def: 1.2, speed: 80, exp: 12,
      boss: true),
  // Hắc Phong Động
  MobDef(
      id: 'bat', name: 'Dơi Hút Máu', hanh: Hanh.thuy, body: Body.flyer,
      c1: 0xFF4A3A5A, c2: 0xFFB04A5A, variant: 'bat', speed: 125,
      hp: 0.7, atk: 0.9, attackCd: 1.1),
  MobDef(
      id: 'spider', name: 'Nhện Độc', hanh: Hanh.moc, body: Body.bug,
      c1: 0xFF2A2A30, c2: 0xFF9C3AD0, variant: 'spider', speed: 100,
      hp: 1.0, atk: 1.05),
  MobDef(
      id: 'zombie', name: 'Cương Thi', hanh: Hanh.kim, body: Body.human,
      c1: 0xFF3E4F6A, c2: 0xFF8FA88A, c3: 0xFFE8D24A, variant: 'zombie',
      speed: 70, hp: 1.4, def: 1.3, atk: 1.1),
  MobDef(
      id: 'zombieKing', name: 'Thi Vương', hanh: Hanh.kim, body: Body.human,
      c1: 0xFF5A2A6A, c2: 0xFF7FA07A, c3: 0xFFE8D24A, variant: 'zombie',
      size: 1.7, hp: 14, atk: 1.6, def: 1.5, speed: 70, exp: 12,
      boss: true),
  // Hoàng Sa Mạc
  MobDef(
      id: 'scorpion', name: 'Bọ Cạp Cát', hanh: Hanh.tho, body: Body.bug,
      c1: 0xFFB0763A, c2: 0xFF6A3E1A, variant: 'scorpion', speed: 95,
      hp: 1.1, def: 1.3),
  MobDef(
      id: 'horseBandit', name: 'Mã Tặc', hanh: Hanh.kim, body: Body.human,
      c1: 0xFFC9A66B, c2: 0xFF6A4A2A, c3: 0xFFCFCFCF, variant: 'spear',
      hp: 1.05, atk: 1.15, speed: 105),
  MobDef(
      id: 'sandWolf', name: 'Sa Lang', hanh: Hanh.hoa, body: Body.quad,
      c1: 0xFFC89A5A, c2: 0xFFF0D8A8, variant: 'wolf', speed: 120,
      hp: 0.9, atk: 1.05),
  MobDef(
      id: 'scorpionKing', name: 'Cự Hạt Vương', hanh: Hanh.tho,
      body: Body.bug, c1: 0xFF8A3A1A, c2: 0xFF3A1A0A, c3: 0xFFFFC34A,
      variant: 'scorpion', size: 2.0, hp: 15, atk: 1.6, def: 1.6,
      speed: 80, exp: 12, boss: true),
  // Băng Tuyết Nguyên
  MobDef(
      id: 'snowWolf', name: 'Tuyết Lang', hanh: Hanh.thuy, body: Body.quad,
      c1: 0xFFE8EEF2, c2: 0xFFAFC4D4, variant: 'wolf', speed: 120,
      hp: 0.95, atk: 1.0),
  MobDef(
      id: 'yeti', name: 'Tuyết Quái', hanh: Hanh.tho, body: Body.brute,
      c1: 0xFFF2F5F8, c2: 0xFF7A9AB8, variant: 'yeti', size: 1.3,
      hp: 1.5, atk: 1.15, speed: 80),
  MobDef(
      id: 'iceSpirit', name: 'Băng Linh', hanh: Hanh.thuy, body: Body.flyer,
      c1: 0xFF9FE3FF, c2: 0xFFFFFFFF, variant: 'wisp', ranged: true,
      range: 250, hp: 0.75, atk: 1.0, attackCd: 1.9),
  MobDef(
      id: 'yetiKing', name: 'Tuyết Sơn Yêu Vương', hanh: Hanh.thuy,
      body: Body.brute, c1: 0xFFDDE9F5, c2: 0xFF3F6E9E, c3: 0xFF7FDBFF,
      variant: 'yeti', size: 2.0, hp: 16, atk: 1.65, def: 1.4, speed: 75,
      exp: 12, boss: true),
  // Hỏa Diệm Sơn
  MobDef(
      id: 'fireWolf', name: 'Hỏa Lang', hanh: Hanh.hoa, body: Body.quad,
      c1: 0xFF8A2A1A, c2: 0xFFFF8A3D, c3: 0xFFFFD34A, variant: 'fireWolf',
      speed: 125, hp: 0.95, atk: 1.1),
  MobDef(
      id: 'lavaGolem', name: 'Dung Nham Thạch Nhân', hanh: Hanh.tho,
      body: Body.brute, c1: 0xFF3A3030, c2: 0xFFFF6A2A, variant: 'golem',
      size: 1.35, hp: 1.6, def: 1.6, speed: 70),
  MobDef(
      id: 'fireSpirit', name: 'Hỏa Linh', hanh: Hanh.hoa, body: Body.flyer,
      c1: 0xFFFF6A2A, c2: 0xFFFFE08A, variant: 'wisp', ranged: true,
      range: 250, hp: 0.75, atk: 1.05, attackCd: 1.8),
  MobDef(
      id: 'kylin', name: 'Hỏa Kỳ Lân', hanh: Hanh.hoa, body: Body.quad,
      c1: 0xFFB3261E, c2: 0xFFFFC34A, c3: 0xFF3AD0C0, variant: 'kylin',
      size: 2.0, hp: 17, atk: 1.7, def: 1.5, speed: 95, exp: 12,
      boss: true),
  // Ma Giáo Tổng Đàn
  MobDef(
      id: 'cultist', name: 'Ma Giáo Đồ', hanh: Hanh.hoa, body: Body.human,
      c1: 0xFF5A1A2A, c2: 0xFF1A1A1A, c3: 0xFFC0C0C0, variant: 'saber',
      hp: 1.1, atk: 1.15),
  MobDef(
      id: 'assassin', name: 'Hắc Y Sát Thủ', hanh: Hanh.moc,
      body: Body.human, c1: 0xFF1A1A22, c2: 0xFF3A3A4A, c3: 0xFFE84B3A,
      variant: 'dagger', speed: 135, hp: 0.85, atk: 1.25, attackCd: 1.0),
  MobDef(
      id: 'ghost', name: 'Quỷ Ảnh', hanh: Hanh.thuy, body: Body.flyer,
      c1: 0xFF8A7AB8, c2: 0xFFE0D8FF, variant: 'ghost', ranged: true,
      range: 260, hp: 0.8, atk: 1.1, attackCd: 1.8),
  MobDef(
      id: 'demonLord', name: 'Huyết Ma Giáo Chủ', hanh: Hanh.kim,
      body: Body.human, c1: 0xFF8A0F1A, c2: 0xFF1A0A0A, c3: 0xFFFFD34A,
      variant: 'demonLord', size: 1.7, hp: 20, atk: 1.8, def: 1.7,
      speed: 100, exp: 15, boss: true),
  // Vân Vụ Sơn
  MobDef(
      id: 'renegade', name: 'Phản Đồ Kiếm Khách', hanh: Hanh.kim,
      body: Body.human, c1: 0xFFD8DCE4, c2: 0xFF3A4A6A, c3: 0xFF5A7AB8,
      variant: 'swordsman', hp: 1.15, atk: 1.2, def: 1.1, speed: 110),
  MobDef(
      id: 'whiteApe', name: 'Bạch Viên', hanh: Hanh.moc, body: Body.brute,
      c1: 0xFFE8E4DC, c2: 0xFF9A8A78, variant: 'ape', size: 1.25,
      hp: 1.4, atk: 1.15, speed: 110),
  MobDef(
      id: 'cloudSpirit', name: 'Vân Linh', hanh: Hanh.thuy, body: Body.flyer,
      c1: 0xFFA8E8E0, c2: 0xFFFFFFFF, variant: 'wisp', ranged: true,
      range: 260, hp: 0.8, atk: 1.1, attackCd: 1.8),
  MobDef(
      id: 'whiteDragon', name: 'Bạch Long Vương', hanh: Hanh.kim,
      body: Body.serpent, c1: 0xFFF0F2F4, c2: 0xFFC8D8E8, c3: 0xFFFFC34A,
      variant: 'dragon', size: 2.2, hp: 22, atk: 1.85, def: 1.7, speed: 90,
      exp: 16, boss: true),
  // Hoa Sơn Tuyệt Đỉnh
  MobDef(
      id: 'goldTiger', name: 'Kim Mao Hổ', hanh: Hanh.kim, body: Body.quad,
      c1: 0xFFE8B040, c2: 0xFFF8ECD0, c3: 0xFF3A2A1A, variant: 'tiger',
      size: 1.15, speed: 130, hp: 1.1, atk: 1.25),
  MobDef(
      id: 'swordGolem', name: 'Kiếm Khôi', hanh: Hanh.tho, body: Body.brute,
      c1: 0xFF6A6E78, c2: 0xFF5AD0F0, variant: 'golem', size: 1.4,
      hp: 1.7, atk: 1.15, def: 1.7, speed: 75),
  MobDef(
      id: 'swordSoul', name: 'Kiếm Hồn', hanh: Hanh.hoa, body: Body.flyer,
      c1: 0xFFFF8A5A, c2: 0xFFFFE0C8, variant: 'ghost', ranged: true,
      range: 270, hp: 0.85, atk: 1.2, attackCd: 1.7),
  MobDef(
      id: 'heavenDemon', name: 'Thiên Ma Lão Tổ', hanh: Hanh.moc,
      body: Body.human, c1: 0xFF3A1A4A, c2: 0xFF120A18, c3: 0xFFB04AFF,
      variant: 'ancient', size: 1.8, hp: 25, atk: 1.95, def: 1.8,
      speed: 105, exp: 18, boss: true),
  // Cửu U Ma Vực (after the fifth rebirth): darker kin of Hoa Sơn's.
  MobDef(
      id: 'abyssTiger', name: 'Huyết Ảnh Hổ', hanh: Hanh.kim, body: Body.quad,
      c1: 0xFF3A2A4A, c2: 0xFFB04AFF, c3: 0xFF120A18, variant: 'tiger',
      size: 1.2, speed: 135, hp: 1.15, atk: 1.3),
  MobDef(
      id: 'abyssGolem', name: 'U Minh Thạch Khôi', hanh: Hanh.tho, body: Body.brute,
      c1: 0xFF2E2A36, c2: 0xFFFF4A6A, variant: 'golem', size: 1.5,
      hp: 1.8, atk: 1.2, def: 1.8, speed: 75),
  MobDef(
      id: 'abyssSoul', name: 'Cửu U Oan Hồn', hanh: Hanh.thuy, body: Body.flyer,
      c1: 0xFF8A5AFF, c2: 0xFFE0D0FF, variant: 'ghost', ranged: true,
      range: 280, hp: 0.9, atk: 1.25, attackCd: 1.6),
  MobDef(
      id: 'abyssLord', name: 'Cửu U Ma Tôn', hanh: Hanh.hoa,
      body: Body.human, c1: 0xFF140A1A, c2: 0xFF2A0A12, c3: 0xFFFF3A5A,
      variant: 'ancient', size: 1.9, hp: 28, atk: 2.0, def: 1.9,
      speed: 110, exp: 20, boss: true),
];

final Map<String, MobDef> mobById = {for (final m in mobs) m.id: m};

enum MapTheme { grass, bamboo, cave, desert, snow, volcano, fortress, cloud, summit, abyss }

class MapDef {
  const MapDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.minLv,
    required this.maxLv,
    required this.theme,
    required this.mobs,
    required this.boss,
    this.width = 3200,
    this.height = 2200,
    this.rebirths = 0,
    this.mul = 1,
  });

  final String id;
  final String name;
  final String desc;
  final int minLv, maxLv;
  final MapTheme theme;
  final List<String> mobs;
  final String boss;
  final double width, height;

  /// Rebirths needed to enter (Cửu U Ma Vực); such a map opens at
  /// [abyssEntryLv] instead.
  final int rebirths;

  /// HP and attack multiplier on top of the monsters' level.
  final double mul;

  /// The hero may enter a little below the map's range.
  int get entryLv => rebirths > 0 ? abyssEntryLv : (minLv <= 1 ? 1 : minLv - 2);
}

/// Cửu U Ma Vực: a field after the fifth rebirth, its monsters tuned for
/// heroes of several hundred thousand lực chiến (about Ác Mộng 12), with
/// Thần Thiết from every kill and an outfit and a mount from its boss.
/// Kept out of [maps], whose order the story, bounties and herbs follow.
const int abyssEntryLv = 90;
const MapDef abyssMap = MapDef(
    id: 'cuuu', name: 'Cửu U Ma Vực',
    desc: 'Vực thẳm dưới Hoa Sơn, ma khí Cửu U chỉ bậc ngũ chuyển mới chịu nổi.',
    minLv: 99, maxLv: 99, theme: MapTheme.abyss,
    mobs: ['abyssTiger', 'abyssGolem', 'abyssSoul'], boss: 'abyssLord',
    rebirths: 5, mul: abyssMul);

/// About Ác Mộng 12 at level 99 (a 350k lực chiến hero), a little under as
/// a field is fought for long stretches; a 60-100k hero dies here within
/// minutes in a simulation.
const double abyssMul = 8;

/// Chance a monster there drops Thần Thiết, and the boss's handful.
const double abyssIronChance = 0.03;
const int abyssBossIron = 4;

const maps = <MapDef>[
  MapDef(
      id: 'ngoaithanh', name: 'Ngoại Thành Lạc An',
      desc: 'Đồng cỏ ven thành, sói và sơn tặc thường quấy nhiễu dân lành.',
      minLv: 1, maxLv: 8, theme: MapTheme.grass,
      mobs: ['wolf', 'boar', 'bandit'], boss: 'banditBoss'),
  MapDef(
      id: 'truclam', name: 'Tử Trúc Lâm',
      desc: 'Rừng trúc tím u tịch, rắn độc và thích khách ẩn mình.',
      minLv: 8, maxLv: 16, theme: MapTheme.bamboo,
      mobs: ['snake', 'ape', 'bambooAssassin'], boss: 'snakeKing'),
  MapDef(
      id: 'hacphong', name: 'Hắc Phong Động',
      desc: 'Hang động âm u, cương thi lang thang trong bóng tối.',
      minLv: 16, maxLv: 25, theme: MapTheme.cave,
      mobs: ['bat', 'spider', 'zombie'], boss: 'zombieKing'),
  MapDef(
      id: 'hoangsa', name: 'Hoàng Sa Mạc',
      desc: 'Sa mạc cát vàng, mã tặc cướp bóc thương đoàn.',
      minLv: 25, maxLv: 35, theme: MapTheme.desert,
      mobs: ['scorpion', 'horseBandit', 'sandWolf'], boss: 'scorpionKing'),
  MapDef(
      id: 'bangnguyen', name: 'Băng Tuyết Nguyên',
      desc: 'Cao nguyên băng giá quanh năm, yêu quái tuyết hoành hành.',
      minLv: 35, maxLv: 45, theme: MapTheme.snow,
      mobs: ['snowWolf', 'yeti', 'iceSpirit'], boss: 'yetiKing'),
  MapDef(
      id: 'hoadiem', name: 'Hỏa Diệm Sơn',
      desc: 'Núi lửa dung nham sôi sục, nơi Hỏa Kỳ Lân trú ngụ.',
      minLv: 45, maxLv: 55, theme: MapTheme.volcano,
      mobs: ['fireWolf', 'lavaGolem', 'fireSpirit'], boss: 'kylin'),
  MapDef(
      id: 'magiao', name: 'Ma Giáo Tổng Đàn',
      desc: 'Sào huyệt Huyết Ma Giáo, nguồn cơn mọi tai ương võ lâm.',
      minLv: 55, maxLv: 70, theme: MapTheme.fortress,
      mobs: ['cultist', 'assassin', 'ghost'], boss: 'demonLord'),
  MapDef(
      id: 'vanvu', name: 'Vân Vụ Sơn',
      desc: 'Núi cao mây phủ, dư đảng ma giáo ẩn náu cùng phản đồ các phái.',
      minLv: 70, maxLv: 84, theme: MapTheme.cloud,
      mobs: ['renegade', 'whiteApe', 'cloudSpirit'], boss: 'whiteDragon'),
  MapDef(
      id: 'hoason', name: 'Hoa Sơn Tuyệt Đỉnh',
      desc: 'Đỉnh núi luận kiếm, nơi Thiên Ma Lão Tổ chờ thách đấu thiên hạ.',
      minLv: 84, maxLv: 99, theme: MapTheme.summit,
      mobs: ['goldTiger', 'swordGolem', 'swordSoul'], boss: 'heavenDemon'),
];

final Map<String, MapDef> mapById = {for (final m in maps) m.id: m, abyssMap.id: abyssMap};

class DungeonDef {
  const DungeonDef({
    required this.id,
    required this.name,
    required this.mapId,
    required this.level,
    required this.waves,
    this.timeLimit = 180,
    this.floor = 0,
    this.mul = 1,
    this.boss = true,
    this.worldBoss = '',
    this.rival,
    this.trial = false,
    this.nightmare = 0,
    this.affix = 0,
    this.realm = 0,
  });

  final String id;
  final String name;
  final String mapId;
  final int level;

  /// Monsters per wave; the boss comes after the last one.
  final List<int> waves;
  final double timeLimit;

  /// Tháp Thử Luyện floor (0 for a regular dungeon), the HP/attack
  /// multiplier on its monsters, and whether a boss ends it.
  final int floor;
  final double mul;
  final bool boss;

  bool get isTower => floor > 0;

  /// Boss Thế Giới run: this boss alone, unkillable, scored by damage.
  final String worldBoss;
  bool get isWorldBoss => worldBoss.isNotEmpty;

  /// Lôi đài duel: this challenger alone, win by knocking them out.
  final ArenaRival? rival;
  bool get isArena => rival != null;

  /// Sư môn khảo hạch: the duel is with an elder of the hero's sect.
  final bool trial;

  /// Ải Ác Mộng number (1-based, 0 for none) and its ma khí (NmAffix index).
  final int nightmare;
  final int affix;
  bool get isNightmare => nightmare > 0;

  /// Bí cảnh number (1-based, 0 for none): a wide land explored, not waves.
  final int realm;
  bool get isRealm => realm > 0;

  MapDef get map => mapById[mapId]!;

  /// Seconds needed for 3 and 2 stars.
  double get threeStar => timeLimit * 0.45;
  double get twoStar => timeLimit * 0.7;

  int starsFor(double seconds) =>
      seconds <= threeStar ? 3 : (seconds <= twoStar ? 2 : 1);
}

const dungeons = <DungeonDef>[
  DungeonDef(id: 'a1', name: 'Sơn Trại Hắc Hổ', mapId: 'ngoaithanh',
      level: 4, waves: [5, 7]),
  DungeonDef(id: 'a2', name: 'Lạc An Cổ Đạo', mapId: 'ngoaithanh',
      level: 8, waves: [6, 8, 8]),
  DungeonDef(id: 'a3', name: 'Trúc Lâm Mê Trận', mapId: 'truclam',
      level: 12, waves: [6, 8, 9]),
  DungeonDef(id: 'a4', name: 'Thanh Xà Cốc', mapId: 'truclam',
      level: 16, waves: [7, 9, 10]),
  DungeonDef(id: 'a5', name: 'Cương Thi Mộ Địa', mapId: 'hacphong',
      level: 20, waves: [7, 9, 10]),
  DungeonDef(id: 'a6', name: 'Hắc Phong Thâm Xứ', mapId: 'hacphong',
      level: 25, waves: [8, 10, 11]),
  DungeonDef(id: 'a7', name: 'Lục Châu Cổ Thành', mapId: 'hoangsa',
      level: 30, waves: [8, 10, 11]),
  DungeonDef(id: 'a8', name: 'Hạt Vương Sào', mapId: 'hoangsa',
      level: 35, waves: [8, 10, 12]),
  DungeonDef(id: 'a9', name: 'Băng Phong Cốc', mapId: 'bangnguyen',
      level: 40, waves: [8, 10, 12]),
  DungeonDef(id: 'a10', name: 'Tuyết Sơn Đỉnh', mapId: 'bangnguyen',
      level: 45, waves: [9, 11, 12]),
  DungeonDef(id: 'a11', name: 'Dung Nham Địa Cung', mapId: 'hoadiem',
      level: 50, waves: [9, 11, 12]),
  DungeonDef(id: 'a12', name: 'Kỳ Lân Hỏa Động', mapId: 'hoadiem',
      level: 55, waves: [9, 11, 13]),
  DungeonDef(id: 'a13', name: 'Huyết Ma Điện', mapId: 'magiao',
      level: 62, waves: [10, 12, 13]),
  DungeonDef(id: 'a14', name: 'Giáo Chủ Mật Thất', mapId: 'magiao',
      level: 70, waves: [10, 12, 14]),
  DungeonDef(id: 'a15', name: 'Vân Hải Kiếm Trận', mapId: 'vanvu',
      level: 76, waves: [10, 12, 14]),
  DungeonDef(id: 'a16', name: 'Bạch Long Đàm', mapId: 'vanvu',
      level: 82, waves: [11, 12, 14]),
  DungeonDef(id: 'a17', name: 'Hoa Sơn Kiếm Trủng', mapId: 'hoason',
      level: 90, waves: [11, 13, 15]),
  DungeonDef(id: 'a18', name: 'Luận Kiếm Đài', mapId: 'hoason',
      level: 97, waves: [12, 14, 16]),
];

final Map<String, DungeonDef> dungeonById = {
  for (final d in dungeons) d.id: d,
};

enum QuestType { kill, boss, dungeon, level, elite }

class QuestDef {
  const QuestDef({
    required this.title,
    required this.story,
    required this.type,
    this.target = '',
    this.count = 1,
    required this.minLv,
    this.gold = 0,
    this.expFactor = 0.5,
    this.item = false,
  });

  final String title;
  final String story;
  final QuestType type;

  /// Monster id for kill/boss, dungeon id for dungeon, [EliteDef] id for elite.
  final String target;

  /// Kills needed, or the level to reach for [QuestType.level].
  final int count;
  final int minLv;
  final int gold;

  /// Reward EXP as a share of the EXP needed at [minLv].
  final double expFactor;

  /// Also pays a [Rarity.rare] item.
  final bool item;

  String get goal => switch (type) {
        QuestType.kill =>
          'Hạ $count ${mobById[target]!.name} (${_mapOfMob(target)})',
        QuestType.boss =>
          'Đánh bại ${mobById[target]!.name} (${_mapOfMob(target)})',
        QuestType.dungeon => 'Vượt ải ${dungeonById[target]!.name}',
        QuestType.level => 'Đạt cấp $count',
        QuestType.elite =>
          'Hạ tinh anh ${eliteById[target]!.name} (${mapById[eliteById[target]!.map]!.name})',
      };
}

/// Where a quest is done: the map of its monster or elite, if any.
MapDef? questMap(QuestDef q) => switch (q.type) {
      QuestType.kill || QuestType.boss => mapOfMob(q.target),
      QuestType.elite => mapById[eliteById[q.target]?.map],
      _ => null,
    };

String _mapOfMob(String id) {
  for (final m in maps) {
    if (m.mobs.contains(id) || m.boss == id) return m.name;
  }
  return '';
}

MapDef? mapOfMob(String id) {
  for (final m in maps) {
    if (m.mobs.contains(id) || m.boss == id) return m;
  }
  return null;
}

/// The main story, done in order.
const mainQuests = <QuestDef>[
  QuestDef(
      title: 'Bước chân giang hồ',
      story: 'Sư phụ dặn: muốn hành hiệp trượng nghĩa trước hết phải luyện '
          'thân thủ. Ngoài thành có bầy sói hay tấn công dân làng.',
      type: QuestType.kill, target: 'wolf', count: 8, minLv: 1, gold: 60,
      expFactor: 0.8),
  QuestDef(
      title: 'Lợn rừng phá ruộng',
      story: 'Nông dân than phiền lợn rừng phá hoại hoa màu. Hãy giúp họ.',
      type: QuestType.kill, target: 'boar', count: 10, minLv: 2, gold: 90,
      expFactor: 0.7),
  QuestDef(
      title: 'Sơn tặc chặn đường',
      story: 'Thương nhân bị sơn tặc cướp hàng giữa đường. Dạy cho chúng '
          'một bài học.',
      type: QuestType.kill, target: 'bandit', count: 12, minLv: 4,
      gold: 140, expFactor: 0.6),
  QuestDef(
      title: 'Phá sơn trại',
      story: 'Sơn tặc có sào huyệt ở phía bắc. Hãy đột nhập Sơn Trại Hắc Hổ.',
      type: QuestType.dungeon, target: 'a1', minLv: 4, gold: 200,
      expFactor: 0.6, item: true),
  QuestDef(
      title: 'Trại chủ Hắc Hổ',
      story: 'Kẻ cầm đầu vẫn nhởn nhơ ngoài thành. Tìm và đánh bại hắn.',
      type: QuestType.boss, target: 'banditBoss', minLv: 6, gold: 260,
      expFactor: 0.7),
  QuestDef(
      title: 'Lạc An cổ đạo',
      story: 'Đường cổ phía tây bị dư đảng sơn tặc chiếm giữ.',
      type: QuestType.dungeon, target: 'a2', minLv: 8, gold: 320,
      expFactor: 0.6),
  QuestDef(
      title: 'Rừng trúc tím',
      story: 'Có tin đồn thích khách lạ xuất hiện ở Tử Trúc Lâm. Hãy điều tra.',
      type: QuestType.kill, target: 'bambooAssassin', count: 15, minLv: 8,
      gold: 360, expFactor: 0.5),
  QuestDef(
      title: 'Rắn độc giữa trúc',
      story: 'Rắn lục cắn chết tiều phu. Diệt trừ chúng.',
      type: QuestType.kill, target: 'snake', count: 18, minLv: 10,
      gold: 420, expFactor: 0.5),
  QuestDef(
      title: 'Hắc Viên hung dữ',
      story: 'Bầy vượn đen cướp đồ của khách qua rừng.',
      type: QuestType.kill, target: 'ape', count: 18, minLv: 12, gold: 480,
      expFactor: 0.5),
  QuestDef(
      title: 'Trúc lâm mê trận',
      story: 'Thích khách lập trận pháp trong rừng. Phá trận tìm manh mối.',
      type: QuestType.dungeon, target: 'a3', minLv: 12, gold: 520,
      expFactor: 0.5, item: true),
  QuestDef(
      title: 'Thanh Xà Vương',
      story: 'Manh mối dẫn tới con rắn khổng lồ được kẻ lạ nuôi dưỡng.',
      type: QuestType.boss, target: 'snakeKing', minLv: 14, gold: 600,
      expFactor: 0.6),
  QuestDef(
      title: 'Thanh Xà Cốc',
      story: 'Hang ổ của rắn chúa nằm sâu trong thung lũng.',
      type: QuestType.dungeon, target: 'a4', minLv: 16, gold: 680,
      expFactor: 0.5),
  QuestDef(
      title: 'Hắc Phong Động',
      story: 'Thích khách để lại ấn ký Huyết Ma Giáo. Dấu vết dẫn về hang '
          'Hắc Phong.',
      type: QuestType.kill, target: 'bat', count: 20, minLv: 16, gold: 720,
      expFactor: 0.45),
  QuestDef(
      title: 'Nhện độc giăng tơ',
      story: 'Tơ nhện chắn lối vào sâu trong động.',
      type: QuestType.kill, target: 'spider', count: 20, minLv: 18,
      gold: 800, expFactor: 0.45),
  QuestDef(
      title: 'Cương thi trỗi dậy',
      story: 'Ma giáo luyện thi thuật, xác chết đứng dậy đi lại.',
      type: QuestType.kill, target: 'zombie', count: 22, minLv: 20,
      gold: 880, expFactor: 0.45),
  QuestDef(
      title: 'Mộ địa cương thi',
      story: 'Phá hủy lò luyện thi trong mộ địa.',
      type: QuestType.dungeon, target: 'a5', minLv: 20, gold: 950,
      expFactor: 0.45, item: true),
  QuestDef(
      title: 'Thi Vương',
      story: 'Thi Vương là tác phẩm đắc ý của ma giáo. Diệt trừ nó.',
      type: QuestType.boss, target: 'zombieKing', minLv: 22, gold: 1050,
      expFactor: 0.55),
  QuestDef(
      title: 'Hắc Phong thâm xứ',
      story: 'Nơi sâu nhất của hang động ẩn chứa mật thư của ma giáo.',
      type: QuestType.dungeon, target: 'a6', minLv: 25, gold: 1150,
      expFactor: 0.45),
  QuestDef(
      title: 'Thương đoàn gặp nạn',
      story: 'Mật thư nói ma giáo mua chuộc mã tặc ở Hoàng Sa Mạc.',
      type: QuestType.kill, target: 'horseBandit', count: 22, minLv: 25,
      gold: 1250, expFactor: 0.4),
  QuestDef(
      title: 'Bọ cạp sa mạc',
      story: 'Đàn bọ cạp chặn mạch nước duy nhất của ốc đảo.',
      type: QuestType.kill, target: 'scorpion', count: 24, minLv: 27,
      gold: 1350, expFactor: 0.4),
  QuestDef(
      title: 'Sa lang đói khát',
      story: 'Sói sa mạc tấn công lữ khách ban đêm.',
      type: QuestType.kill, target: 'sandWolf', count: 24, minLv: 29,
      gold: 1450, expFactor: 0.4),
  QuestDef(
      title: 'Lục Châu cổ thành',
      story: 'Mã tặc tụ tập trong thành cổ bị cát vùi.',
      type: QuestType.dungeon, target: 'a7', minLv: 30, gold: 1600,
      expFactor: 0.4, item: true),
  QuestDef(
      title: 'Cự Hạt Vương',
      story: 'Bọ cạp chúa khổng lồ là thú cưỡi của thủ lĩnh mã tặc.',
      type: QuestType.boss, target: 'scorpionKing', minLv: 32, gold: 1750,
      expFactor: 0.5),
  QuestDef(
      title: 'Hạt Vương sào huyệt',
      story: 'Tiêu diệt tận gốc ổ bọ cạp.',
      type: QuestType.dungeon, target: 'a8', minLv: 35, gold: 1900,
      expFactor: 0.4),
  QuestDef(
      title: 'Băng nguyên giá lạnh',
      story: 'Ma giáo tìm kiếm Băng Phách ở Băng Tuyết Nguyên.',
      type: QuestType.kill, target: 'snowWolf', count: 25, minLv: 35,
      gold: 2050, expFactor: 0.38),
  QuestDef(
      title: 'Tuyết quái',
      story: 'Tuyết quái bị ma khí kích động trở nên hung bạo.',
      type: QuestType.kill, target: 'yeti', count: 25, minLv: 37,
      gold: 2200, expFactor: 0.38),
  QuestDef(
      title: 'Băng linh',
      story: 'Băng linh canh giữ Băng Phách, cần thu phục.',
      type: QuestType.kill, target: 'iceSpirit', count: 25, minLv: 39,
      gold: 2350, expFactor: 0.38),
  QuestDef(
      title: 'Băng Phong Cốc',
      story: 'Đoạt Băng Phách trước khi rơi vào tay ma giáo.',
      type: QuestType.dungeon, target: 'a9', minLv: 40, gold: 2550,
      expFactor: 0.38, item: true),
  QuestDef(
      title: 'Yêu vương tuyết sơn',
      story: 'Yêu vương đã nuốt mất Băng Phách. Đánh bại nó!',
      type: QuestType.boss, target: 'yetiKing', minLv: 42, gold: 2750,
      expFactor: 0.45),
  QuestDef(
      title: 'Tuyết Sơn đỉnh',
      story: 'Trên đỉnh tuyết sơn có lối đi tắt tới Hỏa Diệm Sơn.',
      type: QuestType.dungeon, target: 'a10', minLv: 45, gold: 2950,
      expFactor: 0.38),
  QuestDef(
      title: 'Hỏa Diệm Sơn',
      story: 'Ma giáo dùng Băng Phách và Hỏa Tinh để luyện ma công.',
      type: QuestType.kill, target: 'fireWolf', count: 26, minLv: 45,
      gold: 3150, expFactor: 0.36),
  QuestDef(
      title: 'Thạch nhân dung nham',
      story: 'Thạch nhân canh giữ mỏ Hỏa Tinh.',
      type: QuestType.kill, target: 'lavaGolem', count: 26, minLv: 47,
      gold: 3350, expFactor: 0.36),
  QuestDef(
      title: 'Hỏa linh',
      story: 'Hỏa linh là tinh hoa của núi lửa.',
      type: QuestType.kill, target: 'fireSpirit', count: 26, minLv: 49,
      gold: 3550, expFactor: 0.36),
  QuestDef(
      title: 'Dung nham địa cung',
      story: 'Địa cung là nơi ma giáo khai thác Hỏa Tinh.',
      type: QuestType.dungeon, target: 'a11', minLv: 50, gold: 3800,
      expFactor: 0.36, item: true),
  QuestDef(
      title: 'Hỏa Kỳ Lân',
      story: 'Thần thú bị ma giáo khống chế. Giải thoát nó bằng một trận đấu.',
      type: QuestType.boss, target: 'kylin', minLv: 52, gold: 4050,
      expFactor: 0.42),
  QuestDef(
      title: 'Kỳ Lân hỏa động',
      story: 'Trong hang kỳ lân có bản đồ dẫn tới tổng đàn ma giáo.',
      type: QuestType.dungeon, target: 'a12', minLv: 55, gold: 4300,
      expFactor: 0.36),
  QuestDef(
      title: 'Tổng đàn ma giáo',
      story: 'Cuối cùng đã tìm ra sào huyệt Huyết Ma Giáo.',
      type: QuestType.kill, target: 'cultist', count: 30, minLv: 55,
      gold: 4600, expFactor: 0.34),
  QuestDef(
      title: 'Sát thủ hắc y',
      story: 'Đội sát thủ tinh nhuệ bảo vệ giáo chủ.',
      type: QuestType.kill, target: 'assassin', count: 30, minLv: 58,
      gold: 4900, expFactor: 0.34),
  QuestDef(
      title: 'Quỷ ảnh',
      story: 'Oan hồn bị luyện thành quỷ ảnh, cần được siêu thoát.',
      type: QuestType.kill, target: 'ghost', count: 30, minLv: 60,
      gold: 5200, expFactor: 0.34),
  QuestDef(
      title: 'Huyết Ma Điện',
      story: 'Đột phá chính điện của ma giáo.',
      type: QuestType.dungeon, target: 'a13', minLv: 62, gold: 5600,
      expFactor: 0.34, item: true),
  QuestDef(
      title: 'Huyết Ma Giáo Chủ',
      story: 'Trận chiến định đoạt vận mệnh võ lâm.',
      type: QuestType.boss, target: 'demonLord', minLv: 65, gold: 6500,
      expFactor: 0.5),
  QuestDef(
      title: 'Giáo chủ mật thất',
      story: 'Phá hủy mật thất để ma giáo không thể trỗi dậy lần nữa.',
      type: QuestType.dungeon, target: 'a14', minLv: 70, gold: 8000,
      expFactor: 0.5, item: true),
  QuestDef(
      title: 'Dư đảng ma giáo',
      story: 'Giáo chủ đã đền tội, nhưng dư đảng mang theo bí kíp trốn lên '
          'núi cao. Hãy tu luyện thêm trước khi truy đuổi.',
      type: QuestType.level, count: 72, minLv: 70, gold: 8500,
      expFactor: 0.4),
  QuestDef(
      title: 'Vân Vụ Sơn',
      story: 'Dư đảng cấu kết với phản đồ các phái, ẩn trong mây mù Vân Vụ Sơn.',
      type: QuestType.kill, target: 'renegade', count: 30, minLv: 72,
      gold: 9000, expFactor: 0.32),
  QuestDef(
      title: 'Bạch viên trộm kiếm',
      story: 'Bầy vượn trắng cướp bảo kiếm của tiều phu dâng cho phản đồ.',
      type: QuestType.kill, target: 'whiteApe', count: 30, minLv: 74,
      gold: 9600, expFactor: 0.32),
  QuestDef(
      title: 'Vân linh',
      story: 'Mây núi kết thành linh thể, bị ma khí sai khiến.',
      type: QuestType.kill, target: 'cloudSpirit', count: 32, minLv: 76,
      gold: 10200, expFactor: 0.32),
  QuestDef(
      title: 'Vân hải kiếm trận',
      story: 'Phản đồ bày kiếm trận trên biển mây để ngăn truy binh.',
      type: QuestType.dungeon, target: 'a15', minLv: 76, gold: 11000,
      expFactor: 0.32, item: true),
  QuestDef(
      title: 'Bạch Long Vương',
      story: 'Rồng trắng giữ đầm bị ma giáo dùng bí kíp khống chế.',
      type: QuestType.boss, target: 'whiteDragon', minLv: 79, gold: 12000,
      expFactor: 0.4),
  QuestDef(
      title: 'Bạch Long Đàm',
      story: 'Dưới đáy đầm có mật đạo dẫn lên Hoa Sơn.',
      type: QuestType.dungeon, target: 'a16', minLv: 82, gold: 13000,
      expFactor: 0.32),
  QuestDef(
      title: 'Hoa Sơn tuyệt đỉnh',
      story: 'Thiên Ma Lão Tổ, sư tổ của ma giáo, đã xuất quan trên đỉnh Hoa Sơn.',
      type: QuestType.kill, target: 'goldTiger', count: 32, minLv: 85,
      gold: 14000, expFactor: 0.3),
  QuestDef(
      title: 'Kiếm khôi',
      story: 'Lão Tổ luyện kiếm khôi từ đá núi để canh giữ đường lên đỉnh.',
      type: QuestType.kill, target: 'swordGolem', count: 34, minLv: 87,
      gold: 15000, expFactor: 0.3),
  QuestDef(
      title: 'Kiếm hồn',
      story: 'Kiếm hồn của các cao thủ tử trận vẫn lang thang trên núi.',
      type: QuestType.kill, target: 'swordSoul', count: 34, minLv: 89,
      gold: 16000, expFactor: 0.3),
  QuestDef(
      title: 'Hoa Sơn kiếm trủng',
      story: 'Mộ kiếm của võ lâm tiền bối cất giữ thanh kiếm có thể phá ma công.',
      type: QuestType.dungeon, target: 'a17', minLv: 90, gold: 18000,
      expFactor: 0.3, item: true),
  QuestDef(
      title: 'Thiên Ma Lão Tổ',
      story: 'Trận quyết đấu với kẻ đứng sau mọi tai ương của võ lâm.',
      type: QuestType.boss, target: 'heavenDemon', minLv: 93, gold: 22000,
      expFactor: 0.4),
  QuestDef(
      title: 'Luận kiếm đài',
      story: 'Các phái mời đại hiệp lên luận kiếm đài phân định ngôi chí tôn.',
      type: QuestType.dungeon, target: 'a18', minLv: 97, gold: 30000,
      expFactor: 0.4, item: true),
  QuestDef(
      title: 'Võ lâm chí tôn',
      story: 'Giang hồ đã yên bình. Hãy tiếp tục tu luyện để đạt cảnh giới '
          'tối thượng.',
      type: QuestType.level, count: 99, minLv: 97, gold: 60000,
      expFactor: 0.5),
];

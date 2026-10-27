import 'sects.dart';

/// Hái thuốc & luyện đan: herbs grow on the field maps and drop from
/// monsters, one tier per two regions; the alchemy furnace turns them into
/// pills that buff for a while, refill potions or raise potential for good.
const herbNames = ['Cam Thảo', 'Hà Thủ Ô', 'Linh Chi', 'Tuyết Liên', 'Huyết Sâm'];
const herbColors = [0xFF8CC84A, 0xFFB07A3A, 0xFFC8402E, 0xFFE8F4FF, 0xFFE83A5A];

/// Hero level that opens the furnace.
const int alchemyOpenLevel = 15;

/// Herb tier of map [mapIndex] (0-based, 9 maps).
int herbTierOfMap(int mapIndex) => (mapIndex ~/ 2).clamp(0, herbNames.length - 1);

/// Chance a regular monster drops a herb (bosses and elites always do).
const double herbDropChance = 0.03;

/// Herb plants per field map, and seconds before a picked one regrows.
const int herbNodes = 7;
const double herbRegrow = 90;

enum PillKind { buff, potions, potential }

class PillDef {
  const PillDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.kind,
    required this.herbs,
    required this.gold,
    required this.color,
    this.bonus = const {},
    this.minutes = 0,
  });

  final String id, name, desc;
  final PillKind kind;

  /// Herb counts by tier.
  final List<int> herbs;
  final int gold;
  final int color;

  /// What a buff pill adds while it lasts, and for how long (play time).
  final Map<Bonus, double> bonus;
  final int minutes;
}

/// Buff pills stack their time up to this many minutes.
const int maxBuffMinutes = 120;

/// Tẩy Tủy Đan: potential points each, and how many a hero may ever eat.
const int potentialPerPill = 3;
const int maxPotentialPills = 30;

/// Song Bội Đan's EXP and Tụ Bảo Đan's gold multipliers (on monsters).
const double expPillMul = 2;
const double goldPillMul = 1.5;

const pills = <PillDef>[
  PillDef(
      id: 'hoixuan', name: 'Hồi Xuân Đan', kind: PillKind.potions, color: 0xFFFF7A7A,
      desc: 'Luyện ra 10 Kim Sang Dược và 10 Ngưng Thần Đan.',
      herbs: [4, 0, 0, 0, 0], gold: 100),
  PillDef(
      id: 'songboi', name: 'Song Bội Đan', kind: PillKind.buff, color: 0xFF8AD8FF, minutes: 20,
      desc: 'Kinh nghiệm từ quái x2 trong 20 phút.',
      herbs: [6, 2, 0, 0, 0], gold: 500),
  PillDef(
      id: 'tubao', name: 'Tụ Bảo Đan', kind: PillKind.buff, color: 0xFFFFD34A, minutes: 20,
      desc: 'Lượng rơi từ quái +50% trong 20 phút.',
      herbs: [6, 0, 2, 0, 0], gold: 500),
  PillDef(
      id: 'cuongluc', name: 'Cuồng Lực Đan', kind: PillKind.buff, color: 0xFFFF8A3D, minutes: 20,
      desc: 'Công lực +15%, chí mạng +5% trong 20 phút.',
      herbs: [0, 4, 2, 0, 0], gold: 1500, bonus: {Bonus.atkPct: 0.15, Bonus.crit: 0.05}),
  PillDef(
      id: 'kimcang', name: 'Kim Cang Đan', kind: PillKind.buff, color: 0xFFE8C547, minutes: 20,
      desc: 'Phòng thủ +20%, sinh lực +10% trong 20 phút.',
      herbs: [0, 4, 0, 2, 0], gold: 1500, bonus: {Bonus.defPct: 0.2, Bonus.hpPct: 0.1}),
  PillDef(
      id: 'taytuy', name: 'Tẩy Tủy Đan', kind: PillKind.potential, color: 0xFFC8A0FF,
      desc: 'Tẩy kinh phạt tủy: vĩnh viễn +3 điểm tiềm năng (tối đa 30 viên).',
      herbs: [0, 0, 0, 3, 2], gold: 8000),
];

final Map<String, PillDef> pillById = {for (final p in pills) p.id: p};

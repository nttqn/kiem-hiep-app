import 'sects.dart';

/// Thần binh: after the first rebirth the hero awakens their weapon slot
/// level by level with Thần Thiết (from the hard end of the game: Ác Mộng
/// 7+, Boss Thế Giới, Tháp floors past 100) and gold. Each level adds
/// attack and HP; levels 3, 5, 7 and 10 add more, and the weapon glows
/// brighter by stage. It belongs to the hero, not the item, so changing
/// weapons keeps it.
const int divineMax = 20;
const int divineOpenRebirths = 1;

/// Tầng 11-20 (Thần binh bậc hai) open at the fourth rebirth, something
/// new for the heroes who have done everything else.
const int divineTier2From = 10;
const int divineTier2Rebirths = 4;

/// Thần Thiết to go from level `i` to `i + 1`.
const divineIronCost = [8, 12, 16, 22, 30, 40, 52, 66, 82, 100, 100, 110, 120, 135, 150, 165, 180, 200, 220, 250];
int divineGoldCost(int lv) => 40000 * (lv + 1);

/// Attack and HP per level.
const double divineStatPerLv = 0.025;

/// The extra bonus each milestone level adds.
const divineMarks = <int, (Bonus, double)>{
  3: (Bonus.crit, 0.04),
  7: (Bonus.critDmg, 0.2),
  10: (Bonus.skillDmg, 0.1),
  13: (Bonus.crit, 0.03),
  16: (Bonus.critDmg, 0.25),
  20: (Bonus.skillDmg, 0.12),
};

/// From this level basic hits may call down Thần Binh Giáng Thế: a burst of
/// the hero's phase around the target.
const int divineStrikeLevel = 5;
const double divineStrikeChance = 0.12;
const double divineStrikeCd = 1.5;
const double divineStrikeRadius = 120;
double divineStrikePower(int lv) => 1.0 + 0.15 * (lv - divineStrikeLevel);

Map<Bonus, double> divineBonuses(int lv) {
  if (lv <= 0) return const {};
  final out = <Bonus, double>{Bonus.atkPct: divineStatPerLv * lv, Bonus.hpPct: divineStatPerLv * lv};
  divineMarks.forEach((at, b) {
    if (lv >= at) out[b.$1] = (out[b.$1] ?? 0) + b.$2;
  });
  return out;
}

/// Stage name: Linh binh, Bảo binh, Thánh binh, Thần binh, then Tiên binh
/// at the very top.
String divineStage(int lv) => switch (lv) {
      <= 0 => 'Phàm binh',
      < 4 => 'Linh binh',
      < 7 => 'Bảo binh',
      < divineTier2From => 'Thánh binh',
      < divineMax => 'Thần binh',
      _ => 'Tiên binh',
    };

/// Weapon glow by stage, 0 below level 1.
int divineColor(int lv) => switch (lv) {
      <= 0 => 0,
      < 4 => 0xFF7FDBFF,
      < 7 => 0xFFC88CFF,
      < divineTier2From => 0xFFFFD34A,
      < 15 => 0xFFFF5A3A,
      < divineMax => 0xFFFF3AA8,
      _ => 0xFFE8FBFF,
    };

/// What reaching level [lv] adds, for the UI.
String divineLevelText(int lv) {
  final parts = ['+${(divineStatPerLv * 100).toStringAsFixed(1)}% công, sinh lực'];
  if (lv == divineStrikeLevel) parts.add('mở Thần Binh Giáng Thế');
  if (lv > divineStrikeLevel) parts.add('Giáng Thế mạnh hơn');
  final m = divineMarks[lv];
  if (m != null) {
    parts.add(switch (m.$1) {
      Bonus.crit => '+${(m.$2 * 100).round()}% bạo kích',
      Bonus.critDmg => '+${(m.$2 * 100).round()}% sát thương bạo kích',
      Bonus.skillDmg => '+${(m.$2 * 100).round()}% sát thương kỹ năng',
      _ => '',
    });
  }
  return parts.join(', ');
}

// Where Thần Thiết comes from.
int nightmareIron(int i) => i < 6 ? 0 : 1 + (i - 6) ~/ 4;
int nightmareFirstIron(int i) => i < 6 ? 0 : 2 + i ~/ 3;
const worldBossIron = [0, 0, 1, 2, 3];
int towerIron(int floor) => floor < 100 ? 0 : (floor % 10 == 0 ? 4 : 1);

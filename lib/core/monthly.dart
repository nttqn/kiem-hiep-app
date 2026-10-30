import 'items.dart';

/// Điểm danh tháng: every day the login gift is taken counts toward the
/// calendar month, and five marks along the way pay out by themselves, the
/// last a Truyền thuyết piece, so a player has a reason to keep coming back
/// after the seven newbie days.
class MonthlyMark {
  const MonthlyMark(
    this.days, {
    this.goldK = 0,
    this.gems = 0,
    this.gemTier = 1,
    this.iron = 0,
    this.shards = 0,
    this.pots = 0,
    this.pills = 0,
    this.item,
  });

  /// Check-in days in the month that reach this mark.
  final int days;

  /// Gold as a multiple of the login gift's base for the hero's level.
  final double goldK;
  final int gems, gemTier, iron, shards, pots, pills;
  final Rarity? item;

  int gold(int level) => ((200 + level * 40) * goldK).round();
}

const monthlyMarks = <MonthlyMark>[
  MonthlyMark(3, goldK: 5, gems: 2, gemTier: 3),
  MonthlyMark(7, iron: 3, pots: 30),
  MonthlyMark(14, goldK: 15, gems: 3, gemTier: 4, shards: 5),
  MonthlyMark(21, iron: 5, pills: 1),
  MonthlyMark(28, goldK: 30, item: Rarity.legend),
];

/// The month of a `y-m-d` day key, e.g. `2026-10`.
String monthOf(String day) {
  final p = day.split('-');
  return p.length < 2 ? day : '${p[0]}-${p[1]}';
}

/// Short labels of [m] for a hero at [level], for the board.
List<String> monthlyLabels(MonthlyMark m, int level) => [
      if (m.goldK > 0) '${_dots(m.gold(level))} lượng',
      if (m.item != null) 'Trang bị ${m.item!.label}',
      if (m.gems > 0) '${m.gems} ngọc bậc ${m.gemTier}',
      if (m.iron > 0) '${m.iron} Thần Thiết',
      if (m.shards > 0) '${m.shards} Mảnh Hoàng Kim',
      if (m.pots > 0) '${m.pots} bình máu + nội lực',
      if (m.pills > 0) '${m.pills} Tẩy Tủy Đan',
    ];

String _dots(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

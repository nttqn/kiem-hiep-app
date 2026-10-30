import 'funnel.dart';
import 'hero.dart';

/// Mục tiêu 7 ngày: three goals open on each of a new hero's first seven
/// days, each paying gold and something useful, and finishing all 21 pays a
/// chest. Goals once open stay open, so a slower player loses nothing; they
/// just give the first week a path to follow and a reason to come back.
class WeekGoal {
  const WeekGoal(this.id, this.day, this.name, this.goal, this.progress, {this.gems = 0, this.gemTier = 2, this.pots = 0});
  final String id;

  /// 1-7: the hero's day this goal opens on.
  final int day;
  final String name;
  final int goal;
  final int Function(HeroData h) progress;
  final int gems, gemTier, pots;

  /// Gold, on the login gift's scale for the day's expected level.
  int get gold => (200 + (5 + day * 5) * 40) * 4;
}

int _cleared(HeroData h) => h.dungeonStars.values.where((s) => s > 0).length;
int _threeStars(HeroData h) => h.dungeonStars.values.where((s) => s >= 3).length;
int _lv(HeroData h) => h.rebirths > 0 ? 99 : h.level;

final weekGoals = <WeekGoal>[
  WeekGoal('d1lv', 1, 'Đạt cấp 10', 10, _lv, pots: 20),
  WeekGoal('d1kill', 1, 'Hạ 200 quái', 200, (h) => h.kills, gems: 1),
  WeekGoal('d1dg', 1, 'Vượt 1 ải', 1, _cleared, gems: 1),
  WeekGoal('d2lv', 2, 'Đạt cấp 15', 15, _lv, pots: 20),
  WeekGoal('d2main', 2, 'Hoàn thành 10 nhiệm vụ chính tuyến', 10, (h) => h.mainQuest, gems: 1),
  WeekGoal('d2plus', 2, 'Cường hóa một món lên +3', 3, (h) => h.bestPlus, gems: 1),
  WeekGoal('d3lv', 3, 'Đạt cấp 20', 20, _lv, pots: 30),
  WeekGoal('d3dg', 3, 'Vượt 3 ải', 3, _cleared, gems: 2),
  WeekGoal('d3boss', 3, 'Đánh bại 3 đầu lĩnh', 3, (h) => h.bossKills, gems: 2),
  WeekGoal('d4lv', 4, 'Đạt cấp 25', 25, _lv, pots: 30),
  WeekGoal('d4tower', 4, 'Tháp Thử Luyện tầng 10', 10, (h) => h.towerBest, gems: 2, gemTier: 3),
  WeekGoal('d4kill', 4, 'Hạ 1.000 quái', 1000, (h) => h.kills, gems: 2, gemTier: 3),
  WeekGoal('d5lv', 5, 'Đạt cấp 30', 30, _lv, pots: 30),
  WeekGoal('d5main', 5, 'Hoàn thành 20 nhiệm vụ chính tuyến', 20, (h) => h.mainQuest, gems: 2, gemTier: 3),
  WeekGoal('d5star', 5, '3 sao ở 3 ải', 3, _threeStars, gems: 2, gemTier: 3),
  WeekGoal('d6lv', 6, 'Đạt cấp 35', 35, _lv, pots: 40),
  WeekGoal('d6tower', 6, 'Tháp Thử Luyện tầng 20', 20, (h) => h.towerBest, gems: 2, gemTier: 4),
  WeekGoal('d6plus', 6, 'Cường hóa một món lên +5', 5, (h) => h.bestPlus, gems: 2, gemTier: 4),
  WeekGoal('d7lv', 7, 'Đạt cấp 40', 40, _lv, pots: 50),
  WeekGoal('d7dg', 7, 'Vượt 6 ải', 6, _cleared, gems: 3, gemTier: 4),
  WeekGoal('d7kill', 7, 'Hạ 3.000 quái', 3000, (h) => h.kills, gems: 3, gemTier: 4),
];

final Map<String, WeekGoal> weekGoalById = {for (final g in weekGoals) g.id: g};

/// The chest for all 21: gems, Tẩy Tủy Đan and Thần Thiết.
const int weekChestGems = 5;
const int weekChestGemTier = 4;
const int weekChestPills = 2;
const int weekChestIron = 10;
const int weekChestGold = 100000;

/// The hero's day (1-based) on Vietnam day [today]; 0 for heroes made
/// before goals existed, who don't get them.
int weekGoalDay(HeroData h, String today) {
  final d = daysBetween(h.bornDay, today);
  return d == null ? 0 : d + 1;
}

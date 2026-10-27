import 'dart:math' as math;

/// Điểm năng động: everyday activities earn points (each source capped per
/// day); daily point marks open chests, and the week's total opens bigger
/// ones. Days and weeks follow Vietnam time; weeks start on Monday.
enum ActSource { kills, dungeon, worldBoss, bounty, arena, alchemy, daily }

class ActSourceDef {
  const ActSourceDef(this.label, this.points, this.cap, {this.per = 1});
  final String label;

  /// Points per [per] actions, and the most a day.
  final int points, cap, per;
}

const actSources = {
  ActSource.kills: ActSourceDef('Hạ 30 quái', 2, 20, per: 30),
  ActSource.dungeon: ActSourceDef('Vượt ải / leo tháp', 10, 30),
  ActSource.worldBoss: ActSourceDef('Đánh Boss Thế Giới', 10, 20),
  ActSource.bounty: ActSourceDef('Nộp Truy Nã', 10, 30),
  ActSource.arena: ActSourceDef('Đấu Lôi đài', 5, 25),
  ActSource.alchemy: ActSourceDef('Luyện đan', 5, 15),
  ActSource.daily: ActSourceDef('Nhiệm vụ hằng ngày', 10, 30),
};

/// Daily and weekly chest marks.
const actDailyMarks = [30, 60, 100, 140];
const actWeeklyMarks = [200, 450, 700, 900];

/// What chest [i] holds; [weekly] chests are bigger. Rewards scale with the
/// hero's level when they are claimed.
class ActChest {
  const ActChest({
    this.gold = 0,
    this.potions = 0,
    this.herbs = 0,
    this.gemTier = 0,
    this.coins = 0,
    this.pill = '',
    this.shards = 0,
  });
  final int gold, potions, herbs, gemTier, coins;

  /// Mảnh Hoàng Kim.
  final int shards;
  final String pill;
}

ActChest actChest(int i, int level, {bool weekly = false}) {
  final g = (300 + 60 * level) * (i + 1);
  if (!weekly) {
    return switch (i) {
      0 => ActChest(gold: g, potions: 5),
      1 => ActChest(gold: g, herbs: 4),
      2 => ActChest(gold: g, gemTier: math.min(5, 1 + level ~/ 20)),
      _ => ActChest(gold: g, coins: 50, pill: 'songboi'),
    };
  }
  return switch (i) {
    0 => ActChest(gold: g * 3, herbs: 8, coins: 100),
    1 => ActChest(gold: g * 3, gemTier: math.min(6, 2 + level ~/ 20), coins: 150),
    2 => ActChest(gold: g * 3, pill: 'cuongluc', coins: 200, shards: 5),
    _ => ActChest(gold: g * 4, gemTier: math.min(6, 2 + level ~/ 20), pill: 'taytuy', coins: 300, shards: 10),
  };
}

/// `20261026` key of the Monday that starts the week of [dayKey].
String weekKeyOf(String dayKey) {
  if (dayKey.length != 8) return dayKey;
  final d = DateTime.utc(int.parse(dayKey.substring(0, 4)), int.parse(dayKey.substring(4, 6)),
      int.parse(dayKey.substring(6, 8)));
  final m = d.subtract(Duration(days: d.weekday - 1));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${m.year}${two(m.month)}${two(m.day)}';
}

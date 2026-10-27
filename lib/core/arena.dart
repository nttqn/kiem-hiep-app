import 'dart:math' as math;

import 'content.dart';
import 'hanh.dart';

/// Lôi đài: duels with copies of other players' heroes (from the public
/// leaderboard) or, offline, invented challengers. Wins and losses move the
/// hero's Lôi đài points; every fight pays Uy danh to spend in its shop.
const int arenaOpenLevel = 25;
const int arenaFreeFights = 5;
const int arenaAdFights = 3;
const double arenaTime = 90;

/// HP potions the hero may drink in one duel.
const int arenaPotions = 3;
const int arenaStartPoints = 1000;

// The challenger's make-up, relative to the hero (tuned with a duel
// simulation, test/arena_sim_test.dart): HP in seconds of the hero's own
// damage output; seconds an even challenger's basic hits alone need to
// knock out a hero who drinks nothing; seconds between those hits; and
// their sect skills' damage (times their basic hit and the skill's power)
// and cooldowns (times the skill's own).
const double arenaRivalHp = 115;
const double arenaRivalKill = 16;
const double arenaRivalCd = 0.8;
const double arenaRivalSkillMul = 0.42;
const double arenaRivalSkillCd = 1.3;

/// The duel ground: Hoa Sơn's summit, where swords are judged.
DungeonDef arenaDef(ArenaRival r) => DungeonDef(
      id: 'arena',
      name: 'Lôi đài · ${r.name}',
      mapId: 'hoason',
      level: r.level,
      waves: const [],
      timeLimit: arenaTime,
      rival: r,
    );

/// A challenger, as listed and as fought.
class ArenaRival {
  const ArenaRival({
    required this.name,
    required this.hanh,
    required this.level,
    required this.rebirths,
    required this.power,
    this.female = false,
    this.title = '',
    this.bot = false,
  });

  final String name;
  final Hanh hanh;
  final int level, rebirths, power;
  final bool female;
  final String title;

  /// Invented, not another player's hero.
  final bool bot;
}

/// Points won or lost against a rival [ratio] times the hero's power.
int arenaWinPoints(double ratio) => (20 * ratio.clamp(0.5, 2.0)).round();
int arenaLossPoints(double ratio) => (12 / ratio.clamp(0.5, 2.0)).round();

/// Uy danh for a fight.
const int arenaWinCoins = 30;
const int arenaLossCoins = 10;

class ArenaTier {
  const ArenaTier(this.name, this.min, this.color);
  final String name;
  final int min;
  final int color;
}

const arenaTiers = [
  ArenaTier('Sơ Nhập', 0, 0xFFB8A890),
  ArenaTier('Đồng Nhân', 1100, 0xFFC8844A),
  ArenaTier('Ngân Kiếm', 1250, 0xFFD8E0E8),
  ArenaTier('Kim Kiếm', 1450, 0xFFFFD34A),
  ArenaTier('Bạch Kim', 1700, 0xFF9AE8E0),
  ArenaTier('Tông Sư', 2000, 0xFFC8A0FF),
  ArenaTier('Võ Lâm Chí Tôn', 2400, 0xFFFF6A4A),
];

int arenaTierIndex(int points) {
  var i = 0;
  for (var k = 0; k < arenaTiers.length; k++) {
    if (points >= arenaTiers[k].min) i = k;
  }
  return i;
}

/// Daily salary by tier: Uy danh and gold.
int arenaDailyCoins(int tier) => 40 + tier * 30;
int arenaDailyGold(int tier, int level) => (200 + level * 30) * (tier + 1);

// Mùa giải: two-week seasons counted from Monday 26/10/2026 (Vietnam days).
// A hero who fought in a season is paid by the tier they end it in, and
// every hero's points fall halfway back to the start.
const int arenaSeasonDays = 14;
final DateTime _seasonEpoch = DateTime.utc(2026, 10, 26);

DateTime? _dayOf(String dayKey) {
  if (dayKey.length != 8) return null;
  final y = int.tryParse(dayKey.substring(0, 4));
  final m = int.tryParse(dayKey.substring(4, 6));
  final d = int.tryParse(dayKey.substring(6, 8));
  return y == null || m == null || d == null ? null : DateTime.utc(y, m, d);
}

/// Season number (1-based) of a `yyyymmdd` day.
int arenaSeasonOf(String dayKey) {
  final d = _dayOf(dayKey);
  if (d == null) return 1;
  return math.max(0, d.difference(_seasonEpoch).inDays) ~/ arenaSeasonDays + 1;
}

/// Days left in the season of [dayKey], today included.
int arenaSeasonDaysLeft(String dayKey) {
  final d = _dayOf(dayKey);
  if (d == null) return arenaSeasonDays;
  return arenaSeasonDays - math.max(0, d.difference(_seasonEpoch).inDays) % arenaSeasonDays;
}

/// Points carried into a new season.
int arenaSeasonReset(int points) => arenaStartPoints + math.max(0, points - arenaStartPoints) ~/ 2;

/// One number per season for the leaderboard: newer seasons sort above
/// older ones, so a single-field query lists the current season.
int arenaSeasonScore(int season, int points) => season * 100000 + points.clamp(0, 99999);

class ArenaSeasonReward {
  const ArenaSeasonReward({this.coins = 0, this.gold = 0, this.gemTier = 0, this.shards = 0});
  final int coins, gold, gemTier, shards;
}

/// What ending a season in [tier] pays.
ArenaSeasonReward arenaSeasonReward(int tier, int level) => ArenaSeasonReward(
      coins: const [60, 120, 200, 320, 480, 700, 1000][tier],
      gold: (500 + level * 50) * (tier + 1) * 3,
      gemTier: const [0, 0, 3, 4, 5, 6, 7][tier],
      shards: const [0, 2, 5, 8, 12, 20, 30][tier],
    );

const _surnames = ['Lý', 'Trần', 'Đoàn', 'Mộ Dung', 'Âu Dương', 'Lệnh Hồ', 'Tiêu', 'Hoa', 'Đông Phương', 'Nhạc', 'Vân', 'Bạch'];
const _given = ['Phong', 'Vô Kỵ', 'Thiên Long', 'Tuyết', 'Bất Phàm', 'Kiếm Tâm', 'Lăng Ba', 'Hàn', 'Thanh Y', 'Vô Song', 'Nguyệt', 'Hạo Nhiên'];

/// Three challengers around [power]: weaker, even and stronger, invented
/// from [seed] (stable for a day until the list is refreshed).
List<ArenaRival> botRivals({required int power, required int level, required int rebirths, required int seed}) {
  final r = math.Random(seed);
  return [
    for (final k in const [0.8, 1.0, 1.2])
      ArenaRival(
        name: '${_surnames[r.nextInt(_surnames.length)]} ${_given[r.nextInt(_given.length)]}',
        hanh: Hanh.values[r.nextInt(5)],
        female: r.nextBool(),
        level: (level + (k * 10 - 10).round() + r.nextInt(3) - 1).clamp(1, 99),
        rebirths: rebirths,
        power: (power * k * (0.95 + r.nextDouble() * 0.1)).round(),
        bot: true,
      ),
  ];
}

/// Picks three rivals from [pool] (other players), one each near 0.8x, 1x
/// and 1.2x the hero's power, shuffled by [seed] so a refresh brings new
/// faces; invented ones fill the gaps.
List<ArenaRival> pickRivals(List<ArenaRival> pool, List<ArenaRival> bots, int power, int seed) {
  final left = List<ArenaRival>.of(pool)..shuffle(math.Random(seed));
  final out = <ArenaRival>[];
  for (var i = 0; i < 3; i++) {
    final want = power * const [0.8, 1.0, 1.2][i];
    final k = left.indexWhere((c) => (c.power - want).abs() <= want * 0.1);
    out.add(k < 0 ? bots[i] : left.removeAt(k));
  }
  return out;
}

/// What the Lôi đài shop sells for Uy danh.
enum ArenaWare { mount, gem, herbs, pill }

class ArenaOffer {
  const ArenaOffer(this.kind, this.name, this.price, {this.id = '', this.tier = 0, this.count = 1});
  final ArenaWare kind;
  final String name;
  final int price;

  /// Mount or pill id; gem or herb tier (gem 1-based, herb 0-based); count.
  final String id;
  final int tier;
  final int count;
}

List<ArenaOffer> arenaShop(int level) {
  final gemTier = math.min(5, 2 + level ~/ 25);
  final herb = math.min(4, level ~/ 22);
  return [
    const ArenaOffer(ArenaWare.mount, 'Thú cưỡi Bạch Hổ', 4000, id: 'bachho'),
    ArenaOffer(ArenaWare.gem, 'Ngọc cấp $gemTier (hành ngẫu nhiên)', 60 * gemTier * gemTier, tier: gemTier),
    ArenaOffer(ArenaWare.herbs, '5 dược liệu bậc ${herb + 1}', 80 + herb * 60, tier: herb, count: 5),
    const ArenaOffer(ArenaWare.pill, 'Song Bội Đan', 150, id: 'songboi'),
    const ArenaOffer(ArenaWare.pill, 'Tẩy Tủy Đan', 1200, id: 'taytuy'),
  ];
}

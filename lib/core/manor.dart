import 'dart:math' as math;

import 'alchemy.dart';
import 'sects.dart';

/// Trang viên: the hero's own estate (1.5.0). Linh thảo are sown in its
/// fields and grow in real time, the silkworm house spins Tơ tằm even while
/// the game is closed, and Tơ buys keepsakes that give small lasting
/// bonuses. Gold and Tơ raise the estate, which opens more fields and
/// speeds everything up. Times are server time (GameClock), in ms.
const int manorOpenLevel = 12;
const int manorMaxLevel = 10;
const int manorPlots = 6;

/// Fields open at estate level: 2 at first, all six by level 7.
int manorPlotsAt(int level) => const [2, 3, 4, 4, 5, 5, 6, 6, 6, 6][(level - 1).clamp(0, 9)];

/// A crop: a herb tier sown for a time, yielding a handful of that herb.
class Crop {
  const Crop(this.tier, this.minutes, this.seedGold, this.openLv);
  final int tier;
  final int minutes;
  final int seedGold;

  /// Hero level needed to sow it (any rebirth opens all).
  final int openLv;

  String get name => herbNames[tier];
}

const crops = <Crop>[
  Crop(0, 30, 300, manorOpenLevel),
  Crop(1, 60, 900, 27),
  Crop(2, 120, 2400, 42),
  Crop(3, 240, 6000, 57),
  Crop(4, 480, 15000, 72),
];

/// Herbs a crop gives at estate [level].
int cropYield(int level) => 3 + level ~/ 2;

/// Growth time at estate [level]: 4% quicker a level above the first.
int cropMinutes(Crop c, int level) => (c.minutes * (1 - 0.04 * (level - 1))).round();

/// Tơ tằm spun an hour at estate [level], and how many hours the house
/// holds before it stops (so a week away is not a fortune).
double silkPerHour(int level) => 3 + level * 1.5;
const double silkStoreHours = 12;

/// Gold one Tơ sells for, by hero level.
int silkPrice(int heroLevel) => 20 + heroLevel * 2;

/// Raising the estate from [level] to the next: gold and Tơ.
int manorUpGold(int level) => 4000 * level * level;
int manorUpSilk(int level) => 25 * level;

/// Keepsakes laid out in the hall; each bought once, all count at once.
class Keepsake {
  const Keepsake(this.id, this.name, this.desc, this.silk, this.bonus, this.value, this.openLv);
  final String id, name, desc;
  final int silk;
  final Bonus bonus;
  final double value;

  /// Estate level needed to buy it.
  final int openLv;
}

const keepsakes = <Keepsake>[
  Keepsake('denlong', 'Đèn lồng đỏ', 'Treo trước hiên, soi đường về nhà.', 60, Bonus.regen, 0.002, 1),
  Keepsake('koi', 'Hồ cá chép', 'Chép vượt vũ môn, sinh khí dồi dào.', 120, Bonus.hpPct, 0.015, 2),
  Keepsake('binhphong', 'Bình phong sơn thủy', 'Tranh núi sông che gió độc.', 180, Bonus.defPct, 0.015, 3),
  Keepsake('kylan', 'Tượng Kỳ Lân đá', 'Thần thú giữ cổng, uy phong lẫm liệt.', 260, Bonus.atkPct, 0.015, 4),
  Keepsake('bonsai', 'Tùng bonsai', 'Cây tùng trăm tuổi, tinh thần minh mẫn.', 340, Bonus.crit, 0.006, 5),
  Keepsake('giabinh', 'Giá binh khí', 'Binh khí các phái bày ngay ngắn.', 440, Bonus.critDmg, 0.04, 6),
  Keepsake('chuong', 'Chuông đồng cổ', 'Tiếng chuông tỉnh thức, chiêu thức nhanh nhạy.', 560, Bonus.skillDmg, 0.015, 8),
  Keepsake('luhuong', 'Lư hương trầm', 'Khói trầm thanh tịnh, thân pháp nhẹ nhàng.', 700, Bonus.dodge, 0.006, 10),
];

final Map<String, Keepsake> keepsakeById = {for (final k in keepsakes) k.id: k};

/// A field: empty, or a crop sown at [sownAt] (ms) of [tier].
class Plot {
  Plot({this.tier = -1, this.sownAt = 0, this.readyAt = 0});
  int tier;
  int sownAt, readyAt;
  bool get empty => tier < 0;
  bool ready(int nowMs) => !empty && nowMs >= readyAt;

  /// 0..1 grown.
  double grown(int nowMs) => empty || readyAt <= sownAt ? 0 : ((nowMs - sownAt) / (readyAt - sownAt)).clamp(0, 1);

  List<int> toJson() => [tier, sownAt, readyAt];

  static Plot fromJson(Object? raw) {
    if (raw is! List || raw.length < 3) return Plot();
    try {
      final t = raw[0] as int;
      return Plot(tier: t >= 0 && t < crops.length ? t : -1, sownAt: raw[1] as int, readyAt: raw[2] as int);
    } catch (_) {
      return Plot();
    }
  }
}

class Manor {
  int level = 1;
  final List<Plot> plots = List.generate(manorPlots, (_) => Plot());
  final Set<String> keepsakesOwned = {};

  /// Tơ in hand, and when the silkworm house was last emptied (ms; 0 means
  /// the estate was never visited, so nothing spun yet).
  int silk = 0;
  int silkSince = 0;

  /// Harvests ever, for goals.
  int harvests = 0;

  int get openPlots => manorPlotsAt(level);

  /// Tơ waiting in the house at [nowMs].
  int silkWaiting(int nowMs) {
    if (silkSince <= 0 || nowMs <= silkSince) return 0;
    final hours = math.min(silkStoreHours, (nowMs - silkSince) / 3600000);
    return (hours * silkPerHour(level)).floor();
  }

  /// When the house fills up.
  int silkFullAt() => silkSince + (silkStoreHours * 3600000).round();

  Map<Bonus, double> bonuses() {
    final out = <Bonus, double>{};
    for (final id in keepsakesOwned) {
      final k = keepsakeById[id];
      if (k != null) out[k.bonus] = (out[k.bonus] ?? 0) + k.value;
    }
    return out;
  }

  /// The soonest crop to come ready after [nowMs], if any.
  int? nextReady(int nowMs) {
    int? best;
    for (final p in plots.take(openPlots)) {
      if (!p.empty && p.readyAt > nowMs && (best == null || p.readyAt < best)) best = p.readyAt;
    }
    return best;
  }

  List<Object> toJson() => [level, [for (final p in plots) p.toJson()], keepsakesOwned.toList(), silk, silkSince, harvests];

  static Manor fromJson(Object? raw) {
    final m = Manor();
    if (raw is! List || raw.length < 6) return m;
    try {
      m.level = (raw[0] as int).clamp(1, manorMaxLevel);
      final ps = raw[1] as List;
      for (var i = 0; i < ps.length && i < manorPlots; i++) {
        m.plots[i] = Plot.fromJson(ps[i]);
      }
      for (final id in raw[2] as List) {
        if (keepsakeById.containsKey(id)) m.keepsakesOwned.add(id as String);
      }
      m.silk = math.max(0, raw[3] as int);
      m.silkSince = raw[4] as int;
      m.harvests = math.max(0, raw[5] as int);
    } catch (_) {}
    return m;
  }
}

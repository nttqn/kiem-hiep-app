import 'dart:math' as math;

import 'arena.dart';
import 'content.dart';
import 'hanh.dart';
import 'sects.dart';

/// Sư môn: the sect hands out a chain of [sectDutiesPerDay] errands a day.
/// Each pays cống hiến, which both counts toward the next chức vị and buys
/// from the sect's Tàng Kinh Các. A new chức vị also needs the hero's level
/// and a khảo hạch duel with one of the sect's elders.
const int sectOpenLevel = 10;
const int sectDutiesPerDay = 10;

enum DutyKind { kill, boss, herb, fish, dungeon, traitor }

class SectRank {
  const SectRank(this.name, this.need, this.level, this.trial);
  final String name;

  /// Cống hiến earned in all, hero level (any rebirth counts), and the
  /// examiner's power as a share of the hero's.
  final int need, level;
  final double trial;
}

const sectRanks = <SectRank>[
  SectRank('Đệ tử ký danh', 0, 1, 0),
  SectRank('Đệ tử nhập môn', 200, 15, 0.75),
  SectRank('Đệ tử chân truyền', 700, 30, 0.8),
  SectRank('Hộ pháp', 1600, 45, 0.85),
  SectRank('Trưởng lão', 3200, 60, 0.9),
  SectRank('Phó chưởng môn', 5600, 75, 0.95),
  SectRank('Chưởng môn', 9000, 90, 1.0),
];

int get maxSectRank => sectRanks.length - 1;

/// Bonus of chức vị [r]: life and attack for all, plus the sect's own.
Map<Bonus, double> sectRankBonus(Hanh h, int r) {
  if (r <= 0) return const {};
  final own = switch (h) {
    Hanh.kim => {Bonus.defPct: 0.012 * r},
    Hanh.moc => {Bonus.dotPct: 0.03 * r},
    Hanh.thuy => {Bonus.cdr: 0.008 * r},
    Hanh.hoa => {Bonus.critDmg: 0.03 * r},
    Hanh.tho => {Bonus.hpPct: 0.012 * r},
  };
  final out = {Bonus.hpPct: 0.015 * r, Bonus.atkPct: 0.015 * r};
  own.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
  return out;
}

/// The elder who examines a disciple for chức vị [r] (1..6).
String sectExaminer(Hanh h, int r) {
  const names = {
    Hanh.kim: ['Huyền Khổ', 'Huyền Tịnh', 'Pháp Minh', 'Pháp Không', 'Không Trí', 'Phương Trượng Không Văn'],
    Hanh.moc: ['Lục Xà Cô', 'Hắc Tri Chu', 'Độc Thủ Bà', 'Thanh Xà Lang', 'Vạn Độc Tẩu', 'Môn chủ Đường Mộc'],
    Hanh.thuy: ['Tĩnh Thủy', 'Tĩnh Huyền', 'Diệu Âm', 'Diệu Hải', 'Bích Hà Sư Thái', 'Am chủ Thanh Liên'],
    Hanh.hoa: ['Hỏa Đầu Đà', 'Xích Diện Hổ', 'Liệt Hỏa Tả Sứ', 'Liệt Hỏa Hữu Sứ', 'Phó bang Hỏa Lão', 'Bang chủ Viêm Thiên'],
    Hanh.tho: ['Thanh Phong', 'Minh Nguyệt', 'Huyền Cơ Tử', 'Huyền Chân Tử', 'Thái Hư Đạo Nhân', 'Quán chủ Huyền Thổ'],
  };
  return names[h]![(r - 1).clamp(0, 5)];
}

/// The examiner as a duel challenger.
ArenaRival sectExaminerRival(Hanh h, int r, int level, int rebirths, int power) => ArenaRival(
      name: sectExaminer(h, r),
      hanh: h,
      level: level,
      rebirths: rebirths,
      power: (power * sectRanks[r].trial).round(),
      female: h == Hanh.thuy || (h == Hanh.moc && r.isOdd),
      title: sectRanks[math.min(maxSectRank, r + 1)].name,
      bot: true,
    );

DungeonDef sectTrialDef(ArenaRival r) => DungeonDef(
      id: 'trial',
      name: 'Khảo hạch · ${r.name}',
      mapId: 'hoason',
      level: r.level,
      waves: const [],
      timeLimit: arenaTime,
      rival: r,
      trial: true,
    );

class SectDuty {
  SectDuty({required this.kind, required this.target, required this.map, required this.count, this.progress = 0});

  final DutyKind kind;

  /// Monster id (kill, boss, traitor), or '' when any will do.
  final String target;
  final String map;
  final int count;
  int progress;

  bool get done => progress >= count;

  String get mapName => mapById[map]?.name ?? '';

  /// Key the world tags the traitor with.
  String get eliteKey => 's:$map:$target';

  String get traitorName => 'Phản đồ ${mobById[target]?.name ?? ''}';

  String get goal => switch (kind) {
        DutyKind.kill => 'Hạ $count ${mobById[target]!.name}',
        DutyKind.boss => 'Đánh bại ${mobById[target]!.name}',
        DutyKind.herb => 'Hái $count cây thuốc',
        DutyKind.fish => 'Câu $count con cá',
        DutyKind.dungeon => 'Vượt ải hoặc leo tháp $count lần',
        DutyKind.traitor => 'Thanh lý môn hộ: $traitorName',
      };

  Map<String, dynamic> toJson() => {'k': kind.index, 't': target, 'm': map, 'c': count, 'p': progress};

  static SectDuty? fromJson(Map<String, dynamic> m) {
    final k = m['k'] as int;
    final t = m['t'] as String;
    if (k < 0 || k >= DutyKind.values.length || !mapById.containsKey(m['m'])) return null;
    if (t.isNotEmpty && !mobById.containsKey(t)) return null;
    return SectDuty(
      kind: DutyKind.values[k],
      target: t,
      map: m['m'] as String,
      count: m['c'] as int,
      progress: m['p'] as int? ?? 0,
    );
  }
}

/// Duty number [n] (0-based) of the day for a hero at [level]: on the map
/// they level on. Herbs and fish only once those are open.
SectDuty rollDuty(int level, int n, math.Random rng, {required bool herbs, required bool fish}) {
  final open = maps.where((m) => m.minLv <= level).toList();
  final map = open.last;
  final kinds = <DutyKind>[
    DutyKind.kill, DutyKind.kill, DutyKind.kill,
    if (level >= map.minLv + 2) DutyKind.boss,
    if (herbs) DutyKind.herb,
    if (fish) DutyKind.fish,
    DutyKind.dungeon,
    DutyKind.traitor,
  ];
  // Every fifth errand is a traitor to hunt down.
  final kind = (n + 1) % 5 == 0 ? DutyKind.traitor : kinds[rng.nextInt(kinds.length)];
  final mob = map.mobs[rng.nextInt(map.mobs.length)];
  return SectDuty(
    kind: kind,
    target: switch (kind) {
      DutyKind.kill || DutyKind.traitor => mob,
      DutyKind.boss => map.boss,
      _ => '',
    },
    map: map.id,
    count: switch (kind) {
      DutyKind.kill => 18 + level ~/ 4,
      DutyKind.herb => 3,
      DutyKind.fish => 2,
      _ => 1,
    },
  );
}

/// Cống hiến for duty [n] of the day; every fifth pays double.
int dutyContribution(int n) => (n + 1) % 5 == 0 ? 50 : 25;

/// Share of a level's EXP and the gold per duty.
const double dutyExpShare = 0.04;
int dutyGold(int level) => 80 + level * 25;

/// Gold to swap the current duty for another.
int dutyRerollCost(int level) => 200 + level * 40;

/// Tàng Kinh Các wares bought with cống hiến.
enum SectWare { page, shards, gem, potions }

class SectOffer {
  const SectOffer(this.kind, this.name, this.price, this.rank);
  final SectWare kind;
  final String name;
  final int price;

  /// Chức vị needed to buy it.
  final int rank;
}

const sectOffers = <SectOffer>[
  SectOffer(SectWare.potions, '10 bình máu + 10 bình nội lực', 20, 0),
  SectOffer(SectWare.gem, 'Ngọc ngũ hành theo chức vị', 50, 1),
  SectOffer(SectWare.page, 'Trang bí kíp tự chọn', 80, 2),
  SectOffer(SectWare.shards, '3 Mảnh Hoàng Kim', 90, 4),
];

/// Tier of the gem the sect sells at chức vị [r].
int sectGemTier(int r) => (1 + r).clamp(1, 6);

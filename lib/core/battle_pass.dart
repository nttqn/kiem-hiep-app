import 'dart:math' as math;

import 'gems.dart';
import 'weekly_hunt.dart';

/// Lệnh Bài (1.10.0): a four-week season of 30 tiers climbed with Năng
/// động points, a free reward and a paid one ([skuPass], once a season a
/// hero) at each tier. The paid track ends in the season's outfit.
/// Seasons follow the Săn quái weeks (Monday to Sunday, Vietnam time).

const int passWeeks = 4;
const int passTiers = 30;

/// Năng động points for one tier: 3,000 for all 30, about three quarters of
/// what a player doing every activity each day of a season earns.
const int passTierXp = 100;

/// Mảnh Hoàng Kim instead of a season outfit already owned.
const int passOwnedShards = 20;

/// The Săn quái week season 1 starts: Monday 2026-11-09.
const int passFirstWeek = 3;
const String passOpenText = 'thứ Hai 9/11';

/// The season of [dayKey]; 0 before the first.
int passSeasonOf(String dayKey) {
  final w = huntWeekOf(dayKey);
  return w < passFirstWeek ? 0 : (w - passFirstWeek) ~/ passWeeks + 1;
}

/// Days left in the season of [dayKey], today included.
int passDaysLeft(String dayKey) =>
    huntDaysLeft(dayKey) + 7 * (passWeeks - 1 - (huntWeekOf(dayKey) - passFirstWeek) % passWeeks);

/// The season outfits, worn in turn (the costume ids in costumes.dart).
const passCostumes = ['lb_thanhvan', 'lb_xichdiem', 'lb_hanbang'];

String passCostumeOf(int season) => passCostumes[(season - 1) % passCostumes.length];

/// Titles at the top of each track.
const String passFreeTitle = 'Lệnh Bài Hiệp Khách';
const String passPaidTitle = 'Lệnh Bài Hào Kiệt';

/// One reward of a tier. Gold is a multiple of a level-scaled base; gems
/// come at [gemTier] (0: the hero's usual drop tier).
class PassReward {
  const PassReward({
    this.goldK = 0,
    this.gems = 0,
    this.gemTier = 0,
    this.iron = 0,
    this.stones = 0,
    this.souls = 0,
    this.shards = 0,
    this.soulPills = 0,
    this.pots = 0,
    this.pill = '',
    this.title = '',
    this.costume = false,
  });

  final double goldK;
  final int gems, gemTier, iron, stones, souls, shards, soulPills, pots;
  final String pill, title;

  /// The season's outfit.
  final bool costume;

  int gold(int level, int rebirths) => ((300 + 60 * level + 4000 * rebirths) * goldK).round();

  /// The gem tier for a hero of [level]: the usual drop tier when unset.
  int tierFor(int level) => gemTier > 0 ? gemTier : math.min(maxDropTier, 1 + level ~/ 20);
}

/// The free reward of tier [t] (1-based).
PassReward passFreeReward(int t) {
  if (t == passTiers) return const PassReward(shards: 10, gems: 1, gemTier: 6, title: passFreeTitle);
  if (t % 5 == 0) return PassReward(shards: 2 + t ~/ 5, gems: 1, gemTier: t >= 15 ? 6 : 0);
  return switch (t % 4) {
    0 => const PassReward(goldK: 4),
    1 => const PassReward(pots: 20, goldK: 2),
    2 => const PassReward(gems: 1),
    _ => const PassReward(stones: 3),
  };
}

/// The paid reward of tier [t] (1-based).
PassReward passPaidReward(int t) {
  if (t == passTiers) return const PassReward(costume: true, shards: 30, title: passPaidTitle);
  return switch (t) {
    5 => const PassReward(shards: 15, souls: 1),
    10 => const PassReward(gems: 1, gemTier: maxRewardGemTier, stones: 15),
    15 => const PassReward(shards: 20, pill: 'taytuy'),
    20 => const PassReward(souls: 2, soulPills: 2),
    25 => const PassReward(gems: 2, gemTier: maxRewardGemTier, shards: 20),
    _ => switch (t % 4) {
        0 => const PassReward(stones: 10, goldK: 8),
        1 => const PassReward(iron: 6, shards: 3),
        2 => const PassReward(gems: 2, gemTier: 6),
        _ => const PassReward(stones: 8, pill: 'songboi'),
      },
  };
}

// ------------------------------------------------------------ weekly quests

/// Nhiệm vụ Lệnh Bài: a few goals a week, each worth Lệnh Bài points once
/// done (given at once), so a player who came late or missed days can
/// still reach tier 30, and the strongest have endgame goals.
enum PassQuestKind { kills, dungeon, bounty, worldBoss, arena, maVuc, beast, tamMa }

class PassQuest {
  const PassQuest(this.kind, this.label, this.target, this.xp);
  final PassQuestKind kind;
  final String label;
  final int target, xp;
}

const passQuests = <PassQuest>[
  PassQuest(PassQuestKind.kills, 'Hạ 2.000 quái', 2000, 50),
  PassQuest(PassQuestKind.dungeon, 'Vượt ải, bí cảnh hoặc tháp 15 lần', 15, 50),
  PassQuest(PassQuestKind.bounty, 'Nộp 10 Truy Nã', 10, 50),
  PassQuest(PassQuestKind.worldBoss, 'Đánh Boss Thế Giới 5 lần', 5, 50),
  PassQuest(PassQuestKind.arena, 'Đấu Lôi đài 15 trận', 15, 50),
  PassQuest(PassQuestKind.maVuc, 'Cửu U Ma Vực: vượt tầng 20', 20, 70),
  PassQuest(PassQuestKind.beast, 'Hạ Thượng Cổ Hung Thú ở 2 cấp độ', 2, 70),
  PassQuest(PassQuestKind.tamMa, 'Tâm Ma Ảo Cảnh: vượt 3 tầng mới', 3, 70),
];

// ------------------------------------------------------------ past tier 30

/// Rương thêm: past the last tier, a small chest for every this many points.
const int passExtraXp = 150;
const passExtraReward = PassReward(goldK: 5, stones: 3, shards: 2);

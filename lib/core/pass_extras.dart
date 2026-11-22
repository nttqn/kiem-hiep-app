import 'dart:math' as math;

import 'alchemy.dart';
import 'battle_pass.dart';
import 'costumes.dart';
import 'gems.dart';
import 'hung_thu.dart';
import 'ma_vuc.dart';
import 'tam_ma.dart';
import 'weekly_hunt.dart';
import 'hanh.dart';
import 'hero.dart';
import 'world_boss.dart' show vnDayKey, worldBossOpenLevel;
import 'i18n.dart';

/// Short labels of [r] for a hero of [level] and [rebirths], in [season].
List<String> passLabels(PassReward r, int level, int rebirths, int season) => [
      if (r.costume) tr('Ngoại trang {p0}', {'p0': costumeById[passCostumeOf(season)]?.name ?? ''}),
      if (r.title.isNotEmpty) tr('Danh hiệu « {rTitle} »', {'rTitle': tr(r.title)}),
      if (r.goldK > 0) tr('{p0} lượng', {'p0': _dots(r.gold(level, rebirths))}),
      if (r.gems > 0) tr('{gems} Ngọc {p0}', {'gems': r.gems, 'p0': tr(gemTierNames[r.tierFor(level) - 1])}),
      if (r.stones > 0) tr('{stones} Tinh Thạch', {'stones': r.stones}),
      if (r.shards > 0) tr('{shards} Mảnh Hoàng Kim', {'shards': r.shards}),
      if (r.souls > 0) tr('{souls} Hung Thú Tinh Phách', {'souls': r.souls}),
      if (r.iron > 0) tr('{iron} Thần Thiết', {'iron': r.iron}),
      if (r.soulPills > 0) tr('{soulPills} Linh Phách Đơn', {'soulPills': r.soulPills}),
      if (r.pill.isNotEmpty) pillById[r.pill]?.name ?? r.pill,
      if (r.pots > 0) tr('{pots} bình máu + nội lực', {'pots': r.pots}),
    ];

String _dots(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

extension PassExtras on HeroData {
  /// Moves to the season of [day]. Rewards reached but not taken in the
  /// season that ended are given then, so none are lost. A clock set back
  /// does not go back a season.
  void passRoll(String day) {
    final s = passSeasonOf(day);
    if (s <= passSeason) return;
    if (passSeason > 0) {
      final lines = _passTakeAll(math.Random());
      if (lines.isNotEmpty) {
        notices.add(Notice(tr('Lệnh Bài mùa {passSeason} (chưa nhận): {p0}', {'passSeason': passSeason, 'p0': lines.join(', ')}), color: 0xFFFFD34A, big: true));
      }
    }
    passSeason = s;
    passXp = 0;
    passFree = 0;
    passPaidTaken = 0;
    passExtraTaken = 0;
  }

  // -------------------------------------------------------- weekly quests

  void passQRoll(String day) {
    final w = huntWeekOf(day);
    if (passQWeek == w) return;
    passQWeek = w;
    passQDone = 0;
    passQCounts.clear();
  }

  /// Counts [n] of quest kind [kind] (a [PassQuestKind] name) this week.
  void passCount(String day, String kind, [int n = 1]) {
    passQRoll(day);
    passQCounts[kind] = (passQCounts[kind] ?? 0) + n;
    passCheckQuests(day);
  }

  /// Whether this hero can work on [q] at all.
  bool passQuestOpen(PassQuest q) => switch (q.kind) {
        PassQuestKind.worldBoss => level >= worldBossOpenLevel || rebirths > 0,
        PassQuestKind.arena => arenaOpen,
        PassQuestKind.maVuc => maVucOpen,
        PassQuestKind.beast => beastOpen,
        PassQuestKind.tamMa => tamMaOpen,
        _ => true,
      };

  /// Progress on [q] in the week of [day] (today by default), capped at its
  /// target. Reads only.
  int passQuestProgress(PassQuest q, [String? day]) {
    final w = huntWeekOf(day ?? vnDayKey());
    final v = switch (q.kind) {
      PassQuestKind.maVuc => mvWeek == w ? mvBest : 0,
      PassQuestKind.beast => htWeek == w ? _bits(htKilled) : 0,
      _ => passQWeek == w ? passQCounts[q.kind.name] ?? 0 : 0,
    };
    return math.min(q.target, v);
  }

  /// Done this week (a week not rolled yet counts as none done).
  bool passQuestDone(PassQuest q, [String? day]) =>
      passQWeek == huntWeekOf(day ?? vnDayKey()) && passQDone & (1 << q.kind.index) != 0;

  /// Marks quests newly met and adds their points (only while a season runs).
  void passCheckQuests(String day) {
    passRoll(day);
    if (!passOpen) return;
    passQRoll(day);
    for (final q in passQuests) {
      if (passQuestDone(q, day) || passQuestProgress(q, day) < q.target) continue;
      passQDone |= 1 << q.kind.index;
      passXp += q.xp;
      notices.add(Notice(tr('Nhiệm vụ Lệnh Bài: {qLabel} (+{xp} điểm)', {'qLabel': tr(q.label), 'xp': q.xp}), color: 0xFFFFD34A));
    }
  }

  static int _bits(int v) {
    var n = 0;
    for (var x = v; x > 0; x >>= 1) {
      n += x & 1;
    }
    return n;
  }

  // -------------------------------------------------------- past tier 30

  /// Rương thêm reached and not yet opened.
  int get passExtraReady =>
      math.max(0, (passXp - passTiers * passTierXp) ~/ passExtraXp - passExtraTaken);

  void addPassXp(String day, int n) {
    passRoll(day);
    if (passSeason > 0) passXp += n; // nothing counts before season 1
  }

  /// Whether a season is running (none before [passFirstWeek]).
  bool get passOpen => passSeason > 0;

  /// Tiers reached this season (0..[passTiers]).
  int get passTier => math.min(passTiers, passXp ~/ passTierXp);

  bool get passPaid => passSeason > 0 && passPaidSeason == passSeason;

  bool passTaken(int t, {required bool paid}) => (paid ? passPaidTaken : passFree) & (1 << (t - 1)) != 0;

  bool passCanClaim(int t, {required bool paid}) =>
      t >= 1 && t <= passTier && (!paid || passPaid) && !passTaken(t, paid: paid);

  /// Rewards waiting to be taken (for the town's badge).
  int get passWaiting {
    var n = 0;
    for (var t = 1; t <= passTier; t++) {
      if (passCanClaim(t, paid: false)) n++;
      if (passCanClaim(t, paid: true)) n++;
    }
    return n + passExtraReady;
  }

  /// Takes tier [t] of a track; what came in, or null.
  List<String>? passClaim(int t, {required bool paid, math.Random? rng}) {
    passRoll(vnDayKey());
    if (!passCanClaim(t, paid: paid)) return null;
    return _passTake(t, paid, rng ?? math.Random());
  }

  /// Takes everything reached on both tracks.
  List<String> passClaimAll([math.Random? rng]) {
    passRoll(vnDayKey());
    return _passTakeAll(rng ?? math.Random());
  }

  /// The paid track bought for the season of [day].
  void grantPass(String day) {
    passRoll(day);
    passPaidSeason = passSeason;
  }

  List<String> _passTakeAll(math.Random rng) {
    final lines = <String>[];
    for (var t = 1; t <= passTier; t++) {
      for (final paid in const [false, true]) {
        if (passCanClaim(t, paid: paid)) lines.addAll(_passTake(t, paid, rng));
      }
    }
    final extra = passExtraReady;
    if (extra > 0) lines.addAll(_passTakeExtra(extra, rng));
    return lines;
  }

  /// Opens [n] Rương thêm at once.
  List<String> _passTakeExtra(int n, math.Random rng) {
    passExtraTaken += n;
    final r = passExtraReward;
    return _grantReward(
      PassReward(goldK: r.goldK * n, stones: r.stones * n, shards: r.shards * n),
      rng,
    );
  }

  List<String> _passTake(int t, bool paid, math.Random rng) {
    if (paid) {
      passPaidTaken |= 1 << (t - 1);
    } else {
      passFree |= 1 << (t - 1);
    }
    return _grantReward(paid ? passPaidReward(t) : passFreeReward(t), rng);
  }

  List<String> _grantReward(PassReward r, math.Random rng) {
    final lines = <String>[];
    var shards = r.shards;
    if (r.costume) {
      final c = costumeById[passCostumeOf(passSeason)];
      if (c != null && ownedCostumes.add(c.id)) {
        lines.add(tr('Ngoại trang {cName}', {'cName': tr(c.name)}));
      } else {
        shards += passOwnedShards;
      }
    }
    if (r.title.isNotEmpty && seasonTitles.add(r.title)) lines.add(tr('Danh hiệu « {rTitle} »', {'rTitle': tr(r.title)}));
    final g = r.gold(level, rebirths);
    if (g > 0) {
      gold += g;
      lines.add(tr('+{p0} lượng', {'p0': _dots(g)}));
    }
    for (var i = 0; i < r.gems; i++) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], r.tierFor(level));
      addGem(gem);
      lines.add(gem.name);
    }
    if (r.stones > 0) {
      starStones += r.stones;
      lines.add(tr('+{stones} Tinh Thạch', {'stones': r.stones}));
    }
    if (shards > 0) {
      goldShards += shards;
      lines.add(tr('+{shards} Mảnh Hoàng Kim', {'shards': shards}));
    }
    if (r.souls > 0) {
      beastSouls += r.souls;
      lines.add(tr('+{souls} Hung Thú Tinh Phách', {'souls': r.souls}));
    }
    if (r.iron > 0) {
      divineIron += r.iron;
      lines.add(tr('+{iron} Thần Thiết', {'iron': r.iron}));
    }
    if (r.soulPills > 0) {
      soulPills += r.soulPills;
      lines.add(tr('+{soulPills} Linh Phách Đơn', {'soulPills': r.soulPills}));
    }
    if (r.pill.isNotEmpty) {
      this.pills[r.pill] = (this.pills[r.pill] ?? 0) + 1;
      lines.add(pillById[r.pill]?.name ?? r.pill);
    }
    if (r.pots > 0) {
      hpPots += r.pots;
      mpPots += r.pots;
      lines.add(tr('+{pots} Kim Sang Dược, +{pots} Ngưng Thần Đan', {'pots': r.pots}));
    }
    recompute();
    return lines;
  }
}

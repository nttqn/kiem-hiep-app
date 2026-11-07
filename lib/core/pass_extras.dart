import 'dart:math' as math;

import 'alchemy.dart';
import 'battle_pass.dart';
import 'costumes.dart';
import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'world_boss.dart' show vnDayKey;

/// Short labels of [r] for a hero of [level] and [rebirths], in [season].
List<String> passLabels(PassReward r, int level, int rebirths, int season) => [
      if (r.costume) 'Ngoại trang ${costumeById[passCostumeOf(season)]?.name ?? ''}',
      if (r.title.isNotEmpty) 'Danh hiệu « ${r.title} »',
      if (r.goldK > 0) '${_dots(r.gold(level, rebirths))} lượng',
      if (r.gems > 0) '${r.gems} Ngọc ${gemTierNames[r.tierFor(level) - 1]}',
      if (r.stones > 0) '${r.stones} Tinh Thạch',
      if (r.shards > 0) '${r.shards} Mảnh Hoàng Kim',
      if (r.souls > 0) '${r.souls} Hung Thú Tinh Phách',
      if (r.iron > 0) '${r.iron} Thần Thiết',
      if (r.soulPills > 0) '${r.soulPills} Linh Phách Đơn',
      if (r.pill.isNotEmpty) pillById[r.pill]?.name ?? r.pill,
      if (r.pots > 0) '${r.pots} bình máu + nội lực',
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
        notices.add(Notice('Lệnh Bài mùa $passSeason (chưa nhận): ${lines.join(', ')}', color: 0xFFFFD34A, big: true));
      }
    }
    passSeason = s;
    passXp = 0;
    passFree = 0;
    passPaidTaken = 0;
  }

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
    return n;
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
    return lines;
  }

  List<String> _passTake(int t, bool paid, math.Random rng) {
    if (paid) {
      passPaidTaken |= 1 << (t - 1);
    } else {
      passFree |= 1 << (t - 1);
    }
    final r = paid ? passPaidReward(t) : passFreeReward(t);
    final lines = <String>[];
    var shards = r.shards;
    if (r.costume) {
      final c = costumeById[passCostumeOf(passSeason)];
      if (c != null && ownedCostumes.add(c.id)) {
        lines.add('Ngoại trang ${c.name}');
      } else {
        shards += passOwnedShards;
      }
    }
    if (r.title.isNotEmpty && seasonTitles.add(r.title)) lines.add('Danh hiệu « ${r.title} »');
    final g = r.gold(level, rebirths);
    if (g > 0) {
      gold += g;
      lines.add('+${_dots(g)} lượng');
    }
    for (var i = 0; i < r.gems; i++) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], r.tierFor(level));
      addGem(gem);
      lines.add(gem.name);
    }
    if (r.stones > 0) {
      starStones += r.stones;
      lines.add('+${r.stones} Tinh Thạch');
    }
    if (shards > 0) {
      goldShards += shards;
      lines.add('+$shards Mảnh Hoàng Kim');
    }
    if (r.souls > 0) {
      beastSouls += r.souls;
      lines.add('+${r.souls} Hung Thú Tinh Phách');
    }
    if (r.iron > 0) {
      divineIron += r.iron;
      lines.add('+${r.iron} Thần Thiết');
    }
    if (r.soulPills > 0) {
      soulPills += r.soulPills;
      lines.add('+${r.soulPills} Linh Phách Đơn');
    }
    if (r.pill.isNotEmpty) {
      this.pills[r.pill] = (this.pills[r.pill] ?? 0) + 1;
      lines.add(pillById[r.pill]?.name ?? r.pill);
    }
    if (r.pots > 0) {
      hpPots += r.pots;
      mpPots += r.pots;
      lines.add('+${r.pots} Kim Sang Dược, +${r.pots} Ngưng Thần Đan');
    }
    recompute();
    return lines;
  }
}

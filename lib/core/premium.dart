import 'dart:math' as math;

import 'body_train.dart';
import 'festival.dart';
import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'items.dart';
import 'mount_skins.dart';
import 'newbie.dart';
import 'weekly_hunt.dart';
import 'world_boss.dart' show vnDayKey;

/// Ưu đãi (1.7.0): what a purchase or a chosen rewarded ad gives a hero.
/// Pure rules; the store and the ads live in services/.

// ------------------------------------------------------------ store ids

/// Play Console / App Store Connect product ids.
const String skuMonthCard = 'kh_nguyet_the';
const String skuNoAds = 'kh_bo_quang_cao';
const String skuStarter = 'kh_goi_tan_thu';

/// Gói Thăng Tinh (1.9.0): Tinh Thạch and Tinh Phách, once a week a hero.
const String skuStarPack = 'kh_goi_thang_tinh';
/// Lệnh Bài (1.10.0): the paid track of the running season, for one hero.
const String skuPass = 'kh_lenh_bai';
const Set<String> allSkus = {skuMonthCard, skuNoAds, skuStarter, skuStarPack, skuPass, skuFest};

const int starPackStones = 120;
const int starPackSouls = 3;

// ------------------------------------------------------------ Nguyệt thẻ

const int monthCardDays = 30;

/// One extra Bí cảnh run and Boss Thế Giới run a day while a card runs.
const int monthCardExtraRuns = 1;

/// What a card holder claims each day.
class CardDaily {
  const CardDaily(this.gold, this.gems, this.gemTier, this.iron);
  final int gold, gems, gemTier, iron;
}

CardDaily cardDailyFor(int level, int rebirths) => CardDaily(
      20000 + level * 1000 + rebirths * 20000,
      2,
      math.min(maxDropTier, 1 + level ~/ 20 + (rebirths > 0 ? 1 : 0)),
      rebirths > 0 ? 3 + rebirths : 0,
    );

/// [day] (yyyymmdd) moved by [n] days.
String dayPlus(String day, int n) {
  final d = DateTime.utc(int.parse(day.substring(0, 4)), int.parse(day.substring(4, 6)), int.parse(day.substring(6, 8)))
      .add(Duration(days: n));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}${two(d.month)}${two(d.day)}';
}

// ------------------------------------------------------------ Gói tân thủ

const starterGift = NewbieGift(gold: 100000, hpPots: 50, mpPots: 30, item: Rarity.epic, mount: 'bachma', gems: 3, gemTier: 2);

// ------------------------------------------------------------ ad rewards

/// Rương quảng cáo: five a day, each a little richer, the fifth the best.
const int adChestMax = 5;

class AdChest {
  const AdChest(this.gold, this.gems, this.iron, this.shards);
  final int gold, gems, iron, shards;
}

AdChest adChestFor(int n, int level, int rebirths) {
  final g = (2000 + level * 300 + rebirths * 4000) * (n + 1);
  return AdChest(g, n >= 2 ? 1 : 0, n == adChestMax - 1 && rebirths > 0 ? 2 + rebirths : 0, n == adChestMax - 1 && level >= 60 ? 1 : 0);
}

/// Trang viên: an ad brings every growing crop this much nearer, a few
/// times a day.
const int manorAdMax = 3;
const int manorAdMs = 60 * 60 * 1000;

/// Luyện thể: once a day an ad makes the next training free of gold and
/// half the Thần Thiết.
const int bodyAdMax = 1;

/// Mặc thử: a mount look worn for half an hour for an ad.
const int skinTrialMs = 30 * 60 * 1000;

extension Premium on HeroData {
  // -------------------------------------------------------- card

  bool cardActive(String today) => cardUntil.isNotEmpty && cardUntil.compareTo(today) >= 0;

  /// Days left including today.
  int cardDaysLeft(String today) {
    if (!cardActive(today)) return 0;
    var n = 0;
    var d = today;
    while (d.compareTo(cardUntil) <= 0 && n < 400) {
      n++;
      d = dayPlus(d, 1);
    }
    return n;
  }

  /// A bought card: 30 days from today, or 30 more after a running one.
  void addMonthCard(String today) => addCardDays(today, monthCardDays);

  /// [days] more of Nguyệt thẻ (a purchase, or a mail making good a lost one).
  void addCardDays(String today, int days) {
    cardUntil = dayPlus(cardActive(today) ? cardUntil : dayPlus(today, -1), days);
  }

  /// Keeps what was paid for when this hero is replaced by [other], a copy
  /// of the same hero from another phone: the later Nguyệt thẻ end, and the
  /// starter pack once bought (1.8.0).
  void mergePaid(HeroData other) {
    if (other.cardUntil.compareTo(cardUntil) > 0) cardUntil = other.cardUntil;
    starterBought = starterBought || other.starterBought;
    if (other.passPaidSeason > passPaidSeason) passPaidSeason = other.passPaidSeason;
  }

  /// Gives back a purchase kept in the cloud ledger ([PaidGrant]) that this
  /// save lost; the line to show, or null when nothing was missing.
  String? reapplyGrant(PaidGrant g) {
    switch (g.sku) {
      case skuMonthCard:
        if (g.until.isEmpty || g.until.compareTo(cardUntil) <= 0) return null;
        cardUntil = g.until;
        return 'Khôi phục Nguyệt thẻ đến ${g.until.substring(6, 8)}/${g.until.substring(4, 6)}';
      case skuPass:
        final s = int.tryParse(g.until) ?? 0;
        if (s <= 0 || s <= passPaidSeason) return null;
        passPaidSeason = s;
        return 'Khôi phục Lệnh Bài Hào Kiệt mùa $s';
      case skuFest:
        if (festPack) return null;
        return 'Khôi phục Gói lễ hội: ${grantFestPack().join(', ')}';
      case skuStarter:
        if (starterBought) return null;
        return 'Khôi phục Gói tân thủ: ${grantStarter().join(', ')}';
    }
    return null;
  }

  // -------------------------------------------------------- Gói Thăng Tinh

  /// Bought this hero's Gói Thăng Tinh this week (Monday to Sunday).
  bool get starPackThisWeek => stPackWeek == huntWeekOf(vnDayKey());

  /// Gives the pack (a purchase always delivers, even past the weekly
  /// limit the shop shows).
  List<String> grantStarPack() {
    starStones += starPackStones;
    beastSouls += starPackSouls;
    stPackWeek = huntWeekOf(vnDayKey());
    return ['+$starPackStones Tinh Thạch', '+$starPackSouls Hung Thú Tinh Phách'];
  }

  bool canClaimCard(String today) => cardActive(today) && cardClaimDay != today;

  List<String> claimCard(String today) {
    if (!canClaimCard(today)) return const [];
    cardClaimDay = today;
    final r = cardDailyFor(level, rebirths);
    gold += r.gold;
    final rng = math.Random(today.hashCode ^ name.hashCode);
    final lines = ['+${r.gold} lượng'];
    for (var i = 0; i < r.gems; i++) {
      final g = Gem(Hanh.values[rng.nextInt(5)], r.gemTier);
      addGem(g);
      lines.add(g.name);
    }
    if (r.iron > 0) {
      divineIron += r.iron;
      lines.add('+${r.iron} Thần Thiết');
    }
    return lines;
  }

  // -------------------------------------------------------- starter

  List<String> grantStarter() {
    starterBought = true;
    return grantGift(starterGift, math.Random());
  }

  // -------------------------------------------------------- ad chest

  void _rollAdDay(String today) {
    if (adDay == today) return;
    adDay = today;
    adChestN = 0;
    manorAdN = 0;
    bodyAdN = 0;
  }

  int adChestsLeft(String today) {
    _rollAdDay(today);
    return adChestMax - adChestN;
  }

  List<String> openAdChest(String today) {
    if (adChestsLeft(today) <= 0) return const [];
    final c = adChestFor(adChestN, level, rebirths);
    adChestN++;
    gold += c.gold;
    final lines = ['+${c.gold} lượng'];
    final rng = math.Random();
    for (var i = 0; i < c.gems; i++) {
      final g = Gem(Hanh.values[rng.nextInt(5)], math.min(maxDropTier, 1 + level ~/ 20));
      addGem(g);
      lines.add(g.name);
    }
    if (c.iron > 0) {
      divineIron += c.iron;
      lines.add('+${c.iron} Thần Thiết');
    }
    if (c.shards > 0) {
      goldShards += c.shards;
      lines.add('+${c.shards} mảnh Hoàng Kim');
    }
    return lines;
  }

  // -------------------------------------------------------- manor

  int manorAdsLeft(String today) {
    _rollAdDay(today);
    return manorAdMax - manorAdN;
  }

  bool manorHasGrowing(int nowMs) => manor.plots.any((p) => !p.empty && p.readyAt > nowMs);

  /// Brings every growing crop [manorAdMs] nearer.
  bool hurryManor(String today, int nowMs) {
    if (manorAdsLeft(today) <= 0 || !manorHasGrowing(nowMs)) return false;
    manorAdN++;
    for (final p in manor.plots) {
      if (!p.empty && p.readyAt > nowMs) {
        p.readyAt = math.max(nowMs, p.readyAt - manorAdMs);
        p.sownAt = math.min(p.sownAt, p.readyAt - 1);
      }
    }
    return true;
  }

  // -------------------------------------------------------- body

  int bodyAdsLeft(String today) {
    _rollAdDay(today);
    return bodyAdMax - bodyAdN;
  }

  /// Takes the ad's discount for the next training.
  bool takeBodyAd(String today) {
    if (bodyAdsLeft(today) <= 0 || bodyBoost) return false;
    bodyAdN++;
    bodyBoost = true;
    return true;
  }

  /// Iron and gold the next training of part [i] costs, with any ad boost.
  (int iron, int gold) bodyCost(int i) {
    final lv = bodyLv[i];
    return bodyBoost ? ((bodyIronCost(lv) + 1) ~/ 2, 0) : (bodyIronCost(lv), bodyGoldCost(lv));
  }

  // -------------------------------------------------------- skin trial

  bool trySkin(MountSkin s, int nowMs) {
    if (ownsSkin(s.id) || !ownsMount(s.mount)) return false;
    trialSkin = s.id;
    trialUntil = nowMs + skinTrialMs;
    return true;
  }

  /// The look on trial right now, if any.
  MountSkin? trialAt(int nowMs) => trialUntil > nowMs ? skinById[trialSkin] : null;
}

/// A purchase written to the player's cloud (`users/{uid}/grants/{id}`)
/// when it is given, so a hero whose save is later overwritten by an older
/// copy (two phones playing the same hero) gets it back on the next sync.
class PaidGrant {
  const PaidGrant({required this.sku, required this.seed, required this.slot, this.until = ''});
  final String sku;

  /// The hero it went to ([HeroData.seed], and its slot for heroes with no seed).
  final int seed, slot;

  /// Nguyệt thẻ's last day right after the purchase.
  final String until;

  Map<String, Object> toJson() => {'sku': sku, 'seed': seed, 'slot': slot, 'until': until};

  static PaidGrant? fromJson(Map<String, dynamic> m) {
    final sku = m['sku'], seed = m['seed'], slot = m['slot'];
    if (sku is! String || seed is! num || slot is! num) return null;
    final u = m['until'];
    return PaidGrant(sku: sku, seed: seed.toInt(), slot: slot.toInt(), until: u is String ? u : '');
  }

  bool fits(HeroData h, int heroSlot) => seed != 0 ? h.seed == seed : heroSlot == slot;
}

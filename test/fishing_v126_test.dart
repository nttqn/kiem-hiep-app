import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/fishing.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/weekly_hunt.dart';

HeroData hero({int level = 60}) {
  final h = HeroData(name: 'Ngư', hanh: Hanh.thuy);
  h.level = level;
  return h;
}

void main() {
  // Mondays of weeks 5 and 6 (from 26/10/2026).
  const week5 = '20261123', week5Sun = '20261129', week6 = '20261130';

  test('every field map has a pond of four, one of each rarity', () {
    expect(fishes.length, 52);
    for (final m in maps) {
      final pond = fishOfMap(m.id);
      expect(pond.length, 4, reason: m.id);
      expect(pond.map((f) => f.rarity).toSet(), FishRarity.values.toSet(), reason: m.id);
    }
    expect(fishes.map((f) => f.id).toSet().length, fishes.length);
  });

  test('the later regions price their fish by level, the first nine as before', () {
    expect(fishById['diecvang']!.tier, 0);
    expect(fishById['hoasonthan']!.tier, 8);
    expect(fishById['casuoi']!.tier, 3);
    expect(fishById['conlonthan']!.tier, 8);
    expect(fishById['lyngu']!.price, 20 * 30);
  });

  test('weights run from about half to twice the usual, light ones most often', () {
    final rng = math.Random(1);
    final f = fishById['lyngu']!;
    final avg = fishAvgWeight(f) * 10;
    final ws = [for (var i = 0; i < 4000; i++) rollFishWeight(f, rng)];
    expect(ws.reduce(math.min), greaterThanOrEqualTo((avg * 0.55).floor()));
    expect(ws.reduce(math.max), lessThanOrEqualTo((avg * 2.0).ceil()));
    final below = ws.where((w) => w < avg).length;
    expect(below, greaterThan(ws.length ~/ 2));
    expect(fishWeightText(124), contains('12,4'));
  });

  test('a catch brings points, Ngư tệ and keeps the heaviest as the record', () {
    final h = hero();
    final rng = math.Random(7);
    final f = fishById['chepco']!;
    h.catchFish(f, rng, day: week5);
    expect(h.fishPts, h.lastFishPts);
    expect(h.lastFishPts, fishPoints(f, h.lastFishWeight));
    expect(h.fishCoins, fishCoinsOf[f.rarity.index]);
    expect(h.lastFishRecord, isTrue);
    expect(h.fishBest[f.id], h.lastFishWeight);
    final best = h.fishBest[f.id]!;
    for (var i = 0; i < 50; i++) {
      h.catchFish(f, rng, day: week5);
      expect(h.fishBest[f.id], greaterThanOrEqualTo(best));
      if (h.lastFishRecord) expect(h.fishBest[f.id], h.lastFishWeight);
    }
    expect(h.fishBoardValue, fishScore(huntWeekOf(week5), h.fishPts));
  });

  test('a new week files the old points for their rank and pays them once', () {
    final h = hero();
    final rng = math.Random(3);
    h.catchFish(fishById['diecvang']!, rng, day: week5);
    h.catchFish(fishById['diecvang']!, rng, day: week5Sun);
    final pts = h.fishPts;
    h.fishRollWeek(week6);
    expect(h.fishRankDue, isTrue);
    expect(h.fishLastScore, fishScore(huntWeekOf(week5), pts));
    expect(h.fishPts, 0);
    expect(h.fishBoardValue, 0);
    final iron = h.divineIron, coins = h.fishCoins;
    final lines = h.payFishRank(1);
    expect(lines, isNotEmpty);
    expect(h.divineIron, iron + 8);
    expect(h.fishCoins, coins + 300);
    expect(h.seasonTitles, contains('Ngư Vương'));
    expect(h.payFishRank(1), isEmpty);
    // Off the top 50: nothing, but settled.
    h.fishRankDue = true;
    expect(h.payFishRank(51), isEmpty);
    expect(h.fishRankDue, isFalse);
  });

  test('Ngư phủ sells within Ngư tệ and its weekly limits', () {
    final h = hero();
    final rng = math.Random(5);
    final shop = fishShop(h.level);
    final iron = shop.firstWhere((o) => o.kind == FishWare.iron);
    expect(h.fishBuy(iron, week5, rng), isNull);
    h.fishCoins = 10000;
    for (var i = 0; i < iron.perWeek; i++) {
      expect(h.fishBuy(iron, week5, rng), isNotNull);
    }
    expect(h.fishBuy(iron, week5, rng), isNull);
    expect(h.divineIron, iron.perWeek);
    expect(h.fishCoins, 10000 - iron.price * iron.perWeek);
    // A new week, new stock.
    expect(h.fishOfferLeft(iron, week6), iron.perWeek);
    expect(h.fishBuy(iron, week6, rng), isNotNull);
    // A bí kíp page needs the bí kíp level.
    final low = hero(level: 20)..fishCoins = 1000;
    final page = fishShop(20).firstWhere((o) => o.kind == FishWare.page);
    expect(low.fishBuy(page, week5, rng), isNull);
    expect(low.fishCoins, 1000);
  });

  test('bought baits are used after the day\'s own and kept across days', () {
    final h = hero()..fishCoins = 100;
    final bait = fishShop(h.level).firstWhere((o) => o.kind == FishWare.bait);
    expect(h.fishBuy(bait, week5, math.Random(1)), isNotNull);
    expect(h.fishExtraBait, fishShopBait);
    for (var i = 0; i < fishBaitPerDay; i++) {
      expect(h.fishCast(week5), isTrue);
    }
    expect(h.fishExtraBait, fishShopBait);
    expect(h.fishBaitLeft, fishShopBait);
    expect(h.fishCast(week5), isTrue);
    expect(h.fishExtraBait, fishShopBait - 1);
    expect(h.fishBaitLeft, fishShopBait - 1);
    // Next day: the day's own first again, the bought ones still there.
    expect(h.fishCast('20261124'), isTrue);
    expect(h.fishExtraBait, fishShopBait - 1);
  });

  test('a finished page pays Ngư tệ; an empty page from before 1.26 opens again', () {
    final h = hero();
    for (final f in fishOfMap('ngoaithanh')) {
      h.catchFish(f, math.Random(2), day: week5);
    }
    final coins = h.fishCoins;
    expect(h.fishBookClaim('ngoaithanh'), greaterThan(0));
    expect(h.fishCoins, coins + fishBookCoins);
    // An old save claimed Đông Hải's page while it had no fish.
    final json = h.toJson();
    ((json['fish'] as List)[4] as List).add('donghai');
    final back = HeroData.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
    expect(back.fishBooks, contains('ngoaithanh'));
    expect(back.fishBooks, isNot(contains('donghai')));
  });

  test('the 1.26 fishing state survives a save', () {
    final h = hero();
    final rng = math.Random(9);
    for (var i = 0; i < 5; i++) {
      h.catchFish(fishById['hoibang']!, rng, day: week5);
    }
    h.fishExtraBait = 7;
    h.fishBought['iron'] = 2;
    h.fishBoughtWeek = huntWeekOf(week5);
    h.fishLastScore = fishScore(4, 77);
    h.fishRankDue = true;
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.fishBest, h.fishBest);
    expect(back.fishCoins, h.fishCoins);
    expect(back.fishWeek, h.fishWeek);
    expect(back.fishPts, h.fishPts);
    expect(back.fishLastScore, h.fishLastScore);
    expect(back.fishRankDue, isTrue);
    expect(back.fishBought, {'iron': 2});
    expect(back.fishBoughtWeek, h.fishBoughtWeek);
    expect(back.fishExtraBait, 7);
    // A save from before 1.26 has none of it.
    final old = h.toJson()..remove('fish2');
    final o = HeroData.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
    expect(o.fishCoins, 0);
    expect(o.fishBest, isEmpty);
  });
}

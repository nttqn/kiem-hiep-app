import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/costumes.dart';
import 'package:kiem_hiep/core/fishing.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/ui/theme.dart';

/// 1.26.0 Câu cá phần 2: rods, special baits, feeding hours, titles and
/// the two fishing outfits; every button colour has a painted look.
HeroData hero({int level = 60}) => HeroData(name: 'Ngư', hanh: Hanh.thuy)..level = level;

void main() {
  test('a rod level costs gold, Ngư tệ and a hero level, and helps', () {
    final h = hero(level: 20)
      ..gold = 100000000
      ..fishCoins = 10000;
    expect(h.fishRodUp(), isTrue);
    expect(h.fishRod, 1);
    expect(h.gold, 100000000 - fishRods[1].gold);
    expect(h.fishCoins, 10000 - fishRods[1].coins);
    // Cần Mây Tía needs level 25.
    expect(h.fishRodBlock(), 'Cần cấp 25');
    expect(h.fishRodUp(), isFalse);
    h.level = 99;
    while (h.fishRodUp()) {}
    expect(h.fishRod, fishRodMax);
    expect(h.fishRodNext, isNull);
    // A rebirth counts as level 99.
    final r = hero(level: 5)
      ..rebirths = 1
      ..gold = 100000000
      ..fishCoins = 10000;
    for (var i = 0; i < fishRodMax; i++) {
      expect(r.fishRodUp(), isTrue);
    }
    // Wider mark, slower needle, never past 45% of the bar.
    for (var k = 0; k < 4; k++) {
      expect(rodZone(k, fishRodMax), greaterThan(fishZone[k]));
      expect(rodZone(k, fishRodMax), lessThanOrEqualTo(0.45));
      expect(rodSpeed(k, fishRodMax), lessThan(fishSpeed[k]));
    }
    expect(rodZone(0, 0), fishZone[0]);
  });

  test('a special bait shifts what bites and is spent one a cast', () {
    double legendShare(String bait, {bool feed = false}) {
      final rng = math.Random(3);
      var n = 0;
      for (var i = 0; i < 20000; i++) {
        if (rollFishWith('vanvu', rng, bait: bait, feed: feed).rarity == FishRarity.legend) n++;
      }
      return n / 20000;
    }

    final plain = legendShare('');
    expect(plain, closeTo(0.02, 0.006));
    expect(legendShare('than'), greaterThan(plain * 5));
    expect(legendShare('linh'), greaterThan(plain * 1.8));
    expect(legendShare('', feed: true), greaterThan(plain * 1.3));

    final h = hero()..gold = 1000000;
    expect(h.fishBuyShrimp(), isTrue);
    expect(h.fishLures['tom'], fishShrimpPack);
    h.fishChooseLure('than'); // none in stock
    expect(h.fishLure, '');
    h.fishChooseLure('tom');
    for (var i = 0; i < fishShrimpPack; i++) {
      expect(h.fishSpendLure(), 'tom');
    }
    expect(h.fishLures.containsKey('tom'), isFalse);
    // Running out goes back to plain.
    expect(h.fishSpendLure(), '');
    expect(h.fishLure, '');
  });

  test('Ngư phủ sells Linh Mồi and Thần Mồi into the bait stock', () {
    final h = hero()..fishCoins = 1000;
    final linh = fishShop(h.level).firstWhere((o) => o.id == 'linh');
    final than = fishShop(h.level).firstWhere((o) => o.id == 'than');
    h.fishBuy(linh, '20261127', math.Random(1));
    h.fishBuy(than, '20261127', math.Random(1));
    expect(h.fishLures, {'linh': 3, 'than': 1});
    expect(h.fishCoins, 1000 - linh.price - than.price);
  });

  test('feeding windows by Vietnam hour, with the wait to the next', () {
    DateTime at(int hh, [int mm = 0]) => DateTime.utc(2026, 11, 27, hh, mm);
    expect(fishFeedAt(at(5, 59)), -1);
    expect(fishFeedAt(at(6)), 0);
    expect(fishFeedAt(at(7, 59)), 0);
    expect(fishFeedAt(at(8)), -1);
    expect(fishFeedAt(at(18)), 1);
    expect(fishFeedAt(at(22, 30)), 2);
    expect(fishFeedAt(at(23)), -1);
    expect(fishFeedWait(at(7, 30)), const Duration(minutes: 30));
    expect(fishFeedWait(at(12)), const Duration(hours: 5));
    expect(fishFeedWait(at(23, 30)), const Duration(hours: 6, minutes: 30));
  });

  test('feeding hours double Ngư tệ and a better rod brings heavier fish', () {
    final f = fishById['bachlong']!;
    final a = hero(), b = hero();
    a.catchFish(f, math.Random(5), day: '20261127');
    b.fishRod = fishRodMax;
    b.catchFish(f, math.Random(5), day: '20261127', feed: true);
    expect(b.fishCoins, a.fishCoins * fishFeedCoinMul);
    expect(b.lastFishWeight, greaterThan(a.lastFishWeight * 1.3));
  });

  test('fishing titles and the legend outfit', () {
    final h = hero();
    final rng = math.Random(2);
    for (final f in fishLegends) {
      h.catchFish(f, rng, day: '20261127');
    }
    expect(h.seasonTitles, contains(fishTitleLegend));
    expect(h.ownedCostumes, contains(fishCostumeLegend));
    expect(h.costumeGoalMet(costumeById[fishCostumeLegend]!), isTrue);
    expect(h.seasonTitles, isNot(contains(fishTitleCatch)));
    for (var i = h.fishTotal; i < fishTitleCatches; i++) {
      h.catchFish(fishById['diecvang']!, rng, day: '20261127');
    }
    expect(h.seasonTitles, contains(fishTitleCatch));
    for (final f in fishes) {
      h.fishCaught[f.id] = 1;
    }
    for (final m in pondMaps) {
      h.fishBookClaim(m.id);
    }
    expect(h.seasonTitles, contains(fishTitleBook));
    // The shop outfit costs Ngư tệ, once.
    h.fishCoins = fishCostumePrice;
    expect(h.costumeGoalMet(costumeById[fishCostumeShop]!), isFalse);
    expect(h.fishBuyCostume(), isTrue);
    expect(h.ownedCostumes, contains(fishCostumeShop));
    expect(h.fishBuyCostume(), isFalse);
  });

  test('rod and baits survive a save; an old save has none', () {
    final h = hero()
      ..fishRod = 3
      ..fishLures.addAll({'tom': 4, 'than': 1})
      ..fishLure = 'than';
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.fishRod, 3);
    expect(back.fishLures, {'tom': 4, 'than': 1});
    expect(back.fishLure, 'than');
    final o = HeroData.fromJson(jsonDecode(jsonEncode(hero().toJson())) as Map<String, dynamic>);
    expect(o.fishRod, 0);
    expect(o.fishLures, isEmpty);
    expect(o.fishLure, '');
  });

  test('every button colour family has its painted look', () {
    expect(paintedButtonFor(seal), uiButtonArt);
    expect(paintedButtonFor(jade), uiButtonJadeArt);
    expect(paintedButtonFor(lacquer), uiButtonDarkArt);
    expect(paintedButtonFor(const Color(0xFF8A5A10)), uiButtonAmberArt);
    expect(paintedButtonFor(goldLight), uiButtonAmberArt);
    expect(paintedButtonFor(cream), uiButtonAmberArt);
    expect(paintedButtonFor(const Color(0xFF2E6A8A)), uiButtonBlueArt);
    expect(paintedButtonFor(const Color(0xFF5A3A7A)), uiButtonPurpleArt);
    expect(paintedButtonFor(const Color(0xFF8A2A1A)), uiButtonArt);
    expect(paintedButtonFor(const Color(0xFF5A4A3A)), uiButtonDarkArt);
    expect(paintedButtonFor(const Color(0xFF2E8A7A)), uiButtonJadeArt);
  });
}

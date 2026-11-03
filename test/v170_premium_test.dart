import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/body_train.dart';
import 'package:kiem_hiep/core/clock.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/manor.dart';
import 'package:kiem_hiep/core/mount_skins.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/nightmare.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/core/realm.dart';
import 'package:kiem_hiep/core/world_boss.dart';
import 'package:kiem_hiep/services/ads.dart';

HeroData _hero() => HeroData(name: 'P', hanh: Hanh.hoa)
  ..level = 60
  ..rebirths = 2;

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  test('dayPlus crosses months and years', () {
    expect(dayPlus('20261130', 1), '20261201');
    expect(dayPlus('20261231', 30), '20270130');
    expect(dayPlus('20261103', -1), '20261102');
  });

  group('Nguyệt thẻ', () {
    test('30 days from today, extended by a second card, claimed once a day', () {
      final h = _hero();
      const d = '20261103';
      expect(h.cardActive(d), isFalse);
      h.addMonthCard(d);
      expect(h.cardDaysLeft(d), 30);
      expect(h.cardActive(dayPlus(d, 29)), isTrue);
      expect(h.cardActive(dayPlus(d, 30)), isFalse);
      h.addMonthCard(d);
      expect(h.cardDaysLeft(d), 60);
      final gold = h.gold;
      final lines = h.claimCard(d);
      expect(lines, isNotEmpty);
      expect(h.gold, gold + cardDailyFor(60, 2).gold);
      expect(h.canClaimCard(d), isFalse);
      expect(h.claimCard(d), isEmpty);
      expect(h.canClaimCard(dayPlus(d, 1)), isTrue);
    });

    test('a running card adds a Bí cảnh and a Boss Thế Giới run', () {
      final h = _hero();
      final today = vnDayKey();
      h.realmRollDay(today);
      h.wbRollDay(today);
      final realm = h.realmRunsLeft, wb = h.wbRunsLeft;
      expect(realm, realmFreeRuns);
      h.addMonthCard(today);
      expect(h.realmRunsLeft, realm + monthCardExtraRuns);
      expect(h.wbRunsLeft, wb + monthCardExtraRuns);
      expect(worldBossFreeTries, greaterThan(0));
    });
  });

  test('Gói tân thủ gives Bạch Mã, gear and gold once', () {
    final h = _hero();
    final gold = h.gold, bag = h.bag.length;
    h.grantStarter();
    expect(h.starterBought, isTrue);
    expect(h.ownsMount('bachma'), isTrue);
    expect(h.gold, gold + starterGift.gold);
    expect(h.bag.length, bag + 1);
  });

  group('quảng cáo thưởng', () {
    test('five ad chests a day, each richer; a new day refills them', () {
      final h = _hero();
      const d = '20261103';
      var last = 0;
      for (var i = 0; i < adChestMax; i++) {
        final g = h.gold;
        expect(h.openAdChest(d), isNotEmpty);
        expect(h.gold - g, greaterThan(last));
        last = h.gold - g;
      }
      expect(h.adChestsLeft(d), 0);
      expect(h.openAdChest(d), isEmpty);
      expect(h.adChestsLeft('20261104'), adChestMax);
    });

    test('Trang viên: an ad brings growing crops an hour nearer, three times a day', () {
      final h = _hero();
      const now = 1000000000;
      h.manor.plots[0] = Plot(tier: 0, sownAt: now, readyAt: now + 3 * manorAdMs);
      h.manor.plots[1] = Plot(tier: 0, sownAt: now, readyAt: now + manorAdMs ~/ 2);
      expect(h.hurryManor('20261103', now), isTrue);
      expect(h.manor.plots[0].readyAt, now + 2 * manorAdMs);
      expect(h.manor.plots[1].readyAt, now);
      h.hurryManor('20261103', now);
      expect(h.manorHasGrowing(now), isTrue);
      expect(h.hurryManor('20261103', now), isTrue);
      expect(h.manorAdsLeft('20261103'), 0);
      expect(h.hurryManor('20261103', now - 1), isFalse);
    });

    test('Luyện thể: the ad makes the next training free of gold and half the iron', () {
      final h = _hero()
        ..rebirths = 3
        ..divineIron = 100
        ..gold = 0;
      expect(h.trainBody(0), isFalse, reason: 'no gold');
      expect(h.takeBodyAd('20261103'), isTrue);
      expect(h.takeBodyAd('20261103'), isFalse);
      expect(h.bodyCost(0).$2, 0);
      expect(h.trainBody(0), isTrue);
      expect(h.divineIron, 100 - 1);
      expect(h.bodyBoost, isFalse);
    });

    test('a mount look on trial shows for half an hour', () {
      final h = _hero()
        ..mountLevels['phikiem'] = 1
        ..activeMount = 'phikiem'
        ..riding = true;
      final s = skinById['phikiem_tu']!;
      final now = GameClock.nowMs();
      expect(h.trySkin(s, now), isTrue);
      expect(h.ridingMount!.c2, s.c2);
      h.trialUntil = now - 1;
      expect(h.ridingMount!.c2, mountById['phikiem']!.c2);
    });

    test('Ác Mộng: two more paid clears a day for ads', () {
      final h = _hero();
      h.nmRollDay('20261103');
      expect(h.nmRunsLeft, nightmarePaidRuns);
      expect(h.nmAddAdRun('20261103'), isTrue);
      expect(h.nmAddAdRun('20261103'), isTrue);
      expect(h.nmAddAdRun('20261103'), isFalse);
      expect(h.nmRunsLeft, nightmarePaidRuns + nightmareAdRuns);
      expect(_roundTrip(h).nmAds, nightmareAdRuns);
    });
  });

  test('all of it survives a save', () {
    final h = _hero()
      ..starterBought = true
      ..bodyBoost = true
      ..trialSkin = 'phikiem_tu'
      ..trialUntil = 123;
    h.addMonthCard('20261103');
    h.claimCard('20261103');
    h.openAdChest('20261103');
    final b = _roundTrip(h);
    expect(b.cardUntil, h.cardUntil);
    expect(b.cardClaimDay, '20261103');
    expect(b.starterBought, isTrue);
    expect(b.adChestN, 1);
    expect(b.bodyBoost, isTrue);
    expect(b.trialSkin, 'phikiem_tu');
    expect(b.trialUntil, 123);
  });

  test('ad-free: a rewarded ad is granted without showing anything', () async {
    final ads = AdsService.instance;
    expect(await ads.showRewarded(), isFalse, reason: 'no ad loaded in tests');
    ads.setAdFree(true, save: false);
    expect(ads.rewardedReady.value, isTrue);
    expect(await ads.showRewarded(), isTrue);
    ads.setAdFree(false, save: false);
  });
}

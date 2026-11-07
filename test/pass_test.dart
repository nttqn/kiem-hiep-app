import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/activity.dart';
import 'package:kiem_hiep/core/battle_pass.dart';
import 'package:kiem_hiep/core/costumes.dart';
import 'package:kiem_hiep/core/guide.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/newbie.dart';
import 'package:kiem_hiep/core/pass_extras.dart';
import 'package:kiem_hiep/core/premium.dart';

HeroData _hero() => HeroData(name: 'P', hanh: Hanh.thuy)..level = 80;

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

const _day = '20261130'; // season 1, its third week
const _next = '20261214'; // season 2

void main() {
  test('seasons are four Săn quái weeks', () {
    expect(passSeasonOf('20261026'), 0, reason: 'not open yet');
    expect(passSeasonOf('20261115'), 0);
    expect(passSeasonOf('20261116'), 1);
    expect(passSeasonOf('20261213'), 1);
    expect(passSeasonOf(_next), 2);
    expect(passDaysLeft('20261116'), 28);
    expect(passDaysLeft('20261213'), 1);
    final early = _hero()..addPassXp('20261110', 50);
    expect((early.passSeason, early.passXp), (0, 0), reason: 'nothing counts before season 1');
    for (final id in passCostumes) {
      expect(costumeById[id]?.source, CostumeSource.pass, reason: id);
    }
  });

  test('every tier pays something on both tracks', () {
    for (var t = 1; t <= passTiers; t++) {
      expect(passLabels(passFreeReward(t), 80, 0, 2), isNotEmpty, reason: 'free $t');
      expect(passLabels(passPaidReward(t), 80, 0, 2), isNotEmpty, reason: 'paid $t');
    }
  });

  test('Năng động points climb the pass', () {
    final h = _hero()..passSeason = 1;
    h.addActivity(ActSource.dungeon, 3); // 30 points (the day's cap)
    expect(h.passXp, 30);
    h.addActivity(ActSource.dungeon); // past the cap: nothing more
    expect(h.passXp, 30);
  });

  test('free and paid tracks, claiming and the season roll', () {
    final h = _hero();
    h.addPassXp(_day, passTierXp * 5 + 40);
    expect(h.passTier, 5);
    expect(h.passWaiting, 5, reason: 'the paid track is locked');
    expect(h.passClaim(1, paid: true), isNull);
    final shards = h.goldShards;
    expect(h.passClaim(5, paid: false), isNotEmpty);
    expect(h.goldShards, shards + passFreeReward(5).shards);
    expect(h.passClaim(5, paid: false), isNull, reason: 'once');
    expect(h.passClaim(6, paid: false), isNull, reason: 'not reached');

    h.grantPass(_day);
    expect(h.passPaid, isTrue);
    expect(h.passWaiting, 4 + 5);

    final back = _roundTrip(h);
    expect((back.passSeason, back.passXp, back.passFree, back.passPaidSeason), (h.passSeason, h.passXp, h.passFree, h.passPaidSeason));

    // The season ends with rewards untaken: they are given, then all resets.
    final stones = h.starStones;
    h.passRoll(_next);
    expect(h.starStones, greaterThan(stones));
    expect(h.notices.any((n) => n.text.startsWith('Lệnh Bài mùa 1')), isTrue);
    expect((h.passSeason, h.passXp, h.passFree, h.passPaidTaken), (2, 0, 0, 0));
    expect(h.passPaid, isFalse, reason: 'bought for season 1 only');
    h.passRoll(_day);
    expect(h.passSeason, 2, reason: 'a clock set back keeps the season');
  });

  test('tier 30 of Hào Kiệt gives the season outfit, or shards when owned', () {
    final h = _hero();
    h.addPassXp(_day, passTierXp * passTiers + 999);
    expect(h.passTier, passTiers);
    h.grantPass(_day);
    final id = passCostumeOf(h.passSeason);
    h.passClaimAll();
    expect(h.ownedCostumes, contains(id));
    expect(h.seasonTitles, containsAll([passFreeTitle, passPaidTitle]));
    expect(h.passWaiting, 0);

    final again = _hero()..ownedCostumes.add(id);
    again.addPassXp(_day, passTierXp * passTiers);
    again.grantPass(_day);
    final before = again.goldShards;
    again.passClaim(passTiers, paid: true);
    expect(again.goldShards, before + passPaidReward(passTiers).shards + passOwnedShards);
  });

  test('a lost purchase comes back from the ledger, and merges keep it', () {
    final h = _hero()..passSeason = 2;
    const g = PaidGrant(sku: skuPass, seed: 0, slot: 0, until: '2');
    expect(h.reapplyGrant(g), isNotNull);
    expect(h.passPaidSeason, 2);
    expect(h.reapplyGrant(g), isNull);
    final other = _hero()..passPaidSeason = 3;
    h.mergePaid(other);
    expect(h.passPaidSeason, 3);
  });

  test('level gifts and the guide lead on to the first rebirth', () {
    expect(nextLevelGift(25), 30);
    expect(nextLevelGift(90), isNull);
    final h = HeroData(name: 'N', hanh: Hanh.kim)..level = 55;
    expect(nextSteps(h, _day).any((s) => s.title == 'Hướng tới chuyển sinh'), isTrue);
    h.rebirths = 1;
    expect(nextSteps(h, _day).any((s) => s.title == 'Hướng tới chuyển sinh'), isFalse);
  });
}

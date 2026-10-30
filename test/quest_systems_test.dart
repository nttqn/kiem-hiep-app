import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/bounty.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/luan_hoi.dart';
import 'package:kiem_hiep/core/world.dart';

/// A hero done with the main story and ready to be reborn.
HeroData _ready() {
  final h = HeroData(name: 'T', hanh: Hanh.hoa);
  h.mainQuest = mainQuests.length;
  while (!h.canRebirth) {
    h.gainExp(h.expNeeded.toDouble());
  }
  return h;
}

void _toLevel(HeroData h, int lv) {
  while (h.level < lv) {
    h.gainExp(h.expNeeded.toDouble());
  }
}

void main() {
  test('Luân Hồi opens with a rebirth and walks its chapter', () {
    final h = _ready();
    expect(h.currentMain, isNull);
    h.rebirth();
    expect(h.inLuanHoi, isTrue);
    expect(h.currentMain, same(luanHoi[0].quests[0]));
    expect(h.questLabel, 'Luân Hồi I · 1/${luanHoi[0].quests.length}');

    // Kill quest: counts like the main story did.
    final q = h.currentMain!;
    final mob = mobById[q.target]!;
    for (var i = 0; i < q.count; i++) {
      h.onKill(mob, math.Random(i));
    }
    expect(h.rbQuest, 1);

    // Elite quest: locked below its level, then done by the elite kill.
    final e = h.currentMain!;
    expect(e.type, QuestType.elite);
    h.onEliteKill(e.target, math.Random(1));
    expect(h.rbQuest, 1, reason: 'locked until level ${e.minLv}');
    _toLevel(h, e.minLv);
    expect(h.wantedElites(eliteById[e.target]!.map).map((w) => w.key), contains(e.target));
    h.onEliteKill(e.target, math.Random(1));
    expect(h.rbQuest, 2);
  });

  test('finishing a chapter counts, and the next rebirth opens the next one', () {
    final h = _ready();
    h.rebirth();
    final n = luanHoi[0].quests.length;
    h.rbQuest = n - 1;
    _toLevel(h, h.currentMain!.minLv);
    h.onEliteKill(h.currentMain!.target, math.Random(1));
    expect(h.rbDone, 1);
    expect(h.currentMain, isNull);
    expect(h.notices.any((x) => x.text.contains('Hoàn thành Luân Hồi I')), isTrue);
    while (!h.canRebirth) {
      h.gainExp(h.expNeeded.toDouble());
    }
    h.rebirth();
    expect(h.currentMain, same(luanHoi[1].quests[0]));
  });

  test('heroes reborn before 1.0.8 pick Luân Hồi up near their level', () {
    final h = _ready();
    h.rebirth();
    _toLevel(h, 50);
    final json = h.toJson()..remove('lh')..remove('bounty');
    final back = HeroData.fromJson(json);
    expect(back.currentMain!.minLv, greaterThanOrEqualTo(47));
    expect(back.currentMain!.minLv, lessThan(60));
    // And a 1.0.8 save keeps its place.
    back.rbQuest = 3;
    expect(HeroData.fromJson(back.toJson()).rbQuest, 3);
  });

  test('the bounty board fills, pays, refills and keeps a daily quota', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim);
    h.refreshDaily('2026-10-25');
    expect(h.bounties, isEmpty, reason: 'opens at level $bountyMinLevel');
    _toLevel(h, 30);
    h.bountyDay = '';
    h.refreshDaily('2026-10-26');
    expect(h.bounties, hasLength(bountySlots));
    expect(h.bountyLeft, bountiesPerDay - bountySlots);
    for (final b in h.bounties) {
      expect(mapById[b.map]!.minLv, lessThanOrEqualTo(h.level));
    }

    // Finish a kill bounty by killing, then hand it in.
    final b = Bounty(stars: 2, kind: BountyKind.kill, target: 'scorpion', map: 'hoangsa', count: 3, exp: 500, gold: 900);
    h.bounties[0] = b;
    for (var i = 0; i < 3; i++) {
      h.onKill(mobById['scorpion']!, math.Random(i));
    }
    expect(b.done, isTrue);
    final gold = h.gold;
    final lines = h.claimBounty(0, math.Random(1));
    expect(lines, isNotNull);
    expect(h.gold, gold + 900);
    expect(h.bounties, hasLength(bountySlots), reason: 'a new one takes the slot');
    expect(h.bountyLeft, bountiesPerDay - bountySlots - 1);
    expect(h.claimBounty(0, math.Random(1)), anyOf(isNull, isNotNull));

    // The quota runs dry: no more new bounties today.
    h.bountyLeft = 0;
    for (final x in h.bounties) {
      x.progress = x.count;
    }
    while (h.bounties.isNotEmpty) {
      h.claimBounty(0, math.Random(2));
    }
    expect(h.bounties, isEmpty);
    h.refreshDaily('2026-10-27');
    expect(h.bounties, hasLength(bountySlots));
  });

  test('a refresh rerolls one for one and never refills past the quota', () {
    final h = HeroData(name: 'T', hanh: Hanh.thuy);
    _toLevel(h, 40);
    h.refreshDaily('2026-10-26');
    h.bountyLeft = 0;
    // Hand in three, keep one going, then refresh: still one, not four.
    for (var i = 0; i < 3; i++) {
      h.bounties[0].progress = h.bounties[0].count;
      h.claimBounty(0, math.Random(i));
    }
    expect(h.bounties, hasLength(1));
    h.gold = 1000000;
    expect(h.rerollBounties(math.Random(5)), isTrue);
    expect(h.bounties, hasLength(1));
    expect(h.bountyLeft, 0);
    // Nothing unfinished: nothing to refresh, and no gold taken.
    h.bounties[0].progress = h.bounties[0].count;
    final gold = h.gold;
    expect(h.rerollBounties(math.Random(6)), isFalse);
    expect(h.gold, gold);
  });

  test('rerolls cost gold or one of three ad refreshes, and saves keep the board', () {
    final h = HeroData(name: 'T', hanh: Hanh.thuy);
    _toLevel(h, 40);
    h.refreshDaily('2026-10-26');
    h.gold = 0;
    expect(h.rerollBounties(math.Random(1)), isFalse);
    for (var i = 0; i < bountyAdRefreshes; i++) {
      expect(h.rerollBounties(math.Random(i), ad: true), isTrue);
    }
    expect(h.rerollBounties(math.Random(9), ad: true), isFalse);
    h.gold = bountyRefreshCost(h.level);
    expect(h.rerollBounties(math.Random(3)), isTrue);
    expect(h.gold, 0);

    h.bounties[1].progress = 1;
    final back = HeroData.fromJson(h.toJson());
    expect(back.bounties.map((b) => b.goal), h.bounties.map((b) => b.goal));
    expect(back.bounties[1].progress, 1);
    expect(back.bountyAds, bountyAdRefreshes);
    expect(back.bountyLeft, h.bountyLeft);
  });

  test('elite bounties ask for their elite on their map only', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc);
    _toLevel(h, 50);
    final b = Bounty(stars: 5, kind: BountyKind.elite, target: 'fireWolf', map: 'hoadiem', count: 1, exp: 1, gold: 1, epithet: 2);
    h.bounties
      ..clear()
      ..add(b);
    expect(h.wantedElites('magiao'), isEmpty);
    final w = h.wantedElites('hoadiem').single;
    expect(w.name, 'Hỏa Lang ${bountyEpithets[2]}');
    expect(w.hpMul, 9);
    h.onEliteKill(b.eliteKey, math.Random(1));
    expect(b.done, isTrue);
    expect(h.wantedElites('hoadiem'), isEmpty);
  });

  test('in the field the elite appears, the autopilot hunts it, and the quest moves on', () {
    final h = _ready();
    h.rebirth();
    h.rbQuest = 1; // Kẻ chăn rắn, in Tử Trúc Lâm.
    _toLevel(h, h.currentMain!.minLv);
    final w = World.field(h, mapById['truclam']!, seed: 3)..auto = true;
    for (var i = 0; i < 45; i++) {
      w.update(1 / 30);
    }
    final elite = w.mobs.where((m) => m.elite).single;
    expect(elite.eliteName, 'Ma Ảnh Thích Khách');
    expect(elite.maxHp, greaterThan(mobHpAt(elite.level) * 5));
    // Bring it close and weak so the autopilot finishes it quickly.
    elite
      ..x = w.player.x + 60
      ..y = w.player.y
      ..hp = 1;
    for (var i = 0; i < 30 * 20 && h.rbQuest == 1; i++) {
      w.update(1 / 30);
    }
    expect(h.rbQuest, 2);
    // It stays gone while nothing else wants it.
    for (var i = 0; i < 30 * 3; i++) {
      w.update(1 / 30);
    }
    expect(w.mobs.where((m) => m.elite), isEmpty);
  });
}

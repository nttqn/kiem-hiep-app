import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/luan_hoi.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';

import 'sim.dart';

void main() {
  test('ngũ hành cycle: each phase overcomes exactly one other', () {
    for (final h in Hanh.values) {
      expect(h.overcomes, isNot(h));
      expect(h.overcomes.overcomeBy, h);
      expect(hanhFactor(h, h.overcomes), khacBonus);
      expect(hanhFactor(h.overcomes, h), biKhacMalus);
    }
    expect(Hanh.kim.overcomes, Hanh.moc);
    expect(Hanh.thuy.overcomes, Hanh.hoa);
  });

  test('content references resolve', () {
    for (final m in maps) {
      for (final id in [...m.mobs, m.boss]) {
        expect(mobById[id], isNotNull, reason: id);
      }
      expect(mobById[m.boss]!.boss, isTrue);
    }
    for (final q in [...mainQuests, for (final c in luanHoi) ...c.quests]) {
      switch (q.type) {
        case QuestType.kill || QuestType.boss:
          expect(mobById[q.target], isNotNull, reason: q.title);
          expect(mapOfMob(q.target), isNotNull, reason: q.title);
        case QuestType.dungeon:
          expect(dungeonById[q.target], isNotNull, reason: q.title);
          expect(dungeonById[q.target]!.level, lessThanOrEqualTo(q.minLv), reason: q.title);
        case QuestType.elite:
          final e = eliteById[q.target];
          expect(e, isNotNull, reason: q.title);
          expect(mobById[e!.mob], isNotNull, reason: q.title);
          expect(mobById[e.mob]!.boss, isFalse, reason: 'elites are not built on bosses: ${q.title}');
          expect(mapById[e.map], isNotNull, reason: q.title);
          expect(q.minLv, greaterThanOrEqualTo(mapById[e.map]!.minLv), reason: q.title);
        case QuestType.level:
          break;
      }
    }
    for (final c in luanHoi) {
      // Each chapter climbs from level 10 back to 99, in order.
      expect(c.quests.first.minLv, 10, reason: c.title);
      for (var i = 1; i < c.quests.length; i++) {
        expect(c.quests[i].minLv, greaterThan(c.quests[i - 1].minLv), reason: c.quests[i].title);
      }
      expect(c.quests.last.type, QuestType.elite, reason: c.title);
    }
    for (final s in sects) {
      // Six regular skills (four active) and the tuyệt kỹ last.
      expect(s.skills.length, 7);
      expect(s.skills.where((k) => !k.isPassive && !k.ultimate).length, 4, reason: s.name);
      expect(s.skills.last.ultimate, isTrue, reason: s.name);
      expect(s.skills.where((k) => k.ultimate).length, 1, reason: s.name);
    }
  });

  test('hero save round-trips', () {
    final rng = math.Random(1);
    final h = HeroData(name: 'Lăng Ba', hanh: Hanh.thuy, female: true);
    h.gainExp(5000);
    h.autoSpend();
    h.autoLearn();
    for (final s in Slot.values) {
      h.addItem(makeItem(slot: s, level: 3, rarity: Rarity.rare, sect: h.sect, rng: rng));
    }
    h.autoEquip();
    h.equip[Slot.weapon]!.plus = 4;
    h.recompute();
    h.addItem(makeItem(slot: Slot.ring, level: 2, rarity: Rarity.fine, sect: h.sect, rng: rng));
    h.refreshDaily('2026-10-15');
    h.dungeonStars['a1'] = 3;
    final copy = HeroData.fromJson(
        jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(copy.toJson(), h.toJson());
    expect(copy.stats.atk, closeTo(h.stats.atk, 1e-9));
    expect(copy.stats.maxHp, closeTo(h.stats.maxHp, 1e-9));
  });

  test('levelling pays points and quests advance', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim);
    h.gainExp(expToNext(1).toDouble());
    expect(h.level, 2);
    expect(h.freePoints, pointsPerLevel);
    expect(h.skillPoints, 1);
    final wolf = mobById['wolf']!;
    final rng = math.Random(2);
    for (var i = 0; i < mainQuests.first.count; i++) {
      h.onKill(wolf, rng);
    }
    expect(h.mainQuest, 1, reason: 'first quest is 8 wolves');
  });

  test('every sect clears the first dungeon on autopilot at level 5', () {
    for (final hanh in Hanh.values) {
      final h = HeroData(name: 'T', hanh: hanh);
      for (var l = 1; l < 5; l++) {
        h.gainExp(h.expNeeded.toDouble());
      }
      // Plain shop gear, which any player can afford by now.
      final rng = math.Random(9);
      for (final s in Slot.values) {
        h.addItem(makeItem(slot: s, level: 5, rarity: Rarity.common, sect: h.sect, rng: rng));
      }
      townVisit(h);
      final w = World.dungeon(h, dungeonById['a1']!, seed: 7)..auto = true;
      var cleared = false;
      for (var i = 0; i < 60 * 200 && !w.finished; i++) {
        w.update(1 / 60);
        if (w.events.any((e) => e.kind == EvKind.cleared)) cleared = true;
        w.events.clear();
      }
      expect(cleared, isTrue, reason: sectOf(hanh).name);
      expect(w.rewardLines, isNotEmpty);
      expect(h.dungeonStars['a1'], greaterThan(0));
    }
  });

  test('boss slam is telegraphed and can be dodged', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim);
    final w = World.field(h, maps.first, seed: 3);
    final boss = w.boss!;
    w.player
      ..x = boss.x - 60
      ..y = boss.y;
    boss.state = MobState.chase;
    boss.bossCd = 0;
    w.update(1 / 60);
    final slam = w.zones.where((z) => !z.fromHero).toList();
    expect(slam, hasLength(1));
    expect(slam.single.delay, greaterThan(0.8));
    // Walk out of the circle before it lands.
    w.player.x -= slam.single.r + 80;
    final before = w.player.hp;
    boss.attackCd = 99;
    for (var i = 0; i < 90; i++) {
      w.update(1 / 60);
    }
    expect(w.player.hp, greaterThanOrEqualTo(before - 1));
  });

  test('balance: every sect progresses steadily in 30 minutes', () {
    for (final hanh in Hanh.values) {
      final r = simulate(hanh, minutes: 30, seed: 5);
      final name = sectOf(hanh).name;
      expect(r.levelAtMinute[15], greaterThanOrEqualTo(7), reason: name);
      expect(r.levelAtMinute[30], inInclusiveRange(12, 28), reason: name);
      expect(r.deaths, lessThanOrEqualTo(8), reason: name);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

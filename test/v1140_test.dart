import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/auto_config.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/funnel.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/helper.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/legacy.dart';
import 'package:kiem_hiep/core/quest_go.dart';
import 'package:kiem_hiep/core/tower.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/save.dart';

HeroData hero({int level = 1, int quest = 0, int rebirths = 0, Hanh hanh = Hanh.kim}) {
  final h = HeroData(name: 'T', hanh: hanh)
    ..level = level
    ..mainQuest = quest
    ..rebirths = rebirths;
  h.recompute();
  return h;
}

void main() {
  group('Tự đi nhiệm vụ', () {
    test('a dungeon quest points at its ải, unless already there or locked', () {
      // Quest 10 (index 9) is Trúc lâm mê trận, ải a3, from level 12.
      final h = hero(level: 15, quest: 9);
      expect(h.currentMain!.type, QuestType.dungeon);
      final g = questGo(h, hereMap: 'bamboo')!;
      expect(g.dungeon!.id, 'a3');
      expect(g.label, startsWith('Vào ải'));
      expect(questGo(h, hereDungeon: 'a3'), isNull);
      expect(questGo(hero(level: 5, quest: 9)), isNull);
    });

    test('a kill quest points at its field, none when standing on it', () {
      final h = hero(level: 3, quest: 1); // boars
      final m = questMap(h.currentMain!)!;
      expect(questGo(h, hereMap: m.id), isNull);
      final g = questGo(h, hereMap: 'nowhere')!;
      expect(g.map!.id, m.id);
    });

    test('the setting is on for old and new heroes and round-trips', () {
      expect(AutoConfig().questGo, isTrue);
      // Saved by 1.13: eight fields.
      expect(AutoConfig.fromJson([1, [], 0.42, 0.22, true, true, true, true]).questGo, isTrue);
      final c = AutoConfig()..questGo = false;
      expect(AutoConfig.fromJson(c.toJson()).questGo, isFalse);
      expect(c.isDefault, isFalse);
    });
  });

  group('funnel steps of 1.14.0', () {
    test('an old hero past the new steps does not send them', () {
      final old = hero(level: 40, quest: 24);
      final json = old.toJson();
      // As a 1.13 save: the old step list, no version mark.
      json['fun'] = ['20261101', 0, ['f_lv3', 'f_lv5', 'f_lv10', 'f_lv15', 'f_lv20', 'f_lv30', 'f_lv40']];
      final h = HeroData.fromJson(json);
      final due = funnelDue(h, '20261114');
      expect(due.where((s) => s.startsWith('f_lv') || s.startsWith('f_q')), isEmpty);
      expect(h.funnel, contains(funnelVersion));
    });

    test('a new hero sends them as reached', () {
      final h = hero(level: 13, quest: 5);
      final due = funnelDue(h, '');
      expect(due, containsAll(['f_lv12', 'f_q5']));
      expect(due, isNot(contains('f_lv25')));
      // And they survive a save.
      h.funnel.addAll(due);
      final back = HeroData.fromJson(h.toJson());
      expect(funnelDue(back, ''), isEmpty);
    });
  });

  group('Truyền thừa', () {
    test('a level-60+ hero speeds up the weaker ones until caught up', () {
      final big = hero(level: 99, rebirths: 2)..name = 'Lão';
      final small = hero(level: 10);
      final slots = <HeroData?>[big, null, small, null, null];
      applyLegacy(small, slots, 2);
      expect(small.legacyExp, closeTo(legacyBaseExp + 2 * legacyPerRebirth, 1e-9));
      expect(small.legacyFrom, 'Lão');
      // The big one gets nothing from the small one.
      applyLegacy(big, slots, 0);
      expect(big.legacyExp, 0);
      // Capped.
      expect(legacyBonus(small, hero(level: 99, rebirths: 6)), legacyMaxExp);
      // A level-50 hero passes nothing on.
      expect(legacySource([hero(level: 50), small], 1), isNull);
    });

    test('the bonus multiplies monster EXP and part of gold', () {
      final h = hero(level: 10);
      final e0 = h.expMul, g0 = h.goldMul;
      h.legacyExp = 0.5;
      expect(h.expMul, closeTo(e0 * 1.5, 1e-9));
      expect(h.goldMul, closeTo(g0 * (1 + 0.5 * legacyGoldShare), 1e-9));
    });

    test('the gift is given once, to a young hero, and saved', () {
      final big = hero(level: 99, rebirths: 1);
      final h = hero(level: 5);
      applyLegacy(h, [big, h], 1);
      final gold = h.gold, pots = h.hpPots;
      expect(takeLegacyGift(h, big), isNotEmpty);
      expect(h.gold, gold + legacyGiftOf(big).gold);
      expect(h.hpPots, pots + 30);
      expect(takeLegacyGift(h, big), isEmpty);
      expect(HeroData.fromJson(h.toJson()).legacyTaken, isTrue);
      // Too far along for it.
      final older = hero(level: 35);
      applyLegacy(older, [big, older], 1);
      expect(legacyGiftReady(older), isFalse);
    });
  });

  group('Trợ chiến', () {
    test('where an ally may come', () {
      expect(helperAllowed(dungeonById['a3']!), isTrue);
      expect(helperAllowed(towerFloor(5)), isFalse);
    });

    test('strength from the two lực chiến, within bounds', () {
      expect(helperMul(1000, 1000), closeTo(1, 1e-9));
      expect(helperMul(100, 1000), 0.7);
      expect(helperMul(1000000, 1000), 2.2);
      expect(helperMul(3000, 1000), greaterThan(1.5));
    });

    test('three calls a day, each player once, saved', () {
      final h = hero(level: 20);
      const day = '20261115';
      expect(h.helpsLeft(day), helpCallsPerDay);
      h.useHelper('a_0', day);
      expect(h.canCallHelper('a_0', day), isFalse);
      expect(h.canCallHelper('b_0', day), isTrue);
      h.useHelper('b_0', day);
      h.useHelper('c_0', day);
      expect(h.helpsLeft(day), 0);
      final back = HeroData.fromJson(h.toJson());
      expect(back.helpsLeft(day), 0);
      expect(back.helpsLeft('20261116'), helpCallsPerDay);
    });

    test('Hiệp nghĩa pays gold and titles as it adds up', () {
      final h = hero(level: 40);
      final gold = h.gold;
      final lines = h.takeHiepNghia(10);
      expect(h.gold, gold + hiepNghiaGold(40, 0) * 10);
      expect(lines.any((l) => l.contains('Trượng Nghĩa')), isTrue);
      expect(h.takeHiepNghia(1).any((l) => l.contains('Danh hiệu')), isFalse);
      expect(HeroData.fromJson(h.toJson()).hnTotal, 11);
    });

    test('a called hero is counted up for the helper and taken once', () async {
      final gs = GuildService.instance
        ..debug = true
        ..debugUid = 'caller';
      final save = SaveService.instance;
      final was = save.active;
      save.active = 0;
      final h = hero(level: 20);
      expect(await gs.sendHelp(h, 'helper_0', '20261115'), isTrue);
      expect(await gs.sendHelp(h, 'helper_0', '20261116'), isTrue);
      // Never one's own other slot.
      expect(await gs.sendHelp(h, 'caller_0', '20261116'), isFalse);
      gs.debugUid = 'helper';
      final (n, names) = await gs.takeHelps();
      expect(n, 2);
      expect(names, ['caller_0']);
      expect((await gs.takeHelps()).$1, 0);
      save.active = was;
      gs.debug = false;
    });

    test('an ally fights beside the hero in an ải, not on a field', () {
      final d = dungeonById['a5']!;
      double dealt({required bool ally}) {
        final h = hero(level: 24, quest: 0);
        final w = World.dungeon(h, d, seed: 7)..auto = true;
        if (ally) {
          expect(w.canCallHelper, isTrue);
          w.callHelper(
              const ArenaRival(name: 'Bạn', hanh: Hanh.hoa, level: 60, rebirths: 0, power: 50000, female: false), 2.0);
          expect(w.helper, isNotNull);
          expect(w.canCallHelper, isFalse);
        }
        for (var i = 0; i < 60 * 25 && !w.finished; i++) {
          w.update(1 / 60);
          w.events.clear();
        }
        return w.dmgDealt;
      }

      final alone = dealt(ally: false), withAlly = dealt(ally: true);
      expect(withAlly, greaterThan(alone * 1.4));
      final f = World.field(hero(level: 5), maps.first, seed: 1);
      expect(f.canCallHelper, isFalse);
    });
  });
}

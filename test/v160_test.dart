import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/costumes.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/luan_hoi.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/world.dart';

HeroData _cs(int n) {
  final h = HeroData(name: 'T', hanh: Hanh.kim)..mainQuest = mainQuests.length;
  for (var i = 0; i < n; i++) {
    while (!h.expFull) {
      h.gainExp(h.expNeeded.toDouble());
    }
    h.soulPills += h.nextRebirthPills;
    expect(h.rebirth(), isTrue);
  }
  return h;
}

void main() {
  group('Lục chuyển', () {
    test('a cs5 hero at a full bar can be reborn a sixth time, not a seventh', () {
      final h = _cs(5);
      while (!h.expFull) {
        h.gainExp(h.expNeeded.toDouble());
      }
      expect(h.canRebirth, isFalse, reason: 'no Linh Phách Đơn yet');
      expect(h.rebirth(), isFalse);
      h.soulPills = 65;
      expect(h.canRebirth, isTrue);
      expect(h.rebirth(), isTrue);
      expect(h.rebirths, 6);
      expect(h.soulPills, 5, reason: 'sixty spent');
      expect(h.level, rebirthLevel);
      while (!h.expFull) {
        h.gainExp(h.expNeeded.toDouble());
      }
      expect(h.canRebirth, isFalse);
    });

    test('the sixth life needs more EXP a level but gives more points', () {
      final h5 = _cs(5);
      final h6 = _cs(6);
      expect(h6.expNeeded, (expToNext(rebirthLevel) * lucChuyenExpNeed).round());
      expect(h5.expNeeded, expToNext(rebirthLevel));
      final before = h6.freePoints;
      h6.gainExp(h6.expNeeded.toDouble() / (1 + rebirthExp * 6));
      expect(h6.level, rebirthLevel + 1);
      expect(h6.freePoints, before + pointsPerLevel + lucChuyenPoints);
    });

    test('a level-99 sixth-life save keeps its points (not taken for an edit)', () {
      final h = _cs(6);
      while (!h.expFull) {
        h.gainExp(h.expNeeded.toDouble());
      }
      h.autoSpend();
      final total = h.potentialTotal;
      expect(total, lessThanOrEqualTo(h.maxPotential));
      final back = HeroData.fromJson(h.toJson());
      expect(back.rebirths, 6);
      expect(back.potentialTotal, total);
      expect(back.spent, h.spent);
    });

    test('cs6 brings the deer, Luân Hồi VI and its label', () {
      final h = _cs(6);
      expect(h.ownsMount('cuusac'), isTrue);
      expect(h.chapter, 5);
      expect(luanHoi[h.chapter].title, 'Huyết Hải Ma Đế');
      expect(h.questLabel, startsWith('Luân Hồi VI'));
      for (final q in luanHoi[5].quests) {
        if (q.type == QuestType.elite) expect(mapById[eliteById[q.target]!.map], isNotNull);
        if (q.type == QuestType.kill || q.type == QuestType.boss) expect(mapOfMob(q.target), isNotNull, reason: q.target);
        if (q.type == QuestType.dungeon) expect(dungeonById[q.target], isNotNull);
      }
    });
  });

  group('Linh Phách Đơn cho chuyển sinh', () {
    test('sixty for the sixth, seventy for a seventh; none before', () {
      expect(rebirthPillCost(5), 0);
      expect(rebirthPillCost(6), 60);
      expect(rebirthPillCost(7), 70);
    });

    test('a cs5 hero with a full bar condenses pills toward the sixth rebirth', () {
      final h = _cs(5);
      while (!h.expFull) {
        h.gainExp(h.expNeeded.toDouble());
      }
      expect(h.condensesSoul, isTrue);
      h.notices.clear();
      h.gainExp(h.soulPillExp * 3.0);
      expect(h.soulPills, greaterThanOrEqualTo(3));
      final cs4 = _cs(4);
      while (!cs4.expFull) {
        cs4.gainExp(cs4.expNeeded.toDouble());
      }
      cs4.gainExp(cs4.soulPillExp * 3.0);
      expect(cs4.soulPills, 0, reason: 'the fifth rebirth needs no pills');
    });
  });

  group('U Minh Huyết Hải', () {
    test('opens at the sixth rebirth, scaled up, listed last, off the story road', () {
      expect(huyetHaiMap.rebirths, 6);
      expect(fieldMaps.last, huyetHaiMap);
      expect(maps.contains(huyetHaiMap), isFalse);
      expect(isSideMap(huyetHaiMap), isTrue);
      for (final id in [...huyetHaiMap.mobs, huyetHaiMap.boss]) {
        expect(mobById[id], isNotNull);
      }
      final h = _cs(6);
      final w = World.field(h, huyetHaiMap, seed: 1);
      final m = w.mobs.firstWhere((m) => m.def.id == 'hhWolf');
      expect(m.maxHp, closeTo(Mob(0, m.def, m.level, 0, 0).maxHp * huyetHaiMul, 1e-6));
      expect(ironChanceOf(6), 2 * ironChanceOf(5));
      expect(bossIronOf(6), 2 * bossIronOf(5));
    });

    test('ten Ma Đế kills bring the outfit', () {
      final h = _cs(6);
      final lord = mobById[huyetHaiMap.boss]!;
      for (var i = 0; i < 10; i++) {
        h.onKill(lord, math.Random(i));
      }
      h.unlockCostumes();
      expect(h.ownedCostumes, contains('huyethai'));
      expect(costumeById['huyethai']!.howTo, contains('Huyết Hải Ma Đế'));
      expect(mountById['cuusac']!.howTo, contains('6'));
    });
  });
}

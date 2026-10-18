import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/meridians.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';

HeroData at(Hanh hanh, int level) {
  final h = HeroData(name: 'T', hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  return h;
}

void main() {
  test('tuyệt kỹ opens at 60 and stops at 10', () {
    final h = at(Hanh.hoa, 59)..skillPoints = 50;
    expect(h.canLearn(6), isFalse);
    h.gainExp(h.expNeeded.toDouble());
    expect(h.level, 60);
    expect(h.canLearn(6), isTrue);
    for (var i = 0; i < 20; i++) {
      h.learn(6);
    }
    expect(h.skillLv[6], maxSkillLevel);
    // Breakthrough does not lift the tuyệt kỹ.
    while (h.level < breakthroughLevel) {
      h.gainExp(h.expNeeded.toDouble());
    }
    expect(h.skillCap(6), maxSkillLevel);
  });

  test('regular skills break through to 15 at level 80, and stay open after a rebirth', () {
    final h = at(Hanh.kim, 79)..skillPoints = 100;
    for (var i = 0; i < 30; i++) {
      h.learn(0);
    }
    expect(h.skillLv[0], maxSkillLevel);
    h.gainExp(h.expNeeded.toDouble());
    expect(h.skillCap(0), maxBreakLevel);
    for (var i = 0; i < 30; i++) {
      h.learn(0);
    }
    expect(h.skillLv[0], maxBreakLevel);

    // A reborn hero at level 10 keeps every skill and its breakthrough.
    final r = at(Hanh.kim, maxLevel)..skillPoints = 0;
    r.gainExp(expToNext(maxLevel).toDouble());
    r.rebirth();
    expect(r.level, rebirthLevel);
    expect(r.skillOpen(6), isTrue);
    expect(r.skillCap(1), maxBreakLevel);
    expect(r.meridiansOpen, isTrue);
  });

  test('auto-learn fills every skill by level 99, then spills into the meridians', () {
    for (final hn in Hanh.values) {
      final h = HeroData(name: 'T', hanh: hn);
      while (h.level < maxLevel) {
        h.gainExp(h.expNeeded.toDouble());
        h.autoLearn();
      }
      expect(h.skillPoints, 0, reason: '$hn');
      expect(h.skillLv[6], greaterThanOrEqualTo(9), reason: '$hn tuyệt kỹ');
      expect(h.skillLv.sublist(0, 6).every((v) => v >= 14), isTrue, reason: '$hn ${h.skillLv}');

      // The next life's points go into the meridians, own phase first.
      h.gainExp(expToNext(maxLevel).toDouble());
      h.rebirth();
      while (h.level < 60) {
        h.gainExp(h.expNeeded.toDouble());
        h.autoLearn();
      }
      final pts = h.meridianPts.reduce((a, b) => a + b);
      expect(pts, greaterThan(40), reason: '$hn');
      expect(h.meridianPts[hn.index], h.meridianPts.reduce((a, b) => a > b ? a : b), reason: '$hn');
      expect(h.allBonuses()[meridians[0].bonus], greaterThan(0));
    }
  });

  test('meridians have diminishing returns and survive a save', () {
    final m = meridians[0];
    expect(m.valueAt(0), 0);
    expect(m.valueAt(50), closeTo(m.per * 25, 1e-9));
    expect(m.valueAt(200) / m.valueAt(100), lessThan(1.5));

    final h = at(Hanh.thuy, 60)..skillPoints = 30;
    expect(h.trainMeridian(2, 10), isTrue);
    expect(h.skillPoints, 20);
    expect(h.stats.skillDmg, greaterThan(0));
    expect(at(Hanh.thuy, 59).trainMeridian(2), isFalse, reason: 'closed before 60');
    final copy = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(copy.meridianPts[2], 10);
    expect(copy.stats.skillDmg, closeTo(h.stats.skillDmg, 1e-9));
  });

  test('every sect\'s tuyệt kỹ hurts a monster standing in front of the hero', () {
    for (final hn in Hanh.values) {
      final h = at(hn, 60)..skillLv[6] = 10;
      h.recompute();
      final w = World.field(h, mapById['magiao']!, seed: 2);
      final p = w.player;
      p.mp = h.stats.maxMp;
      final m = w.mobs.firstWhere((m) => !m.def.boss);
      m
        ..x = p.x + 120
        ..y = p.y
        ..state = MobState.idle;
      final hp0 = m.hp;
      p.aimX = 1;
      p.aimY = 0;
      w.input.skills.add(6);
      for (var i = 0; i < 60; i++) {
        m.attackCd = 99;
        w.update(1 / 30);
      }
      expect(m.hp, lessThan(hp0), reason: sectOf(hn).skills[6].name);
    }
  });
}

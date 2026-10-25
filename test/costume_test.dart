import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/costumes.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/world_boss.dart';
import 'package:kiem_hiep/render/art_figures.dart';

void main() {
  test('tower, rebirth and level outfits unlock once and announce it', () {
    final h = HeroData(name: 'T', hanh: Hanh.thuy);
    expect(h.ownedCostumes, isEmpty);
    h.towerBest = 29;
    h.towerReward(30, math.Random(1));
    expect(h.ownedCostumes, contains('bachy'));
    expect(h.notices.where((n) => n.text.contains('Bạch Y Kiếm Khách')), hasLength(1));
    h.unlockCostumes();
    expect(h.notices.where((n) => n.text.contains('Bạch Y Kiếm Khách')), hasLength(1),
        reason: 'no second notice for an outfit already owned');
    expect(h.ownedCostumes, isNot(contains('tuvan')));
  });

  test('old saves get the outfits they already earned, silently', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim);
    h.rebirths = 3;
    h.towerBest = 65;
    final json = h.toJson()..remove('look');
    final back = HeroData.fromJson(json);
    expect(back.ownedCostumes, containsAll(['hacklong', 'huyetma', 'minhchu', 'bachy', 'tuvan']));
    expect(back.ownedCostumes, isNot(contains('kimgiap')));
    expect(back.notices, isEmpty);
    expect(back.costume, '');
  });

  test('Boss Thế Giới milestones 4 and 5 give their outfits', () {
    final h = HeroData(name: 'T', hanh: Hanh.hoa);
    h.wbRollDay('20261025');
    h.wbTotal = worldBossMilestones.last;
    for (var i = 0; i < worldBossMilestones.length; i++) {
      h.wbClaim(i, math.Random(i));
    }
    expect(h.ownedCostumes, containsAll(['phuong', 'bangtam']));
  });

  test('gold outfits cost gold, can be worn, and survive a save', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc, female: true);
    final c = costumeById['thanhsam']!;
    h.gold = c.need - 1;
    expect(h.buyCostume(c.id), isFalse);
    h.gold = c.need + 5;
    expect(h.buyCostume(c.id), isTrue);
    expect(h.gold, 5);
    expect(h.buyCostume(c.id), isFalse, reason: 'already owned');
    expect(h.wearCostume('tuyetanh'), isFalse, reason: 'not owned');
    expect(h.buyCostume('bachy'), isFalse, reason: 'not for sale');
    expect(h.wearCostume(c.id), isTrue);
    h.hideHat = true;
    final back = HeroData.fromJson(h.toJson());
    expect(back.costume, c.id);
    expect(back.hideHat, isTrue);
    expect(back.ownedCostumes, contains(c.id));
  });

  test('the worn outfit and hidden hat reach the hero look', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim, female: true);
    expect(lookOfHero(h).hair, Hair.nunCap);
    expect(heroLook(Hanh.kim).hair, Hair.bald);
    h.ownedCostumes.add('kimgiap');
    h.wearCostume('kimgiap');
    final k = lookOfHero(h);
    final c = costumeById['kimgiap']!;
    expect(k.robe, c.robe);
    expect(k.aura, c.aura);
    expect(k.armor, c.armor, reason: 'the outfit lifts the armour look');
  });
}

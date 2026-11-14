import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/alchemy.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/ledger.dart';
import 'package:kiem_hiep/core/meridians.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/tam_ma.dart';
import 'package:kiem_hiep/core/weekly_hunt.dart';
import 'package:kiem_hiep/core/world.dart';

void main() {
  ledgerTests();
  pillTests();
  overflowTests();
  test('one volley on one target: the first missile in full, the rest a share', () {
    expect(volleyShare(1), 1);
    expect(volleyShare(2), volleyExtraShare);
    expect(volleyShare(22), volleyExtraShare);
  });

  test('Tâm Ma board rows past 8x their lực chiến are not believed', () {
    // Real climbers: 2.79M on floor 52, about 4M on 59.
    expect(tamMaPlausible(52, 2790000), isTrue);
    expect(tamMaPlausible(59, 4000000), isTrue);
    // The 600k row on floor 104.
    expect(tamMaPlausible(104, 600000), isFalse);
    expect(tamMaPlausible(1, 0), isTrue);
    expect(tamMaPlausible(0, 0), isTrue);
  });
}

void ledgerTests() {
  group('edited currencies', () {
    // 2026-11-13 is Săn quái week 3.
    const day = '20261113';
    test('honest top players stay under every ceiling', () {
      final wk = huntWeekOf(day);
      expect(wk, 3);
      // RenCa's stone ledger (~1,330) and the most Tinh Phách anyone could
      // have earned by then (~25).
      expect(stoneCeiling(wk, 59), greaterThan(1330 * 1.5));
      expect(soulCeiling(wk), greaterThan(25 * 1.5));
      expect(jadeCeiling(wk, 11), greaterThan(60));
    });

    test('the edited save of 2026-11-13 is cut down; worn ★5 stays', () {
      final h = HeroData(name: 'S', hanh: Hanh.moc)
        ..level = 99
        ..rebirths = 6
        ..tmBest = 39
        ..daoLv = 11
        ..starStones = 22751
        ..beastSouls = 3922
        ..tienJade = 1467;
      final it = makeItem(slot: Slot.weapon, level: 99, rarity: Rarity.legend, sect: h.sect, rng: math.Random(1))
        ..star = 5;
      h.addItem(it);
      h.clampEdited(day);
      expect(h.starStones, stoneCeiling(3, 39));
      expect(h.beastSouls, soulCeiling(3));
      expect(h.tienJade, jadeCeiling(3, 11));
      expect(it.star, 5);
      // Honest amounts are left alone.
      h
        ..starStones = 300
        ..beastSouls = 4
        ..tienJade = 12
        ..clampEdited(day);
      expect([h.starStones, h.beastSouls, h.tienJade], [300, 4, 12]);
    });

    test('Tinh Phách in gear: ★4 two, ★5 four more, a Thiên gem one each', () {
      final it = makeItem(slot: Slot.weapon, level: 99, rarity: Rarity.legend, sect: sectOf(Hanh.moc), rng: math.Random(1))
        ..star = 5;
      it.gems[0] = const Gem(Hanh.moc, maxGemTier);
      expect(soulsInvested([it]), 7);
      // Seven such pieces with five Thiên each (the 2026-11-13 save): 77.
      expect(7 * (6 + 5), greaterThan(soulCeiling(3)));
    });
  });
}

void pillTests() {
  test('Uống đầy takes buff pills up to six hours and stops', () {
    final h = HeroData(name: 'P', hanh: Hanh.kim)..level = 30;
    final p = pillById['songboi']!;
    h.pills[p.id] = 25;
    expect(h.fillPill(p), maxBuffMinutes ~/ p.minutes);
    expect(h.buffLeft(p.id), maxBuffMinutes * 60);
    expect(h.pills[p.id], 25 - 18);
    expect(h.fillPill(p), 0);
  });
}

void overflowTests() {
  test('chí mạng, né tránh, tốc đánh past their caps turn into other stats', () {
    final h = HeroData(name: 'O', hanh: Hanh.moc)..level = 99;
    h.recompute();
    final cd0 = h.stats.critDmg, hp0 = h.stats.maxHp, atk0 = h.stats.atk;
    // A pile of thân pháp: crit, dodge and speed all far past the caps.
    h.spent[1] = 1000;
    h.recompute();
    final s = h.stats;
    expect(s.crit, critCap);
    expect(s.dodge, dodgeCap);
    expect(s.aspd, aspdCap);
    expect(s.overCrit, greaterThan(0));
    expect(s.overDodge, greaterThan(0));
    expect(s.overAspd, greaterThan(0));
    expect(s.critDmg, closeTo(cd0 + s.overCrit * overCritToCritDmg, 1e-9));
    expect(s.maxHp, closeTo(hp0 * (1 + s.overDodge * overDodgeToHp), 1e-6));
    expect(s.atk, greaterThan(atk0));
  });
}

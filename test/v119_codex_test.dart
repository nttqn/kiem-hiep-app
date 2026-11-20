import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/codex.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sects.dart';

import 'v130_realm_test.dart' show geared;

Item _piece(HeroData h, Slot s, int level, {Rarity r = Rarity.legend}) =>
    makeItem(slot: s, level: level, rarity: r, sect: h.sect, rng: math.Random(level * 7 + s.index));

void main() {
  test('a Truyền thuyết piece fills its cell even when it is broken down', () {
    final h = geared(60, Hanh.kim);
    h.codexGear.clear();
    h.autoSalvageUpTo = Rarity.legend.index;
    expect(h.addItem(_piece(h, Slot.ring, 64)), isFalse); // broken down
    expect(h.codexGear.contains(codexGearKey(6, Slot.ring)), isTrue);
    expect(h.lastCodexNew, isTrue);
    h.addItem(_piece(h, Slot.ring, 66));
    expect(h.lastCodexNew, isFalse);
    // Lesser pieces do not count.
    h.addItem(_piece(h, Slot.hat, 64, r: Rarity.epic));
    expect(h.codexGear.contains(codexGearKey(6, Slot.hat)), isFalse);
  });

  test('a whole tier can be taken once, for gold, Tinh Hoa and a bonus', () {
    final h = geared(60, Hanh.thuy);
    h.codexGear.clear();
    h.codexClaimed.clear();
    for (final s in Slot.values.skip(1)) {
      h.codexNote(_piece(h, s, 75));
    }
    expect(h.codexClaimable(codexGearPage(7)), isFalse);
    h.codexNote(_piece(h, Slot.weapon, 79));
    expect(h.codexClaimable(codexGearPage(7)), isTrue);
    expect(h.codexReady, 1);
    final gold0 = h.gold, ess0 = h.essence;
    final b0 = h.allBonuses()[Bonus.skillDmg] ?? 0;
    final lines = h.codexClaim(codexGearPage(7));
    expect(lines, isNotEmpty);
    expect(h.gold, gold0 + codexGearGold(7));
    expect(h.essence, ess0 + codexGearEssence(7));
    expect((h.allBonuses()[Bonus.skillDmg] ?? 0) - b0, closeTo(0.02, 1e-9));
    expect(h.codexClaim(codexGearPage(7)), isEmpty);
  });

  test('a land page needs every monster and the boss', () {
    final h = geared(30, Hanh.hoa);
    h.mobKills.clear();
    h.codexClaimed.clear();
    final m = mieuCuongMap;
    for (final id in m.mobs) {
      for (var i = 0; i < codexMobGoal + 5; i++) {
        h.codexKill(mobById[id]!);
      }
    }
    expect(h.codexMobCount(m.mobs.first), codexMobGoal);
    expect(h.codexLandDone(m), isFalse);
    h.bossKillsById[m.boss] = codexBossGoal;
    expect(h.codexLandDone(m), isTrue);
    expect(h.codexClaim(codexLandPage(m.id)), isNotEmpty);
    expect(h.codexBonuses()[Bonus.hpPct], closeTo(0.008, 1e-9));
  });

  test('onKill counts monsters for the book', () {
    final h = geared(30, Hanh.moc);
    h.mobKills.clear();
    h.onKill(mobById['mcGu']!, math.Random(1));
    h.onKill(mobById['mcGu']!, math.Random(1));
    h.onKill(mobById['mcKing']!, math.Random(1));
    expect(h.mobKills['mcGu'], 2);
    expect(h.mobKills.containsKey('mcKing'), isFalse);
  });

  test('the book survives a save, and old saves note what is worn', () {
    final h = geared(60, Hanh.tho);
    h.codexGear.clear();
    h.codexNote(_piece(h, Slot.belt, 41));
    h.mobKills['wolf'] = 120;
    h.codexClaimed.add('m:ngoaithanh');
    final back = HeroData.fromJson(h.toJson());
    expect(back.codexGear.contains(codexGearKey(4, Slot.belt)), isTrue);
    expect(back.mobKills['wolf'], 120);
    expect(back.codexClaimed, contains('m:ngoaithanh'));

    final old = h.toJson()..remove('cx');
    final worn = _piece(h, Slot.amulet, 88);
    old['equip'] = {'${Slot.amulet.index}': worn.toJson()};
    final loaded = HeroData.fromJson(old);
    expect(loaded.codexGear.contains(codexGearKey(8, Slot.amulet)), isTrue);
  });

  test('a set title keeps its bonus when pages are added later', () {
    final h = geared(60, Hanh.kim);
    h.codexClaimed.clear();
    h.seasonTitles.add(codexLandTitle);
    expect(h.codexLandAll, isFalse);
    expect(h.codexBonuses()[Bonus.hpPct], closeTo(0.03, 1e-9));
  });

  test('every land with a page has a bonus', () {
    for (final m in codexLands) {
      expect(codexLandBonus[m.id], isNotNull, reason: m.id);
    }
    expect(codexLands.length, 13);
  });
}

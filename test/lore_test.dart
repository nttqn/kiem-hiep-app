import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/lore.dart';
import 'package:kiem_hiep/core/realm.dart';
import 'package:kiem_hiep/core/sects.dart';

import 'v130_realm_test.dart' show geared, runRealm;

void main() {
  test('every chapter has five pages and a bonus', () {
    expect(loreChapters.length, realms.length);
    for (final c in loreChapters) {
      expect(c.pages.length, lorePagesPer);
      expect(c.value, greaterThan(0));
    }
  });

  test('pages come one missing at a time; a whole chapter pays, all nine give the title', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim)..level = 40;
    final r = math.Random(1);
    h.recompute();
    final hp = h.stats.maxHp;
    for (var i = 0; i < lorePagesPer; i++) {
      expect(h.gainLorePage('r1', r), contains('(${i + 1}/$lorePagesPer)'));
    }
    expect(h.gainLorePage('r1', r), isNull);
    expect(h.loreDone('r1'), isTrue);
    expect(h.stats.maxHp, greaterThan(hp));
    expect(h.loreBonuses()[Bonus.hpPct], closeTo(0.02, 1e-9));
    for (final c in loreChapters.skip(1)) {
      for (var i = 0; i < lorePagesPer; i++) {
        h.gainLorePage(c.realm, r);
      }
    }
    expect(h.loreAllDone, isTrue);
    expect(h.seasonTitles, contains(loreTitle));
    final back = HeroData.fromJson(h.toJson());
    expect(back.lorePages.length, lorePageCount);
  });

  test('beating a bí cảnh always brings a page', () {
    final h = geared(14, Hanh.thuy);
    final (stars, w) = runRealm(h, 0);
    expect(stars, greaterThanOrEqualTo(1));
    expect(h.lorePagesOf('r1'), greaterThanOrEqualTo(1));
    expect(w.rewardLines.any((l) => l.startsWith('Trang Ký sự')), isTrue);
  });
}

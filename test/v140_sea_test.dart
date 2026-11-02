import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/lore.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/realm.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';

import 'v130_realm_test.dart' show geared, runRealm;

/// Fights on a field map on autopilot for [minutes]: kills and deaths.
(int, int) farm(HeroData h, MapDef m, {double minutes = 4, int seed = 5}) {
  final kills0 = h.kills;
  var deaths = 0;
  final w = World.field(h, m, seed: seed)..auto = true;
  for (var t = 0; t < minutes * 60 * 30; t++) {
    w.update(1 / 30);
    for (final e in w.events) {
      if (e.kind == EvKind.heroDied) {
        deaths++;
        w.reviveHere();
      }
    }
    w.events.clear();
  }
  return (h.kills - kills0, deaths);
}

void main() {
  test('Đông Hải sits in the lists by level, off the story road', () {
    expect(maps.contains(dongHaiMap), isFalse);
    final i = fieldMaps.indexOf(dongHaiMap);
    expect(fieldMaps[i - 1].id, 'magiao');
    expect(fieldMaps[i + 1].id, 'vanvu');
    expect(fieldMaps.last, huyetHaiMap);
    for (final id in [...dongHaiMap.mobs, dongHaiMap.boss]) {
      expect(mobById[id], isNotNull);
    }
    expect(dungeonById['dh1']!.map, dongHaiMap);
    for (var k = 1; k < dungeonList.length; k++) {
      expect(dungeonList[k].level, greaterThanOrEqualTo(dungeonList[k - 1].level));
    }
    for (var k = 1; k < realms.length; k++) {
      expect(realms[k].level, greaterThan(realms[k - 1].level));
    }
    expect(loreByRealm['r10'], isNotNull);
    expect(mountById['longma']!.source, MountSource.sea);
  });

  test('Đông Hải fights like the maps beside it', () {
    for (final hanh in Hanh.values) {
      final a = geared(68, hanh);
      final (seaKills, seaDeaths) = farm(a, dongHaiMap);
      final b = geared(68, hanh);
      final (mgKills, _) = farm(b, mapById['magiao']!);
      // ignore: avoid_print
      print('${hanh.name}: Đông Hải $seaKills kills $seaDeaths deaths · Ma Giáo $mgKills');
      expect(seaDeaths, lessThanOrEqualTo(2), reason: hanh.name);
      expect(seaKills, greaterThan(mgKills * 0.6), reason: hanh.name);
      expect(seaKills, lessThan(mgKills * 1.6), reason: hanh.name);
    }
  });

  test('Long Cung Thủy Phủ can be cleared at its level', () {
    for (final hanh in Hanh.values) {
      final h = geared(74, hanh);
      final w = World.dungeon(h, dungeonById['dh1']!, seed: 2)..auto = true;
      var cleared = false;
      while (!w.finished) {
        w.update(1 / 30);
        for (final e in w.events) {
          if (e.kind == EvKind.cleared) cleared = true;
          if (e.kind == EvKind.heroDied) w.reviveHere();
        }
        w.events.clear();
      }
      expect(cleared, isTrue, reason: hanh.name);
      expect(h.seaBossKills, 1, reason: hanh.name);
    }
  });

  test('Long Cung Hải Vực bí cảnh can be cleared and gives its pages', () {
    final i = realms.indexWhere((r) => r.id == 'r10');
    final h = geared(70, Hanh.moc);
    final (stars, _) = runRealm(h, i);
    expect(stars, greaterThanOrEqualTo(1));
    expect(h.lorePagesOf('r10'), greaterThanOrEqualTo(1));
  });

  test('Long Mã comes with the twentieth Long Vương', () {
    final h = geared(70, Hanh.kim);
    h.bossKillsById[dongHaiMap.boss] = 19;
    h.unlockMounts(quiet: true);
    expect(h.ownsMount('longma'), isFalse);
    h.bossKillsById[dongHaiMap.boss] = 20;
    h.unlockMounts(quiet: true);
    expect(h.ownsMount('longma'), isTrue);
  });

  test('a hero with the whole Ký sự before Đông Hải keeps its bonus', () {
    final h = HeroData(name: 'T', hanh: Hanh.kim)..level = 60;
    for (final c in loreChapters) {
      if (c.realm == 'r10') continue;
      for (var p = 0; p < lorePagesPer; p++) {
        h.lorePages.add(loreKey(c.realm, p));
      }
    }
    expect(h.loreAllDone, isFalse);
    h.seasonTitles.add(loreTitle);
    final withTitle = h.loreBonuses()[Bonus.atkPct]!;
    h.seasonTitles.remove(loreTitle);
    final without = h.loreBonuses()[Bonus.atkPct]!;
    expect(withTitle, closeTo(without + loreAllBonus[Bonus.atkPct]!, 1e-9));
  });
}

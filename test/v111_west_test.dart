import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/lore.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/realm.dart';
import 'package:kiem_hiep/core/world.dart';

import 'v130_realm_test.dart' show geared, runRealm;
import 'v140_sea_test.dart' show farm;

void main() {
  test('Tây Vực sits in the lists by level, off the story road', () {
    expect(maps.contains(tayVucMap), isFalse);
    expect(isSideMap(tayVucMap), isTrue);
    final i = fieldMaps.indexOf(tayVucMap);
    expect(fieldMaps[i - 1].id, 'bangnguyen');
    expect(fieldMaps[i + 1].id, 'hoadiem');
    for (final id in [...tayVucMap.mobs, tayVucMap.boss]) {
      expect(mobById[id], isNotNull, reason: id);
    }
    expect(dungeonById['tv1']!.map, tayVucMap);
    expect(dungeonById['tv2']!.map, tayVucMap);
    expect(realmById['r11']!.map, tayVucMap);
    expect(loreByRealm['r11'], isNotNull);
    expect(mountById['bachda']!.source, MountSource.west);
  });

  test('Tây Vực fights like Hỏa Diệm Sơn beside it', () {
    for (final hanh in Hanh.values) {
      final a = geared(50, hanh);
      final (kills, deaths) = farm(a, tayVucMap);
      final b = geared(50, hanh);
      final (hdKills, _) = farm(b, mapById['hoadiem']!);
      // ignore: avoid_print
      print('${hanh.name}: Tây Vực $kills kills $deaths deaths · Hỏa Diệm $hdKills');
      expect(deaths, lessThanOrEqualTo(2), reason: hanh.name);
      expect(kills, greaterThan(hdKills * 0.6), reason: hanh.name);
      expect(kills, lessThan(hdKills * 1.6), reason: hanh.name);
    }
  });

  test('both Tây Vực dungeons can be cleared at their level', () {
    for (final id in ['tv1', 'tv2']) {
      final d = dungeonById[id]!;
      for (final hanh in Hanh.values) {
        final h = geared(d.level, hanh);
        final w = World.dungeon(h, d, seed: 3)..auto = true;
        var cleared = false;
        while (!w.finished) {
          w.update(1 / 30);
          for (final e in w.events) {
            if (e.kind == EvKind.cleared) cleared = true;
            if (e.kind == EvKind.heroDied) w.reviveHere();
          }
          w.events.clear();
        }
        expect(cleared, isTrue, reason: '$id ${hanh.name}');
      }
    }
  });

  test('Thiên Phật Động can be cleared and gives its pages', () {
    final i = realms.indexWhere((r) => r.id == 'r11');
    final h = geared(47, Hanh.thuy);
    final (stars, _) = runRealm(h, i);
    expect(stars, greaterThanOrEqualTo(1));
    expect(h.lorePagesOf('r11'), greaterThanOrEqualTo(1));
  });

  test('Bạch Đà comes with the fifteenth Pháp Vương', () {
    final h = geared(50, Hanh.kim);
    h.bossKillsById[tayVucMap.boss] = 14;
    h.unlockMounts(quiet: true);
    expect(h.ownsMount('bachda'), isFalse);
    h.bossKillsById[tayVucMap.boss] = 15;
    h.unlockMounts(quiet: true);
    expect(h.ownsMount('bachda'), isTrue);
  });
}

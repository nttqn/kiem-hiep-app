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
  test('Miêu Cương and Côn Lôn sit in the lists by level, off the story road', () {
    for (final m in [mieuCuongMap, conLonMap]) {
      expect(maps.contains(m), isFalse);
      expect(isSideMap(m), isTrue);
      expect(mapById[m.id], m);
      for (final id in [...m.mobs, m.boss]) {
        expect(mobById[id], isNotNull, reason: id);
      }
    }
    var i = fieldMaps.indexOf(mieuCuongMap);
    expect(fieldMaps[i - 1].id, 'hacphong');
    expect(fieldMaps[i + 1].id, 'hoangsa');
    i = fieldMaps.indexOf(conLonMap);
    expect(fieldMaps[i - 1].id, 'hoason');
    expect(fieldMaps[i + 1], abyssMap);
    for (final id in ['mc1', 'mc2']) {
      expect(dungeonById[id]!.map, mieuCuongMap);
    }
    for (final id in ['kl1', 'kl2']) {
      expect(dungeonById[id]!.map, conLonMap);
    }
    expect(realmById['r12']!.map, mieuCuongMap);
    expect(realmById['r13']!.map, conLonMap);
    expect(loreByRealm['r12'], isNotNull);
    expect(loreByRealm['r13'], isNotNull);
    expect(mountById['hacbao']!.source, MountSource.south);
    expect(mountById['tienhac']!.source, MountSource.kunlun);
    // Realms stay in level order.
    for (var k = 1; k < realms.length; k++) {
      expect(realms[k].level, greaterThanOrEqualTo(realms[k - 1].level), reason: realms[k].id);
    }
  });

  test('Miêu Cương fights like Hắc Phong and Hoàng Sa beside it', () {
    for (final hanh in Hanh.values) {
      final (kills, deaths) = farm(geared(28, hanh), mieuCuongMap);
      final (hsKills, _) = farm(geared(28, hanh), mapById['hoangsa']!);
      // ignore: avoid_print
      print('${hanh.name}: Miêu Cương $kills kills $deaths deaths · Hoàng Sa $hsKills');
      expect(deaths, lessThanOrEqualTo(2), reason: hanh.name);
      expect(kills, greaterThan(hsKills * 0.6), reason: hanh.name);
      expect(kills, lessThan(hsKills * 1.6), reason: hanh.name);
    }
  });

  test('Côn Lôn fights like Hoa Sơn beside it', () {
    for (final hanh in Hanh.values) {
      final (kills, deaths) = farm(geared(92, hanh), conLonMap);
      final (hsKills, _) = farm(geared(92, hanh), mapById['hoason']!);
      // ignore: avoid_print
      print('${hanh.name}: Côn Lôn $kills kills $deaths deaths · Hoa Sơn $hsKills');
      expect(deaths, lessThanOrEqualTo(2), reason: hanh.name);
      expect(kills, greaterThan(hsKills * 0.6), reason: hanh.name);
      expect(kills, lessThan(hsKills * 1.4), reason: hanh.name);
    }
  });

  test('the four new dungeons can be cleared at their level', () {
    for (final id in ['mc1', 'mc2', 'kl1', 'kl2']) {
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

  test('both new bí cảnh can be cleared and give their pages', () {
    for (final (id, lv) in [('r12', 27), ('r13', 95)]) {
      final i = realms.indexWhere((r) => r.id == id);
      final h = geared(lv, Hanh.thuy);
      final (stars, _) = runRealm(h, i);
      expect(stars, greaterThanOrEqualTo(1), reason: id);
      expect(h.lorePagesOf(id), greaterThanOrEqualTo(1), reason: id);
    }
  });

  test('Côn Lôn gives Thần Thiết and Tinh Hoa', () {
    final h = geared(95, Hanh.kim);
    final iron0 = h.divineIron, ess0 = h.essence;
    farm(h, conLonMap);
    expect(h.divineIron, greaterThan(iron0));
    expect(h.essence, greaterThan(ess0));
  });

  test('the new mounts come with their bosses', () {
    final h = geared(95, Hanh.kim);
    h.bossKillsById[mieuCuongMap.boss] = 11;
    h.bossKillsById[conLonMap.boss] = 24;
    h.unlockMounts(quiet: true);
    expect(h.ownsMount('hacbao'), isFalse);
    expect(h.ownsMount('tienhac'), isFalse);
    h.bossKillsById[mieuCuongMap.boss] = 12;
    h.bossKillsById[conLonMap.boss] = 25;
    h.unlockMounts(quiet: true);
    expect(h.ownsMount('hacbao'), isTrue);
    expect(h.ownsMount('tienhac'), isTrue);
  });
}

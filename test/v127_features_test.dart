import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/costumes.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/game/battle_game.dart';

void main() {
  group('Cửu U Ma Vực', () {
    test('kept out of the story maps, found by id, every monster defined', () {
      expect(maps.contains(abyssMap), isFalse);
      expect(mapById['cuuu'], same(abyssMap));
      for (final id in [...abyssMap.mobs, abyssMap.boss]) {
        expect(mobById[id], isNotNull, reason: id);
      }
      expect(abyssMap.entryLv, abyssEntryLv);
    });

    test('its monsters are scaled up; Hoa Sơn\'s are not', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..rebirths = 5;
      final w = World.field(h, abyssMap, seed: 1);
      final tiger = w.mobs.firstWhere((m) => m.def.id == 'abyssTiger');
      final plain = Mob(0, tiger.def, tiger.level, 0, 0);
      expect(tiger.maxHp, closeTo(plain.maxHp * abyssMul, 1e-6));
      expect(tiger.atk, closeTo(plain.atk * abyssMul, 1e-6));
      expect(w.hasPond, isFalse);
      final hs = World.field(h, mapById['hoason']!, seed: 1);
      final g = hs.mobs.first;
      expect(g.maxHp, closeTo(Mob(0, g.def, g.level, 0, 0).maxHp, 1e-6));
    });

    test('Ma Tôn kills unlock the outfit at 10 and the mount at 30', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..rebirths = 5;
      final lord = mobById[abyssMap.boss]!;
      for (var i = 0; i < 9; i++) {
        h.onKill(lord, math.Random(i));
      }
      h.unlockCostumes();
      expect(h.ownedCostumes.contains('cuuu'), isFalse);
      h.onKill(lord, math.Random(9));
      h.unlockCostumes();
      expect(h.ownedCostumes, contains('cuuu'));
      expect(h.ownsMount('huyenminh'), isFalse);
      for (var i = 0; i < 20; i++) {
        h.onKill(lord, math.Random(i));
      }
      h.unlockCostumes();
      expect(h.ownsMount('huyenminh'), isTrue);
      expect(costumeById['cuuu']!.howTo, contains('Cửu U Ma Tôn'));
      expect(mountById['huyenminh']!.howTo, contains('30'));
    });
  });

  group('Phát hiện máy giật', () {
    BattleGame game(void Function(double) onSlow) => BattleGame(
          world: World.field(HeroData(name: 'T', hanh: Hanh.kim), maps.first, seed: 1),
          onEvent: (_) {},
          onSound: (_) {},
          onSlow: onSlow,
        );

    test('a slow phone is reported once, a smooth one never', () {
      final slow = <double>[];
      final g = game(slow.add);
      for (var i = 0; i < 20 * 20; i++) {
        g.update(1 / 20);
      }
      expect(slow, hasLength(1));
      expect(slow.single, closeTo(20, 1));

      final smooth = <double>[];
      final s = game(smooth.add);
      for (var i = 0; i < 60 * 20; i++) {
        s.update(1 / 60);
      }
      expect(smooth, isEmpty);
    });

    test('paused time does not count', () {
      final slow = <double>[];
      final g = game(slow.add)..halted = true;
      for (var i = 0; i < 20 * 20; i++) {
        g.update(1 / 20);
      }
      expect(slow, isEmpty);
    });
  });
}

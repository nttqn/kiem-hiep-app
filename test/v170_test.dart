import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/body_train.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/mount_skins.dart';
import 'package:kiem_hiep/core/mounts.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';

void main() {
  group('Đánh khi chạy', () {
    for (final hanh in [Hanh.kim, Hanh.moc]) {
      test('${hanh.name}: holding attack while steering hits what is in reach and keeps moving', () {
        final h = HeroData(name: 'R', hanh: hanh)..level = 10;
        final w = World.field(h, maps.first, seed: 3);
        w.mobs.clear();
        final p = w.player;
        final m = Mob(999, mobById[maps.first.mobs.first]!, 1, p.x + 50, p.y)..maxHp = 1e9;
        m.hp = 1e9;
        w.mobs.add(m);
        final x0 = p.x;
        w.input
          ..moveY = 1
          ..attack = true;
        for (var i = 0; i < 30; i++) {
          w.update(1 / 30);
          m
            ..x = p.x + 50
            ..y = p.y;
        }
        expect(m.hp, lessThan(1e9), reason: 'the monster was hit');
        expect((p.y - 0).abs(), greaterThan(0));
        expect(p.x, closeTo(x0, 1), reason: 'did not walk over to it');
        expect(p.moving, isTrue);
      });
    }
  });

  group('Luyện thể', () {
    test('closed below the third rebirth; training spends iron and gold and raises power', () {
      final h = HeroData(name: 'L', hanh: Hanh.hoa)
        ..level = 99
        ..rebirths = 2
        ..divineIron = 1000
        ..gold = 100000000;
      expect(h.bodyBlock(0), BodyBlock.closed);
      h.rebirths = 3;
      h.recompute();
      final p0 = h.power;
      expect(h.trainBody(4), isTrue);
      expect(h.bodyLv[4], 1);
      expect(h.divineIron, 1000 - bodyIronCost(0));
      expect(h.gold, 100000000 - bodyGoldCost(0));
      expect(h.power, greaterThan(p0));
    });

    test('levels 11 and 21 need rebirths and Linh Phách Đơn', () {
      final h = HeroData(name: 'L', hanh: Hanh.kim)
        ..rebirths = 3
        ..divineIron = 100000
        ..gold = 1000000000;
      for (var i = 0; i < 10; i++) {
        expect(h.trainBody(1), isTrue);
      }
      expect(h.bodyBlock(1), BodyBlock.rebirth);
      h.rebirths = 5;
      expect(h.bodyBlock(1), BodyBlock.pills);
      h.soulPills = 10;
      expect(h.trainBody(1), isTrue);
      expect(h.soulPills, 0);
      for (var i = 0; i < 9; i++) {
        expect(h.trainBody(1), isTrue);
      }
      expect(h.bodyBlock(1), BodyBlock.rebirth);
      h
        ..rebirths = 6
        ..soulPills = 20;
      while (h.trainBody(1)) {}
      expect(h.bodyLv[1], bodyMax);
      expect(h.bodyBlock(1), BodyBlock.maxed);
    });

    test('cảnh giới bonuses by total level, saved and loaded', () {
      expect(bodyRealmOf(29), isNull);
      expect(bodyRealmOf(30)!.name, 'Đồng Bì');
      expect(bodyRealmOf(150)!.name, 'Bất Hoại Kim Thân');
      final b = bodyBonuses([30, 30, 30, 30, 30]);
      expect(b[Bonus.atkPct], closeTo(0.3 + 0.08 + 0.1, 1e-9));
      final h = HeroData(name: 'L', hanh: Hanh.tho)..bodyLv.setAll(0, [3, 1, 4, 1, 5]);
      final back = HeroData.fromJson(h.toJson());
      expect(back.bodyLv, [3, 1, 4, 1, 5]);
      expect(HeroData.fromJson({...h.toJson()}..remove('lt')).bodyLv, [0, 0, 0, 0, 0]);
    });
  });

  group('Ngoại hình thú cưỡi', () {
    test('every look belongs to a real mount and ids are unique', () {
      expect(skinById.length, mountSkins.length);
      for (final s in mountSkins) {
        expect(mountById.containsKey(s.mount), isTrue, reason: s.id);
        expect(s.aura == 0 || s.aura >> 24 == 0xFF, isTrue);
      }
    });

    test('buy a look, wear it, stats unchanged; saved and loaded', () {
      final s = skinById['phikiem_tu']!;
      final h = HeroData(name: 'S', hanh: Hanh.thuy)
        ..level = 99
        ..arenaCoins = 30000;
      expect(h.canGetSkin(s), isFalse, reason: 'needs the mount first');
      h
        ..mountLevels['phikiem'] = 5
        ..activeMount = 'phikiem'
        ..riding = true
        ..recompute();
      final power = h.power;
      expect(h.getSkin(s), isTrue);
      expect(h.arenaCoins, 30000 - s.need);
      expect(h.ridingMount!.c2, s.c2);
      expect(h.ridingMount!.aura, s.aura);
      h.recompute();
      expect(h.power, power);
      final back = HeroData.fromJson(h.toJson());
      expect(back.ownsSkin(s.id), isTrue);
      expect(back.ridingMount!.c2, s.c2);
      back.wearSkin('phikiem', null);
      expect(back.ridingMount!.c2, mountById['phikiem']!.c2);
    });

    test('a tower look is claimed for free once the floor is reached', () {
      final s = skinById['phikiem_hoa']!;
      final h = HeroData(name: 'S', hanh: Hanh.thuy)..mountLevels['phikiem'] = 1;
      h.towerBest = s.need - 1;
      expect(h.getSkin(s), isFalse);
      h.towerBest = s.need;
      final gold = h.gold;
      expect(h.getSkin(s), isTrue);
      expect(h.gold, gold);
    });
  });
}

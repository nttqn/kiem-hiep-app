import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/world.dart';

void main() {
  group('Chạm một lần để tự đánh', () {
    World near() {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..level = 30;
      final w = World.field(h, mapById['hoason']!, seed: 1);
      final m = w.mobs.first;
      w.mobs
        ..clear()
        ..add(m);
      m.x = w.player.x + 40;
      m.y = w.player.y;
      return w;
    }

    test('keeps hitting the monster in reach without the button held', () {
      final w = near();
      final m = w.mobs.first;
      final hp = m.hp;
      w.engaged = true;
      for (var i = 0; i < 120; i++) {
        w.update(1 / 60);
      }
      expect(m.hp, lessThan(hp));
    });

    test('stops when the joystick moves', () {
      final w = near()..engaged = true;
      w.input.moveX = 1;
      w.update(1 / 60);
      expect(w.engaged, isFalse);
    });

    test('stops when nothing is left in reach', () {
      final w = near();
      w.mobs.clear();
      w.engaged = true;
      w.update(1 / 60);
      expect(w.engaged, isFalse);
    });
  });
}

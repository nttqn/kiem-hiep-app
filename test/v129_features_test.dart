import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';

void main() {
  group('Linh Phách Đơn', () {
    HeroData maxed({int rebirths = maxRebirths}) {
      final h = HeroData(name: 'T', hanh: Hanh.kim)
        ..rebirths = rebirths
        ..level = maxLevel;
      h.exp = expToNext(maxLevel);
      return h;
    }

    test('a million EXP past the last rebirth makes one pill', () {
      final h = maxed();
      final raw = h.soulPillExp / (1 + rebirthExp * h.rebirths);
      h.gainExp(raw * 0.99);
      expect(h.soulPills, 0);
      h.gainExp(raw * 0.02);
      expect(h.soulPills, 1);
      h.gainExp(raw * 2.5);
      expect(h.soulPills, 3);
      expect(h.soulExp, lessThan(h.soulPillExp));
    });

    test('nothing condenses while a rebirth is still to come', () {
      final h = maxed(rebirths: maxRebirths - 1);
      h.gainExp(h.soulPillExp * 10.0);
      expect(h.soulPills, 0);
      expect(h.soulExp, 0);
    });

    test('five pills trade for one Thần Thiết, and they survive a save', () {
      final h = maxed()
        ..soulPills = 7
        ..soulExp = 123;
      final iron = h.divineIron;
      expect(h.soulToIron(), isTrue);
      expect(h.soulToIron(), isFalse);
      expect(h.divineIron, iron + 1);
      final back = HeroData.fromJson(h.toJson());
      expect(back.soulPills, 2);
      expect(back.soulExp, 123);
    });
  });
}

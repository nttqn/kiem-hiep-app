import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/divine.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/ngo_dao.dart';
import 'package:kiem_hiep/core/sects.dart';

HeroData top({int rebirths = 6}) {
  final h = HeroData(name: 'T', hanh: Hanh.hoa)
    ..level = 99
    ..rebirths = rebirths
    ..divine = divineMax
    ..divineIron = 100000
    ..gold = 2000000000;
  h.recompute();
  return h;
}

void main() {
  group('Tiên binh past tầng 20 (1.13.3)', () {
    test('only in the sixth rebirth', () {
      final h = top(rebirths: 5);
      expect(h.divineTienLocked, isTrue);
      expect(h.upgradeDivine(), isFalse);
      h.rebirths = 6;
      expect(h.upgradeDivine(), isTrue);
      expect(h.divine, divineMax + 1);
    });

    test('each level costs more Thần Thiết and gold and adds 1% attack and HP', () {
      final h = top();
      var power = h.power;
      for (var lv = divineMax; lv < divineMax + 30; lv++) {
        final iron = h.divineIron, gold = h.gold;
        expect(h.upgradeDivine(), isTrue);
        expect(iron - h.divineIron, 250 + 25 * (lv - divineMax));
        expect(gold - h.gold, 300000 * (lv - divineMax + 1));
        expect(h.power, greaterThan(power));
        power = h.power;
      }
      final b = divineBonuses(divineMax + 30);
      expect(b[Bonus.atkPct], closeTo(divineStatPerLv * divineMax + 0.30, 1e-9));
      expect(divineStage(divineMax + 30), 'Tiên binh');
      expect(divineStrikePower(divineMax + 30), divineStrikePower(divineMax), reason: 'Giáng Thế stops growing at 20');
      final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(back.divine, divineMax + 30, reason: 'kept past 20 on load');
    });

    test('Nhân Long\'s 11,300 Thần Thiết go about 25 levels', () {
      var iron = 11300, lv = divineMax;
      while (iron >= divineIronAt(lv)) {
        iron -= divineIronAt(lv);
        lv++;
      }
      expect(lv - divineMax, inInclusiveRange(20, 30));
    });
  });

  test('Linh Phách Đơn still needed for every Độ kiếp ahead', () {
    expect(kiepPillsAhead(0), 50 * (1 + 2 + 3 + 4 + 5 + 6 + 7 + 8));
    expect(kiepPillsAhead(9), kiepPillsAhead(0), reason: 'the gate at 9 still to pass');
    expect(kiepPillsAhead(10), kiepPillsAhead(0) - 50);
    expect(kiepPillsAhead(72), 400);
    expect(kiepPillsAhead(73), 0);
  });
}

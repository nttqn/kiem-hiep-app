import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/meridians.dart';

void main() {
  test('Tẩy kinh mạch gives every point back for gold (1.13.3)', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc)
      ..level = 99
      ..rebirths = 2
      ..skillPoints = 40
      ..gold = 10000000;
    h.recompute();
    expect(h.resetMeridians(), isFalse, reason: 'nothing to give back');
    h.trainMeridian(1, 30);
    h.trainMeridian(3, 10);
    final crit = h.stats.crit;
    expect(h.skillPoints, 0);
    final gold = h.gold;
    expect(h.resetMeridians(), isTrue);
    expect(h.skillPoints, 40);
    expect(h.meridianPts.every((v) => v == 0), isTrue);
    expect(h.gold, gold - h.meridianResetCost);
    expect(h.stats.crit, lessThan(crit));
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.skillPoints, 40);
    h.trainMeridian(0, 5);
    h.gold = h.meridianResetCost - 1;
    expect(h.resetMeridians(), isFalse, reason: 'short of gold');
    expect(h.meridianPts[0], 5);
  });

  test('the caps shown are the ones applied', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc)..spent[1] = 100000;
    h.recompute();
    expect(h.stats.crit, critCap);
    expect(h.stats.aspd, aspdCap);
  });
}

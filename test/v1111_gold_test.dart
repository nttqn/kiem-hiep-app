import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/core/rewards.dart';

void main() {
  test('Hòm Ngân Lượng grows with level and rebirths, below a month of Nguyệt thẻ gold at the top', () {
    expect(goldPackFor(30, 0), 400000);
    expect(goldPackFor(99, 5), 6540000);
    final h = HeroData(name: 'G', hanh: Hanh.kim)
      ..level = 60
      ..rebirths = 1;
    final g0 = h.gold;
    expect(h.grantGoldPack(), ['+${goldPackFor(60, 1)} lượng']);
    expect(h.gold, g0 + goldPackFor(60, 1));
    expect(allSkus, contains(skuGoldPack));
    for (final cs in [0, 3, 5, 6]) {
      expect(goldPackFor(99, cs), lessThan(cardDailyFor(99, cs).gold * monthCardDays * 1.2), reason: 'cs$cs');
    }
  });

  test('closed-door training gold grows with rebirths too', () {
    final a = HeroData(name: 'A', hanh: Hanh.kim)..level = 99;
    final b = HeroData(name: 'B', hanh: Hanh.kim)
      ..level = 99
      ..rebirths = 4;
    final ga = offlineReward(a, const Duration(hours: 2))!.gold;
    final gb = offlineReward(b, const Duration(hours: 2))!.gold;
    expect(gb, closeTo(ga * (1 + rebirthGold * 4), 2));
  });
}

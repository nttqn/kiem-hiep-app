import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/hoard_check.dart';

void main() {
  test('every gold change lands in the ledger', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc);
    h.gold += 5000;
    h.gold -= 1200;
    h.gold = 300;
    expect(h.goldIn, 80 + 5000);
    expect(h.goldOut, 1200 + 3580);
    expect(h.goldUnaccounted, 0);
  });

  test('the ledger survives a save round trip', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc)
      ..gold += 900000
      ..gold -= 400000;
    final back = HeroData.fromJson(h.toJson());
    expect(back.gold, h.gold);
    expect(back.goldIn, h.goldIn);
    expect(back.goldOut, h.goldOut);
    expect(back.goldUnaccounted, 0);
    expect(hoardReason(back), isNull);
  });

  test('a save from before the ledger opens it with its gold', () {
    final json = (HeroData(name: 'T', hanh: Hanh.moc)..gold = 588080660).toJson()..remove('gl');
    final back = HeroData.fromJson(json);
    expect(back.goldIn - back.goldOut, 588080660);
    expect(back.goldUnaccounted, 0);
  });

  test('gold edited by hand is caught', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc)..gold += 2000000;
    final json = h.toJson()..['gold'] = 500000000;
    final back = HeroData.fromJson(json);
    expect(back.goldUnaccounted, 500000000 - h.gold);
    expect(hoardReason(back), 'gold');
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/ledger.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/core/weekly_hunt.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;

void main() {
  test('Hộp Tinh Phách: souls, weekly count, saved, counted as paid', () {
    final h = HeroData(name: 'P', hanh: Hanh.moc);
    expect(allSkus, contains(skuSoulPack));
    expect(h.soulPacksLeft, soulPackPerWeek);
    expect(h.paidAny, isFalse);
    h.grantSoulPack();
    expect(h.beastSouls, soulPackSouls);
    expect(h.soulPacksLeft, soulPackPerWeek - 1);
    for (var i = 0; i < soulPackPerWeek; i++) {
      h.grantSoulPack(); // a purchase past the limit still delivers
    }
    expect(h.soulPacksLeft, 0);
    expect(h.soulsBought, soulPackSouls * (soulPackPerWeek + 1));
    expect(h.paidAny, isTrue);
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.soulsBought, h.soulsBought);
    expect(back.soulPacksLeft, 0);
    expect(back.beastSouls, h.beastSouls);
  });

  test('bought souls are allowed past the ceiling, within the buy cap', () {
    final wk = huntWeekOf(vnDayKey());
    final h = HeroData(name: 'P', hanh: Hanh.moc)
      ..soulsBought = 40
      ..beastSouls = soulCeiling(wk) + 40;
    h.clampEdited();
    expect(h.beastSouls, soulCeiling(wk) + 40);
    h
      ..soulsBought = 99999
      ..beastSouls = 99999;
    h.clampEdited();
    expect(h.beastSouls, soulCeiling(wk) + soulBuyCap(wk));
  });
}

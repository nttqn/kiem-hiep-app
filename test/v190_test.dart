import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/gem_extras.dart';
import 'package:kiem_hiep/core/gems.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/core/sects.dart' show Bonus;
import 'package:kiem_hiep/core/tower.dart';

HeroData _hero() => HeroData(name: 'P', hanh: Hanh.hoa)
  ..level = 99
  ..rebirths = 6;

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  test('crit damage: full to +800%, half above', () {
    expect(critDmgSoftCap(2), 2);
    expect(critDmgSoftCap(8), 8);
    expect(critDmgSoftCap(12), 10);
    final h = _hero();
    final g = Gem(Hanh.hoa, 7);
    h.recompute();
    final base = h.stats.critDmg;
    expect(base, 1.5 + critDmgSoftCap(h.allBonuses()[Bonus.critDmg] ?? 0), reason: 'the stat goes through the cap');
    expect(g.tier, 7);
  });

  group('Thiên gems (tier 8)', () {
    test('three Thánh and a Tinh Phách make one; rewards never pay one', () {
      final h = _hero()..gold = 10000000;
      const thanh = Gem(Hanh.kim, 7);
      h.addGem(thanh, 3);
      expect(h.fuseGem(thanh), isFalse, reason: 'no Tinh Phách');
      h.beastSouls = 1;
      expect(h.fuseGem(thanh), isTrue);
      expect(h.gemCount(const Gem(Hanh.kim, 8)), 1);
      expect(h.beastSouls, 0);
      expect(Gem.parse('0:8'), const Gem(Hanh.kim, 8));
      expect(const Gem(Hanh.kim, 8).name, contains('Thiên'));
      expect(gemEffect(const Gem(Hanh.kim, 8))[Bonus.atkPct], closeTo(0.025 * 9.5, 1e-9));
      expect(towerGemTier(999), maxRewardGemTier);
      // Hợp tất cả stops at Thánh.
      h.addGem(const Gem(Hanh.moc, 7), 9);
      expect(h.fusePlan(8).made, isEmpty);
      expect(_roundTrip(h).gemCount(const Gem(Hanh.kim, 8)), 1);
    });
  });

  test('Gói Thăng Tinh: stones and souls, marked for the week, kept in a save', () {
    final h = _hero();
    expect(h.starPackThisWeek, isFalse);
    final s0 = h.starStones, b0 = h.beastSouls;
    expect(h.grantStarPack(), hasLength(2));
    expect(h.starStones, s0 + starPackStones);
    expect(h.beastSouls, b0 + starPackSouls);
    expect(h.starPackThisWeek, isTrue);
    expect(_roundTrip(h).starPackThisWeek, isTrue);
    expect(allSkus, contains(skuStarPack));
  });
}

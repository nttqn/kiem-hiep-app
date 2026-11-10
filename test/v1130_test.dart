import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/ngo_dao.dart';
import 'package:kiem_hiep/core/spar.dart';
import 'package:kiem_hiep/core/tien_khi.dart';
import 'package:kiem_hiep/render/art_figures.dart';
import 'package:kiem_hiep/services/leaderboard.dart';

HeroData _top() {
  final h = HeroData(name: 'T', hanh: Hanh.thuy)
    ..level = 99
    ..rebirths = 6
    ..gold = 100000000;
  for (final s in Slot.values) {
    h.equip[s] = makeItem(slot: s, level: 95, rarity: Rarity.legend, sect: h.sect, rng: math.Random(s.index))
      ..plus = maxPlus;
  }
  h.recompute();
  return h;
}

HeroData _load(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  group('Tỉ thí', () {
    test('five a day, no Lôi đài points, a little Uy danh, saved', () {
      final h = HeroData(name: 'S', hanh: Hanh.kim)..level = 40;
      final pts = h.arenaPoints;
      for (var i = 0; i < sparPerDay; i++) {
        expect(h.sparStart('20261111'), isTrue);
      }
      expect(h.sparStart('20261111'), isFalse);
      final coins = h.arenaCoins;
      h.sparResult(true);
      h.sparResult(false);
      expect(h.arenaCoins, coins + sparWinCoins + sparLossCoins);
      expect(h.arenaPoints, pts);
      expect(h.sparWins, 1);
      final b = _load(h);
      expect([b.sparDay, b.sparCount, b.sparWins], ['20261111', sparPerDay, 1]);
      expect(b.sparLeft('20261112'), sparPerDay);
    });

    test('a low hero cannot spar', () {
      final h = HeroData(name: 'L', hanh: Hanh.kim)..level = 10;
      expect(h.sparStart('20261111'), isFalse);
    });

    test('the copy wears what the board row says', () {
      final h = _top();
      final e = LbEntry.fromDoc('u_0', jsonDecode(jsonEncode({
        'name': 'X', 'hanh': 1, 'level': 99, 'rebirths': 6, 'power': h.power, 'look': lookRow(h),
      })) as Map<String, dynamic>)!;
      final r = e.toRival();
      expect(rivalGear(r), HeroGear.of(h.equip, hideHat: h.hideHat, divine: h.divine));
      final def = sparDef(r);
      expect(def.spar, isTrue);
      expect(def.isArena, isTrue);
      // A row from an older app: gear fitting the level.
      final old = LbEntry.fromDoc('u_1', {'name': 'Y', 'hanh': 0, 'level': 60, 'power': 5})!.toRival();
      expect(rivalGear(old).weapon, 3);
    });
  });

  group('Tiên khí', () {
    test('needs Ngộ Đạo, +10, the cảnh giới, jade and gold', () {
      final h = _top();
      final w = h.equip[Slot.weapon]!;
      expect(tienBlock(h, w), isNotNull); // not in Ngộ Đạo yet
      h.daoLv = 1;
      expect(tienBlock(h, w), 'Thiếu Tiên Ngọc');
      h.tienJade = 100;
      final atk = h.stats.atk;
      expect(h.tienForge(w), isTrue);
      expect(w.tien, 1);
      expect(h.tienJade, 100 - tienJadeCost[0]);
      expect(h.stats.atk, greaterThan(atk));
      // Phẩm 2 needs Trúc Cơ.
      expect(tienBlock(h, w), 'Cần cảnh giới ${daoStages[1].name}');
      h.daoLv = daoLayers + 1;
      expect(h.tienForge(w), isTrue);
      final ring = h.equip[Slot.ring]!..plus = 5;
      expect(tienBlock(h, ring), 'Cần cường hóa +$maxPlus');
    });

    test('phẩm is saved on the item and shown in the title', () {
      final it = makeItem(slot: Slot.hat, level: 90, rarity: Rarity.epic, sect: _top().sect, rng: math.Random(3))
        ..plus = maxPlus
        ..tien = 4;
      final b = Item.fromJson(jsonDecode(jsonEncode(it.toJson())) as Map<String, dynamic>);
      expect(b.tien, 4);
      expect(b.title, contains('Tiên 4'));
      expect(b.baseMul, closeTo(it.baseMul, 1e-9));
    });

    test('jade from new tầng and from Độ kiếp, saved', () {
      final h = _top();
      h.gainDao(daoCost(0) + daoCost(1) + 10.0);
      expect(h.daoLv, 2);
      expect(h.tienJade, 2 * daoLayerJade);
      h.daoLv = daoLayers;
      h.daoExp = daoCost(daoLayers);
      h.soulPills = 1000;
      h.tienJade = 0;
      h.kiepResult(true);
      expect(h.daoLv, daoLayers + 1);
      expect(h.tienJade, kiepJade(1));
      expect(_load(h).tienJade, kiepJade(1));
    });
  });
}

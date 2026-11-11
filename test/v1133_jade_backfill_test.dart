import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/tien_khi.dart';

HeroData load(Map<String, dynamic> m) => HeroData.fromJson(jsonDecode(jsonEncode(m)) as Map<String, dynamic>);

void main() {
  test('Tiên Ngọc Ngộ Đạo pays on the way up', () {
    expect(daoJadeTotal(0), 0);
    expect(daoJadeTotal(9), 9, reason: 'Luyện Khí: one a tầng');
    expect(daoJadeTotal(10), 14, reason: 'the Độ kiếp into Trúc Cơ pays 5');
    expect(daoJadeTotal(12), 16);
    expect(daoJadeTotal(19), 9 + 5 + 8 + 10);
  });

  group('backfill for Ngộ Đạo reached before 1.13.0 (1.13.3)', () {
    Map<String, dynamic> old({int dao = 12, int jade = 0}) {
      final h = HeroData(name: 'T', hanh: Hanh.moc)
        ..level = 99
        ..rebirths = 6
        ..daoLv = dao
        ..tienJade = jade;
      return h.toJson()
        ..remove('tk');
    }

    test('a hero at tầng 12 with none gets what the climb pays, once', () {
      final h = load(old());
      expect(h.tienJade, 16);
      expect(h.notices.any((n) => n.text.contains('Bù 16 Tiên Ngọc')), isTrue);
      final again = load(h.toJson());
      expect(again.tienJade, 16, reason: 'paid once');
      expect(again.tienBackfilled, isTrue);
    });

    test('Tiên Ngọc already had or forged into gear counts', () {
      final m = old(dao: 16)..['tk'] = [2];
      final h0 = load(m);
      expect(h0.tienJade, daoJadeTotal(16), reason: 'topped up from 2');
      // Spent 2 on a phẩm: none in hand, 2 in the gear, and a forged piece
      // in the bag (3 more) counts as well.
      Item piece(Slot sl, int tien) => Item(
          slot: sl, level: 99, rarity: Rarity.legend, base: const {}, bonus: const {}, name: "X", plus: 10, tien: tien);
      final h = load(old(dao: 16))
        ..tienBackfilled = false
        ..tienJade = 0;
      h.equip[Slot.weapon] = piece(Slot.weapon, 1);
      h.bag.add(piece(Slot.hat, 2));
      final back = load(h.toJson()..remove("tk"));
      expect(back.tienJade, daoJadeTotal(16) - 2 - 5);
    });

    test('a hero with as much as the climb pays, or more, gets nothing', () {
      final h = load(old(dao: 12)..['tk'] = [40]);
      expect(h.tienJade, 40);
      expect(h.notices.where((n) => n.text.contains('Tiên Ngọc')), isEmpty);
      final none = load(old(dao: 0));
      expect(none.tienJade, 0);
    });

  });
}

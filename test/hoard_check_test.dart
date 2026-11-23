import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/hoard_check.dart';

HeroData hero({required int divine, required int iron, required int shards, required double play}) =>
    HeroData(name: 'T', hanh: Hanh.moc)
      ..divine = divine
      ..divineIron = iron
      ..goldShards = shards
      ..playSeconds = play;

void main() {
  test('divineIronTotal matches the cost table', () {
    expect(divineIronTotal(0), 0);
    expect(divineIronTotal(20), 2058);
    expect(divineIronTotal(100), 2058 + 99000);
  });

  // Real saves read on 2026-11-23.
  test('the edited save is caught', () {
    final h = hero(divine: 158, iron: 257164, shards: 491947, play: 223370);
    expect(hoardReason(h), 'iron');
    expect(hoardReason(h..divine = 0..divineIron = 0), 'shards');
  });

  test('top real farmers pass', () {
    // TranQuanKyy: Tiên binh 100 after 219 h of auto-fight.
    expect(hoardReason(hero(divine: 100, iron: 3339, shards: 30, play: 790349)), isNull);
    // Nhân Long: farmed the re-entry boss bug (fixed in 1.24.1), 313k iron.
    expect(hoardReason(hero(divine: 76, iron: 258422, shards: 2544, play: 781578)), isNull);
    // PoPo-like: 70 after 360 h.
    expect(hoardReason(hero(divine: 70, iron: 5000, shards: 3000, play: 360 * 3600)), isNull);
    // A new hero.
    expect(hoardReason(hero(divine: 0, iron: 0, shards: 0, play: 0)), isNull);
  });

  test('the rules formula agrees with divineIronTotal', () {
    for (var dv = 21; dv <= 300; dv++) {
      final n = dv - 20;
      expect(4116 + 500 * n + 25 * n * (n - 1), 2 * divineIronTotal(dv));
    }
  });
}

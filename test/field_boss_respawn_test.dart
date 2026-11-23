import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/world.dart';

void main() {
  test('a boss felled lately waits out the rest of its respawn', () {
    const now = 1795444000000;
    expect(fieldBossWait(null, now), 0);
    expect(fieldBossWait(now - 20000, now), closeTo(130, 0.01)); // re-entered after 20 s
    expect(fieldBossWait(now - 200000, now), 0); // long gone
    expect(fieldBossWait(now + 60000, now), fieldBossRespawnSec); // clock set back
  });

  test('boss kill times survive a save round trip', () {
    final h = HeroData(name: 'T', hanh: Hanh.moc)..fieldBossAt['huyethai'] = 1795444000000;
    final back = HeroData.fromJson(h.toJson());
    expect(back.fieldBossAt['huyethai'], 1795444000000);
  });
}

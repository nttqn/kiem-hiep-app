import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/live_event.dart';

void main() {
  tearDown(() => liveEvents = const []);

  test('Song Bội Đan and an EXP event do not stack: the better one counts', () {
    final h = HeroData(name: 'T', hanh: Hanh.hoa);
    expect(h.expMul, 1);
    h.buffs['songboi'] = 600;
    expect(h.expMul, 2);
    liveEvents = [const LiveEvent(id: 'x2', exp: 2)];
    expect(h.expMul, 2);
    liveEvents = [const LiveEvent(id: 'x3', exp: 3)];
    expect(h.expMul, 3);
    h.buffs.remove('songboi');
    liveEvents = [const LiveEvent(id: 'x15', exp: 1.5)];
    expect(h.expMul, 1.5);
  });
}

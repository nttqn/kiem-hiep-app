import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/clock.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;

void main() {
  late int device, mono;
  const day = 86400000;
  final t0 = DateTime.utc(2026, 11, 2, 3).millisecondsSinceEpoch; // 10:00 in Vietnam

  setUp(() {
    GameClock.reset();
    device = t0;
    mono = 0;
    GameClock.deviceMs = () => device;
    GameClock.monoMs = () => mono;
  });
  tearDown(GameClock.reset);

  test('once the server is known, moving the phone clock changes nothing', () {
    GameClock.synced(t0);
    device += 3 * day; // the player sets the date ahead
    mono += 60000; // a minute really passes
    expect(GameClock.nowMs(), t0 + 60000);
    expect(vnDayKey(), '20261102');
    expect(GameClock.deviceSkewMs, greaterThan(2 * day));
  });

  test('a phone already set ahead is pulled back by the server', () {
    device = t0 + 2 * day;
    expect(vnDayKey(), '20261104');
    GameClock.synced(t0);
    expect(vnDayKey(), '20261102');
  });

  test('offline, the clock never runs back before what was trusted', () {
    GameClock.floor = t0;
    device = t0 - day; // the date set back to replay yesterday
    expect(GameClock.nowMs(), t0);
    device = t0 + 5000;
    expect(GameClock.nowMs(), t0 + 5000);
  });

  test('the server wins even below a floor a fast clock left behind', () {
    GameClock.floor = t0 + 3 * day;
    GameClock.synced(t0);
    expect(GameClock.nowMs(), t0);
    expect(GameClock.floor, t0);
  });
}

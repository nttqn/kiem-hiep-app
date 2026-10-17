import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/sects.dart';

import 'sim.dart';

void main() {
  test('progression report', () {
    final minutes = int.tryParse(
            const String.fromEnvironment('SIM_MIN', defaultValue: '60')) ??
        60;
    for (final h in Hanh.values) {
      final sw = Stopwatch()..start();
      final r = simulate(h, minutes: minutes);
      final marks = [5, 15, 30, 60, 120, 240, 480, 720, 960, 1200, 1500, 1800]
          .where((m) => r.levelAtMinute.containsKey(m))
          .map((m) => '${m}m:${r.levelAtMinute[m]}')
          .join(' ');
      // ignore: avoid_print
      print('${sectOf(h).name.padRight(14)} $marks  deaths ${r.deaths}  '
          'dungeons ${r.dungeonsCleared}/${r.dungeonsTried}  '
          'gold ${r.hero.gold} kills ${r.hero.kills} '
          'main ${r.hero.mainQuest} (${sw.elapsed.inSeconds}s)');
      if (const bool.fromEnvironment('SIM_LOG')) {
        // ignore: avoid_print
        r.log.forEach(print);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

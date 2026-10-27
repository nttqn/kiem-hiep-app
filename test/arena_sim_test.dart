@Tags(['sim'])
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/world.dart';

/// A hero of [level] in rare gear of that level, points spent.
HeroData _hero(Hanh hanh, int level) {
  final h = HeroData(name: 'Sim', hanh: hanh);
  final rng = math.Random(level * 7 + hanh.index);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  for (final s in Slot.values) {
    h.addItem(makeItem(slot: s, level: level, rarity: Rarity.rare, sect: h.sect, rng: rng));
  }
  h.autoSpend();
  h.autoLearn();
  h.autoEquip();
  h.hpPots = 50;
  h.mpPots = 50;
  return h;
}

/// Plays one duel on autopilot: (won, seconds).
(bool, double) duel(HeroData h, double ratio, int seed) {
  final r = math.Random(seed);
  final rival = ArenaRival(
    name: 'Đối thủ',
    hanh: Hanh.values[r.nextInt(5)],
    level: h.level,
    rebirths: 0,
    power: (h.power * ratio).round(),
  );
  final w = World.dungeon(h, arenaDef(rival), seed: seed)..auto = true;
  var won = false;
  while (!w.finished) {
    w.update(1 / 30);
    for (final e in w.events) {
      if (e.kind == EvKind.cleared) won = true;
    }
    w.events.clear();
  }
  return (won, w.finishTime);
}

void main() {
  // State 2026-10-27 (autopilot, 80 duels each, challengers using their sect
  // skills): 0.8x 80%, 1x 41%, 1.2x 24%
  // won; an even duel lasts 35-40 s at every level.
  test('Lôi đài: even duels are close, weaker rivals easy, stronger hard', () {
    final rate = <double>[];
    for (final ratio in const [0.8, 1.0, 1.2]) {
      final line = StringBuffer('ratio $ratio:');
      var wins = 0, n = 0;
      for (final lv in const [30, 50, 70, 99]) {
        var lw = 0;
        var secs = 0.0;
        for (final hanh in Hanh.values) {
          for (var s = 0; s < 4; s++) {
            final (won, t) = duel(_hero(hanh, lv), ratio, s * 31 + hanh.index);
            if (won) lw++;
            secs += t;
            n++;
          }
        }
        wins += lw;
        line.write('  lv$lv ${lw * 5}% ${(secs / 20).toStringAsFixed(0)}s');
      }
      // ignore: avoid_print
      print('$line  all ${(wins * 100 / n).round()}%');
      rate.add(wins / n);
    }
    expect(rate[0], greaterThan(rate[1]));
    expect(rate[1], greaterThan(rate[2]));
    expect(rate[1], inInclusiveRange(0.3, 0.65));
  });
}

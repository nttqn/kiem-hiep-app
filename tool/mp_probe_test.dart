// Mana: pool, regen and what casting every skill on cooldown costs.
//   flutter test tool/mp_probe_test.dart [--dart-define=HERO=<save.json>]
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import '../test/sim.dart';

const _path = String.fromEnvironment('HERO');

void _report(String tag, HeroData h) {
  h.recompute();
  final st = h.stats;
  var spend = 0.0;
  var biggest = 0.0;
  for (var i = 0; i < h.sect.skills.length; i++) {
    final s = h.sect.skills[i];
    final lv = h.skillLv[i];
    if (lv <= 0 || s.cooldown <= 0) continue;
    final cost = h.skillMp(s, lv);
    spend += cost / (s.cooldown * (1 - st.cdr));
    if (cost > biggest) biggest = cost;
  }
  // ignore: avoid_print
  print('$tag lv${h.level} cs${h.rebirths}: maxMp ${st.maxMp.round()} regen ${st.mpRegen.toStringAsFixed(1)}/s '
      'spend ${spend.toStringAsFixed(1)}/s biggest ${biggest.round()} (${(100 * biggest / st.maxMp).toStringAsFixed(1)}%) '
      'net ${(st.mpRegen - spend).toStringAsFixed(1)}/s');
}

void main() {
  test('mana', () {
    if (_path.isNotEmpty) {
      _report('save', HeroData.fromJson(jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>));
    }
    for (final hn in Hanh.values) {
      for (final mins in [60, 240]) {
        final r = simulate(hn, minutes: mins, seed: 2);
        _report('sim ${hn.name} ${mins}m', r.hero);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

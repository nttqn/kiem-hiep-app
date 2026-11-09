// EXP a level-99, sixth-rebirth hero earns per hour on each field map.
//   flutter test tool/exp99_probe_test.dart --dart-define=HERO=<save.json>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/world.dart';

const _path = String.fromEnvironment('HERO');

void main() {
  test('exp per hour at 99', () {
    for (final m in fieldMaps.where((m) => m.minLv >= 84)) {
      final h = HeroData.fromJson(jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>);
      h.recompute();
      h.exp = h.expNeedAt(99);
      h.hpPots = 999;
      h.mpPots = 999;
      final before = h.soulPills * soulPillExpCost + h.soulExp;
      final w = World.field(h, m, seed: 3)..auto = true;
      const mins = 10;
      var t = 0.0;
      var deaths = 0;
      while (t < mins * 60) {
        w.update(1 / 30);
        t += 1 / 30;
        for (final e in w.events) {
          if (e.kind == EvKind.heroDied) deaths++;
        }
        w.events.clear();
      }
      final got = h.soulPills * soulPillExpCost + h.soulExp - before;
      // ignore: avoid_print
      print('power ${h.power} ${m.id} lv${m.minLv}: ${(got * 60 / mins / 1e6).toStringAsFixed(1)}M/h deaths $deaths  need99 ${h.expNeedAt(99)}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

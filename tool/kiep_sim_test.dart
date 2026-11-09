// Độ kiếp win rates on autopilot for a real endgame save, at every gate.
//   flutter test tool/kiep_sim_test.dart --dart-define=HERO=<save.json>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/ngo_dao.dart';
import 'package:kiem_hiep/core/world.dart';

const _path = String.fromEnvironment('HERO');
const _mul = String.fromEnvironment('MUL');
const _noAff = String.fromEnvironment('NOAFF') == '1';

void main() {
  test('kiep win rates', () {
    for (var stage = 1; stage <= int.fromEnvironment('MAXS', defaultValue: 8); stage++) {
      var wins = 0;
      var secs = 0.0;
      const runs = 16;
      for (var seed = 0; seed < runs; seed++) {
        final h = HeroData.fromJson(jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>);
        h.daoLv = stage * daoLayers;
        h.recompute();
        h.hpPots = 999;
        h.mpPots = 999;
        var d = h.kiepDef();
        if (_mul.isNotEmpty || _noAff) {
          final r = h.kiepRival();
          d = DungeonDef(id: 'kiep', name: d.name, mapId: d.mapId, level: d.level, waves: const [], timeLimit: kiepTime,
              rival: _mul.isEmpty ? r : ArenaRival(name: r.name, hanh: r.hanh, level: r.level, rebirths: r.rebirths, power: (h.power * double.parse(_mul)).round(), female: r.female, title: r.title, mount: r.mount, mountLv: r.mountLv, skin: r.skin),
              kiep: stage, tmAffixes: _noAff ? const [] : d.tmAffixes);
        }
        final w = World.dungeon(h, d, seed: seed)..auto = true;
        var won = false;
        while (!w.finished && w.time < kiepTime + 5) {
          w.update(1 / 30);
          for (final e in w.events) {
            if (e.kind == EvKind.cleared) won = true;
          }
          w.events.clear();
        }
        if (won) {
          wins++;
          secs += w.time;
        }
      }
      // ignore: avoid_print
      print('stage $stage ${daoStages[stage].name}: $wins/$runs won, ${wins > 0 ? (secs / wins).toStringAsFixed(0) : '-'}s');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

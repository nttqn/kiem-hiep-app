// Balance runs for the 1.8.0 endgame (Tâm Ma, Ma Vực, Hung Thú) with a real
// endgame save on autopilot. The save is not in the repo; pass it with
//   flutter test tool/endgame_sim_test.dart --dart-define=HERO=<save.json>
// and MODE=tower|mavuc|tamma|beast|all, WEAK=1 for the same hero at +5.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/hung_thu.dart';
import 'package:kiem_hiep/core/ma_vuc.dart';
import 'package:kiem_hiep/core/tam_ma.dart';
import 'package:kiem_hiep/core/tower.dart';
import 'package:kiem_hiep/core/world.dart';

const _path = String.fromEnvironment('HERO');
const _mode = String.fromEnvironment('MODE', defaultValue: 'all');
const _weak = String.fromEnvironment('WEAK') == '1';
const _star = int.fromEnvironment('STAR');

HeroData _load() {
  final h = HeroData.fromJson(jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>);
  if (_weak) {
    for (final it in h.equip.values) {
      it.plus = 5;
    }
  }
  for (final it in h.equip.values) {
    it.star = _star;
  }
  h.recompute();
  return h;
}

/// Runs [d] on autopilot: (won, seconds, how it ended).
(bool, double, String) _run(HeroData h, DungeonDef d, int seed) {
  h.hpPots = 999;
  h.mpPots = 999;
  final w = World.dungeon(h, d, seed: seed)..auto = true;
  var won = false;
  var why = 'time';
  while (!w.finished && w.time < d.timeLimit + 5) {
    w.update(1 / 30);
    for (final e in List.of(w.events)) {
      if (e.kind == EvKind.cleared) {
        won = true;
        why = 'won';
      }
      if (e.kind == EvKind.failed) why = e.text;
      if (e.kind == EvKind.heroDied) {
        why = 'died';
        w.giveUp();
      }
    }
    w.events.clear();
  }
  final b = w.boss;
  if (b != null && !won) why += ' boss ${(100 * b.hp / b.maxHp).round()}%';
  return (won, w.time, why);
}

void main() {
  test('endgame balance', () {
    if (_path.isEmpty) return;
    final h0 = _load();
    // ignore: avoid_print
    print('hero power ${h0.power}, tower ${h0.towerBest}, star $_star, weak $_weak');
    void log(String s) => print(s); // ignore: avoid_print

    if (_mode == 'tower' || _mode == 'all') {
      for (final f in [150, 155, 160, 165, 170, 175, 185]) {
        final r = _run(_load(), towerFloor(f), f);
        log('tower $f: ${r.$1 ? 'WIN' : 'lose'} ${r.$2.toStringAsFixed(0)}s ${r.$3}');
      }
    }
    if (_mode == 'mavuc' || _mode == 'all') {
      for (final week in [3, 4]) {
        var f = 1;
        while (f < 80) {
          final h = _load();
          final a = _run(h, maVucFloor(f, week), f * 31 + week);
          final ok = a.$1 || _run(_load(), maVucFloor(f, week), f * 37 + week).$1;
          if (!ok) break;
          f += f < 20 ? 3 : 1;
        }
        log('mavuc week $week (${maVucWeekAffixes(week).map((e) => e.name).join(',')}): stopped at floor $f');
      }
    }
    if (_mode == 'tamma' || _mode == 'all') {
      var f = 1;
      while (f < 90) {
        final r = _run(_load(), tamMaDef(_load(), f), f);
        final ok = r.$1 || _run(_load(), tamMaDef(_load(), f), f + 1000).$1;
        log('tamma $f ${tamMaAffixes(f).map((e) => e.name)}: ${r.$1 ? 'WIN' : 'lose'} ${r.$2.toStringAsFixed(0)}s ${r.$3}');
        if (!ok) break;
        f += f < 20 ? 4 : 2;
      }
      log('tamma: stopped at floor $f (shadow ${tamMaPower(f)})');
    }
    if (_mode == 'beast' || _mode == 'all') {
      for (var diff = 1; diff <= 3; diff++) {
        for (final week in [0, 1, 3]) {
          final r = _run(_load(), beastDungeon(diff, week), diff * 10 + week);
          log('beast ${beastOfWeek(week).name} ${beastLevels[diff - 1]}: ${r.$1 ? 'WIN' : 'lose'} '
              '${r.$2.toStringAsFixed(0)}s ${r.$3}');
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

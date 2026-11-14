// Boss damage by sect: the same geared cs6 lv99 hero of every sect hits the
// Boss Thế Giới for its 60 s, with each bí kíp school at 5 and each lưu phái,
// and duels Tâm Ma floors. Run with:
//   flutter test tool/sect_boss_probe_test.dart [--dart-define=MODE=wb|tm]
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/companions.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/gold_sets.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sect_duty.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/manuals.dart';
import 'package:kiem_hiep/core/tam_ma.dart';
import 'package:kiem_hiep/core/world.dart';
import 'package:kiem_hiep/core/world_boss.dart';

import '../test/v130_realm_test.dart' show geared;

const _hug = String.fromEnvironment('HUG') == '1';
const _mode = String.fromEnvironment('MODE', defaultValue: 'wb');

const _end = String.fromEnvironment('END') == '1';

double dotTotal = 0;

HeroData endHero(Hanh hanh, {ManualKind? school, int branch = -1}) {
  final h = geared(99, hanh)..rebirths = 6;
  if (_end) {
    // Hoàng Kim 7 of the sect's own set, +10 ★5, top sect rank, companion.
    final r = math.Random(2);
    for (final s in Slot.values) {
      final it = makeGoldItem(set: goldSetById[hanh.name]!, slot: s, level: 99, sect: h.sect, rng: r)
        ..plus = 10
        ..star = 5;
      h.equip[s] = it;
    }
    h.sectRank = maxSectRank;
    final comp = hanh == Hanh.moc ? 'lamdiep' : 'macliet';
    h.companionBonds[comp] = maxBond;
    h.activeCompanion = comp;
  }
  for (var i = 0; i < h.sect.skills.length; i++) {
    h.skillLv[i] = h.skillCap(i);
  }
  for (final i in manualSkills(h.sect)) {
    final s = h.sect.skills[i];
    final k = school ?? ManualKind.power;
    if (!manualKindsFor(s).contains(k)) continue;
    h.addManualPage(manualKey(s.id, k), 15);
    h.setManual(s.id, k);
  }
  if (branch >= 0) {
    h.branch = branch;
    h.branchLv = 1;
  }
  h.recompute();
  return h;
}

double wbRun(HeroData h, int seed) {
  h.hpPots = 999;
  h.mpPots = 999;
  final d = worldBossDef(DateTime.utc(2026, 11, 13 + seed));
  final w = World.dungeon(h, d, seed: seed)..auto = true;
  while (!w.finished && w.time < d.timeLimit + 5) {
    final b = w.boss;
    if (_hug && b != null) {
      w.player.x = b.x - 10;
      w.player.y = b.y;
    }
    w.update(1 / 30);
    w.events.clear();
  }
  dotTotal += w.dotDealt;
  return w.dmgDealt;
}

(bool, double) tmRun(HeroData h, double mul, int seed) {
  h.hpPots = 999;
  h.mpPots = 999;
  const floor = 51;
  final r = tamMaRival(h, floor);
  final d = DungeonDef(
      id: 'tamma', name: 'tm', mapId: huyetHaiMap.id, level: h.level, waves: const [], timeLimit: tamMaTime,
      rival: ArenaRival(name: r.name, hanh: r.hanh, level: r.level, rebirths: r.rebirths, power: (h.power * mul).round()),
      tamMa: floor, tmAffixes: [for (final a in tamMaAffixes(floor)) a.index]);
  final w = World.dungeon(h, d, seed: seed)..auto = true;
  var won = false;
  while (!w.finished && w.time < d.timeLimit + 5) {
    final b = w.boss;
    if (_hug && b != null) {
      w.player.x = b.x - 10;
      w.player.y = b.y;
    }
    w.update(1 / 30);
    for (final e in w.events) {
      if (e.kind == EvKind.cleared) won = true;
      if (e.kind == EvKind.heroDied) w.giveUp();
    }
    w.events.clear();
  }
  return (won, w.time);
}

void main() {
  test('sect boss probe', () {
    final vs = double.tryParse(const String.fromEnvironment('VS'));
    if (vs != null) World.debugVolleyShare = vs;
    void log(String s) => print(s); // ignore: avoid_print
    if (_mode == 'stats') {
      String f(double v) => v.toStringAsFixed(2);
      for (final hanh in Hanh.values) {
        final h = endHero(hanh, school: ManualKind.power, branch: 0);
        final s = h.stats;
        final atkEff = s.atk * (1 + s.crit * (s.critDmg - 1)) * s.aspd * (1 + s.skillDmg * 0.6);
        final tough = s.maxHp * (1 + s.dodge) * 0.4 + s.def * 3;
        log('${hanh.name} power ${h.power} = atkEff*4 ${(atkEff * 4).round()} + tough ${tough.round()} | '
            'atk ${s.atk.round()} crit ${f(s.crit)} cd ${f(s.critDmg)} aspd ${f(s.aspd)} skill ${f(s.skillDmg)} '
            'dot ${f(s.dotPct)} hp ${s.maxHp.round()} def ${s.def.round()} dodge ${f(s.dodge)} | over crit ${f(s.overCrit)} dodge ${f(s.overDodge)} aspd ${f(s.overAspd)}');
      }
      return;
    }
    if (_mode == 'wb') {
      for (final hanh in Hanh.values) {
        final row = <String>[];
        for (final school in [ManualKind.power, ManualKind.wide, ManualKind.phase]) {
          for (final br in [0, 1]) {
            var sum = 0.0;
            dotTotal = 0;
            for (final seed in [1, 2, 3]) {
              sum += wbRun(endHero(hanh, school: school, branch: br), seed);
            }
            row.add('${school.name}/${br == 0 ? 'A' : 'B'} ${(sum / 3 / 1e6).toStringAsFixed(1)}M dot${(100 * dotTotal / sum).round()}%');
          }
        }
        log('${hanh.name} power ${endHero(hanh).power}: ${row.join(' | ')}');
      }
    } else {
      for (final hanh in Hanh.values) {
        final h0 = endHero(hanh, school: ManualKind.wide, branch: 0);
        final row = <String>[];
        // Shadows at 0.5x..8x the hero's power.
        for (final mul in [1.0, 1.25, 1.5, 2.0]) {
          var wins = 0;
          for (final seed in [1, 2, 3]) {
            if (tmRun(endHero(hanh, school: ManualKind.wide, branch: 0), mul, seed).$1) wins++;
          }
          row.add('x$mul $wins/3');
        }
        log('${hanh.name} power ${h0.power}: ${row.join(' | ')}');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

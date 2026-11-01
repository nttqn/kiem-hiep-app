import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/arena.dart';
import 'package:kiem_hiep/core/auto_config.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/dai_hoi.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/stats.dart';
import 'package:kiem_hiep/core/world.dart';

import 'v130_realm_test.dart' show geared;

World _field(HeroData h, {int seed = 3}) => World.field(h, maps.first, seed: seed)..auto = true;

void main() {
  group('Cài đặt tự đánh', () {
    test('saved with the hero', () {
      final h = HeroData(name: 'T', hanh: Hanh.moc);
      h.autoCfg
        ..target = AutoTarget.strong
        ..skillsOff.addAll([0, 2])
        ..hpPot = 0.6
        ..mpPot = 0.1
        ..loot = false
        ..saveUltimate = false;
      final b = HeroData.fromJson(h.toJson()).autoCfg;
      expect(b.target, AutoTarget.strong);
      expect(b.skillsOff, {0, 2});
      expect(b.hpPot, 0.6);
      expect(b.mpPot, 0.1);
      expect(b.loot, isFalse);
      expect(b.saveUltimate, isFalse);
      expect(HeroData.fromJson(HeroData(name: 'U', hanh: Hanh.kim).toJson()).autoCfg.isDefault, isTrue);
    });

    test('skills switched off are never cast by the autopilot', () {
      final h = geared(20, Hanh.hoa);
      final active = [for (var i = 0; i < h.sect.skills.length; i++) if (!h.sect.skills[i].isPassive) i];
      h.autoCfg.skillsOff.addAll(active);
      final w = _field(h);
      for (var t = 0; t < 30 * 60; t++) {
        w.update(1 / 30);
        w.events.clear();
        for (final i in active) {
          expect(w.player.cd[i], lessThanOrEqualTo(0), reason: 'skill $i was cast');
        }
      }
      expect(w.dmgDealt, greaterThan(0));
    });

    test('the potion threshold is the one picked', () {
      final h = geared(20, Hanh.kim)..autoCfg.hpPot = 0.7;
      final w = _field(h);
      final pots = h.hpPots;
      w.player.hp = w.player.maxHp * 0.65;
      w.update(1 / 30);
      expect(h.hpPots, pots - 1);
      final h2 = geared(20, Hanh.kim)..autoCfg.hpPot = 0.25;
      final w2 = _field(h2);
      final pots2 = h2.hpPots;
      w2.player.hp = w2.player.maxHp * 0.3;
      w2.update(1 / 30);
      expect(h2.hpPots, pots2);
    });
  });

  group('Thống kê', () {
    test('a battle is logged with its damage and records are kept', () {
      final h = geared(20, Hanh.thuy);
      final w = _field(h);
      for (var t = 0; t < 30 * 90; t++) {
        w.update(1 / 30);
        w.events.clear();
      }
      final r = w.runSummary(RunResult.left);
      expect(r.kills, greaterThan(0));
      expect(r.dmg, greaterThan(0));
      expect(r.dps, greaterThan(0));
      expect(r.bestHit, greaterThan(0));
      expect(w.combatTime, lessThanOrEqualTo(w.time));
      h.logRun(r, w.combatTime);
      expect(h.runLog.first.name, maps.first.name);
      expect(h.records.bestDps, r.dps);
      expect(h.records.bestHit, r.bestHit);
      // A short walk-through is not logged.
      h.logRun(RunLog(
          name: 'x', kind: 'field', sec: 5, kills: 0, dmg: 0, bestHit: 0, dps: 0, gold: 0, levels: 0,
          result: RunResult.left, at: 0), 0);
      expect(h.runLog.length, 1);
      final b = HeroData.fromJson(h.toJson());
      expect(b.runLog.length, 1);
      expect(b.runLog.first.kills, r.kills);
      expect(b.records.bestHit.round(), r.bestHit.round());
      for (var i = 0; i < 30; i++) {
        h.logRun(r, 0);
      }
      expect(h.runLog.length, runLogSize);
    });

    test('a better run breaks the record and says so', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim);
      RunLog run(double dps, double hit) => RunLog(
          name: 'm', kind: 'field', sec: 60, kills: 30, dmg: dps * 60, bestHit: hit, dps: dps, gold: 0, levels: 0,
          result: RunResult.won, at: 0);
      expect(h.logRun(run(100, 500), 60), isEmpty);
      expect(h.logRun(run(200, 400), 60), [contains('sát thương/giây')]);
      // Too little fighting for a DPS record.
      expect(h.logRun(run(900, 400), 5), isEmpty);
      expect(h.records.bestDps, 200);
      expect(h.records.wins, 3);
    });
  });

  group('Võ Lâm Đại Hội', () {
    List<ArenaRival> foes(HeroData h, int week) => daiHoiEntrants(const [], h.power, h.level, h.rebirths, week);

    test('eight entrants, each round a stronger foe', () {
      final h = geared(40, Hanh.kim)..recompute();
      h.daiHoiEnter(3, foes(h, 3));
      expect(h.dhEntered, isTrue);
      final seen = <int>[];
      for (var r = 0; r < 3; r++) {
        final f = h.dhNextFoe!;
        seen.add(f.power);
        expect(h.daiHoiResult(true), isNotEmpty);
      }
      expect(seen[0], lessThan(seen[2]));
      expect(h.dhNextFoe, isNull);
      expect(h.dhChamps, 1);
      expect(h.seasonTitles, contains(daiHoiTitle));
      // Done for the week: no more matches.
      expect(h.daiHoiResult(true), isEmpty);
    });

    test('a loss may be fought again once, then the prize', () {
      final h = geared(40, Hanh.moc)..recompute();
      h.daiHoiEnter(4, foes(h, 4));
      h.daiHoiResult(true);
      final foe = h.dhNextFoe!;
      final coins = h.arenaCoins;
      h.daiHoiResult(false);
      expect(h.dhOut && h.dhUnpaid, isTrue);
      expect(h.arenaCoins, coins);
      expect(h.daiHoiRematch(), isTrue);
      expect(h.dhNextFoe!.name, foe.name);
      final lines = h.daiHoiResult(false);
      expect(lines.length, greaterThan(2));
      expect(h.arenaCoins, coins + daiHoiPrize(1, h.level).coins);
      expect(h.daiHoiRematch(), isFalse);
    });

    test('an uncollected prize is paid when the week turns; saved with the hero', () {
      final h = geared(40, Hanh.tho)..recompute();
      h.daiHoiEnter(5, foes(h, 5));
      h.daiHoiResult(false);
      final b = HeroData.fromJson(h.toJson());
      expect(b.dhEntered && b.dhOut && b.dhUnpaid, isTrue);
      expect(b.dhNextFoe, isNull);
      final coins = b.arenaCoins;
      expect(b.daiHoiRoll(6), isNotEmpty);
      expect(b.arenaCoins, coins + daiHoiPrize(0, b.level).coins);
      expect(b.dhEntered, isFalse);
    });

    test('the bracket favours the stronger but is not fixed', () {
      var upsets = 0;
      for (var s = 0; s < 400; s++) {
        if (!daiHoiFirstWins(1100, 1000, s)) upsets++;
      }
      expect(upsets, inInclusiveRange(60, 200));
    });

    test('a bracket duel is played as a Lôi đài duel and scored for the Đại Hội', () {
      final h = geared(40, Hanh.hoa)..recompute();
      h.daiHoiEnter(7, foes(h, 7));
      final d = arenaDef(h.dhNextFoe!, round: daiHoiRounds[0]);
      expect(d.daiHoi && d.isArena, isTrue);
      final w = World.dungeon(h, d, seed: 1)..auto = true;
      final points = h.arenaPoints;
      while (!w.finished) {
        w.update(1 / 30);
        w.events.clear();
      }
      expect(h.arenaPoints, points);
      expect(h.dhWins == 1 || h.dhOut, isTrue);
      expect(w.runSummary(RunResult.won).kind, 'daihoi');
    });
  });
}

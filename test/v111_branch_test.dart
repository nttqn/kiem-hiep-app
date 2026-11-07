import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/branches.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/sects.dart';

import 'v130_realm_test.dart' show geared;
import 'v140_sea_test.dart' show farm;

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  test('every school changes real skills of its own sect', () {
    for (final hanh in Hanh.values) {
      final sect = sectOf(hanh);
      final ids = {for (final s in sect.skills) s.id: s};
      expect(branchesOf(hanh).length, 2);
      for (final b in branchesOf(hanh)) {
        expect(b.mods, isNotEmpty, reason: b.id);
        expect(b.bonus, isNotEmpty, reason: b.id);
        for (final m in b.mods) {
          final s = ids[m.skill];
          expect(s, isNotNull, reason: '${b.id} ${m.skill}');
          expect(s!.isPassive || s.ultimate, isFalse, reason: '${b.id} ${m.skill}');
          expect(m.note, isNotEmpty);
          if (m.statusPower != 1 || m.statusTime != 1) {
            expect(s.status, isNot(Status.none), reason: '${m.skill} has no status to strengthen');
          }
          if (m.duration != 1) expect(s.duration, greaterThan(0), reason: m.skill);
          if (m.count != 0) {
            expect([SkillKind.projectile, SkillKind.radial, SkillKind.line], contains(s.kind), reason: m.skill);
          }
        }
      }
    }
  });

  test('opens after the first rebirth; first pick free, switching costs gold', () {
    final h = HeroData(name: 'L', hanh: Hanh.hoa)..level = 60;
    expect(h.pickBranch(0), isFalse, reason: 'not reborn yet');
    h.rebirths = 1;
    h.gold = 0;
    expect(h.pickBranch(0), isTrue);
    final before = h.castSkill(0).power;
    expect(before, closeTo(sectOf(Hanh.hoa).skills[0].power * 1.2, 1e-9));
    expect(h.pickBranch(1), isFalse, reason: 'no gold to switch');
    h.gold = branchSwitchCost(1);
    expect(h.pickBranch(1), isTrue);
    expect(h.gold, 0);
    expect(h.castSkill(0).power, sectOf(Hanh.hoa).skills[0].power);
  });

  test('Tu vi raises the nội công and survives a save', () {
    final h = HeroData(name: 'L', hanh: Hanh.kim)
      ..level = 99
      ..rebirths = 2;
    h.pickBranch(1);
    final hp1 = h.allBonuses()[Bonus.hpPct]!;
    h.gold = 1 << 40;
    h.divineIron = 1000;
    while (h.raiseBranch()) {}
    expect(h.branchLv, maxBranchLevel);
    final hp10 = h.allBonuses()[Bonus.hpPct]!;
    expect(hp10 - hp1, closeTo(0.06 * (branchMul(10) - 1), 1e-9));
    final back = _roundTrip(h);
    expect((back.branch, back.branchLv), (1, maxBranchLevel));
    expect(back.allBonuses()[Bonus.hpPct], closeTo(hp10, 1e-9));
  });

  test('an old save has no school, and a cheated save is clamped', () {
    final h = HeroData(name: 'O', hanh: Hanh.tho)..rebirths = 1;
    final m = h.toJson()..remove('lp');
    final old = HeroData.fromJson(jsonDecode(jsonEncode(m)) as Map<String, dynamic>);
    expect((old.branch, old.branchLv, old.branchDef), (-1, 1, null));
    m['lp'] = [7, 999];
    final bad = HeroData.fromJson(jsonDecode(jsonEncode(m)) as Map<String, dynamic>);
    expect(bad.branchLv, maxBranchLevel);
    expect(bad.branch, 1);
  });

  test('a school adds a modest share of power', () {
    for (final hanh in Hanh.values) {
      for (var i = 0; i < 2; i++) {
        final h = HeroData(name: 'P', hanh: hanh)
          ..level = 99
          ..rebirths = 1;
        h.recompute();
        final p0 = h.power;
        h.pickBranch(i);
        h.branchLv = maxBranchLevel;
        h.recompute();
        final gain = h.power / p0 - 1;
        // ignore: avoid_print
        print('${hanh.name} ${branchesOf(hanh)[i].name}: +${(gain * 100).toStringAsFixed(1)}% power at Tu vi 10');
        expect(gain, inInclusiveRange(0.0, 0.25));
      }
    }
  });

  test('a school fights better on a field, but not by leaps', () {
    for (final hanh in Hanh.values) {
      final base = geared(90, hanh)..rebirths = 1;
      final (k0, _) = farm(base, mapById['hoason']!, minutes: 3);
      for (var i = 0; i < 2; i++) {
        final h = geared(90, hanh)..rebirths = 1;
        h.pickBranch(i);
        h.branchLv = 5;
        h.recompute();
        final (k, d) = farm(h, mapById['hoason']!, minutes: 3);
        // ignore: avoid_print
        print('${hanh.name} ${branchesOf(hanh)[i].name}: $k kills (none $k0), $d deaths');
        expect(k, lessThan(k0 * 1.45 + 5), reason: branchesOf(hanh)[i].name);
      }
    }
  });
}

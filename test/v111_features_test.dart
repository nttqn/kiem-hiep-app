import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/fishing.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/manuals.dart';
import 'package:kiem_hiep/core/nightmare.dart';
import 'package:kiem_hiep/core/sect_duty.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/core/world.dart';

HeroData at(Hanh hanh, int level, {bool gear = false}) {
  final h = HeroData(name: 'T', hanh: hanh);
  while (h.level < level) {
    h.gainExp(h.expNeeded.toDouble());
  }
  if (gear) {
    final rng = math.Random(level);
    for (final s in Slot.values) {
      h.addItem(makeItem(slot: s, level: level, rarity: Rarity.epic, sect: h.sect, rng: rng));
    }
    h.autoEquip();
  }
  h.autoSpend();
  h.autoLearn();
  h.hpPots = 99;
  h.mpPots = 99;
  h.notices.clear();
  return h;
}

HeroData roundTrip(HeroData h) =>
    HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  group('Bí kíp', () {
    test('pages add up to five levels', () {
      expect([0, 1, 2, 3, 5, 6, 9, 10, 14, 15, 40].map(manualLevelOf), [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5]);
      expect(manualPagesToNext(4), 2);
      expect(manualPagesToNext(15), 0);
    });

    test('each school reshapes a skill', () {
      final kim1 = sectOf(Hanh.kim).skills[0];
      expect(applyManual(kim1, ManualKind.power, 5, Hanh.kim).power, closeTo(kim1.power * 1.3, 1e-9));
      expect(applyManual(kim1, ManualKind.swift, 5, Hanh.kim).cooldown, closeTo(kim1.cooldown * 0.75, 1e-9));
      expect(applyManual(kim1, ManualKind.wide, 5, Hanh.kim).range, closeTo(kim1.range * 1.35, 1e-9));
      final stun = applyManual(kim1, ManualKind.phase, 3, Hanh.kim);
      expect(stun.status, Status.stun);
      expect(stun.statusTime, greaterThan(0));

      final proj = sects.expand((s) => s.skills).firstWhere((s) => s.kind == SkillKind.projectile);
      expect(applyManual(proj, ManualKind.wide, 3, Hanh.moc).count, proj.count + 1);
      expect(applyManual(proj, ManualKind.wide, 5, Hanh.moc).count, proj.count + 2);
      final radial = sects.expand((s) => s.skills).firstWhere((s) => s.kind == SkillKind.radial);
      expect(applyManual(radial, ManualKind.wide, 5, Hanh.thuy).count, radial.count + 4);

      final guard = sectOf(Hanh.kim).skills[1];
      expect(manualKindsFor(guard), contains(ManualKind.endure));
      expect(manualKindsFor(guard), isNot(contains(ManualKind.wide)));
      expect(applyManual(guard, ManualKind.endure, 5, Hanh.kim).duration, closeTo(guard.duration * 1.6, 1e-9));
      expect(manualKindsFor(sectOf(Hanh.kim).skills[3]), isEmpty);
      expect(manualSkills(sectOf(Hanh.kim)), [0, 1, 2, 4, 6]);
    });

    test('worn only once learned, cast in the world, saved', () {
      final h = at(Hanh.hoa, 40);
      final s = h.sect.skills[0];
      expect(h.setManual(s.id, ManualKind.power), isFalse);
      h.addManualPage(manualKey(s.id, ManualKind.power), 6);
      expect(h.setManual(s.id, ManualKind.power), isTrue);
      expect(h.castSkill(0).power, closeTo(s.power * 1.18, 1e-9));
      final w = World.field(h, maps[3], seed: 1);
      expect(w.skills[0].power, closeTo(s.power * 1.18, 1e-9));
      expect(w.skills[1].power, h.sect.skills[1].power);

      final b = roundTrip(h);
      expect(b.manualOf(s.id), ManualKind.power);
      expect(b.manualLevel(manualKey(s.id, ManualKind.power)), 3);
      expect(b.setManual(s.id, null), isTrue);
      expect(b.castSkill(0).power, s.power);
    });

    test('a random page is always for one of the sect\'s active skills', () {
      final rng = math.Random(3);
      for (final sect in sects) {
        for (var i = 0; i < 40; i++) {
          final key = rollManualPage(sect, rng);
          final s = sect.skills.firstWhere((s) => s.id == key.split(':')[0]);
          expect(s.isPassive, isFalse);
          expect(manualPageName(sect, key), startsWith('Bí kíp ${s.name} · '));
        }
      }
    });
  });

  group('Sư môn', () {
    test('a chain of ten duties a day pays cống hiến, gold and EXP', () {
      final rng = math.Random(5);
      final h = at(Hanh.kim, 30);
      h.sectRollDay('20261101', rng);
      expect(h.sectDuty, isNotNull);
      final map = maps.lastWhere((m) => m.minLv <= h.level);
      h.sectDuty = SectDuty(kind: DutyKind.kill, target: map.mobs.first, map: map.id, count: 2);
      expect(h.wantedMobs(), contains(map.mobs.first));
      h.onKill(mobById[map.mobs.first]!, rng);
      expect(h.sectDuty!.done, isFalse);
      h.onKill(mobById[map.mobs.first]!, rng);
      expect(h.sectDuty!.done, isTrue);
      final gold = h.gold;
      expect(h.sectClaim(rng), contains('+25 cống hiến'));
      expect(h.gold, gold + dutyGold(h.level));
      expect([h.sectContrib, h.sectCoins, h.sectDone], [25, 25, 1]);
      expect(h.sectDuty, isNotNull);

      h.sectDone = 9;
      h.sectDuty!.progress = h.sectDuty!.count;
      expect(h.sectClaim(rng), contains('+50 cống hiến'));
      expect(h.sectDuty, isNull);
      h.sectRollDay('20261101', rng);
      expect(h.sectDuty, isNull);
      h.sectRollDay('20261102', rng);
      expect(h.sectDone, 0);
      expect(h.sectDuty, isNotNull);
    });

    test('every fifth duty hunts a traitor the world puts on the map', () {
      final rng = math.Random(2);
      for (var n = 0; n < 10; n++) {
        final d = rollDuty(50, n, rng, herbs: true, fish: true);
        if ((n + 1) % 5 == 0) expect(d.kind, DutyKind.traitor);
        expect(d.map, 'hoadiem');
      }
      final h = at(Hanh.moc, 50);
      h.sectDuty = rollDuty(50, 4, rng, herbs: true, fish: true);
      final key = h.sectDuty!.eliteKey;
      expect(h.wantedElites('hoadiem').map((e) => e.key), contains(key));
      h.onEliteKill(key, rng);
      expect(h.sectDuty!.done, isTrue);
    });

    test('herbs, fish and dungeon clears count for their duties', () {
      final rng = math.Random(4);
      final h = at(Hanh.thuy, 40);
      h.sectDuty = SectDuty(kind: DutyKind.herb, target: '', map: 'bangnguyen', count: 2);
      h.onHerbPicked();
      h.onHerbPicked();
      expect(h.sectDuty!.done, isTrue);
      h.sectDuty = SectDuty(kind: DutyKind.fish, target: '', map: 'bangnguyen', count: 1);
      h.catchFish(fishById['hoibang']!, rng);
      expect(h.sectDuty!.done, isTrue);
      h.sectDuty = SectDuty(kind: DutyKind.dungeon, target: '', map: 'bangnguyen', count: 1);
      h.onDungeonClear('a5', 3, rng);
      expect(h.sectDuty!.done, isTrue);
    });

    test('khảo hạch needs cống hiến and level; a win raises the chức vị and its bonus', () {
      final h = at(Hanh.hoa, 30);
      expect(h.sectCanTrial, isFalse);
      h.sectContrib = 200;
      expect(h.sectCanTrial, isTrue);
      final atk = h.stats.atk;
      final r = h.sectExaminerNow();
      expect(r.hanh, Hanh.hoa);
      expect(r.power, (h.power * 0.75).round());
      expect(h.sectTrialResult(false), isNot(contains(startsWith('Chức vị'))));
      expect(h.sectRank, 0);
      expect(h.sectTrialResult(true).first, 'Chức vị mới: Đệ tử nhập môn');
      expect(h.sectRank, 1);
      expect(h.stats.atk, greaterThan(atk));
      expect(h.sectCanTrial, isFalse);
      h.sectContrib = 9000;
      expect(h.sectCanTrial, isTrue);
      h.sectRank = 3;
      h.unlockCostumes();
      expect(h.ownedCostumes, isNot(contains('truonglao')));
      h.sectRank = 4;
      h.unlockCostumes();
      expect(h.ownedCostumes, contains('truonglao'));
      // Level gates the higher chức vị.
      expect(h.sectCanTrial, isFalse);
    });

    test('a khảo hạch duel pays through the sect, not the Lôi đài', () {
      final h = at(Hanh.kim, 30, gear: true);
      h.sectContrib = 200;
      final pts = h.arenaPoints;
      final w = World.dungeon(h, sectTrialDef(h.sectExaminerNow()), seed: 1)..auto = true;
      while (!w.finished) {
        w.update(1 / 30);
      }
      expect(h.arenaPoints, pts);
      expect(h.arenaSeasonFights, 0);
      expect(h.sectRank, w.rewardLines.isNotEmpty && w.rewardLines.first.startsWith('Chức vị') ? 1 : 0);
    });

    test('Tàng Kinh Các sells by chức vị', () {
      final rng = math.Random(1);
      final h = at(Hanh.tho, 40);
      h.sectCoins = 500;
      final page = sectOffers.firstWhere((o) => o.kind == SectWare.page);
      final key = manualKey(h.sect.skills[0].id, ManualKind.swift);
      expect(h.sectBuy(page, rng, page: key), isFalse);
      h.sectRank = 2;
      expect(h.sectBuy(page, rng), isFalse);
      expect(h.sectBuy(page, rng, page: key), isTrue);
      expect(h.manualPagesOf(key), 1);
      expect(h.sectCoins, 500 - page.price);
      final pots = sectOffers.firstWhere((o) => o.kind == SectWare.potions);
      final hp = h.hpPots;
      expect(h.sectBuy(pots, rng), isTrue);
      expect(h.hpPots, hp + 10);
    });

    test('everything is saved', () {
      final h = at(Hanh.thuy, 30)
        ..sectRank = 2
        ..sectContrib = 900
        ..sectCoins = 140
        ..sectDay = '20261101'
        ..sectDone = 3
        ..sectDuty = SectDuty(kind: DutyKind.boss, target: maps[0].boss, map: 'ngoaithanh', count: 1, progress: 0);
      final b = roundTrip(h);
      expect([b.sectRank, b.sectContrib, b.sectCoins, b.sectDay, b.sectDone], [2, 900, 140, '20261101', 3]);
      expect(b.sectDuty?.kind, h.sectDuty!.kind);
    });
  });

  group('Câu cá', () {
    test('twenty baits a day, ten more for an ad, once', () {
      final h = at(Hanh.kim, 12);
      for (var i = 0; i < fishBaitPerDay; i++) {
        expect(h.fishCast('20261101'), isTrue);
      }
      expect(h.fishCast('20261101'), isFalse);
      expect(h.fishAddAd('20261101'), isTrue);
      expect(h.fishAddAd('20261101'), isFalse);
      expect(h.fishBaitLeft, fishAdBait);
      expect(h.fishCast('20261102'), isTrue);
      expect(h.fishBaitLeft, fishBaitPerDay - 1);
    });

    test('catches sell, the first of a kind pays more, legends hold shards and pages', () {
      final rng = math.Random(1);
      final h = at(Hanh.moc, 40);
      final f = fishById['chepco']!;
      var g = h.gold;
      h.catchFish(f, rng);
      expect(h.gold, g + f.price * (1 + fishFirstBonus));
      g = h.gold;
      h.catchFish(f, rng);
      expect(h.gold, g + f.price);
      final shards = h.goldShards;
      final lines = h.catchFish(fishById['lyngu']!, rng);
      expect(h.goldShards, shards + 2);
      expect(lines.last, startsWith('Bí kíp'));
      expect(h.manualPages.values.fold<int>(0, (a, b) => a + b), 1);
    });

    test('a finished Ngư phổ page pays once', () {
      final rng = math.Random(1);
      final h = at(Hanh.kim, 12);
      final pond = fishOfMap('ngoaithanh');
      expect(pond, hasLength(4));
      for (final f in pond.take(3)) {
        h.catchFish(f, rng);
      }
      expect(h.fishBookClaim('ngoaithanh'), 0);
      h.catchFish(pond.last, rng);
      expect(h.fishBookClaim('ngoaithanh'), fishBookGold(0));
      expect(h.fishBookClaim('ngoaithanh'), 0);
      expect(roundTrip(h).fishBooks, contains('ngoaithanh'));
      expect(roundTrip(h).fishCaught, h.fishCaught);
    });

    test('every map has four fish of rising rarity, commons bite most', () {
      for (final m in maps) {
        expect(fishOfMap(m.id).map((f) => f.rarity), FishRarity.values);
      }
      final rng = math.Random(9);
      final n = List.filled(4, 0);
      for (var i = 0; i < 10000; i++) {
        n[rollFish('hoason', rng).rarity.index]++;
      }
      expect(n[0], inInclusiveRange(5600, 6400));
      expect(n[3], inInclusiveRange(120, 300));
    });

    test('each field has a pond by the gate that keeps the hero on the bank', () {
      final h = at(Hanh.kim, 12);
      final w = World.field(h, maps[0], seed: 1);
      expect(w.hasPond, isTrue);
      expect(w.nearPond, isFalse);
      w.player.x = w.pondX;
      w.player.y = w.pondY - pondRy - 30;
      expect(w.nearPond, isTrue);
      w.player.y = w.pondY;
      w.update(1 / 30);
      final dx = (w.player.x - w.pondX) / pondRx, dy = (w.player.y - w.pondY) / pondRy;
      expect(dx * dx + dy * dy, greaterThanOrEqualTo(0.99));
      expect(World.dungeon(h, dungeons[0], seed: 1).hasPond, isFalse);
    });
  });

  group('Ải Ác Mộng', () {
    test('a ladder from level 60 to 99 whose ma khí changes each Monday', () {
      expect(nightmareLevel(0), 60);
      expect(nightmareLevel(nightmareCount - 1), 99);
      for (var i = 1; i < nightmareCount; i++) {
        expect(nightmareLevel(i), greaterThanOrEqualTo(nightmareLevel(i - 1)));
        expect(nightmareMul(i), greaterThan(nightmareMul(i - 1)));
      }
      expect(nightmareAffix(0, '20261026'), isNot(nightmareAffix(0, '20261102')));
      expect(nightmareAffix(0, '20261026'), nightmareAffix(4, '20261026'));
      final d = nightmareDef(3, NmAffix.chill);
      expect([d.id, d.isNightmare, d.affix], ['nm4', true, NmAffix.chill.index]);
      expect(d.waves, [for (final n in dungeons[3].waves) n + 2]);
    });

    test('opened one by one from level 60', () {
      final h = at(Hanh.tho, 59);
      expect(h.nightmareUnlocked(0), isFalse);
      h.gainExp(h.expNeeded.toDouble());
      expect(h.nightmareUnlocked(0), isTrue);
      expect(h.nightmareUnlocked(1), isFalse);
      h.nmStars['nm1'] = 1;
      expect(h.nightmareUnlocked(1), isTrue);
    });

    test('the first clear pays big, then five paid clears a day', () {
      final rng = math.Random(1);
      final h = at(Hanh.hoa, 70);
      final d = nightmareDef(0, NmAffix.frenzy);
      final shards = h.goldShards;
      final lines = h.nightmareReward(d, 3, rng, day: '20261101');
      expect(h.goldShards, shards + nightmareShards(0, 3) + nightmareFirstShards);
      expect(lines.where((l) => l.startsWith('Bí kíp')), hasLength(1));
      expect(h.nmStars['nm1'], 3);
      expect(h.nmRunsLeft, nightmarePaidRuns);
      for (var i = 0; i < nightmarePaidRuns; i++) {
        expect(h.nightmareReward(d, 2, rng, day: '20261101').first, startsWith('+'));
      }
      expect(h.nightmareReward(d, 2, rng, day: '20261101'), ['Hết lượt thưởng Ác Mộng hôm nay']);
      expect(h.lastDungeonGold, 0);
      expect(h.nmStars['nm1'], 3);
      expect(h.nightmareReward(d, 1, rng, day: '20261102').first, startsWith('+'));
      final b = roundTrip(h);
      expect([b.nmStars['nm1'], b.nmDay, b.nmRuns], [3, '20261102', 1]);
    });

    test('ma khí changes the monsters; the boss calls for help as it weakens', () {
      final h = at(Hanh.kim, 99, gear: true);
      double hpShare(Mob m) => m.maxHp / (mobHpAt(m.level) * m.def.hp);
      World run(NmAffix a) {
        final w = World.dungeon(h, nightmareDef(0, a), seed: 2)..auto = true;
        while (w.mobs.isEmpty) {
          w.update(1 / 30);
        }
        return w;
      }

      final fort = run(NmAffix.fortified).mobs.first;
      final frenzy = run(NmAffix.frenzy).mobs.first;
      expect(hpShare(fort), closeTo(hpShare(frenzy) * 1.6, 1e-6));
      expect(frenzy.speedMul, 1.25);
      expect(fort.speedMul, 1);

      final w = World.dungeon(h, nightmareDef(0, NmAffix.chill), seed: 3)..auto = true;
      while (w.boss == null && !w.finished) {
        w.player.hp = w.player.maxHp;
        w.update(1 / 30);
      }
      final boss = w.boss!;
      boss.hp = boss.maxHp * 0.71;
      final before = w.mobs.length;
      for (var i = 0; i < 30 * 20 && w.mobs.length < before + nightmareAdds; i++) {
        w.player.hp = w.player.maxHp;
        w.update(1 / 30);
      }
      expect(w.mobs.length, greaterThanOrEqualTo(before + nightmareAdds));
    });
  });
}

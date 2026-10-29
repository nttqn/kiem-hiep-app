import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/divine.dart';
import 'package:kiem_hiep/core/fatigue.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/mail.dart';
import 'package:kiem_hiep/core/nightmare.dart';
import 'package:kiem_hiep/core/sects.dart';

HeroData reborn() {
  final h = HeroData(name: 'T', hanh: Hanh.kim);
  while (h.level < 60) {
    h.gainExp(h.expNeeded.toDouble());
  }
  h.rebirths = 1;
  h.notices.clear();
  h.recompute();
  return h;
}

void main() {
  group('Thần binh', () {
    test('locked before the first rebirth', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)
        ..divineIron = 999
        ..gold = 99999999;
      expect(h.divineOpen, isFalse);
      expect(h.upgradeDivine(), isFalse);
    });

    test('each level costs iron and gold and raises lực chiến', () {
      final h = reborn()
        ..divineIron = 1000
        ..gold = 100000000;
      var iron = h.divineIron, gold = h.gold, power = h.power;
      for (var lv = 0; lv < divineMax; lv++) {
        expect(h.upgradeDivine(), isTrue);
        expect(h.divineIron, iron - divineIronCost[lv]);
        expect(h.gold, gold - divineGoldCost(lv));
        expect(h.power, greaterThan(power), reason: 'level ${lv + 1}');
        iron = h.divineIron;
        gold = h.gold;
        power = h.power;
      }
      expect(h.divine, divineMax);
      expect(h.upgradeDivine(), isFalse, reason: 'already at the top');
    });

    test('not enough Thần Thiết', () {
      final h = reborn()
        ..divineIron = divineIronCost[0] - 1
        ..gold = 100000000;
      expect(h.canDivine, isFalse);
    });

    test('bonuses and milestones', () {
      expect(divineBonuses(0), isEmpty);
      final top = divineBonuses(divineMax);
      expect(top[Bonus.atkPct], closeTo(divineStatPerLv * divineMax, 1e-9));
      expect(top[Bonus.crit], 0.04);
      expect(top[Bonus.critDmg], 0.2);
      expect(top[Bonus.skillDmg], 0.1);
      expect(divineBonuses(2).containsKey(Bonus.crit), isFalse);
      expect(divineIronCost.length, divineMax);
      expect(divineStage(divineMax), 'Thần binh');
      expect(divineColor(0), 0);
    });

    test('Thần Thiết from the hard end only, climbing with the tier', () {
      expect(nightmareIron(0), 0);
      expect(towerIron(99), 0);
      expect(towerIron(100), 4);
      expect(towerIron(101), 1);
      for (var i = 1; i < nightmareCount; i++) {
        expect(nightmareIron(i), greaterThanOrEqualTo(nightmareIron(i - 1)));
      }
      expect(nightmareIron(nightmareCount - 1), greaterThan(0));
    });

    test('nightmare 15 pays Thần Thiết', () {
      final h = reborn();
      final d = nightmareDef(14, NmAffix.frenzy);
      final lines = h.nightmareReward(d, 3, math.Random(1), day: '20261101');
      expect(h.divineIron, nightmareIron(14) + nightmareFirstIron(14));
      expect(lines.any((l) => l.contains('Thần Thiết')), isTrue);
    });

    test('saved and loaded', () {
      final h = reborn()
        ..divine = 6
        ..divineIron = 42
        ..mailClaimed.add('tet');
      final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(back.divine, 6);
      expect(back.divineIron, 42);
      expect(back.mailClaimed, {'tet'});
      // Older saves have neither.
      final old = h.toJson()
        ..remove('tb')
        ..remove('mail');
      final o = HeroData.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      expect(o.divine, 0);
      expect(o.mailClaimed, isEmpty);
    });
  });

  group('Hòm thư', () {
    test('console documents are read defensively', () {
      expect(MailDef.fromMap('a', {}), isNull);
      expect(MailDef.fromMap('a', {'title': '  '}), isNull);
      final m = MailDef.fromMap('a', {
        'title': 'Đền bù',
        'body': 'Xin lỗi vì sự cố',
        'gold': 50000,
        'shards': 5000,
        'iron': 'x',
        'gems': 2,
        'gemTier': 99,
        'until': 20261105,
        'from': 'hôm nay',
      })!;
      expect(m.gold, 50000);
      expect(m.shards, 1000, reason: 'capped');
      expect(m.iron, 0, reason: 'not a number');
      expect(m.gemTier, lessThanOrEqualTo(7));
      expect(m.until, '20261105');
      expect(m.from, '', reason: 'not a day');
      expect(m.openOn('20261105'), isTrue);
      expect(m.openOn('20261106'), isFalse);
    });

    test('claimed once per hero, within its days and level', () {
      final h = HeroData(name: 'T', hanh: Hanh.thuy);
      final m = MailDef(id: 'm1', title: 'Quà', gold: 1000, iron: 3, gems: 2, gemTier: 2, from: '20261101', until: '20261110');
      final gold = h.gold;
      expect(h.canClaimMail(m, '20261031'), isFalse);
      final lines = h.claimMail(m, '20261102', math.Random(1));
      expect(h.gold, gold + 1000);
      expect(h.divineIron, 3);
      expect(h.gemBag.values.fold<int>(0, (a, b) => a + b), 2);
      expect(lines.length, 4);
      expect(h.claimMail(m, '20261102', math.Random(1)), isEmpty, reason: 'only once');
      expect(h.gold, gold + 1000);
      const high = MailDef(id: 'm2', title: 'Cao thủ', gold: 1, minLevel: 50);
      expect(h.canClaimMail(high, '20261102'), isFalse);
      h.rebirths = 1;
      expect(h.canClaimMail(high, '20261102'), isTrue, reason: 'any rebirth counts');
    });
  });

  group('Mệt mỏi', () {
    test('monster EXP tapers after 4 and 6 hours, with a notice each step', () {
      final h = HeroData(name: 'T', hanh: Hanh.moc)..fatigueRoll('20261101');
      expect(h.expMul, 1);
      h.tickFatigue(fatigueStart - 1);
      expect(h.expMul, 1);
      expect(h.notices, isEmpty);
      h.tickFatigue(2);
      expect(h.expMul, 0.5);
      expect(h.notices.single.text, contains('50%'));
      h.tickFatigue(fatigueHeavy - fatigueStart);
      expect(h.expMul, 0.2);
      expect(h.notices.length, 2);
      h.buffs['songboi'] = 60;
      expect(h.expMul, closeTo(0.2 * 2, 1e-9), reason: 'Song Bội Đan still doubles');
    });

    test('a new day starts fresh; the count is saved', () {
      final h = HeroData(name: 'T', hanh: Hanh.moc)..fatigueRoll('20261101');
      h.tickFatigue(fatigueHeavy + 10);
      final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(back.fatigueDay, '20261101');
      expect(back.expMul, 0.2);
      back.fatigueRoll('20261101');
      expect(back.expMul, 0.2, reason: 'same day');
      back.fatigueRoll('20261102');
      expect(back.expMul, 1);
    });
  });

  test('every nightmare still has a dungeon behind it', () {
    expect(nightmareCount, dungeons.length);
  });
}

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/live_event.dart';
import 'package:kiem_hiep/core/newbie.dart';
import 'package:kiem_hiep/core/nightmare.dart';
import 'package:kiem_hiep/core/reminders.dart';
import 'package:kiem_hiep/core/world_boss.dart';

HeroData fresh() => HeroData(name: 'Tiểu Hiệp', hanh: Hanh.kim)..bornDay = '20261101';

void main() {
  tearDown(() => liveEvents = const []);

  group('Quà tân thủ', () {
    test('one gift a day, seven in all, ending with an outfit and a mount', () {
      final h = fresh();
      final rng = math.Random(1);
      expect(h.newbieReady('20261101'), isTrue);
      final gold = h.gold;
      expect(h.claimNewbie('20261101', rng), isNotEmpty);
      expect(h.gold, gold + newbieGifts[0].gold);
      expect(h.newbieReady('20261101'), isFalse, reason: 'once a day');
      expect(h.claimNewbie('20261101', rng), isEmpty);
      // Days need not be in a row.
      for (final d in ['20261103', '20261104', '20261110', '20261111', '20261112']) {
        expect(h.claimNewbie(d, rng), isNotEmpty);
      }
      expect(h.ownedCostumes, contains('thanhsam'));
      final last = h.claimNewbie('20261113', rng);
      expect(last.any((l) => l.contains('Bạch Mã')), isTrue);
      expect(h.ownsMount('bachma'), isTrue);
      expect(h.newbieOpen, isFalse);
      expect(h.claimNewbie('20261114', rng), isEmpty);
    });

    test('an outfit already owned pays gold instead', () {
      final h = fresh()
        ..newbieClaimed = 4
        ..ownedCostumes.add('thanhsam');
      final gold = h.gold;
      h.claimNewbie('20261101', math.Random(1));
      expect(h.gold, gold + newbieOwnedGold);
    });

    test('older heroes get it only while still low level', () {
      final low = HeroData(name: 'T', hanh: Hanh.moc);
      expect(low.newbieOpen, isTrue);
      low.rebirths = 1;
      expect(low.newbieOpen, isFalse);
      expect(fresh().newbieOpen, isTrue);
    });

    test('saved and loaded', () {
      final h = fresh()
        ..newbieClaimed = 3
        ..newbieDay = '20261103';
      final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(back.newbieClaimed, 3);
      expect(back.newbieDay, '20261103');
    });
  });

  group('Sự kiện', () {
    test('console documents, dates and weekends', () {
      expect(LiveEvent.fromMap('none', {'name': 'Không gì'}), isNull, reason: 'boosts nothing');
      final e = LiveEvent.fromMap('wk', {'name': 'Cuối tuần', 'exp': 2, 'gems': 9, 'weekends': true, 'from': 20261101})!;
      expect(e.gems, 3, reason: 'capped');
      expect(e.activeOn('20261031'), isFalse, reason: 'before from');
      expect(e.activeOn('20261101'), isTrue, reason: 'a Sunday');
      expect(e.activeOn('20261102'), isFalse, reason: 'a Monday');
      expect(e.activeOn('20261107'), isTrue, reason: 'Saturday');
      expect(e.perks, ['EXP quái x2', 'Rơi ngọc x3']);
    });

    test('boosts apply on their days only, the strongest of each', () {
      liveEvents = [
        const LiveEvent(id: 'a', exp: 2, from: '20261101', until: '20261130'),
        const LiveEvent(id: 'b', exp: 1.5, gold: 2, wbRuns: 2, from: '20261101', until: '20261130'),
      ];
      final b = EventBoost('20261105');
      expect(b.exp, 2);
      expect(b.gold, 2);
      expect(b.wbRuns, 2);
      expect(EventBoost('20261201').exp, 1);
    });

    test('Ác Mộng Thần Thiết doubles in an event', () {
      final day = vnDayKey();
      liveEvents = [const LiveEvent(id: 'x', iron: 2)];
      final h = HeroData(name: 'T', hanh: Hanh.kim)..rebirths = 1;
      h.nightmareReward(nightmareDef(14, NmAffix.frenzy), 3, math.Random(1), day: day);
      expect(h.divineIron, greaterThan(0));
      final plain = HeroData(name: 'T', hanh: Hanh.kim)..rebirths = 1;
      liveEvents = const [];
      plain.nightmareReward(nightmareDef(14, NmAffix.frenzy), 3, math.Random(1), day: day);
      expect(h.divineIron, plain.divineIron * 2);
    });

    test('extra Boss Thế Giới runs', () {
      final h = HeroData(name: 'T', hanh: Hanh.kim)..wbRollDay(vnDayKey());
      final base = h.wbRunsLeft;
      liveEvents = [const LiveEvent(id: 'x', wbRuns: 2)];
      expect(h.wbRunsLeft, base + 2);
    });
  });

  group('Nhắc nhở', () {
    test('tomorrow evening, then 3 and 7 days, at 19:30 Vietnam time', () {
      final h = fresh();
      // 10:00 in Vietnam on 1 Nov.
      final now = DateTime.utc(2026, 11, 1, 3);
      final plan = reminderPlan(h, now);
      final byId = {for (final r in plan) r.id: r};
      expect(byId[2]!.at, DateTime.utc(2026, 11, 2, 12, 30));
      expect(byId[3]!.at, DateTime.utc(2026, 11, 4, 12, 30));
      expect(byId[4]!.at, DateTime.utc(2026, 11, 8, 12, 30));
      // Training is full at 18:00, far enough from 19:30 the next day.
      expect(byId[1]!.at, now.add(const Duration(hours: 8)));
    });

    test('no training reminder in the night', () {
      // 20:00 in Vietnam: full at 04:00.
      final plan = reminderPlan(fresh(), DateTime.utc(2026, 11, 1, 13));
      expect(plan.any((r) => r.id == 1), isFalse);
    });

    test('newbie gift text while it lasts', () {
      final h = fresh();
      final r = reminderPlan(h, DateTime.utc(2026, 11, 1, 3), newbieWaiting: true).firstWhere((r) => r.id == 2);
      expect(r.body, contains('ngày 1'));
    });
  });
}

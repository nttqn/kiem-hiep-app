import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/content.dart';
import 'package:kiem_hiep/core/costumes.dart';
import 'package:kiem_hiep/core/festival.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/live_event.dart';
import 'package:kiem_hiep/core/mount_skins.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/core/world_boss.dart' show vnDayKey;

import 'v130_realm_test.dart' show geared;
import 'v140_sea_test.dart' show farm;

HeroData _roundTrip(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

final _dc = festById['dongchi']!;

void main() {
  setUp(() => liveEvents = const [LiveEvent(id: 't', fest: 'dongchi')]);
  tearDown(() => liveEvents = const []);

  test('Đông Chí runs 15/12 to 4/1, its shop five days more; a console event opens it too', () {
    liveEvents = const [];
    expect(festOn('20261214'), isNull);
    expect(festOn('20261215'), _dc);
    expect(festOn('20270104'), _dc);
    expect(festOn('20270105'), isNull);
    expect(festShopOn('20270109'), _dc);
    expect(festShopOn('20270110'), isNull);
    liveEvents = [LiveEvent.fromMap('x', {'fest': 'dongchi', 'from': '20261120', 'until': '20261122'})!];
    expect(festOn('20261121'), _dc);
    expect(festOn('20261123'), isNull);
    expect(LiveEvent.fromMap('y', {'name': 'trống'}), isNull, reason: 'still nothing to do');
  });

  test('its rewards exist and its monsters are off every other list', () {
    expect(costumeById[_dc.costume]?.source, CostumeSource.fest);
    expect(skinById[_dc.skin]?.source, SkinSource.fest);
    for (final id in [..._dc.mobs, _dc.boss]) {
      expect(mobById[id], isNotNull, reason: id);
      expect(mobs.any((m) => m.id == id), isFalse, reason: id);
    }
    expect(allSkus, contains(skuFest));
  });

  test('kills drop coins up to the day cap; tasks pay once', () {
    final h = geared(50, Hanh.kim);
    final rng = math.Random(1);
    final mob = mobById['fdSnowman']!;
    for (var i = 0; i < 2000; i++) {
      h.festKill(mob, rng: rng);
    }
    expect(h.festEarned, festDayCap);
    expect(h.festCoins, festDayCap);
    h.festKill(mobById[_dc.boss]!, rng: rng);
    expect(h.festCoins, festDayCap, reason: 'the boss is capped too');
    expect(h.festTasksReady, 3);
    expect(h.festClaimTask(0), festTaskCoins);
    expect(h.festClaimTask(0), 0);
    h.festClaimTask(1);
    h.festClaimTask(2);
    expect(h.festCoins, festDayCap + 2 * festTaskCoins + festBossTaskCoins);
    expect(h.festTasksReady, 0);
  });

  test('the shop sells each keepsake once and keeps to its limits', () {
    final h = geared(60, Hanh.moc)..mountLevels['nau'] = 1;
    h.festRoll(_dc, vnDayKey());
    h.festCoins = 100000;
    final rng = math.Random(2);
    for (final it in _dc.shop) {
      var n = 0;
      while (h.festBuy(_dc, it, rng) != null) {
        n++;
      }
      expect(n, it.limit, reason: it.id);
    }
    expect(h.ownedCostumes, contains(_dc.costume));
    expect(h.ownedSkins, contains(_dc.skin));
    expect(h.mountSkin['nau'], _dc.skin, reason: 'worn at once');
    expect(h.seasonTitles, contains(_dc.title));
    final cost = _dc.shop.fold(0, (s, it) => s + it.price * it.limit);
    expect(h.festCoins, 100000 - cost);
    // ignore: avoid_print
    print('whole shop: $cost coins; a day of play gives ${festDayCap + 2 * festTaskCoins + festBossTaskCoins}');

    final back = _roundTrip(h);
    expect((back.festId, back.festCoins, back.festBought['stones']), (h.festId, h.festCoins, h.festBought['stones']));
  });

  test('the pack delivers once a festival and comes back from the ledger', () {
    final h = geared(40, Hanh.thuy);
    h.grantFestPack();
    expect(h.festCoins, festPackCoins);
    expect(h.festPack, isTrue);
    final lost = _roundTrip(h)
      ..festPack = false
      ..festCoins = 0;
    expect(lost.reapplyGrant(const PaidGrant(sku: skuFest, seed: 0, slot: 0, until: '')), isNotNull);
    expect(lost.festCoins, festPackCoins);
    expect(h.reapplyGrant(const PaidGrant(sku: skuFest, seed: 0, slot: 0, until: '')), isNull);
  });

  test('the land fights at the hero level, scaled for rebirths', () {
    for (final (lv, cs) in [(20, 0), (55, 0), (90, 2), (99, 5)]) {
      final h = geared(lv, Hanh.values[lv % 5])..rebirths = cs;
      h.recompute();
      final m = festMap(_dc, h);
      expect((m.minLv, m.maxLv), (lv, lv));
      expect(isSideMap(m), isTrue, reason: 'no pond');
      final coins0 = h.festCoins;
      final (kills, deaths) = farm(h, m, minutes: 3);
      // ignore: avoid_print
      print('lv$lv cs$cs: $kills kills, $deaths deaths, +${h.festCoins - coins0} coins in 3 min');
      expect(deaths, lessThanOrEqualTo(2));
      expect(h.festCoins, greaterThan(coins0));
      if (cs == 5) {
        // Easier than Cửu U Ma Vực for the same hero.
        final b = geared(lv, Hanh.values[lv % 5])..rebirths = cs;
        b.recompute();
        final (abyss, _) = farm(b, abyssMap, minutes: 3);
        // ignore: avoid_print
        print('  Cửu U: $abyss kills');
        expect(kills, greaterThanOrEqualTo(abyss));
      } else {
        expect(kills, greaterThan(40));
      }
    }
  });
}

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/guild.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/leaderboard.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/guild_screen.dart';
import 'package:kiem_hiep/ui/hero_card.dart';
import 'package:kiem_hiep/ui/tien_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [Size(760, 344), Size(915, 412), Size(1280, 800)];
const _day = '20261111';

HeroData _hero() {
  final h = HeroData(name: 'Bang Chủ', hanh: Hanh.hoa)
    ..level = 99
    ..rebirths = 6
    ..gold = 50000000;
  h.recompute();
  return h;
}

HeroData _load(HeroData h) => HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);

void main() {
  group('Bang hội core', () {
    test('levels, seats and perk', () {
      expect(guildLevelOf(0), 1);
      expect(guildLevelOf(2999), 1);
      expect(guildLevelOf(3000), 2);
      expect(guildLevelOf(1 << 40), guildMaxLevel);
      expect(guildMaxMembers(1), 22);
      final h = _hero();
      final exp = h.expMul;
      h.joinGuild('g', 'G', roleMember, 4);
      expect(h.expMul, closeTo(exp * (1 + 4 * guildPerkPerLv), 1e-9));
      h.leaveGuild();
      expect(h.expMul, closeTo(exp, 1e-9));
    });

    test('Điểm danh, Quyên góp, Boss Bang and its chests', () {
      final h = _hero()..joinGuild('g', 'G', roleMember, 1);
      expect(h.guildSign(_day), isTrue);
      expect(h.guildSign(_day), isFalse);
      for (var i = 0; i < guildDonatesPerDay; i++) {
        expect(h.guildDonate(_day), isTrue);
      }
      expect(h.guildDonate(_day), isFalse);
      expect(h.guildContrib, guildSignContrib + guildDonatesPerDay * guildContribPerDonate);
      expect(h.guildCoins, h.guildContrib);
      for (var i = 0; i < guildBossRuns; i++) {
        expect(h.guildBossStart(_day), isTrue);
      }
      expect(h.guildBossStart(_day), isFalse);
      // No damage this week: no chest even when the bang made the mark.
      expect(h.guildChestReady(0, guildBossTiers[0]), isFalse);
      h.guildBossReward(5000000);
      expect(h.gBossDmg, 5000000);
      expect(h.lastDungeonGold, greaterThan(0));
      expect(h.guildChestReady(0, guildBossTiers[0] - 1), isFalse);
      final iron = h.divineIron;
      expect(h.guildTakeChest(0, guildBossTiers[0]), isNotEmpty);
      expect(h.divineIron, iron + guildBossChests[0].iron);
      expect(h.guildTakeChest(0, guildBossTiers[0]), isEmpty);
      // A new day: runs back; a new week: damage and chests too.
      expect(h.guildBossLeft('20261112'), guildBossRuns);
      h.guildRollDay('20261116');
      expect([h.gBossDmg, h.gBossClaimed], [0, 0]);
    });

    test('the shop: bang level, weekly limit, coins', () {
      final h = _hero()..joinGuild('g', 'G', roleMember, 1);
      final jade = guildShop.firstWhere((o) => o.ware == GuildWare.jade);
      final pills = guildShop.first;
      h.guildCoins = 10000;
      expect(h.guildBuyBlock(jade, _day), 'Bang cấp ${jade.minLv}');
      for (var i = 0; i < pills.limit; i++) {
        expect(h.guildBuy(pills, _day), isTrue);
      }
      expect(h.guildBuyBlock(pills, _day), 'Hết lượt tuần');
      h.guildLv = jade.minLv;
      expect(h.guildBuy(jade, _day), isTrue); // sixth life: Ngộ Đạo is open
      expect(h.tienJade, jade.n);
      h.rebirths = 5;
      expect(h.guildBuyBlock(jade, _day), 'Cần Ngộ Đạo');
    });

    test('friends: thirty, a gift each a day, ten taken a day', () {
      final h = _hero();
      for (var i = 0; i < maxFriends; i++) {
        expect(h.addFriend('u${i}_0', 'F$i', i % 5), isTrue);
      }
      expect(h.addFriend('x_0', 'X', 0), isFalse);
      expect(h.addFriend('u1_0', 'F1', 1), isFalse);
      expect(h.canGift('u1_0', _day), isTrue);
      h.markGifted('u1_0', _day);
      expect(h.canGift('u1_0', _day), isFalse);
      expect(h.canGift('u1_0', '20261112'), isTrue);
      final gold = h.gold;
      for (var i = 0; i < friendGiftsPerDay; i++) {
        expect(h.takeGift(_day), friendGiftGold(h.level, h.rebirths));
      }
      expect(h.takeGift(_day), 0);
      expect(h.gold, gold + friendGiftsPerDay * friendGiftGold(h.level, h.rebirths));
    });

    test('bang and friends are saved', () {
      final h = _hero()
        ..joinGuild('gid1', 'Thiên Hạ', roleVice, 3)
        ..guildContrib = 777
        ..guildCoins = 55
        ..guildApplied.add('gid2');
      h.guildRollDay(_day);
      h.guildSign(_day);
      h.gBossDmg = 1234;
      h.gShopBought['iron'] = 2;
      h.addFriend('a_0', 'A', 3);
      h.markGifted('a_0', _day);
      h.friendTaken = 4;
      final b = _load(h);
      expect([b.guildId, b.guildName, b.guildRole, b.guildLv, b.guildContrib, b.guildCoins],
          ['gid1', 'Thiên Hạ', roleVice, 3, 777 + guildSignContrib, 55 + guildSignContrib]);
      expect(b.guildApplied, ['gid2']);
      expect([b.gDay, b.gSigned, b.gBossDmg, b.gShopBought['iron']], [_day, true, 1234, 2]);
      expect(b.friends.single.name, 'A');
      expect(b.friendSent, {'a_0'});
      expect(b.friendTaken, 4);
    });
  });

  group('screens', () {
    late HeroData h;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      h = _hero();
      SaveService.instance.slots[0] = h;
      SaveService.instance.active = 0;
      GuildService.instance.debug = true;
      Leaderboard.instance.debugEntries = [
        const LbEntry(id: 'f_0', name: 'Bạn Hiền', hanh: 2, level: 88, rebirths: 3, power: 900000, tower: 50),
      ];
    });
    tearDown(() {
      GuildService.instance.debug = false;
      Leaderboard.instance.debugEntries = null;
    });

    Future<void> at(WidgetTester tester, Size s, Widget home) async {
      tester.view.physicalSize = s * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final s in _sizes) {
      final tag = '${s.width.toInt()}x${s.height.toInt()}';

      testWidgets('outside a bang fits $tag', (tester) async {
        await at(tester, s, const GuildScreen());
        expect(tester.takeException(), isNull);
        expect(find.text('Chưa vào bang'), findsOneWidget);
      });

      testWidgets('in a bang, every view fits $tag', (tester) async {
        final (id, _) = await GuildService.instance.create(h, 'Thiên Hạ $tag');
        h.joinGuild(id!, 'Thiên Hạ $tag', roleLeader, 1);
        await GuildService.instance.join(
            (await GuildService.instance.guild(id))!.let((g) => GuildInfo(id: g.id, name: g.name, leader: 'x', open: false)),
            _hero()..name = 'Người Xin');
        await at(tester, s, const GuildScreen());
        expect(tester.takeException(), isNull);
        expect(find.text('Thiên Hạ $tag'), findsOneWidget);
        for (final v in ['Thành viên', 'Cửa hàng', 'Kênh Bang', 'Tổng quan']) {
          await tester.tap(find.textContaining(v).first);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: v);
        }
        await tester.tap(find.textContaining('Điểm danh').first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.gSigned, isTrue);
      });

      testWidgets('Hảo hữu fits $tag', (tester) async {
        h.addFriend('f_0', 'Bạn Hiền', 2);
        h.addFriend('gone_0', 'Người Cũ', 0);
        await at(tester, s, const GuildScreen(tab: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('Bạn Hiền'), findsOneWidget);
        await tester.tap(find.text('Tặng tất cả'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.friendSent, {'f_0', 'gone_0'});
      });

      testWidgets('Tiên khí fits $tag', (tester) async {
        for (final sl in Slot.values) {
          h.equip[sl] = makeItem(slot: sl, level: 95, rarity: Rarity.legend, sect: h.sect, rng: math.Random(sl.index))
            ..plus = maxPlus;
        }
        h
          ..daoLv = 3
          ..tienJade = 9;
        await at(tester, s, const TienScreen());
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Luyện').first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.equip.values.where((it) => it.tien == 1), hasLength(1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('hero card with Tỉ thí and Kết bạn fits $tag', (tester) async {
        await at(
          tester,
          s,
          Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showHeroCard(ctx, Leaderboard.instance.debugEntries!.first),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Kết bạn'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.isFriend('f_0'), isTrue);
        expect(find.text('Bỏ bạn'), findsOneWidget);
      });
    }
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

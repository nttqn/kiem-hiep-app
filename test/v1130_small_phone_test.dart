import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/gear_sets.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/alchemy_screen.dart';
import 'package:kiem_hiep/ui/arena_screen.dart';
import 'package:kiem_hiep/ui/bag_screen.dart';
import 'package:kiem_hiep/ui/character_screen.dart';
import 'package:kiem_hiep/ui/dai_hoi_screen.dart';
import 'package:kiem_hiep/ui/rebirth_screen.dart';
import 'package:kiem_hiep/ui/sect_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:kiem_hiep/ui/town_screen.dart';
import 'package:kiem_hiep/ui/world_boss_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.13.0: players on small phones could not take a Sư môn duty's reward
/// ("Phục mệnh") or enter Boss Thế Giới: the buttons sat under the bottom
/// of the screen. These screens are laid out with the game's own fonts
/// (the test font is far wider) at the largest text the game allows (x1.1,
/// main.dart) on small landscape phones, and must not overflow.
Future<void> _fonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await l.load();
  }

  await load('BeVietnam', ['BeVietnamPro-Regular.ttf', 'BeVietnamPro-Bold.ttf', 'BeVietnamPro-ExtraBold.ttf']);
  await load('Playfair', ['PlayfairDisplay.ttf']);
}

const _sizes = [Size(700, 330), Size(760, 344)];

void main() {
  setUpAll(_fonts);

  final screens = <String, Widget Function()>{
    'Thành': () => const TownScreen(),
    'Thử thách': () => const ChallengeScreen(),
    'Sư môn': () => const SectScreen(),
    'Lôi đài': () => const ArenaScreen(),
    'Đại Hội': () => const DaiHoiScreen(),
    'Chuyển sinh': () => const RebirthScreen(),
    'Thuộc tính': () => const CharacterScreen(tab: 0),
    'Kỹ năng + Kinh mạch': () => const CharacterScreen(tab: 1),
    'Thần binh': () => const CharacterScreen(tab: 7),
    'Bộ đồ': () => const CharacterScreen(tab: 10),
    'Túi đồ · Trang bị': () => const BagScreen(),
    'Túi đồ · Vật phẩm': () => const BagScreen(tab: 1),
    'Thợ rèn · Hành trang': () => const CharacterScreen(tab: 2, forge: true),
    'Luyện đan': () => const AlchemyScreen(),
  };

  for (final (lv, cs) in const [(40, 0), (99, 6)]) {
    for (final s in _sizes) {
      for (final e in screens.entries) {
        testWidgets('${e.key} fits lv$lv cs$cs ${s.width.toInt()}x${s.height.toInt()} at x1.1 text', (tester) async {
          SharedPreferences.setMockInitialValues({});
          final h = HeroData(name: 'Thử Nghiệm', hanh: Hanh.moc)
            ..level = lv
            ..rebirths = cs
            ..gold = 123456789;
          if (cs == 6) h.daoLv = 10;
          h.meridianPts[1] = 400; // Tẩy kinh mạch shown, Chí mạng at its cap
          if (cs == 6) h.divine = 23; // Tiên binh rows
          // Túi đồ: big counts, a buff pill and a gem in the Vật phẩm grid.
          h
            ..goldShards = 12345
            ..soulPills = 7
            ..arenaCoins = 25000000
            ..pills['songboi'] = 3
            ..gemBag['2:4'] = 2;
          if (e.key == 'Bộ đồ') {
            // Two saved sets of long-named legend pieces, one piece gone.
            final rng = math.Random(5);
            for (final slot in Slot.values) {
              h.equip[slot] = makeItem(slot: slot, level: lv, rarity: Rarity.legend, sect: h.sect, rng: rng)
                ..plus = 10
                ..star = 10;
            }
            h.saveGearSet(0);
            h.saveGearSet(1);
            h.gearSets[1]!.uids[Slot.ring] = 999;
            h.dummyBest = 123456789;
          }
          h.recompute();
          SaveService.instance.slots[0] = h;
          SaveService.instance.active = 0;
          tester.view.physicalSize = s * 2.75;
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            theme: buildTheme(),
            builder: (c, child) =>
                MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.1)), child: child!),
            home: e.value(),
          ));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('"Vào Boss Thế Giới" is on screen on a small phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final h = HeroData(name: 'B', hanh: Hanh.kim)..level = 60;
    h.recompute();
    SaveService.instance.slots[0] = h;
    SaveService.instance.active = 0;
    tester.view.physicalSize = const Size(700, 330) * 2.75;
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.1)), child: child!),
      home: const ChallengeScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getRect(find.text('Vào Boss Thế Giới')).bottom, lessThanOrEqualTo(330));
  });
}

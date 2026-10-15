import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'core/content.dart';
import 'core/hanh.dart';
import 'core/hero.dart';
import 'core/items.dart';
import 'services/save.dart';
import 'services/sound.dart';
import 'ui/character_screen.dart';
import 'ui/create_screen.dart';
import 'ui/lists.dart';
import 'ui/play_screen.dart';
import 'ui/rewards_ui.dart';
import 'ui/shop_screen.dart';
import 'ui/theme.dart';
import 'ui/title_screen.dart';
import 'ui/town_screen.dart';

/// Dev entry for screenshots: `?screen=play&sect=3&level=20&map=hacphong`.
/// Builds a hero in memory (slot 0) and opens one screen directly.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final screen = q['screen'] ?? 'town';
  final sect = int.tryParse(q['sect'] ?? '') ?? 0;
  final level = int.tryParse(q['level'] ?? '') ?? 1;
  final female = q['female'] == '1';
  await SaveService.instance.load();
  SoundService.instance.init();
  var map = maps.first;
  for (final m in maps) {
    if (m.minLv <= level) map = m;
  }
  if (q['map'] != null) map = mapById[q['map']] ?? map;
  if (screen != 'title' && screen != 'create') {
    final h = HeroData(name: q['name'] ?? 'Tiểu Hiệp', hanh: Hanh.values[sect], female: female);
    final rng = math.Random(level * 7 + sect);
    for (var l = 1; l < level; l++) {
      h.gainExp(h.expNeeded.toDouble());
    }
    h.notices.clear();
    h.autoSpend();
    h.autoLearn();
    if (level > 1) {
      for (final s in Slot.values) {
        h.addItem(makeItem(
          slot: s,
          level: level,
          rarity: Rarity.values[1 + rng.nextInt(3)],
          sect: h.sect,
          rng: rng,
        ));
      }
      h.autoEquip();
      for (var i = 0; i < 14; i++) {
        h.addItem(makeItem(
          slot: Slot.values[rng.nextInt(7)],
          level: math.max(1, level - rng.nextInt(6)),
          rarity: rollRarity(rng),
          sect: h.sect,
          rng: rng,
        ));
      }
      h.gold = 1200 * level;
    }
    // By default, the main quest that hunts on the chosen map.
    final onMap = mainQuests.indexWhere((x) => map.mobs.contains(x.target) || x.target == map.boss);
    h.mainQuest = int.tryParse(q['quest'] ?? '') ?? (onMap < 0 ? 0 : onMap);
    h.refreshDaily(todayKey());
    SaveService.instance.slots[0] = h;
    SaveService.instance.active = 0;
    SaveService.instance.autoFight = q['auto'] != '0';
    final away = int.tryParse(q['away'] ?? '');
    if (away != null) SaveService.instance.pendingAway = Duration(minutes: away);
  }
  final Widget home = switch (screen) {
    'title' => const TitleScreen(),
    'create' => const CreateScreen(slot: 0),
    'play' => PlayScreen.field(map),
    'dungeon' => PlayScreen.dungeon(dungeonById[q['d'] ?? 'a1'] ?? dungeons.first),
    'char' => const CharacterScreen(tab: 0),
    'skills' => const CharacterScreen(tab: 1),
    'bag' => const CharacterScreen(tab: 2),
    'shop' => const ShopScreen(),
    'quests' => const QuestScreen(),
    'maps' => const MapListScreen(),
    'dungeons' => const DungeonListScreen(),
    'ach' => const AchievementsScreen(),
    _ => const TownScreen(),
  };
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: home,
  ));
}

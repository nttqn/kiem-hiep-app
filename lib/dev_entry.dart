import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'core/content.dart';
import 'core/gems.dart';
import 'core/hanh.dart';
import 'core/hero.dart';
import 'core/world.dart';
import 'game/battle_game.dart';
import 'render/art_figures.dart';
import 'render/world_renderer.dart';
import 'ui/backdrop.dart';
import 'ui/leaderboard_screen.dart';
import 'ui/world_boss_screen.dart';
import 'core/world_boss.dart';
import 'services/leaderboard.dart';
import 'core/tower.dart';
import 'core/items.dart';
import 'services/save.dart';
import 'services/sound.dart';
import 'ui/character_screen.dart';
import 'ui/create_screen.dart';
import 'ui/lists.dart';
import 'ui/pet_screen.dart';
import 'ui/rebirth_screen.dart';
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
  World.debugUltimate = q['ult'] == '1';
  // slow=4 runs battles at quarter speed for smooth screen recordings.
  BattleGame.debugSpeed = 1 / (double.tryParse(q['slow'] ?? '') ?? 1);
  PlayScreen.debugHideHud = q['hud'] == '0';
  // clean=1 also drops damage numbers and monster bars (thumbnails).
  WorldRenderer.debugClean = q['clean'] == '1';
  BattleGame.debugLogSfx = q['sfx'] == '1';
  // lb=1: a made-up leaderboard, since the web build has no Firebase.
  if (q['lb'] == '1') {
    const names = ['Độc Cô Cầu Bại', 'Lệnh Hồ Xung', 'Tiểu Long Nữ', 'Kiều Phong', 'Hư Trúc', 'Đoàn Dự',
        'Hoàng Dung', 'Quách Tĩnh', 'Dương Quá', 'Vô Kỵ', 'Chu Chỉ Nhược', 'Lâm Bình Chi'];
    Leaderboard.instance.debugBoss = [
      for (var i = 0; i < 10; i++)
        LbEntry(
          id: 'b${i}_0',
          name: const ['Kiều Phong', 'Độc Cô Cầu Bại', 'Hoàng Dung', 'Tiểu Long Nữ', 'Lệnh Hồ Xung', 'Đoàn Dự',
              'Hư Trúc', 'Quách Tĩnh', 'Dương Quá', 'Vô Kỵ'][i],
          hanh: (i + 3) % 5,
          level: 99 - i * 2,
          rebirths: 0,
          power: 18500000 - i * 1700000,
          tower: 0,
        ),
    ];
    Leaderboard.instance.debugEntries = [
      for (var i = 0; i < names.length; i++)
        LbEntry(
          id: 'u${i}_0',
          name: names[i],
          hanh: i % 5,
          level: 99 - i * 3,
          rebirths: math.max(0, 3 - i ~/ 2),
          power: 160000 - i * 9000,
          tower: 96 - i * 4,
          title: i == 0 ? 'Ngũ Chuyển Chân Nhân' : (i < 4 ? 'Võ Thánh' : ''),
        ),
    ];
  }
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
  // bak=1 on the title screen: slot 1 regressed to level 27 with a level 50
  // backup, as after a bad sync.
  if (screen == 'title' && q['bak'] == '1') {
    HeroData mk(int lv) {
      final h = HeroData(name: 'Tiểu Hiệp', hanh: Hanh.hoa);
      while (h.level < lv) {
        h.gainExp(h.expNeeded.toDouble());
      }
      h.notices.clear();
      return h;
    }
    SaveService.instance.slots[0] = mk(27);
    SaveService.instance.backups[0] = mk(50);
  }
  if (screen != 'title' && screen != 'create') {
    final h = HeroData(name: q['name'] ?? 'Tiểu Hiệp', hanh: Hanh.values[sect], female: female);
    final rng = math.Random(level * 7 + sect);
    for (var l = 1; l < level; l++) {
      h.gainExp(h.expNeeded.toDouble());
    }
    // exp=<0..100> fills that share of the bar, cs=<n> sets rebirths.
    h.rebirths = int.tryParse(q['cs'] ?? '') ?? 0;
    final expPct = int.tryParse(q['exp'] ?? '');
    if (expPct != null) h.exp = (h.expNeeded * expPct / 100).round();
    h.notices.clear();
    h.autoSpend();
    h.autoLearn();
    // sp=<n> spare skill points, mer=a,b,c,d,e kinh mạch points.
    if (q['sp'] != null) h.skillPoints = int.parse(q['sp']!);
    h.towerBest = int.tryParse(q['tower'] ?? '') ?? 0;
    // wb=<damage> fills today's Boss Thế Giới total (one run used).
    final wb = int.tryParse(q['wb'] ?? '');
    if (wb != null) {
      h.wbStartRun(vnDayKey());
      h.worldBossReward(wb, rng);
    }
    final mer = q['mer']?.split(',') ?? const [];
    for (var i = 0; i < mer.length && i < h.meridianPts.length; i++) {
      h.meridianPts[i] = int.tryParse(mer[i]) ?? 0;
    }
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
      // Some gems and pets to show off the gem and pet screens.
      for (final hn in Hanh.values) {
        h.addGem(Gem(hn, 1 + rng.nextInt(3)), 1 + rng.nextInt(4));
      }
      final w = h.equip[Slot.weapon];
      if (w != null && w.gems.isNotEmpty) {
        final g = Gem(h.hanh, 2);
        h.addGem(g);
        h.socketGem(w, 0, g);
      }
      h.petLevels['crane'] = 3;
      h.petLevels['tiger'] = 6;
      if (q['pets'] == 'all') {
        for (final (id, lv) in [('turtle', 9), ('fox', 12), ('kylin', 15), ('dragon', 20)]) {
          h.petLevels[id] = lv;
        }
      }
      h.activePet = q['pet'] ?? 'tiger';
      h.recompute();
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
    'wboss' => PlayScreen.dungeon(worldBossDef()),
    'dungeon' => PlayScreen.dungeon(q['tf'] != null
        ? towerFloor(int.parse(q['tf']!))
        : dungeonById[q['d'] ?? 'a1'] ?? dungeons.first),
    'rank' => const LeaderboardScreen(),
    'challenge' => const ChallengeScreen(),
    'boss' => const WorldBossScreen(),
    'treasure' => const ShopScreen(tab: 1),
    'refine' => const CharacterScreen(tab: 4, forge: true),
    'char' => const CharacterScreen(tab: 0),
    'skills' => const CharacterScreen(tab: 1),
    'bag' => const CharacterScreen(tab: 2),
    'shop' => const ShopScreen(),
    'quests' => const QuestScreen(),
    'maps' => const MapListScreen(),
    'dungeons' => const DungeonListScreen(),
    'ach' => const AchievementsScreen(),
    'pets' => const PetScreen(),
    'rebirth' => const RebirthScreen(),
    'gems' => const CharacterScreen(tab: 3, forge: true),
    'gear' => const _GearSheet(),
    _ => const TownScreen(),
  };
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: home,
  ));
}

/// Every sect, both sexes, at each gear look tier (rows), to check the art.
class _GearSheet extends StatelessWidget {
  const _GearSheet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A4A3A),
      body: FittedBox(
        child: Column(
          children: [
            for (var tier = 0; tier <= maxGearTier; tier++)
              Row(
                children: [
                  SizedBox(width: 40, child: Text('T$tier', style: const TextStyle(color: Colors.white))),
                  for (final hn in Hanh.values)
                    for (final f in [false, true])
                      FigurePreview(
                        hanh: hn,
                        female: f,
                        scale: 2.4,
                        gear: HeroGear(
                          weapon: tier,
                          hat: tier,
                          armor: tier,
                          belt: tier,
                          boots: tier,
                          pendant: tier == 0 ? 0 : Rarity.values[tier].color,
                          cape: tier >= maxGearTier,
                        ),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

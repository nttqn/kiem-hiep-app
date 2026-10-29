import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'core/activity.dart';
import 'core/chat.dart';
import 'services/chat.dart';
import 'ui/chat_screen.dart';
import 'core/alchemy.dart';
import 'core/arena.dart';
import 'core/companions.dart';
import 'core/content.dart';
import 'core/costumes.dart';
import 'core/fishing.dart';
import 'core/gold_sets.dart';
import 'core/manuals.dart';
import 'core/mounts.dart';
import 'core/nightmare.dart';
import 'core/sect_duty.dart';
import 'ui/fishing_view.dart';
import 'ui/sect_screen.dart';
import 'ui/activity_screen.dart';
import 'ui/alchemy_screen.dart';
import 'ui/arena_screen.dart';
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
  World.debugHerbNear = q['herb'] == '1';
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
          arenaS: arenaSeasonScore(arenaSeasonOf(vnDayKey()), 2150 - i * 95),
        ),
    ];
  }
  // chat=1: a made-up Kênh Thế Giới; chatwait=<s> seconds of cooldown left.
  if (q['chat'] == '1') {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    const lines = [
      ('Kiều Phong', 4, 99, 2, 'Ai đi Ác Mộng 15 không, thiếu một người đánh boss'),
      ('Hoàng Dung', 1, 92, 1, 'Ma khí tuần này là Bạo liệt, nhớ tránh xa xác quái nha'),
      ('Đoàn Dự', 2, 64, 0, 'Bí kíp Hoả thiên với Kim thiên cái nào mạnh hơn mọi người?'),
      ('Lệnh Hồ Xung', 3, 88, 1, 'Kim thiên tăng sát thương, Hoả thiên đốt máu, đánh boss thì Hoả'),
      ('Tiểu Long Nữ', 0, 71, 0, 'Câu được cá Kim Long rồi, vui quá vcl'),
      ('Hư Trúc', 4, 55, 0, 'Lôi đài mùa này ai top 1 vậy'),
      ('Độc Cô Cầu Bại', 3, 99, 3, 'Tôi :) Tháp tầng 140 rồi'),
    ];
    ChatService.instance.debugMessages = [
      for (var i = 0; i < lines.length; i++)
        ChatMsg(
          id: 'm$i',
          uid: 'u$i',
          name: lines[i].$1,
          hanh: lines[i].$2,
          level: lines[i].$3,
          rebirths: lines[i].$4,
          text: chatClean(lines[i].$5),
          at: t0 - (lines.length - i) * 7 * 60000,
        ),
    ];
    final cw = int.tryParse(q['chatwait'] ?? '');
    if (cw != null) ChatService.instance.lastSent = t0 - chatCooldown.inMilliseconds + cw * 1000;
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
    // look=<id> wears that outfit (granting it), costumes=all owns them all.
    if (q['costumes'] == 'all') h.ownedCostumes.addAll([for (final c in costumes) c.id]);
    h.unlockCostumes(quiet: true);
    if (q['look'] != null) {
      h.ownedCostumes.add(q['look']!);
      h.wearCostume(q['look']!);
    }
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
    // lh=<n>: past the main story, at Luân Hồi quest n (needs cs>=1).
    if (q['lh'] != null) {
      h.mainQuest = mainQuests.length;
      h.rbQuest = int.parse(q['lh']!);
    }
    // mount=<id|all>: ride that mount (all: own every one); herbs=<n> of
    // each; pills=1: a few of each pill and two buffs running; arena=<pts>;
    // act=<n>: n of every activity today.
    final mount = q['mount'];
    if (mount != null) {
      for (final m in mounts) {
        if (mount == 'all' || m.id == mount) h.mountLevels[m.id] = 3;
      }
      h.activeMount = mount == 'all' ? 'hanhuyet' : mount;
    }
    final herbsN = int.tryParse(q['herbs'] ?? '');
    if (herbsN != null) h.herbs.fillRange(0, h.herbs.length, herbsN);
    if (q['pills'] == '1') {
      for (final p in pills) {
        h.pills[p.id] = 2;
      }
      h.buffs['songboi'] = 900;
      h.buffs['cuongluc'] = 1100;
    }
    h.arenaPoints = int.tryParse(q['arena'] ?? '') ?? h.arenaPoints;
    h.arenaCoins = int.tryParse(q['coins'] ?? '') ?? h.arenaCoins;
    final act = int.tryParse(q['act'] ?? '');
    if (act != null) {
      for (final s in ActSource.values) {
        h.addActivity(s, s == ActSource.kills ? act * 30 : act);
      }
    }
    // comp=<id|all>[:bond]: hiệp khách met (all at that hảo cảm), the id
    // along; shards=<n>; gold=<set id>: a full Hoàng Kim set worn;
    // season=1: last season ended in Kim Kiếm (the result dialog).
    final comp = q['comp']?.split(':');
    if (comp != null) {
      final bond = comp.length > 1 ? int.parse(comp[1]) : 4;
      for (final c in companions) {
        if (comp[0] == 'all' || c.id == comp[0]) h.companionBonds[c.id] = bond;
      }
      h.activeCompanion = comp[0] == 'all' ? companions[h.hanh.index].id : comp[0];
    }
    h.goldShards = int.tryParse(q['shards'] ?? '') ?? h.goldShards;
    final gs = goldSetById[q['gold'] ?? ''];
    if (gs != null) {
      for (final s in Slot.values) {
        h.equip[s] = makeGoldItem(set: gs, slot: s, level: level, sect: h.sect, rng: rng);
      }
    }
    if (q['season'] == '1') {
      h.arenaRollDay(vnDayKey());
      h.arenaPoints = 1260;
      h.arenaSeasonResult = [arenaSeasonOf(vnDayKey()) - 1, 3, 1520, 320, 99000, 8, 4];
    }
    // Sư môn: rank=<chức vị> contrib=<cống hiến, also spendable>.
    h.sectRank = (int.tryParse(q['rank'] ?? '') ?? 0).clamp(0, maxSectRank);
    final contrib = int.tryParse(q['contrib'] ?? '');
    if (contrib != null) {
      h.sectContrib = contrib;
      h.sectCoins = contrib ~/ 3;
    }
    if (q['duty'] == 'done') {
      h.sectRollDay(vnDayKey(), rng);
      h.sectDone = 4;
      h.sectDuty?.progress = h.sectDuty!.count;
    }
    // manual=<pages>: that many pages of every school, the first worn.
    final manual = int.tryParse(q['manual'] ?? '');
    if (manual != null) {
      for (final i in manualSkills(h.sect)) {
        final s = h.sect.skills[i];
        final kinds = manualKindsFor(s);
        for (var k = 0; k < kinds.length; k++) {
          h.addManualPage(manualKey(s.id, kinds[k]), math.max(0, manual - k * 4));
        }
        h.setManual(s.id, kinds[i % kinds.length]);
      }
    }
    // nm=<n>: the first n nightmares cleared with three stars.
    final nm = int.tryParse(q['nm'] ?? '');
    if (nm != null) {
      for (var i = 1; i <= nm; i++) {
        h.nmStars['nm$i'] = 3;
      }
    }
    // fish=<n>: the first n fish caught; pond=1 starts by the pond.
    final fish = int.tryParse(q['fish'] ?? '');
    if (fish != null) {
      for (final f in fishes.take(fish)) {
        h.fishCaught[f.id] = 1 + rng.nextInt(9);
      }
    }
    World.debugPond = q['pond'] == '1';
    FishingPanel.debugBite = double.tryParse(q['bite'] ?? '');
    // gift=0: today's login gift already taken (no dialog over the town).
    if (q['gift'] == '0') h.lastLoginDate = todayKey();
    h.recompute();
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
    'chat' => const ChatScreen(),
    'challenge' => const ChallengeScreen(),
    'boss' => const WorldBossScreen(),
    'treasure' => const ShopScreen(tab: 1),
    'refine' => const CharacterScreen(tab: 4, forge: true),
    'char' => const CharacterScreen(tab: 0),
    'skills' => const CharacterScreen(tab: 1),
    'bag' => const CharacterScreen(tab: 2),
    'shop' => const ShopScreen(),
    'quests' => const QuestScreen(),
    'bounty' => const QuestScreen(tab: 1),
    'maps' => const MapListScreen(),
    'dungeons' => const DungeonListScreen(),
    'ach' => const AchievementsScreen(),
    'pets' => const PetScreen(),
    'rebirth' => const RebirthScreen(),
    'gems' => const CharacterScreen(tab: 3, forge: true),
    'gear' => const _GearSheet(),
    'outfits' => const _OutfitSheet(),
    'wardrobe' => const CharacterScreen(tab: 5),
    'mounts' => const PetScreen(tab: 1),
    'comp' => const PetScreen(tab: 2),
    'goldforge' => const CharacterScreen(tab: 6, forge: true),
    'alchemy' => const AlchemyScreen(),
    'activity' => const ActivityScreen(),
    'arena' => const ArenaScreen(),
    'sect' => const SectScreen(),
    'nightmare' => const DungeonListScreen(nightmare: true),
    'nmplay' => PlayScreen.dungeon(nightmareDef(int.tryParse(q['nmi'] ?? '') ?? 0,
        NmAffix.values[int.tryParse(q['affix'] ?? '') ?? 0])),
    'trial' => PlayScreen.dungeon(sectTrialDef(SaveService.instance.hero.sectExaminerNow())),
    'duel' => PlayScreen.dungeon(arenaDef(botRivals(
        power: SaveService.instance.hero.power,
        level: SaveService.instance.hero.level,
        rebirths: 1,
        seed: 3)[1])),
    _ => const TownScreen(),
  };
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: home,
  ));
}

/// Every outfit (rows) on each sect, both sexes, over mid-tier gear.
class _OutfitSheet extends StatelessWidget {
  const _OutfitSheet();

  @override
  Widget build(BuildContext context) {
    const gear = HeroGear(weapon: 2, hat: 2, armor: 2, belt: 2, boots: 2);
    return Scaffold(
      backgroundColor: const Color(0xFF3A4A3A),
      body: FittedBox(
        child: Column(
          children: [
            for (final c in costumes)
              Row(
                children: [
                  SizedBox(width: 150, child: Text(c.name, style: const TextStyle(color: Colors.white))),
                  for (final hn in Hanh.values)
                    for (final f in [false, true])
                      FigurePreview(hanh: hn, female: f, scale: 0.9, gear: gear, costume: c),
                ],
              ),
          ],
        ),
      ),
    );
  }
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

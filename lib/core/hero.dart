import 'dart:math' as math;

import 'activity.dart';
import 'alchemy.dart';
import 'arena.dart';
import 'bounty.dart';
import 'companions.dart';
import 'content.dart';
import 'costumes.dart';
import 'gold_sets.dart';
import 'fishing.dart';
import 'luan_hoi.dart';
import 'gems.dart';
import 'hanh.dart';
import 'items.dart';
import 'manuals.dart';
import 'meridians.dart';
import 'mounts.dart';
import 'nightmare.dart';
import 'pets.dart';
import 'sect_duty.dart';
import 'tower.dart';
import 'treasure.dart';
import 'world_boss.dart';
import 'sects.dart';

/// 1234567 as "1.234.567" (Vietnamese grouping) for reward lines.
String _thousands(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

const int maxLevel = 99;
const int pointsPerLevel = 5;

// Chuyển sinh: at level 99 with a full EXP bar the hero may be reborn at
// [rebirthLevel], keeping gear, skills, gems, pets and gold, for permanent
// bonuses that stack with each rebirth.
const int maxRebirths = 5;
const int rebirthLevel = 10;
const int rebirthPoints = 40;
const double rebirthHpAtk = 0.05;
const double rebirthDef = 0.04;
const double rebirthExp = 0.5;

/// Permanent bonuses after [n] rebirths.
Map<Bonus, double> rebirthBonuses(int n) => n <= 0
    ? const {}
    : {Bonus.hpPct: rebirthHpAtk * n, Bonus.atkPct: rebirthHpAtk * n, Bonus.defPct: rebirthDef * n};
const int bagSize = 60;

// ---------------------------------------------------------------- balance

double mobExpAt(int l) => 8 + 4.0 * l;
int expToNext(int l) => (mobExpAt(l) * (20 + 3.0 * l + 0.25 * l * l)).round();
double mobHpAt(int l) => 150 + 50.0 * l + 2.0 * l * l;
double mobAtkAt(int l) => 8 + 5.0 * l;
double mobDefAt(int l) => 5 + 2.5 * l;

/// Share of damage a defender with [def] shrugs off from an attacker of
/// [attackerLevel].
double mitigation(double def, int attackerLevel) =>
    def / (def + 40 + 12 * attackerLevel);

/// Killing far weaker monsters pays little, so heroes move on.
double expLevelFactor(int heroLevel, int mobLevel) {
  final d = mobLevel - heroLevel;
  if (d >= 0) return 1 + math.min(d, 5) * 0.05;
  if (d >= -4) return 1;
  if (d >= -8) return 0.6;
  return 0.25;
}

/// Derived numbers the fight uses.
class Stats {
  double maxHp = 0, maxMp = 0, atk = 0, def = 0;
  double crit = 0, critDmg = 0, dodge = 0, aspd = 1, move = 0;
  double hpRegen = 0, mpRegen = 0, skillDmg = 0, cdr = 0, dotPct = 0;
  List<int> attrs = [0, 0, 0, 0];
}

class DailyQuest {
  DailyQuest({
    required this.type,
    required this.target,
    required this.count,
    required this.exp,
    required this.gold,
    this.progress = 0,
    this.done = false,
  });

  final QuestType type;

  /// Monster id, '*' for any monster, or '' for any dungeon.
  final String target;
  final int count;
  final int exp;
  final int gold;
  int progress;
  bool done;

  String get goal => switch (type) {
        QuestType.kill => target == '*'
            ? 'Hạ $count quái bất kỳ'
            : 'Hạ $count ${mobById[target]!.name}'
                ' (${mapOfMob(target)?.name ?? ''})',
        QuestType.boss => 'Đánh bại ${mobById[target]!.name}',
        QuestType.dungeon => 'Vượt ải bất kỳ $count lần',
        QuestType.level || QuestType.elite => '',
      };

  Map<String, dynamic> toJson() => {
        't': type.index,
        'g': target,
        'c': count,
        'e': exp,
        'o': gold,
        'p': progress,
        'd': done,
      };

  static DailyQuest fromJson(Map<String, dynamic> m) => DailyQuest(
        type: QuestType.values[m['t'] as int],
        target: m['g'] as String,
        count: m['c'] as int,
        exp: m['e'] as int,
        gold: m['o'] as int,
        progress: m['p'] as int,
        done: m['d'] as bool,
      );
}

/// What happened to the hero that the UI should announce.
class Notice {
  Notice(this.text, {this.color = 0xFFFFF3C4, this.big = false});
  final String text;
  final int color;
  final bool big;
}

/// Everything saved about one character.
class HeroData {
  HeroData({required this.name, required this.hanh, this.female = false}) {
    skillLv[0] = 1;
    recompute();
  }

  String name;
  final Hanh hanh;
  bool female;
  int level = 1;
  int exp = 0;
  int gold = 80;

  /// Points put in str, dex, vit, ene on top of the sect's base.
  final List<int> spent = [0, 0, 0, 0];
  int freePoints = 0;
  int skillPoints = 0;
  /// Levels of the sect's skills: six regular ones and the tuyệt kỹ.
  final List<int> skillLv = List.filled(7, 0);

  /// Points trained into each kinh mạch, by phase.
  final List<int> meridianPts = List.filled(5, 0);
  final Map<Slot, Item> equip = {};
  final List<Item> bag = [];
  int hpPots = 15;
  int mpPots = 10;
  int mainQuest = 0;
  int mainProgress = 0;
  String dailyDate = '';
  List<DailyQuest> daily = [];
  final Map<String, int> dungeonStars = {};
  int kills = 0;
  double playSeconds = 0;
  bool autoSellCommon = false;
  int seed = 0;

  /// When this save was last written (ms since epoch); cloud sync keeps
  /// whichever copy is newer.
  int savedAt = 0;

  /// The last dungeon payout, so a rewarded ad can pay it again.
  // Retention: login gift cycle, records for achievements, worn title.
  String lastLoginDate = '';
  int loginDay = 0;
  int bossKills = 0;
  int bestPlus = 0;
  bool ownedLegend = false;
  final Set<String> achClaimed = {};
  String title = '';

  // Gems in the bag by Gem.key, pets owned with their level, the pet out,
  // and kills per boss (for the pet drop pity).
  final Map<String, int> gemBag = {};
  final Map<String, int> petLevels = {};
  String activePet = '';
  final Map<String, int> bossKillsById = {};

  /// Times reborn (chuyển sinh), 0..[maxRebirths].
  int rebirths = 0;

  /// Highest Tháp Thử Luyện floor cleared.
  int towerBest = 0;

  // Boss Thế Giới, per Vietnam day: runs used (free and ad), the day's total
  // and best run, and which damage milestones were claimed (bit mask).
  String wbDay = '';
  int wbRuns = 0;
  int wbAdRuns = 0;
  int wbTotal = 0;
  int wbBest = 0;
  int wbClaimed = 0;

  /// Luân Hồi: quest index in this rebirth's chapter, and chapters finished.
  int rbQuest = 0;
  int rbDone = 0;

  // Bảng Truy Nã: the posted bounties, and per day the new ones still to
  // come and the ad refreshes used.
  final List<Bounty> bounties = [];
  String bountyDay = '';
  int bountyLeft = 0;
  int bountyAds = 0;

  // Ngoại trang: outfits owned, the one worn ('' shows the gear's own look),
  // and whether the hat is hidden.
  final Set<String> ownedCostumes = {};
  String costume = '';
  bool hideHat = false;

  // Kỳ Trân Các, per day: refreshes made and offers bought (indices).
  String shopDay = '';
  int shopRefresh = 0;
  final Set<int> shopBought = {};

  // Thú cưỡi: mounts owned with their level, the one ridden, and whether
  // the hero rides at all.
  final Map<String, int> mountLevels = {};
  String activeMount = '';
  bool riding = true;

  // Luyện đan: herbs by tier, pills on hand, buff time left (play seconds)
  // and Tẩy Tủy Đan eaten.
  final List<int> herbs = List.filled(herbNames.length, 0);
  final Map<String, int> pills = {};
  final Map<String, double> buffs = {};
  int potentialPills = 0;

  // Lôi đài: points, Uy danh, per day fights and ad fights, the day the
  // salary was claimed, wins, and list refreshes (for invented rivals).
  int arenaPoints = arenaStartPoints;
  int arenaCoins = 0;
  String arenaDay = '';
  int arenaFights = 0;
  int arenaAds = 0;
  String arenaSalaryDay = '';
  int arenaWins = 0;
  int arenaRefresh = 0;

  // Mùa giải: the season the points belong to, fights in it, the best tier
  // ever ended a season in (-1 none), and the last settled season's
  // [season, tier, points] until the Lôi đài screen has shown it.
  int arenaSeason = 0;
  int arenaSeasonFights = 0;
  int arenaBestTier = -1;
  List<int> arenaSeasonResult = const [];

  /// Mảnh Hoàng Kim for forging Hoàng Kim pieces.
  int goldShards = 0;

  // Hiệp khách: companions met with their hảo cảm, and the one along.
  final Map<String, int> companionBonds = {};
  String activeCompanion = '';

  // Năng động: today's actions by source and chests claimed (bit mask),
  // then the week's points and chests.
  String actDay = '';
  final Map<ActSource, int> actCounts = {};
  int actClaimed = 0;
  String actWeek = '';
  int actWeekPoints = 0;
  int actWeekClaimed = 0;

  // Sư môn: chức vị, cống hiến earned in all and on hand, and per day the
  // duties handed in, plus the one under way.
  int sectRank = 0;
  int sectContrib = 0;
  int sectCoins = 0;
  String sectDay = '';
  int sectDone = 0;
  SectDuty? sectDuty;

  // Bí kíp: pages by manualKey, and the school each skill wears (by skill
  // id, ManualKind index).
  final Map<String, int> manualPages = {};
  final Map<String, int> manualOn = {};

  // Câu cá: per day the baits used and ad baits, catches by fish, and the
  // Ngư phổ pages paid (map ids).
  String fishDay = '';
  int fishUsed = 0;
  int fishAds = 0;
  final Map<String, int> fishCaught = {};
  final Set<String> fishBooks = {};

  // Ải Ác Mộng: best stars by id, and per day the paid clears.
  final Map<String, int> nmStars = {};
  String nmDay = '';
  int nmRuns = 0;

  int lastDungeonGold = 0;
  double lastDungeonExp = 0;

  final Stats stats = Stats();

  SectDef get sect => sectOf(hanh);

  /// The story quest under way: the main story, then after a rebirth that
  /// rebirth's Luân Hồi chapter.
  QuestDef? get currentMain {
    if (mainQuest < mainQuests.length) return mainQuests[mainQuest];
    if (rebirths == 0) return null;
    final qs = luanHoi[chapter].quests;
    return rbQuest < qs.length ? qs[rbQuest] : null;
  }

  /// Luân Hồi chapter for this rebirth (0-based).
  int get chapter => (rebirths.clamp(1, luanHoi.length)) - 1;

  bool get inLuanHoi => mainQuest >= mainQuests.length && rebirths > 0;

  /// "Chính tuyến 12/56" or "Luân Hồi II · 3/12".
  String get questLabel => inLuanHoi
      ? '${chapterLabel(chapter)} · ${rbQuest + 1}/${luanHoi[chapter].quests.length}'
      : 'Chính tuyến ${mainQuest + 1}/${mainQuests.length}';

  bool get mainLocked => (currentMain?.minLv ?? 0) > level;

  /// Pending messages for the UI (level up, quest done…).
  final List<Notice> notices = [];

  // ------------------------------------------------------------- stats

  Map<Bonus, double> passiveBonuses() {
    final out = <Bonus, double>{};
    for (var i = 0; i < sect.skills.length; i++) {
      final s = sect.skills[i];
      if (!s.isPassive || skillLv[i] == 0) continue;
      s.passive.forEach((k, v) => out[k] = (out[k] ?? 0) + v * skillLv[i]);
    }
    return out;
  }

  /// Distinct phases among gems socketed in worn gear.
  int get gemPhases => {
        for (final it in equip.values)
          for (final g in it.gems)
            if (g != null) g.hanh,
      }.length;

  /// Passives plus socketed gems, the gem set bonus and the pet's bonus.
  Map<Bonus, double> allBonuses() {
    final out = passiveBonuses();
    void add(Map<Bonus, double> m, [double mul = 1]) =>
        m.forEach((k, v) => out[k] = (out[k] ?? 0) + v * mul);
    for (final it in equip.values) {
      for (final g in it.gems) {
        if (g != null) add(gemEffect(g), g.hanh == hanh ? banMenhBonus : 1);
      }
    }
    add(setBonus(gemPhases));
    add(rebirthBonuses(rebirths));
    for (var i = 0; i < meridians.length; i++) {
      final n = meridianPts[i];
      if (n > 0) add({meridians[i].bonus: meridians[i].valueAt(n)});
    }
    final pet = petById[activePet];
    if (pet != null) add({pet.bonus: pet.bonusAt(petLevels[pet.id] ?? 1)});
    final mount = ridingMount;
    if (mount != null) {
      final lv = mountLevels[mount.id] ?? 1;
      add({Bonus.move: mount.moveAt(lv), mount.bonus: mount.bonusAt(lv)});
    }
    buffs.forEach((id, left) {
      final p = pillById[id];
      if (p != null && left > 0) add(p.bonus);
    });
    add(goldSetBonuses(goldPieces(equip.values)));
    final comp = companionById[activeCompanion];
    if (comp != null) add({comp.bonus: comp.bonusAt(companionBonds[comp.id] ?? 1)});
    add(sectRankBonus(hanh, sectRank));
    return out;
  }

  // ------------------------------------------------------------- gems

  int gemCount(Gem g) => gemBag[g.key] ?? 0;

  void addGem(Gem g, [int n = 1]) => gemBag[g.key] = gemCount(g) + n;

  bool _takeGem(Gem g, [int n = 1]) {
    final c = gemCount(g);
    if (c < n) return false;
    if (c == n) {
      gemBag.remove(g.key);
    } else {
      gemBag[g.key] = c - n;
    }
    return true;
  }

  /// Puts a gem from the bag into socket [i] of [it] (returning any gem
  /// already there).
  bool socketGem(Item it, int i, Gem g) {
    if (i < 0 || i >= it.gems.length || !_takeGem(g)) return false;
    final old = it.gems[i];
    if (old != null) addGem(old);
    it.gems[i] = g;
    recompute();
    return true;
  }

  void unsocketGem(Item it, int i) {
    final g = it.gems[i];
    if (g == null) return;
    addGem(g);
    it.gems[i] = null;
    recompute();
  }

  /// Three gems of a tier become one of the next tier, for gold.
  bool fuseGem(Gem g) {
    if (g.tier >= maxGemTier || gold < fuseCost(g.tier) || gemCount(g) < 3) return false;
    gold -= fuseCost(g.tier);
    _takeGem(g, 3);
    addGem(Gem(g.hanh, g.tier + 1));
    return true;
  }

  // ------------------------------------------------------------- pets

  bool ownsPet(String id) => petLevels.containsKey(id);

  bool buyPet(PetDef p) {
    if (p.price <= 0 || ownsPet(p.id) || gold < p.price) return false;
    gold -= p.price;
    petLevels[p.id] = 1;
    if (activePet.isEmpty) activePet = p.id;
    recompute();
    return true;
  }

  bool levelPet(PetDef p) {
    final lv = petLevels[p.id];
    if (lv == null || lv >= maxPetLevel || gold < petLevelCost(lv)) return false;
    gold -= petLevelCost(lv);
    petLevels[p.id] = lv + 1;
    recompute();
    return true;
  }

  void setActivePet(String id) {
    activePet = activePet == id ? '' : id;
    recompute();
  }

  /// Rolls the boss's pet drop after a kill; returns it when tamed.
  PetDef? rollPet(String bossId, math.Random rng) {
    final p = petFromBoss(bossId);
    if (p == null || ownsPet(p.id)) return null;
    final kills = bossKillsById[bossId] ?? 0;
    if (kills < petPity && rng.nextDouble() >= petDropChance) return null;
    petLevels[p.id] = 1;
    if (activePet.isEmpty) activePet = p.id;
    recompute();
    return p;
  }

  void recompute() {
    final gear = <Stat, double>{};
    for (final it in equip.values) {
      it.totals.forEach((k, v) => gear[k] = (gear[k] ?? 0) + v);
    }
    double g(Stat s) => gear[s] ?? 0;
    final p = allBonuses();
    double b(Bonus k) => p[k] ?? 0;
    final a = [
      for (var i = 0; i < 4; i++)
        sect.base[i] + spent[i] + g(Stat.values[i]).round(),
    ];
    final st = stats;
    st.attrs = a;
    final l = level;
    st.maxHp = (150 + 15 * l + a[2] * 12 + g(Stat.hp)) *
        sect.hpMul *
        (1 + b(Bonus.hpPct));
    st.maxMp = (40 + 4 * l + a[3] * 6 + g(Stat.mp)) * (1 + b(Bonus.mpPct));
    var raw = 8.0 + 2 * l + g(Stat.atk);
    for (var i = 0; i < 4; i++) {
      raw += a[i] * sect.atkWeights[i];
    }
    st.atk = raw * (1 + b(Bonus.atkPct));
    st.def = (2 + 1.5 * l + a[2] * 0.5 + g(Stat.def)) * (1 + b(Bonus.defPct));
    st.crit = math.min(0.6, 0.05 + a[1] * 0.0025 + g(Stat.crit) + b(Bonus.crit));
    st.critDmg = 1.5 + g(Stat.critDmg) + b(Bonus.critDmg);
    st.dodge = math.min(0.35, a[1] * 0.0015 + g(Stat.dodge) + b(Bonus.dodge));
    st.aspd = math.min(2.0, 1 + a[1] * 0.004 + g(Stat.aspd) + b(Bonus.aspd));
    st.move = math.min(320, (165 + g(Stat.move)) * (1 + b(Bonus.move)));
    st.hpRegen = st.maxHp * (0.004 + b(Bonus.regen));
    st.mpRegen = st.maxMp * 0.02 + a[3] * 0.05;
    st.skillDmg = b(Bonus.skillDmg);
    st.cdr = math.min(0.3, b(Bonus.cdr));
    st.dotPct = b(Bonus.dotPct);
  }

  // ------------------------------------------------------------- growth

  int get expNeeded => expToNext(level);

  /// Level 99 with the EXP bar filled: nothing more to gain.
  bool get expFull => level >= maxLevel && exp >= expToNext(maxLevel);

  bool get canRebirth => expFull && rebirths < maxRebirths;

  /// Adds EXP and handles level-ups. Returns levels gained. At level 99 the
  /// bar still fills up, which is the requirement for a rebirth.
  int gainExp(double amount) {
    amount *= 1 + rebirthExp * rebirths;
    if (level >= maxLevel) {
      final cap = expToNext(maxLevel);
      if (exp >= cap) return 0;
      exp = math.min(cap, exp + amount.round());
      if (exp >= cap && rebirths < maxRebirths) {
        notices.add(Notice('Kinh nghiệm đã đầy! Về thành để chuyển sinh.', color: 0xFFFFD34A, big: true));
      }
      return 0;
    }
    exp += amount.round();
    var gained = 0;
    while (level < maxLevel && exp >= expToNext(level)) {
      exp -= expToNext(level);
      level++;
      gained++;
      freePoints += pointsPerLevel;
      skillPoints++;
    }
    if (level >= maxLevel) exp = math.min(exp, expToNext(maxLevel));
    if (gained > 0) {
      recompute();
      notices.add(Notice('THĂNG CẤP $level!', color: 0xFFFFD34A, big: true));
      _checkLevelQuests();
      unlockCostumes();
    }
    return gained;
  }

  bool spendPoint(int attr, [int n = 1]) {
    n = math.min(n, freePoints);
    if (n <= 0) return false;
    spent[attr] += n;
    freePoints -= n;
    recompute();
    return true;
  }

  /// Spreads every free point following the sect's suggested build.
  void autoSpend() {
    final w = sect.autoBuild;
    final total = w.reduce((x, y) => x + y);
    var i = 0;
    while (freePoints > 0) {
      // Round-robin weighted by the build: attr k gets w[k] of each total.
      final slot = i % total;
      var acc = 0;
      for (var k = 0; k < 4; k++) {
        acc += w[k];
        if (slot < acc) {
          spent[k]++;
          break;
        }
      }
      freePoints--;
      i++;
    }
    recompute();
  }

  int get resetCost => level * 60;

  bool resetPoints() {
    if (gold < resetCost) return false;
    gold -= resetCost;
    for (var i = 0; i < 4; i++) {
      freePoints += spent[i];
      spent[i] = 0;
    }
    recompute();
    return true;
  }

  /// Whether skill [i] is open to points: its unlock level was reached in
  /// this life or any earlier one.
  bool skillOpen(int i) => level >= sect.skills[i].unlock || rebirths > 0;

  /// Đột phá lets the regular skills go past 10.
  bool get breakthrough => level >= breakthroughLevel || rebirths > 0;

  int skillCap(int i) => !sect.skills[i].ultimate && breakthrough ? maxBreakLevel : maxSkillLevel;

  bool canLearn(int i) => skillPoints > 0 && skillLv[i] < skillCap(i) && skillOpen(i);

  bool get meridiansOpen => level >= meridianLevel || rebirths > 0;

  bool canTrainMeridian() => skillPoints > 0 && meridiansOpen;

  bool trainMeridian(int i, [int n = 1]) {
    n = math.min(n, skillPoints);
    if (n <= 0 || !meridiansOpen) return false;
    meridianPts[i] += n;
    skillPoints -= n;
    recompute();
    return true;
  }

  bool learn(int i) {
    if (!canLearn(i)) return false;
    skillLv[i]++;
    skillPoints--;
    recompute();
    return true;
  }

  /// Spends skill points: unlock new skills first, then the tuyệt kỹ and the
  /// first active, then whatever is lowest; once every skill is full after
  /// the breakthrough, the rest goes into the kinh mạch, evening them out
  /// (own phase first).
  void autoLearn() {
    final n = sect.skills.length;
    while (skillPoints > 0) {
      int? pick;
      for (var i = 0; i < n; i++) {
        if (canLearn(i) && skillLv[i] == 0) {
          pick = i;
          break;
        }
      }
      if (pick == null) {
        var best = 99;
        for (var i = 0; i < n; i++) {
          if (!canLearn(i)) continue;
          // Bias toward the bread-and-butter first skill and the tuyệt kỹ.
          final v = skillLv[i] * 2 - (i == 0 ? 3 : 0) - (sect.skills[i].ultimate ? 6 : 0);
          if (v < best) {
            best = v;
            pick = i;
          }
        }
      }
      if (pick == null) break;
      learn(pick);
    }
    // Before the breakthrough, spare points wait for the skills to open up.
    while (breakthrough && canTrainMeridian()) {
      var m = hanh.index;
      for (var i = 0; i < meridians.length; i++) {
        if (meridianPts[i] < meridianPts[m]) m = i;
      }
      trainMeridian(m);
    }
  }

  // ------------------------------------------------------------- items

  /// Puts [it] in the bag, or sells it if the bag is full or it is a
  /// common item and auto-sell is on. Returns false if sold.
  bool addItem(Item it) {
    if (it.rarity == Rarity.legend) ownedLegend = true;
    if ((autoSellCommon && it.rarity == Rarity.common) ||
        bag.length >= bagSize) {
      gold += it.sellPrice;
      return false;
    }
    bag.add(it);
    return true;
  }

  void equipItem(Item it) {
    bag.remove(it);
    final old = equip[it.slot];
    equip[it.slot] = it;
    if (old != null) bag.add(old);
    recompute();
  }

  void unequip(Slot s) {
    final old = equip.remove(s);
    if (old != null) bag.add(old);
    recompute();
  }

  /// Selling never loses gems: they go back to the gem bag.
  void sell(Item it) {
    if (!bag.remove(it)) return;
    gold += it.sellPrice;
    for (final g in it.gems) {
      if (g != null) addGem(g);
    }
  }

  /// Equips every bag item that scores higher than what is worn.
  int autoEquip() {
    var n = 0;
    for (final slot in Slot.values) {
      Item? best = equip[slot];
      for (final it in bag) {
        if (it.slot != slot || it.level > level) continue;
        if (best == null || it.score > best.score) best = it;
      }
      if (best != null && best != equip[slot]) {
        equipItem(best);
        n++;
      }
    }
    return n;
  }

  // ------------------------------------------------------------- rebirth

  /// Back to [rebirthLevel] with every potential point refunded (minus the
  /// ones earned above that level) plus [rebirthPoints] more.
  bool rebirth() {
    if (!canRebirth) return false;
    rebirths++;
    // A new Luân Hồi chapter starts (after the main story, if unfinished).
    rbQuest = 0;
    if (mainQuest >= mainQuests.length) mainProgress = 0;
    var total = freePoints;
    for (var i = 0; i < 4; i++) {
      total += spent[i];
      spent[i] = 0;
    }
    total -= (level - rebirthLevel) * pointsPerLevel;
    freePoints = math.max(0, total) + rebirthPoints;
    level = rebirthLevel;
    exp = 0;
    recompute();
    notices.add(Notice('CHUYỂN SINH LẦN $rebirths!', color: 0xFFFFD34A, big: true));
    unlockCostumes();
    // Bounties were rolled for level 99 maps: post new ones for level 10.
    bounties.clear();
    _fillBounties(math.Random(seed ^ rebirths), free: true);
    if (sectDuty != null) sectDuty = _rollSectDuty(math.Random(seed ^ rebirths));
    return true;
  }

  // ------------------------------------------------------------- truy nã

  bool get bountyOpen => level >= bountyMinLevel || rebirths > 0;

  /// A new day: fresh quota and ad refreshes, then fill the board.
  void rollBountyDay(String today) {
    if (bountyDay == today) return;
    bountyDay = today;
    bountyLeft = bountiesPerDay;
    bountyAds = 0;
    _fillBounties(math.Random(seed ^ today.hashCode));
  }

  /// Tops the board up to [bountySlots]; [free] ones do not use the day's quota.
  void _fillBounties(math.Random rng, {bool free = false}) {
    if (!bountyOpen) return;
    while (bounties.length < bountySlots && (free || bountyLeft > 0)) {
      bounties.add(rollBounty(level, expToNext(level), rng));
      if (!free) bountyLeft--;
    }
  }

  /// Hands in finished bounty [i]: its gold and EXP, a Quý item at 4 stars,
  /// a Hiếm item and a gem at 5. Returns the reward lines, or null.
  List<String>? claimBounty(int i, math.Random rng) {
    if (i < 0 || i >= bounties.length || !bounties[i].done) return null;
    final b = bounties.removeAt(i);
    gold += b.gold;
    addActivity(ActSource.bounty);
    final lines = ['+${_thousands(b.exp)} kinh nghiệm', '+${_thousands(b.gold)} lượng'];
    if (b.stars >= 4) {
      final it = makeItem(
          slot: Slot.values[rng.nextInt(Slot.values.length)],
          level: level,
          rarity: b.stars >= 5 ? Rarity.epic : Rarity.rare,
          sect: sect,
          rng: rng);
      addItem(it);
      lines.add('${it.name} [${it.rarity.label}]');
    }
    if (b.stars >= 5) {
      final g = Gem(Hanh.values[rng.nextInt(5)], dropTier(level, boss: true));
      addGem(g);
      lines.add(g.name);
    }
    gainExp(b.exp.toDouble());
    _fillBounties(rng);
    return lines;
  }

  /// Rerolls every unfinished bounty; [ad] uses one of the day's free
  /// refreshes, otherwise it costs [bountyRefreshCost] gold.
  bool rerollBounties(math.Random rng, {bool ad = false}) {
    if (ad) {
      if (bountyAds >= bountyAdRefreshes) return false;
      bountyAds++;
    } else {
      final cost = bountyRefreshCost(level);
      if (gold < cost) return false;
      gold -= cost;
    }
    bounties.removeWhere((b) => !b.done);
    _fillBounties(rng, free: true);
    return true;
  }

  void _progressBounties(bool Function(Bounty b) matches, int by) {
    for (final b in bounties) {
      if (b.done || !matches(b)) continue;
      b.progress = math.min(b.count, b.progress + by);
      if (b.done) {
        notices.add(Notice('Truy nã xong: ${b.goal} · về thành nhận thưởng', color: 0xFF8CE07A, big: true));
      }
    }
  }

  /// Elites the world should put on map [mapId]: the Luân Hồi quest's and
  /// the bounties'.
  List<WantedElite> wantedElites(String mapId) {
    final out = <WantedElite>[];
    final q = currentMain;
    if (q != null && q.type == QuestType.elite && !mainLocked) {
      final e = eliteById[q.target]!;
      if (e.map == mapId) {
        out.add(WantedElite(e.id, e.name, e.mob, math.min(maxLevel, q.minLv + 3), e.hpMul, e.atkMul));
      }
    }
    final m = mapById[mapId];
    for (final b in bounties) {
      if (b.kind != BountyKind.elite || b.done || b.map != mapId || m == null) continue;
      out.add(WantedElite(b.eliteKey, b.eliteName, b.target,
          (level + 2).clamp(m.minLv, math.min(maxLevel, m.maxLv + 2)), b.eliteHp, b.eliteAtk));
    }
    final d = sectDuty;
    if (d != null && d.kind == DutyKind.traitor && !d.done && d.map == mapId && m != null) {
      out.add(WantedElite(d.eliteKey, d.traitorName, d.target,
          (level + 1).clamp(m.minLv, math.min(maxLevel, m.maxLv + 2)), 5, 1.15));
    }
    return out;
  }

  /// Monster ids worth hunting on this map: the story quest's and the
  /// kill and boss bounties'.
  Set<String> wantedMobs() => {
        if (currentMain case final q? when !mainLocked && (q.type == QuestType.kill || q.type == QuestType.boss))
          q.target,
        for (final b in bounties)
          if (!b.done && b.kind != BountyKind.elite) b.target,
        if (sectDuty case final d? when !d.done && (d.kind == DutyKind.kill || d.kind == DutyKind.boss)) d.target,
      };

  void onEliteKill(String key, math.Random rng) {
    final q = currentMain;
    if (q != null && !mainLocked && q.type == QuestType.elite && q.target == key) {
      _rewardMain(q, rng);
    }
    _progressBounties((b) => b.kind == BountyKind.elite && b.eliteKey == key, 1);
    _progressDuty((d) => d.kind == DutyKind.traitor && d.eliteKey == key);
  }

  // ------------------------------------------------------------- ngoại trang

  /// Whether [c]'s tower, rebirth or level goal is met. Boss Thế Giới and
  /// gold outfits are granted when claimed or bought instead.
  bool costumeGoalMet(CostumeDef c) => switch (c.source) {
        CostumeSource.tower => towerBest >= c.need,
        CostumeSource.rebirth => rebirths >= c.need,
        // A rebirth means level 99 was reached.
        CostumeSource.level => level >= c.need || rebirths > 0,
        CostumeSource.arena => arenaBestTier >= c.need,
        CostumeSource.sect => sectRank >= c.need,
        CostumeSource.worldBoss || CostumeSource.gold => false,
      };

  /// Grants every outfit whose goal is met; [quiet] skips the notices (when
  /// loading a save made before outfits existed).
  void unlockCostumes({bool quiet = false}) {
    for (final c in costumes) {
      if (costumeGoalMet(c)) _grantCostume(c, quiet: quiet);
    }
    unlockMounts(quiet: quiet);
  }

  void _grantCostume(CostumeDef c, {bool quiet = false}) {
    if (!ownedCostumes.add(c.id) || quiet) return;
    notices.add(Notice('Mở khóa ngoại trang: ${c.name}', color: 0xFFFFD34A, big: true));
  }

  /// Buys a gold outfit; false when not for sale, owned or too dear.
  bool buyCostume(String id) {
    final c = costumeById[id];
    if (c == null || c.source != CostumeSource.gold || ownedCostumes.contains(id) || gold < c.need) {
      return false;
    }
    gold -= c.need;
    ownedCostumes.add(id);
    return true;
  }

  /// Wears an owned outfit, or '' for the gear's own look.
  bool wearCostume(String id) {
    if (id.isNotEmpty && !ownedCostumes.contains(id)) return false;
    costume = id;
    return true;
  }

  // ------------------------------------------------------------- quests

  void _rewardMain(QuestDef q, math.Random rng) {
    final xp = expToNext(q.minLv) * q.expFactor;
    gold += q.gold;
    notices.add(Notice('Hoàn thành: ${q.title}', color: 0xFF8CE07A,
        big: true));
    notices.add(Notice('+${xp.round()} kinh nghiệm · +${q.gold} lượng'));
    if (q.item) {
      final slot = Slot.values[rng.nextInt(Slot.values.length)];
      final it = makeItem(
          slot: slot, level: level, rarity: Rarity.rare, sect: sect, rng: rng);
      addItem(it);
      notices.add(Notice('Nhận ${it.name}', color: Rarity.rare.color));
    }
    if (mainQuest < mainQuests.length) {
      mainQuest++;
    } else {
      rbQuest++;
      final ch = luanHoi[chapter];
      if (rbQuest >= ch.quests.length) {
        rbDone = math.max(rbDone, chapter + 1);
        notices.add(Notice('Hoàn thành ${chapterLabel(chapter)}: ${ch.title}!', color: 0xFFFFD34A, big: true));
      }
    }
    mainProgress = 0;
    gainExp(xp);
    _checkLevelQuests();
  }

  void _checkLevelQuests() {
    final q = currentMain;
    if (q != null && q.type == QuestType.level && level >= q.count) {
      _rewardMain(q, math.Random(seed + mainQuest));
    }
  }

  void _progressDaily(bool Function(DailyQuest d) matches) {
    for (final d in daily) {
      if (d.done || !matches(d)) continue;
      d.progress++;
      if (d.progress >= d.count) {
        d.done = true;
        gold += d.gold;
        notices.add(Notice('Hằng ngày xong: ${d.goal}', color: 0xFF8CE07A,
            big: true));
        addActivity(ActSource.daily);
        notices.add(Notice('+${d.exp} kinh nghiệm · +${d.gold} lượng'));
        gainExp(d.exp.toDouble());
      }
    }
  }

  void onKill(MobDef m, math.Random rng) {
    kills++;
    addActivity(ActSource.kills);
    if (m.boss) {
      bossKills++;
      bossKillsById[m.id] = (bossKillsById[m.id] ?? 0) + 1;
    }
    final q = currentMain;
    if (q != null && !mainLocked && q.target == m.id &&
        (q.type == QuestType.kill || q.type == QuestType.boss)) {
      mainProgress++;
      if (mainProgress >= q.count) _rewardMain(q, rng);
    }
    _progressDaily((d) =>
        (d.type == QuestType.kill && (d.target == '*' || d.target == m.id)) ||
        (d.type == QuestType.boss && d.target == m.id));
    _progressBounties((b) => b.kind != BountyKind.elite && b.target == m.id, 1);
    _progressDuty((d) => (d.kind == DutyKind.kill || d.kind == DutyKind.boss) && d.target == m.id);
  }

  /// Pays for a cleared dungeon; the first clear pays most and adds an
  /// item. Returns the lines to show on the result board.
  List<String> dungeonReward(DungeonDef d, int stars, math.Random rng) {
    final first = (dungeonStars[d.id] ?? 0) == 0;
    final xp = expToNext(level) * (first ? 0.15 : 0.05) * (0.8 + stars * 0.1);
    final g = ((150 + d.level * 30) * (first ? 1 : 0.4) * (0.7 + stars * 0.1))
        .round();
    final lines = <String>['+${xp.round()} kinh nghiệm', '+$g lượng'];
    lastDungeonGold = g;
    lastDungeonExp = xp;
    gold += g;
    if (first) {
      final it = makeItem(
        slot: Slot.values[rng.nextInt(Slot.values.length)],
        level: math.min(maxLevel, d.level + 1),
        rarity: stars >= 3 ? Rarity.epic : Rarity.rare,
        sect: sect,
        rng: rng,
      );
      addItem(it);
      lines.add('${it.name} [${it.rarity.label}]');
    }
    gainExp(xp);
    return lines;
  }

  /// Pays for a tower floor. Only the first clear of a floor pays (the climb
  /// always starts above the best floor); boss floors add a gem whose tier
  /// grows with height, up to Thánh.
  List<String> towerReward(int floor, math.Random rng) {
    if (floor <= towerBest) {
      lastDungeonGold = 0;
      lastDungeonExp = 0;
      return const ['Tầng đã vượt trước đây'];
    }
    towerBest = floor;
    unlockCostumes();
    final g = towerGold(floor);
    final xp = level >= maxLevel ? 0.0 : expToNext(level) * 0.03;
    lastDungeonGold = g;
    lastDungeonExp = xp;
    gold += g;
    final lines = <String>['+$g lượng', if (xp > 0) '+${xp.round()} kinh nghiệm'];
    if (towerBossFloor(floor)) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], towerGemTier(floor));
      addGem(gem);
      lines.add(gem.name);
    }
    final shards = towerGoldShards(floor);
    if (shards > 0) {
      goldShards += shards;
      lines.add('+$shards Mảnh Hoàng Kim');
    }
    if (xp > 0) gainExp(xp);
    _progressDaily((d) => d.type == QuestType.dungeon);
    _progressDuty((d) => d.kind == DutyKind.dungeon);
    addActivity(ActSource.dungeon);
    return lines;
  }

  /// Starts a new Boss Thế Giới day when the date changed.
  void wbRollDay(String day) {
    if (wbDay == day) return;
    wbDay = day;
    wbRuns = 0;
    wbAdRuns = 0;
    wbTotal = 0;
    wbBest = 0;
    wbClaimed = 0;
  }

  int get wbRunsLeft => worldBossFreeTries + wbAdRuns - wbRuns;

  /// Uses one run; false when none are left.
  bool wbStartRun(String day) {
    wbRollDay(day);
    if (wbRunsLeft <= 0) return false;
    wbRuns++;
    return true;
  }

  /// A rewarded ad adds a run (at most [worldBossAdTries] a day).
  bool wbAddAdRun(String day) {
    wbRollDay(day);
    if (wbAdRuns >= worldBossAdTries) return false;
    wbAdRuns++;
    return true;
  }

  /// Pays one Boss Thế Giới run and adds it to the day's total.
  List<String> worldBossReward(int damage, math.Random rng) {
    wbTotal += damage;
    wbBest = math.max(wbBest, damage);
    final g = worldBossGold(damage);
    gold += g;
    lastDungeonGold = g;
    lastDungeonExp = 0;
    _progressDaily((d) => d.type == QuestType.dungeon);
    addActivity(ActSource.worldBoss);
    return ['Sát thương: ${_thousands(damage)}', '+${_thousands(g)} lượng'];
  }

  bool wbCanClaim(int i) => wbTotal >= worldBossMilestones[i] && wbClaimed & (1 << i) == 0;

  /// Claims damage milestone [i]: gold and a gem of a random phase.
  Gem? wbClaim(int i, math.Random rng) {
    if (!wbCanClaim(i)) return null;
    wbClaimed |= 1 << i;
    gold += worldBossMilestoneGold(i);
    goldShards += worldBossGoldShards[i];
    final g = Gem(Hanh.values[rng.nextInt(5)], worldBossMilestoneGem[i]);
    addGem(g);
    for (final c in costumes) {
      if (c.source == CostumeSource.worldBoss && c.need == i) _grantCostume(c);
    }
    recompute();
    return g;
  }

  // ------------------------------------------------------------- refine

  /// Tẩy luyện [it], keeping the lines in [locked] (at most all but one).
  bool refine(Item it, Set<Stat> locked, math.Random rng) {
    if (it.bonus.isEmpty || locked.length >= it.bonus.length) return false;
    final cost = refineCost(it, locked.length);
    if (gold < cost) return false;
    gold -= cost;
    rerollAffixes(it, locked, rng);
    recompute();
    return true;
  }

  // ------------------------------------------------------------- treasure

  void shopRollDay(String day) {
    if (shopDay == day) return;
    shopDay = day;
    shopRefresh = 0;
    shopBought.clear();
  }

  List<TreasureOffer> treasureOffers(String day) {
    shopRollDay(day);
    return treasureStock(level: level, hanh: hanh, sect: sect, day: day, refresh: shopRefresh, seed: seed);
  }

  /// New stock; [free] for the rewarded-ad refresh.
  bool treasureRefresh(String day, {bool free = false}) {
    shopRollDay(day);
    final cost = treasureRefreshCost(shopRefresh);
    if (!free && gold < cost) return false;
    if (!free) gold -= cost;
    shopRefresh++;
    shopBought.clear();
    return true;
  }

  bool treasureBuy(String day, int i) {
    final offers = treasureOffers(day);
    if (i < 0 || i >= offers.length || shopBought.contains(i)) return false;
    final o = offers[i];
    if (gold < o.price) return false;
    if (o.item != null && bag.length >= bagSize) return false;
    gold -= o.price;
    shopBought.add(i);
    if (o.gem != null) addGem(o.gem!);
    if (o.item != null) bag.add(o.item!);
    recompute();
    return true;
  }

  // ------------------------------------------------------------- mounts

  bool ownsMount(String id) => mountLevels.containsKey(id);

  /// The mount under the hero, if any.
  MountDef? get ridingMount => riding ? mountById[activeMount] : null;

  bool mountGoalMet(MountDef m) => switch (m.source) {
        MountSource.tower => towerBest >= m.need,
        MountSource.rebirth => rebirths >= m.need,
        MountSource.gold || MountSource.arena => false,
      };

  void unlockMounts({bool quiet = false}) {
    for (final m in mounts) {
      if (mountGoalMet(m) && !ownsMount(m.id)) _grantMount(m, quiet: quiet);
    }
  }

  void _grantMount(MountDef m, {bool quiet = false}) {
    mountLevels[m.id] = 1;
    if (activeMount.isEmpty) activeMount = m.id;
    recompute();
    if (!quiet) notices.add(Notice('Nhận thú cưỡi: ${m.name}', color: 0xFFFFD34A, big: true));
  }

  bool get mountsOpen => level >= mountOpenLevel || rebirths > 0;

  bool buyMount(MountDef m) {
    if (m.source != MountSource.gold || ownsMount(m.id) || gold < m.need || !mountsOpen) return false;
    gold -= m.need;
    _grantMount(m, quiet: true);
    return true;
  }

  bool feedMount(MountDef m) {
    final lv = mountLevels[m.id];
    if (lv == null || lv >= maxMountLevel || gold < mountLevelCost(lv)) return false;
    gold -= mountLevelCost(lv);
    mountLevels[m.id] = lv + 1;
    recompute();
    return true;
  }

  /// Rides [id], or gets off it when it is already ridden.
  void rideMount(String id) {
    if (!ownsMount(id)) return;
    if (activeMount == id) {
      riding = !riding;
    } else {
      activeMount = id;
      riding = true;
    }
    recompute();
  }

  // ------------------------------------------------------------- alchemy

  bool get alchemyOpen => level >= alchemyOpenLevel || rebirths > 0;

  /// Herb tier of the region the hero's level belongs to.
  int get herbTier {
    var i = 0;
    for (var k = 0; k < maps.length; k++) {
      if (maps[k].minLv <= level) i = k;
    }
    return herbTierOfMap(i);
  }

  void addHerb(int tier, [int n = 1]) => herbs[tier.clamp(0, herbs.length - 1)] += n;

  bool canCraft(PillDef p) {
    if (gold < p.gold) return false;
    for (var i = 0; i < p.herbs.length; i++) {
      if (herbs[i] < p.herbs[i]) return false;
    }
    return true;
  }

  bool craft(PillDef p) {
    if (!alchemyOpen || !canCraft(p)) return false;
    gold -= p.gold;
    for (var i = 0; i < p.herbs.length; i++) {
      herbs[i] -= p.herbs[i];
    }
    pills[p.id] = (pills[p.id] ?? 0) + 1;
    addActivity(ActSource.alchemy);
    return true;
  }

  /// Seconds of [id]'s buff left.
  double buffLeft(String id) => buffs[id] ?? 0;

  bool canUsePill(PillDef p) {
    if ((pills[p.id] ?? 0) <= 0) return false;
    return switch (p.kind) {
      PillKind.buff => buffLeft(p.id) + p.minutes * 60 <= maxBuffMinutes * 60 + 1,
      PillKind.potions => true,
      PillKind.potential => potentialPills < maxPotentialPills,
    };
  }

  bool usePill(PillDef p) {
    if (!canUsePill(p)) return false;
    pills[p.id] = pills[p.id]! - 1;
    if (pills[p.id] == 0) pills.remove(p.id);
    switch (p.kind) {
      case PillKind.buff:
        buffs[p.id] = buffLeft(p.id) + p.minutes * 60;
      case PillKind.potions:
        hpPots += 10;
        mpPots += 10;
      case PillKind.potential:
        potentialPills++;
        freePoints += potentialPerPill;
    }
    recompute();
    return true;
  }

  double get expMul => buffLeft('songboi') > 0 ? expPillMul : 1;
  double get goldMul => buffLeft('tubao') > 0 ? goldPillMul : 1;

  /// Counts buff time down while playing; true when one ran out.
  bool tickBuffs(double dt) {
    if (buffs.isEmpty) return false;
    var ended = false;
    for (final id in buffs.keys.toList()) {
      final left = buffs[id]! - dt;
      if (left > 0) {
        buffs[id] = left;
      } else {
        buffs.remove(id);
        ended = true;
        final p = pillById[id];
        if (p != null) notices.add(Notice('${p.name} đã hết tác dụng', color: 0xFFB8A890));
      }
    }
    if (ended) recompute();
    return ended;
  }

  // ------------------------------------------------------------- arena

  bool get arenaOpen => level >= arenaOpenLevel || rebirths > 0;

  void arenaRollDay(String day) {
    arenaRollSeason(day);
    if (arenaDay == day) return;
    arenaDay = day;
    arenaFights = 0;
    arenaAds = 0;
  }

  /// Settles the season the points belong to once [day] is in a later one:
  /// a hero who fought in it is paid by the tier held at its end, and the
  /// points fall halfway back. True when a reward was paid.
  bool arenaRollSeason(String day) {
    final s = arenaSeasonOf(day);
    if (arenaSeason == s) return false;
    final old = arenaSeason;
    arenaSeason = s;
    final fought = arenaSeasonFights > 0;
    arenaSeasonFights = 0;
    if (old == 0 || !fought) {
      arenaPoints = math.max(arenaPoints, arenaStartPoints);
      return false;
    }
    final tier = arenaTier;
    final r = arenaSeasonReward(tier, level);
    arenaCoins += r.coins;
    gold += r.gold;
    goldShards += r.shards;
    if (r.gemTier > 0) addGem(Gem(Hanh.values[math.Random(seed ^ old).nextInt(5)], r.gemTier));
    arenaBestTier = math.max(arenaBestTier, tier);
    arenaSeasonResult = [old, tier, arenaPoints, r.coins, r.gold, r.shards, r.gemTier];
    arenaPoints = arenaSeasonReset(arenaPoints);
    unlockCostumes();
    return true;
  }

  /// The settled season's reward as lines, for the screen that shows it.
  List<String> arenaSeasonLines() {
    final r = arenaSeasonResult;
    if (r.length < 7) return const [];
    return [
      '+${_thousands(r[3])} Uy danh',
      '+${_thousands(r[4])} lượng',
      if (r[5] > 0) '+${r[5]} Mảnh Hoàng Kim',
      if (r[6] > 0) 'Ngọc cấp ${r[6]} (hành ngẫu nhiên)',
    ];
  }

  int get arenaFightsLeft => arenaFreeFights + arenaAds - arenaFights;

  /// Uses one of today's duels; false when none are left.
  bool arenaStart(String day) {
    arenaRollDay(day);
    if (arenaFightsLeft <= 0) return false;
    arenaFights++;
    return true;
  }

  bool arenaAddAdFight(String day) {
    arenaRollDay(day);
    if (arenaAds >= arenaAdFights) return false;
    arenaAds++;
    return true;
  }

  int get arenaTier => arenaTierIndex(arenaPoints);

  /// Settles a duel against [rival]; returns the result lines.
  List<String> arenaResult(bool won, ArenaRival rival) {
    final ratio = rival.power / math.max(1, power);
    final pts = won ? arenaWinPoints(ratio) : -arenaLossPoints(ratio);
    final before = arenaTier;
    arenaPoints = math.max(0, arenaPoints + pts);
    final coins = won ? arenaWinCoins : arenaLossCoins;
    arenaCoins += coins;
    arenaSeasonFights++;
    if (won) arenaWins++;
    addActivity(ActSource.arena);
    final lines = ['${pts >= 0 ? '+' : ''}$pts điểm Lôi đài ($arenaPoints)', '+$coins Uy danh'];
    if (arenaTier > before) lines.add('Thăng hạng: ${arenaTiers[arenaTier].name}!');
    return lines;
  }

  bool arenaSalaryReady(String day) => arenaSalaryDay != day;

  /// Today's salary for the current tier: Uy danh and gold.
  bool arenaClaimSalary(String day) {
    if (!arenaSalaryReady(day)) return false;
    arenaSalaryDay = day;
    arenaCoins += arenaDailyCoins(arenaTier);
    gold += arenaDailyGold(arenaTier, level);
    return true;
  }

  bool arenaBuy(ArenaOffer o, math.Random rng) {
    if (arenaCoins < o.price) return false;
    if (o.kind == ArenaWare.mount && ownsMount(o.id)) return false;
    arenaCoins -= o.price;
    switch (o.kind) {
      case ArenaWare.mount:
        _grantMount(mountById[o.id]!, quiet: true);
      case ArenaWare.gem:
        addGem(Gem(Hanh.values[rng.nextInt(5)], o.tier));
      case ArenaWare.herbs:
        addHerb(o.tier, o.count);
      case ArenaWare.pill:
        pills[o.id] = (pills[o.id] ?? 0) + o.count;
    }
    return true;
  }

  // ------------------------------------------------------------- hiệp khách

  bool get companionsOpen => level >= companions.first.unlock || rebirths > 0;

  bool hasCompanion(String id) => companionBonds.containsKey(id);

  bool canMeetCompanion(CompanionDef c) => level >= c.unlock || rebirths > 0;

  /// Has [c] join for their price; the first one comes along at once.
  bool hireCompanion(CompanionDef c) {
    if (hasCompanion(c.id) || !canMeetCompanion(c) || gold < c.price) return false;
    gold -= c.price;
    companionBonds[c.id] = 1;
    if (activeCompanion.isEmpty) activeCompanion = c.id;
    recompute();
    return true;
  }

  /// A gift that raises [c]'s hảo cảm by one.
  bool giftCompanion(CompanionDef c) {
    final b = companionBonds[c.id];
    if (b == null || b >= maxBond || gold < bondCost(b)) return false;
    gold -= bondCost(b);
    companionBonds[c.id] = b + 1;
    recompute();
    return true;
  }

  /// Takes [id] along, or sends them off when already along.
  void setActiveCompanion(String id) {
    if (!hasCompanion(id)) return;
    activeCompanion = activeCompanion == id ? '' : id;
    recompute();
  }

  // ------------------------------------------------------------- hoàng kim

  bool get goldOpen => level >= goldOpenLevel || rebirths > 0;

  /// Forges a Hoàng Kim [slot] piece of [set] at the hero's level into the
  /// bag; null when short of shards or bag space.
  Item? forgeGold(GoldSetDef set, Slot slot, math.Random rng) {
    final cost = goldPieceCost(slot);
    if (!goldOpen || goldShards < cost || bag.length >= bagSize) return null;
    goldShards -= cost;
    final it = makeGoldItem(set: set, slot: slot, level: level, sect: sect, rng: rng);
    bag.add(it);
    ownedLegend = true;
    return it;
  }

  bool canReforgeGold(Item it) => it.golden && it.level < level && goldShards >= goldReforgeCost(it.slot);

  /// Forges [it] again at the hero's level, worn or in the bag.
  Item? reforgeGold(Item it) {
    if (!canReforgeGold(it)) return null;
    final out = reforgedGold(it, level);
    if (equip[it.slot] == it) {
      equip[it.slot] = out;
    } else {
      final i = bag.indexOf(it);
      if (i < 0) return null;
      bag[i] = out;
    }
    goldShards -= goldReforgeCost(it.slot);
    recompute();
    return out;
  }

  // ------------------------------------------------------------- năng động

  void actRollDay(String day) {
    if (actDay != day) {
      actDay = day;
      actCounts.clear();
      actClaimed = 0;
    }
    final week = weekKeyOf(day);
    if (actWeek != week) {
      actWeek = week;
      actWeekPoints = 0;
      actWeekClaimed = 0;
    }
  }

  int actPointsOf(ActSource s) {
    final d = actSources[s]!;
    return math.min(d.cap, (actCounts[s] ?? 0) ~/ d.per * d.points);
  }

  int get actPoints => ActSource.values.fold(0, (a, s) => a + actPointsOf(s));

  /// Records [n] actions of [s] toward today's and the week's points.
  void addActivity(ActSource s, [int n = 1]) {
    actRollDay(vnDayKey());
    final before = actPoints;
    actCounts[s] = (actCounts[s] ?? 0) + n;
    actWeekPoints += actPoints - before;
  }

  bool actCanClaim(int i, {bool weekly = false}) => weekly
      ? actWeekPoints >= actWeeklyMarks[i] && actWeekClaimed & (1 << i) == 0
      : actPoints >= actDailyMarks[i] && actClaimed & (1 << i) == 0;

  /// Opens chest [i]; returns its contents as lines, or null.
  List<String>? actClaim(int i, math.Random rng, {bool weekly = false}) {
    actRollDay(vnDayKey());
    if (!actCanClaim(i, weekly: weekly)) return null;
    if (weekly) {
      actWeekClaimed |= 1 << i;
    } else {
      actClaimed |= 1 << i;
    }
    final c = actChest(i, level, weekly: weekly);
    final lines = <String>[];
    if (c.gold > 0) {
      gold += c.gold;
      lines.add('+${_thousands(c.gold)} lượng');
    }
    if (c.potions > 0) {
      hpPots += c.potions;
      mpPots += c.potions;
      lines.add('+${c.potions} Kim Sang Dược, +${c.potions} Ngưng Thần Đan');
    }
    if (c.herbs > 0) {
      final t = herbTier;
      addHerb(t, c.herbs);
      lines.add('+${c.herbs} ${herbNames[t]}');
    }
    if (c.gemTier > 0) {
      final g = Gem(Hanh.values[rng.nextInt(5)], c.gemTier);
      addGem(g);
      lines.add(g.name);
    }
    if (c.coins > 0) {
      arenaCoins += c.coins;
      lines.add('+${c.coins} Uy danh');
    }
    if (c.pill.isNotEmpty) {
      pills[c.pill] = (pills[c.pill] ?? 0) + 1;
      lines.add(pillById[c.pill]!.name);
    }
    if (c.shards > 0) {
      goldShards += c.shards;
      lines.add('+${c.shards} Mảnh Hoàng Kim');
    }
    return lines;
  }

  /// Lực chiến: one number for leaderboards, from effective attack,
  /// toughness and trained skills.
  int get power {
    final s = stats;
    final atkEff = s.atk * (1 + s.crit * (s.critDmg - 1)) * s.aspd * (1 + s.skillDmg * 0.6);
    final tough = s.maxHp * (1 + s.dodge) * 0.4 + s.def * 3;
    final skills = skillLv.fold<int>(0, (a, b) => a + b);
    return (atkEff * 4 + tough + skills * 20).round();
  }

  void onDungeonClear(String id, int stars, math.Random rng) {
    dungeonStars[id] = math.max(dungeonStars[id] ?? 0, stars);
    final q = currentMain;
    if (q != null && !mainLocked && q.type == QuestType.dungeon &&
        q.target == id) {
      _rewardMain(q, rng);
    }
    _progressDaily((d) => d.type == QuestType.dungeon);
    _progressDuty((d) => d.kind == DutyKind.dungeon);
    addActivity(ActSource.dungeon);
  }

  /// Rolls today's three daily quests if the date changed.
  void refreshDaily(String today) {
    // Also settles a level quest already met, e.g. after an update re-ordered
    // the story.
    _checkLevelQuests();
    rollBountyDay(today);
    if (dailyDate == today && daily.isNotEmpty) return;
    dailyDate = today;
    final rng = math.Random(today.hashCode ^ hanh.index ^ name.hashCode);
    var map = maps.first;
    for (final m in maps) {
      if (m.minLv <= level) map = m;
    }
    final xp = (expToNext(level) * 0.22).round();
    final gp = 60 + level * 25;
    daily = [
      DailyQuest(
          type: QuestType.kill,
          target: map.mobs[rng.nextInt(map.mobs.length)],
          count: 30,
          exp: xp,
          gold: gp),
      DailyQuest(
          type: QuestType.dungeon, target: '', count: 2, exp: xp, gold: gp),
      level >= map.minLv + 2
          ? DailyQuest(
              type: QuestType.boss,
              target: map.boss,
              count: 1,
              exp: xp,
              gold: gp)
          : DailyQuest(
              type: QuestType.kill, target: '*', count: 60, exp: xp, gold: gp),
    ];
  }

  // ------------------------------------------------------------- sư môn

  bool get sectOpen => level >= sectOpenLevel || rebirths > 0;

  SectDuty _rollSectDuty(math.Random rng) =>
      rollDuty(level, sectDone, rng, herbs: alchemyOpen, fish: fishOpen);

  /// A new day resets the count of duties handed in; the chain goes on.
  void sectRollDay(String day, math.Random rng) {
    if (!sectOpen) return;
    if (sectDay != day) {
      sectDay = day;
      sectDone = 0;
    }
    if (sectDuty == null && sectDone < sectDutiesPerDay) sectDuty = _rollSectDuty(rng);
  }

  void _progressDuty(bool Function(SectDuty d) matches, [int by = 1]) {
    final d = sectDuty;
    if (d == null || d.done || !matches(d)) return;
    d.progress = math.min(d.count, d.progress + by);
    if (d.done) notices.add(Notice('Sư môn xong: ${d.goal} · về thành phục mệnh', color: 0xFF8CE07A, big: true));
  }

  void onHerbPicked() => _progressDuty((d) => d.kind == DutyKind.herb);

  /// Hands in the finished duty: cống hiến, EXP and gold, then the next one
  /// while the day's chain lasts.
  List<String>? sectClaim(math.Random rng) {
    final d = sectDuty;
    if (d == null || !d.done) return null;
    final c = dutyContribution(sectDone);
    sectContrib += c;
    sectCoins += c;
    final xp = level >= maxLevel ? 0.0 : expToNext(level) * dutyExpShare * (c > 25 ? 2 : 1);
    final g = dutyGold(level) * (c > 25 ? 2 : 1);
    gold += g;
    if (xp > 0) gainExp(xp);
    sectDone++;
    sectDuty = sectDone < sectDutiesPerDay ? _rollSectDuty(rng) : null;
    addActivity(ActSource.daily);
    return ['+$c cống hiến', '+${_thousands(g)} lượng', if (xp > 0) '+${xp.round()} kinh nghiệm'];
  }

  /// Swaps an unfinished duty for another, for gold.
  bool sectReroll(math.Random rng) {
    final d = sectDuty;
    final cost = dutyRerollCost(level);
    if (d == null || d.done || gold < cost) return false;
    gold -= cost;
    SectDuty next;
    var tries = 0;
    do {
      next = _rollSectDuty(rng);
    } while (++tries < 8 && next.kind == d.kind && next.target == d.target);
    sectDuty = next;
    return true;
  }

  SectRank? get nextSectRank => sectRank < maxSectRank ? sectRanks[sectRank + 1] : null;

  /// Enough cống hiến and level for the next chức vị's khảo hạch.
  bool get sectCanTrial {
    final n = nextSectRank;
    return n != null && sectContrib >= n.need && (level >= n.level || rebirths > 0);
  }

  ArenaRival sectExaminerNow() => sectExaminerRival(hanh, sectRank + 1, level, rebirths, power);

  /// Pays a khảo hạch: a win raises the chức vị.
  List<String> sectTrialResult(bool won) {
    if (!won || !sectCanTrial) return won ? const [] : const ['Khảo hạch chưa đạt, hãy luyện thêm.'];
    sectRank++;
    final g = 2000 * sectRank * sectRank;
    gold += g;
    notices.add(Notice('Thăng chức: ${sectRanks[sectRank].name}!', color: 0xFFFFD34A, big: true));
    unlockCostumes();
    recompute();
    return ['Chức vị mới: ${sectRanks[sectRank].name}', '+${_thousands(g)} lượng'];
  }

  /// Buys from Tàng Kinh Các; [page] names the page for a page offer.
  bool sectBuy(SectOffer o, math.Random rng, {String? page}) {
    if (sectCoins < o.price || sectRank < o.rank) return false;
    if (o.kind == SectWare.page && page == null) return false;
    sectCoins -= o.price;
    switch (o.kind) {
      case SectWare.potions:
        hpPots += 10;
        mpPots += 10;
      case SectWare.gem:
        addGem(Gem(Hanh.values[rng.nextInt(5)], sectGemTier(sectRank)));
      case SectWare.page:
        addManualPage(page!);
      case SectWare.shards:
        goldShards += 3;
    }
    return true;
  }

  // ------------------------------------------------------------- bí kíp

  bool get manualOpen => level >= manualOpenLevel || rebirths > 0;

  int manualPagesOf(String key) => manualPages[key] ?? 0;

  int manualLevel(String key) => manualLevelOf(manualPagesOf(key));

  void addManualPage(String key, [int n = 1]) => manualPages[key] = manualPagesOf(key) + n;

  /// A random page for one of the hero's skills; returns its name.
  String gainManualPage(math.Random rng) {
    final key = rollManualPage(sect, rng);
    addManualPage(key);
    return manualPageName(sect, key);
  }

  ManualKind? manualOf(String skillId) {
    final k = manualOn[skillId];
    return k == null ? null : ManualKind.values[k];
  }

  /// Wears school [k] on [skillId] (null takes it off); only learned ones.
  bool setManual(String skillId, ManualKind? k) {
    if (k == null) {
      manualOn.remove(skillId);
      return true;
    }
    if (manualLevel(manualKey(skillId, k)) <= 0) return false;
    manualOn[skillId] = k.index;
    return true;
  }

  /// Skill [i] as the hero casts it, with its bí kíp.
  SkillDef castSkill(int i) {
    final s = sect.skills[i];
    final k = manualOf(s.id);
    if (k == null) return s;
    return applyManual(s, k, manualLevel(manualKey(s.id, k)), hanh);
  }

  // ------------------------------------------------------------- câu cá

  bool get fishOpen => level >= fishOpenLevel || rebirths > 0;

  void fishRollDay(String day) {
    if (fishDay == day) return;
    fishDay = day;
    fishUsed = 0;
    fishAds = 0;
  }

  int get fishBaitLeft => fishBaitPerDay + fishAds * fishAdBait - fishUsed;

  /// Uses a bait for a cast; false when none are left.
  bool fishCast(String day) {
    fishRollDay(day);
    if (fishBaitLeft <= 0) return false;
    fishUsed++;
    return true;
  }

  /// A rewarded ad adds [fishAdBait] baits, once a day.
  bool fishAddAd(String day) {
    fishRollDay(day);
    if (fishAds >= 1) return false;
    fishAds++;
    return true;
  }

  /// Sells catch [f] and logs it; rare ones may hold a gem, legendary ones
  /// a bí kíp page and Hoàng Kim shards.
  List<String> catchFish(FishDef f, math.Random rng) {
    final first = (fishCaught[f.id] ?? 0) == 0;
    fishCaught[f.id] = (fishCaught[f.id] ?? 0) + 1;
    final g = f.price * (first ? 1 + fishFirstBonus : 1);
    gold += g;
    final lines = ['+${_thousands(g)} lượng${first ? ' (lần đầu)' : ''}'];
    if (f.rarity == FishRarity.rare && rng.nextDouble() < 0.3) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], math.min(maxDropTier, 1 + f.mapIndex ~/ 2));
      addGem(gem);
      lines.add('Trong bụng cá có ${gem.name}');
    }
    if (f.rarity == FishRarity.legend) {
      goldShards += 2;
      lines.add('+2 Mảnh Hoàng Kim');
      if (manualOpen) lines.add(gainManualPage(rng));
    }
    _progressDuty((d) => d.kind == DutyKind.fish);
    return lines;
  }

  bool fishBookDone(String mapId) => fishOfMap(mapId).every((f) => (fishCaught[f.id] ?? 0) > 0);

  /// Pays a finished page of the Ngư phổ once.
  int fishBookClaim(String mapId) {
    if (fishBooks.contains(mapId) || !fishBookDone(mapId)) return 0;
    fishBooks.add(mapId);
    final g = fishBookGold(maps.indexWhere((m) => m.id == mapId));
    gold += g;
    return g;
  }

  // ------------------------------------------------------------- ác mộng

  bool get nightmareOpen => level >= nightmareOpenLevel || rebirths > 0;

  /// Nightmare [i] (0-based) opens once the one before is cleared.
  bool nightmareUnlocked(int i) => nightmareOpen && (i == 0 || (nmStars['nm$i'] ?? 0) > 0);

  void nmRollDay(String day) {
    if (nmDay == day) return;
    nmDay = day;
    nmRuns = 0;
  }

  int get nmRunsLeft => math.max(0, nightmarePaidRuns - nmRuns);

  /// Pays a nightmare clear: the first ever pays big; after that the day's
  /// first [nightmarePaidRuns] clears pay.
  List<String> nightmareReward(DungeonDef d, int stars, math.Random rng, {String? day}) {
    nmRollDay(day ?? vnDayKey());
    final i = d.nightmare - 1;
    final first = (nmStars[d.id] ?? 0) == 0;
    nmStars[d.id] = math.max(nmStars[d.id] ?? 0, stars);
    _progressDaily((q) => q.type == QuestType.dungeon);
    _progressDuty((q) => q.kind == DutyKind.dungeon);
    addActivity(ActSource.dungeon);
    if (!first && nmRuns >= nightmarePaidRuns) {
      lastDungeonGold = 0;
      lastDungeonExp = 0;
      return const ['Hết lượt thưởng Ác Mộng hôm nay'];
    }
    if (!first) nmRuns++;
    final g = nightmareGold(i, stars);
    final xp = level >= maxLevel ? 0.0 : expToNext(level) * nightmareExpShare(i);
    gold += g;
    lastDungeonGold = g;
    lastDungeonExp = xp;
    final shards = nightmareShards(i, stars) + (first ? nightmareFirstShards(i) : 0);
    goldShards += shards;
    final lines = ['+${_thousands(g)} lượng', if (xp > 0) '+${xp.round()} kinh nghiệm', '+$shards Mảnh Hoàng Kim'];
    if (first || rng.nextDouble() < nightmareGemChance(i)) {
      final gem = Gem(Hanh.values[rng.nextInt(5)], nightmareGemTier(i));
      addGem(gem);
      lines.add(gem.name);
    }
    if (manualOpen && (first || rng.nextDouble() < nightmarePageChance(i))) lines.add(gainManualPage(rng));
    if (manualOpen && rng.nextDouble() < nightmareExtraPageChance(i)) lines.add(gainManualPage(rng));
    if (xp > 0) gainExp(xp);
    return lines;
  }

  // ------------------------------------------------------------- save

  Map<String, dynamic> toJson() => {
        'v': 1,
        'name': name,
        'hanh': hanh.index,
        'female': female,
        'level': level,
        'exp': exp,
        'gold': gold,
        'spent': spent,
        'free': freePoints,
        'sp': skillPoints,
        'skills': skillLv,
        'equip': {for (final e in equip.entries) '${e.key.index}': e.value.toJson()},
        'bag': [for (final it in bag) it.toJson()],
        'hpPots': hpPots,
        'mpPots': mpPots,
        'main': mainQuest,
        'mainP': mainProgress,
        'dailyDate': dailyDate,
        'daily': [for (final d in daily) d.toJson()],
        'stars': dungeonStars,
        'kills': kills,
        'time': playSeconds,
        'autoSell': autoSellCommon,
        'seed': seed,
        'savedAt': savedAt,
        'loginDate': lastLoginDate,
        'loginDay': loginDay,
        'bossKills': bossKills,
        'bestPlus': bestPlus,
        'legend': ownedLegend,
        'ach': achClaimed.toList(),
        'title': title,
        'gemBag': gemBag,
        'pets': petLevels,
        'pet': activePet,
        'bossKillsById': bossKillsById,
        'rebirths': rebirths,
        'meridians': meridianPts,
        'tower': towerBest,
        'wb': [wbDay, wbRuns, wbAdRuns, wbTotal, wbBest, wbClaimed],
        'shop': [shopDay, shopRefresh, shopBought.toList()],
        'look': [costume, hideHat, ownedCostumes.toList()],
        'lh': [rbQuest, rbDone],
        'bounty': [bountyDay, bountyLeft, bountyAds, [for (final b in bounties) b.toJson()]],
        'mount': [activeMount, riding, mountLevels],
        'alch': [herbs, pills, buffs, potentialPills],
        'arena': [arenaPoints, arenaCoins, arenaDay, arenaFights, arenaAds, arenaSalaryDay, arenaWins, arenaRefresh],
        'season': [arenaSeason, arenaSeasonFights, arenaBestTier, arenaSeasonResult],
        'shards': goldShards,
        'comp': [activeCompanion, companionBonds],
        'sect': [sectRank, sectContrib, sectCoins, sectDay, sectDone, sectDuty?.toJson()],
        'manual': [manualPages, manualOn],
        'fish': [fishDay, fishUsed, fishAds, fishCaught, fishBooks.toList()],
        'nm': [nmStars, nmDay, nmRuns],
        'act': [
          actDay,
          {for (final e in actCounts.entries) '${e.key.index}': e.value},
          actClaimed,
          actWeek,
          actWeekPoints,
          actWeekClaimed,
        ],
      };

  static HeroData fromJson(Map<String, dynamic> m) {
    final h = HeroData(
      name: m['name'] as String,
      hanh: Hanh.values[m['hanh'] as int],
      female: m['female'] as bool? ?? false,
    );
    h.level = (m['level'] as int).clamp(1, maxLevel);
    h.exp = m['exp'] as int;
    h.gold = m['gold'] as int;
    final sp = m['spent'] as List;
    for (var i = 0; i < 4; i++) {
      h.spent[i] = sp[i] as int;
    }
    h.freePoints = m['free'] as int;
    h.skillPoints = m['sp'] as int;
    final sk = m['skills'] as List;
    for (var i = 0; i < sk.length && i < h.skillLv.length; i++) {
      h.skillLv[i] = sk[i] as int;
    }
    final mer = m['meridians'] as List? ?? const [];
    for (var i = 0; i < mer.length && i < h.meridianPts.length; i++) {
      h.meridianPts[i] = math.max(0, mer[i] as int);
    }
    (m['equip'] as Map).forEach((k, v) {
      final it = Item.fromJson((v as Map).cast<String, dynamic>());
      h.equip[it.slot] = it;
    });
    for (final v in m['bag'] as List) {
      h.bag.add(Item.fromJson((v as Map).cast<String, dynamic>()));
    }
    h.hpPots = m['hpPots'] as int;
    h.mpPots = m['mpPots'] as int;
    h.mainQuest = m['main'] as int;
    h.mainProgress = m['mainP'] as int;
    h.dailyDate = m['dailyDate'] as String;
    h.daily = [
      for (final v in m['daily'] as List)
        DailyQuest.fromJson((v as Map).cast<String, dynamic>()),
    ];
    (m['stars'] as Map).forEach((k, v) => h.dungeonStars['$k'] = v as int);
    h.kills = m['kills'] as int;
    h.playSeconds = (m['time'] as num).toDouble();
    h.autoSellCommon = m['autoSell'] as bool? ?? false;
    h.seed = m['seed'] as int? ?? 0;
    h.savedAt = m['savedAt'] as int? ?? 0;
    h.lastLoginDate = m['loginDate'] as String? ?? '';
    h.loginDay = (m['loginDay'] as int? ?? 0) % 7;
    h.bossKills = m['bossKills'] as int? ?? 0;
    h.bestPlus = m['bestPlus'] as int? ??
        [...h.bag, ...h.equip.values].fold<int>(0, (b, i) => math.max(b, i.plus));
    h.ownedLegend = m['legend'] as bool? ?? false;
    h.achClaimed.addAll([for (final a in m['ach'] as List? ?? const []) '$a']);
    h.title = m['title'] as String? ?? '';
    (m['gemBag'] as Map? ?? const {}).forEach((k, v) {
      if (Gem.parse(k) != null && v is int && v > 0) h.gemBag['$k'] = v;
    });
    (m['pets'] as Map? ?? const {}).forEach((k, v) {
      if (petById.containsKey(k) && v is int) h.petLevels['$k'] = v.clamp(1, maxPetLevel);
    });
    final pet = m['pet'] as String? ?? '';
    h.activePet = h.petLevels.containsKey(pet) ? pet : '';
    (m['bossKillsById'] as Map? ?? const {}).forEach((k, v) {
      if (v is int) h.bossKillsById['$k'] = v;
    });
    h.rebirths = ((m['rebirths'] as int?) ?? 0).clamp(0, maxRebirths);
    h.towerBest = math.max(0, (m['tower'] as int?) ?? 0);
    final wb = m['wb'];
    if (wb is List && wb.length == 6) {
      h.wbDay = wb[0] as String;
      h.wbRuns = wb[1] as int;
      h.wbAdRuns = wb[2] as int;
      h.wbTotal = wb[3] as int;
      h.wbBest = wb[4] as int;
      h.wbClaimed = wb[5] as int;
    }
    final shop = m['shop'];
    if (shop is List && shop.length == 3) {
      h.shopDay = shop[0] as String;
      h.shopRefresh = shop[1] as int;
      h.shopBought.addAll([for (final v in shop[2] as List) v as int]);
    }
    final look = m['look'];
    if (look is List && look.length == 3) {
      h.ownedCostumes.addAll([
        for (final v in look[2] as List)
          if (costumeById.containsKey(v)) v as String,
      ]);
      h.hideHat = look[1] as bool;
      h.costume = h.ownedCostumes.contains(look[0]) ? look[0] as String : '';
    }
    final season = m['season'];
    if (season is List && season.length == 4) {
      h.arenaSeason = math.max(0, season[0] as int);
      h.arenaSeasonFights = math.max(0, season[1] as int);
      h.arenaBestTier = (season[2] as int).clamp(-1, arenaTiers.length - 1);
      h.arenaSeasonResult = [for (final v in season[3] as List) v as int];
    }
    h.goldShards = math.max(0, m['shards'] as int? ?? 0);
    final comp = m['comp'];
    if (comp is List && comp.length == 2) {
      (comp[1] as Map).forEach((k, v) {
        if (companionById.containsKey(k) && v is int) h.companionBonds['$k'] = v.clamp(1, maxBond);
      });
      h.activeCompanion = h.companionBonds.containsKey(comp[0]) ? comp[0] as String : '';
    }
    final sect = m['sect'];
    if (sect is List && sect.length == 6) {
      h.sectRank = (sect[0] as int).clamp(0, maxSectRank);
      h.sectContrib = math.max(0, sect[1] as int);
      h.sectCoins = math.max(0, sect[2] as int);
      h.sectDay = sect[3] as String;
      h.sectDone = math.max(0, sect[4] as int);
      final d = sect[5];
      h.sectDuty = d is Map ? SectDuty.fromJson(d.cast<String, dynamic>()) : null;
    }
    final manual = m['manual'];
    if (manual is List && manual.length == 2) {
      (manual[0] as Map).forEach((k, v) {
        if (v is int && v > 0) h.manualPages['$k'] = v;
      });
      (manual[1] as Map).forEach((k, v) {
        if (v is int && v >= 0 && v < ManualKind.values.length) h.manualOn['$k'] = v;
      });
    }
    final fish = m['fish'];
    if (fish is List && fish.length == 5) {
      h.fishDay = fish[0] as String;
      h.fishUsed = math.max(0, fish[1] as int);
      h.fishAds = math.max(0, fish[2] as int);
      (fish[3] as Map).forEach((k, v) {
        if (fishById.containsKey(k) && v is int && v > 0) h.fishCaught['$k'] = v;
      });
      h.fishBooks.addAll([for (final v in fish[4] as List) '$v']);
    }
    final nm = m['nm'];
    if (nm is List && nm.length == 3) {
      (nm[0] as Map).forEach((k, v) {
        if (v is int) h.nmStars['$k'] = v.clamp(0, 3);
      });
      h.nmDay = nm[1] as String;
      h.nmRuns = math.max(0, nm[2] as int);
    }
    h.unlockCostumes(quiet: true);
    final lh = m['lh'];
    if (lh is List && lh.length == 2) {
      h.rbQuest = math.max(0, lh[0] as int);
      h.rbDone = (lh[1] as int).clamp(0, luanHoi.length);
    } else if (h.inLuanHoi) {
      // Reborn before Luân Hồi existed: start at the first quest near the
      // hero's level rather than back at level 10.
      final qs = luanHoi[h.chapter].quests;
      final i = qs.indexWhere((q) => q.minLv >= h.level - 3);
      h.rbQuest = i < 0 ? qs.length - 1 : i;
      h.mainProgress = 0;
    }
    final bounty = m['bounty'];
    if (bounty is List && bounty.length == 4) {
      h.bountyDay = bounty[0] as String;
      h.bountyLeft = bounty[1] as int;
      h.bountyAds = bounty[2] as int;
      for (final v in bounty[3] as List) {
        final b = Bounty.fromJson((v as Map).cast<String, dynamic>());
        if (b != null && h.bounties.length < bountySlots) h.bounties.add(b);
      }
    }
    final mount = m['mount'];
    if (mount is List && mount.length == 3) {
      (mount[2] as Map).forEach((k, v) {
        if (mountById.containsKey(k) && v is int) h.mountLevels['$k'] = v.clamp(1, maxMountLevel);
      });
      h.riding = mount[1] as bool;
      h.activeMount = h.mountLevels.containsKey(mount[0]) ? mount[0] as String : '';
    }
    h.unlockMounts(quiet: true);
    final alch = m['alch'];
    if (alch is List && alch.length == 4) {
      final hb = alch[0] as List;
      for (var i = 0; i < hb.length && i < h.herbs.length; i++) {
        h.herbs[i] = math.max(0, hb[i] as int);
      }
      (alch[1] as Map).forEach((k, v) {
        if (pillById.containsKey(k) && v is int && v > 0) h.pills['$k'] = v;
      });
      (alch[2] as Map).forEach((k, v) {
        if (pillById.containsKey(k) && v is num && v > 0) {
          h.buffs['$k'] = math.min(v.toDouble(), maxBuffMinutes * 60.0);
        }
      });
      h.potentialPills = (alch[3] as int).clamp(0, maxPotentialPills);
    }
    final ar = m['arena'];
    if (ar is List && ar.length == 8) {
      h.arenaPoints = math.max(0, ar[0] as int);
      h.arenaCoins = math.max(0, ar[1] as int);
      h.arenaDay = ar[2] as String;
      h.arenaFights = ar[3] as int;
      h.arenaAds = ar[4] as int;
      h.arenaSalaryDay = ar[5] as String;
      h.arenaWins = ar[6] as int;
      h.arenaRefresh = ar[7] as int;
    }
    final act = m['act'];
    if (act is List && act.length == 6) {
      h.actDay = act[0] as String;
      (act[1] as Map).forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && i >= 0 && i < ActSource.values.length && v is int) h.actCounts[ActSource.values[i]] = v;
      });
      h.actClaimed = act[2] as int;
      h.actWeek = act[3] as String;
      h.actWeekPoints = act[4] as int;
      h.actWeekClaimed = act[5] as int;
    }
    h.recompute();
    return h;
  }
}

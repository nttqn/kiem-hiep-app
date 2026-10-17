import 'dart:math' as math;

import 'content.dart';
import 'gems.dart';
import 'hanh.dart';
import 'items.dart';
import 'pets.dart';
import 'sects.dart';

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
        QuestType.level => '',
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
  final List<int> skillLv = List.filled(6, 0);
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

  int lastDungeonGold = 0;
  double lastDungeonExp = 0;

  final Stats stats = Stats();

  SectDef get sect => sectOf(hanh);

  QuestDef? get currentMain =>
      mainQuest < mainQuests.length ? mainQuests[mainQuest] : null;

  bool get mainLocked => (currentMain?.minLv ?? 0) > level;

  /// Pending messages for the UI (level up, quest done…).
  final List<Notice> notices = [];

  // ------------------------------------------------------------- stats

  Map<Bonus, double> passiveBonuses() {
    final out = <Bonus, double>{};
    for (var i = 0; i < 6; i++) {
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
    final pet = petById[activePet];
    if (pet != null) add({pet.bonus: pet.bonusAt(petLevels[pet.id] ?? 1)});
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

  bool canLearn(int i) =>
      skillPoints > 0 &&
      skillLv[i] < maxSkillLevel &&
      level >= sect.skills[i].unlock;

  bool learn(int i) {
    if (!canLearn(i)) return false;
    skillLv[i]++;
    skillPoints--;
    recompute();
    return true;
  }

  /// Spends skill points: unlock new skills first, then the first active,
  /// then whatever is lowest.
  void autoLearn() {
    while (skillPoints > 0) {
      int? pick;
      for (var i = 0; i < 6; i++) {
        if (canLearn(i) && skillLv[i] == 0) {
          pick = i;
          break;
        }
      }
      if (pick == null) {
        var best = 99;
        for (var i = 0; i < 6; i++) {
          if (!canLearn(i)) continue;
          // Bias toward the bread-and-butter first skill.
          final v = skillLv[i] * 2 - (i == 0 ? 3 : 0);
          if (v < best) {
            best = v;
            pick = i;
          }
        }
      }
      if (pick == null) break;
      learn(pick);
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
    mainQuest++;
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
        notices.add(Notice('+${d.exp} kinh nghiệm · +${d.gold} lượng'));
        gainExp(d.exp.toDouble());
      }
    }
  }

  void onKill(MobDef m, math.Random rng) {
    kills++;
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

  void onDungeonClear(String id, int stars, math.Random rng) {
    dungeonStars[id] = math.max(dungeonStars[id] ?? 0, stars);
    final q = currentMain;
    if (q != null && !mainLocked && q.type == QuestType.dungeon &&
        q.target == id) {
      _rewardMain(q, rng);
    }
    _progressDaily((d) => d.type == QuestType.dungeon);
  }

  /// Rolls today's three daily quests if the date changed.
  void refreshDaily(String today) {
    // Also settles a level quest already met, e.g. after an update re-ordered
    // the story.
    _checkLevelQuests();
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
    for (var i = 0; i < 6; i++) {
      h.skillLv[i] = sk[i] as int;
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
    h.recompute();
    return h;
  }
}

import 'dart:math' as math;

import 'content.dart';
import 'hero.dart';
import 'ky_ngo.dart';
import 'items.dart';
import 'lore.dart' show loreBonusLabel;
import 'sects.dart';
import 'tam_ma.dart' show fmtThousands;
import 'i18n.dart';

/// Đồ giám Truyền thuyết (1.19.0): a book of what the hero has met.
///
/// * Thần binh phổ: one cell for each item tier (ten, by level / 10) and
///   slot, filled by the first Truyền thuyết or Hoàng Kim piece of it the
///   hero ever picks up (kept even after it is sold or broken down).
/// * Vạn thú phổ: one page for each land open to all, its monsters to be
///   beaten [codexMobGoal] times each and its boss [codexBossGoal] times.
///
/// A whole page is taken once ("Nhận") for a little gold or Tinh Hoa and a
/// small lasting bonus; every page of a book adds a title and a bigger one.
const int codexMobGoal = 300;
const int codexBossGoal = 10;
const int codexTiers = 10;

int codexTierOf(int level) => (level ~/ 10).clamp(0, codexTiers - 1);

/// The tier's material name and level range, as items are named.
String codexTierName(int t) => tierName(t * 10);
String codexTierRange(int t) => t == codexTiers - 1 ? tr('Cấp 90+') : tr('Cấp {p0}–{p1}', {'p0': t * 10, 'p1': t * 10 + 9});

String codexGearKey(int tier, Slot slot) => 'g$tier.${slot.index}';
String codexGearPage(int tier) => 'g$tier';
String codexLandPage(String mapId) => 'm:$mapId';

/// Lands with a Vạn thú phổ page: the story's and the side lands, by level.
final List<MapDef> codexLands = [for (final m in fieldMaps) if (m.rebirths == 0) m];

/// What each Thần binh phổ page grants, by tier.
const List<(Bonus, double)> codexGearBonus = [
  (Bonus.hpPct, 0.01),
  (Bonus.atkPct, 0.01),
  (Bonus.defPct, 0.015),
  (Bonus.hpPct, 0.015),
  (Bonus.atkPct, 0.015),
  (Bonus.crit, 0.005),
  (Bonus.critDmg, 0.03),
  (Bonus.skillDmg, 0.02),
  (Bonus.hpPct, 0.02),
  (Bonus.atkPct, 0.02),
];

/// What each Vạn thú phổ page grants, by land.
const Map<String, (Bonus, double)> codexLandBonus = {
  'ngoaithanh': (Bonus.hpPct, 0.005),
  'truclam': (Bonus.atkPct, 0.005),
  'hacphong': (Bonus.defPct, 0.01),
  'mieucuong': (Bonus.hpPct, 0.008),
  'hoangsa': (Bonus.atkPct, 0.008),
  'bangnguyen': (Bonus.defPct, 0.012),
  'tayvuc': (Bonus.hpPct, 0.01),
  'hoadiem': (Bonus.atkPct, 0.01),
  'magiao': (Bonus.critDmg, 0.02),
  'donghai': (Bonus.hpPct, 0.012),
  'vanvu': (Bonus.atkPct, 0.012),
  'hoason': (Bonus.skillDmg, 0.015),
  'conlon': (Bonus.crit, 0.005),
};

// ------------------------------------------------- Truyền thuyết phổ (1.26.0)
// One page for each name a Truyền thuyết piece is forged under (Bá Vương,
// Kinh Hồng...), a cell for each slot. Only Truyền thuyết pieces count, not
// Hoàng Kim. Cells are kept in [HeroData.codexGear] as 'l<name>.<slot>'.

String codexLegendKey(int name, Slot slot) => 'l$name.${slot.index}';
String codexLegendPage(int name) => 'l$name';

/// What each Truyền thuyết phổ page grants, by [legendNames] index.
const List<(Bonus, double)> codexLegendBonus = [
  (Bonus.atkPct, 0.02), // Bá Vương
  (Bonus.dodge, 0.01), // Kinh Hồng
  (Bonus.skillDmg, 0.025), // Thiên Cơ
  (Bonus.aspd, 0.02), // Phong Vân
  (Bonus.critDmg, 0.04), // Lăng Tiêu
  (Bonus.hpPct, 0.02), // Vô Song
];

int codexLegendGold(int name) => 1000000 + 250000 * name;
const int codexLegendEssence = 20;
const String codexLegendTitle = 'Truyền Thuyết Tàng Gia';
const Map<Bonus, double> codexLegendAllBonus = {Bonus.atkPct: 0.03, Bonus.hpPct: 0.03};

const String codexGearTitle = 'Thần Binh Bác Lãm';
const String codexLandTitle = 'Vạn Thú Đồ Phổ';
const Map<Bonus, double> codexGearAllBonus = {Bonus.atkPct: 0.03};
const Map<Bonus, double> codexLandAllBonus = {Bonus.hpPct: 0.03};

/// Once-off gold for taking a page (tier or land position from 0), and the
/// Tinh Hoa the higher Thần binh phổ pages add.
int codexGearGold(int tier) => 20000 * (tier + 1) * (tier + 1);
int codexGearEssence(int tier) => tier >= 5 ? 5 * (tier - 4) : 0;
int codexLandGold(int i) => 15000 * (i + 1) * (i + 1);

extension Codex on HeroData {
  /// Notes [it] in Thần binh phổ; true when it filled a new cell.
  bool codexNote(Item it) {
    if (it.rarity != Rarity.legend && !it.golden) return false;
    return codexGear.add(codexGearKey(codexTierOf(it.level), it.slot));
  }

  /// Notes [it] in Truyền thuyết phổ; true when it filled a new cell.
  bool codexNoteLegend(Item it) {
    final n = legendNameOf(it);
    return n >= 0 && codexGear.add(codexLegendKey(n, it.slot));
  }

  /// Notes every piece worn or carried (old saves, pieces given straight
  /// into the bag).
  void codexScanOwned() {
    for (final it in [...equip.values, ...bag]) {
      codexNote(it);
      codexNoteLegend(it);
    }
  }

  void codexKill(MobDef m) {
    if (m.boss) return; // Bosses count in bossKillsById.
    final n = mobKills[m.id] ?? 0;
    if (n < codexMobGoal) mobKills[m.id] = n + 1;
  }

  int codexGearCount(int tier) => [for (final s in Slot.values) if (codexGear.contains(codexGearKey(tier, s))) s].length;
  bool codexGearDone(int tier) => codexGearCount(tier) >= Slot.values.length;

  int codexLegendCount(int name) => [for (final s in Slot.values) if (codexGear.contains(codexLegendKey(name, s))) s].length;
  bool codexLegendDone(int name) => codexLegendCount(name) >= Slot.values.length;
  bool get codexLegendAll => [for (var i = 0; i < legendNames.length; i++) codexLegendPage(i)].every(codexClaimed.contains);

  int codexMobCount(String id) => math.min(codexMobGoal, mobKills[id] ?? 0);
  int codexBossCount(String id) => math.min(codexBossGoal, bossKillsById[id] ?? 0);

  /// Monsters (and the boss) of [m] fully beaten, of all of them.
  (int, int) codexLandProgress(MapDef m) =>
      ([for (final id in m.mobs) if (codexMobCount(id) >= codexMobGoal) id].length +
          (codexBossCount(m.boss) >= codexBossGoal ? 1 : 0), m.mobs.length + 1);

  bool codexLandDone(MapDef m) {
    final (a, b) = codexLandProgress(m);
    return a >= b;
  }

  bool codexClaimable(String page) {
    if (codexClaimed.contains(page)) return false;
    if (page.startsWith('m:')) {
      final m = mapById[page.substring(2)];
      return m != null && codexLandDone(m);
    }
    if (page.startsWith('l')) {
      final n = int.tryParse(page.substring(1));
      return n != null && n >= 0 && n < legendNames.length && codexLegendDone(n);
    }
    final t = int.tryParse(page.substring(1));
    return t != null && t >= 0 && t < codexTiers && codexGearDone(t);
  }

  List<String> get codexPages => [
        for (var t = 0; t < codexTiers; t++) codexGearPage(t),
        for (final m in codexLands) codexLandPage(m.id),
        for (var i = 0; i < legendNames.length; i++) codexLegendPage(i),
      ];

  /// Pages to take, Kỳ ngộ phổ's (1.20.0) among them.
  int get codexReady => codexPages.where(codexClaimable).length + kyPagesReady;

  bool get codexGearAll => [for (var t = 0; t < codexTiers; t++) codexGearPage(t)].every(codexClaimed.contains);
  bool get codexLandAll => codexLands.every((m) => codexClaimed.contains(codexLandPage(m.id)));

  /// Takes page [page]: its gold (and Tinh Hoa) once, and its bonus from now
  /// on. Returns the lines to show, empty when it cannot be taken.
  List<String> codexClaim(String page) {
    if (!codexClaimable(page)) return const [];
    codexClaimed.add(page);
    final lines = <String>[];
    if (page.startsWith('m:')) {
      final i = codexLands.indexWhere((m) => m.id == page.substring(2));
      final g = codexLandGold(math.max(0, i));
      gold += g;
      lines.add(tr('+{p0} lượng', {'p0': fmtThousands(g)}));
      final b = codexLandBonus[page.substring(2)];
      if (b != null) lines.add(loreBonusLabel(b.$1, b.$2));
      if (codexLandAll && seasonTitles.add(codexLandTitle)) {
        lines.add(tr('Vạn thú phổ trọn bộ! Danh hiệu « {codexLandTitle} »', {'codexLandTitle': codexLandTitle}));
      }
    } else if (page.startsWith('l')) {
      final n = int.parse(page.substring(1));
      final g = codexLegendGold(n);
      gold += g;
      essence += codexLegendEssence;
      lines.add(tr('+{p0} lượng', {'p0': fmtThousands(g)}));
      lines.add(tr('+{e} Tinh Hoa', {'e': codexLegendEssence}));
      final b = codexLegendBonus[n];
      lines.add(loreBonusLabel(b.$1, b.$2));
      if (codexLegendAll && seasonTitles.add(codexLegendTitle)) {
        lines.add(tr('Truyền thuyết phổ trọn bộ! Danh hiệu « {t} »', {'t': tr(codexLegendTitle)}));
      }
    } else {
      final t = int.parse(page.substring(1));
      final g = codexGearGold(t);
      gold += g;
      lines.add(tr('+{p0} lượng', {'p0': fmtThousands(g)}));
      final e = codexGearEssence(t);
      if (e > 0) {
        essence += e;
        lines.add(tr('+{e} Tinh Hoa', {'e': e}));
      }
      final b = codexGearBonus[t];
      lines.add(loreBonusLabel(b.$1, b.$2));
      if (codexGearAll && seasonTitles.add(codexGearTitle)) {
        lines.add(tr('Thần binh phổ trọn bộ! Danh hiệu « {codexGearTitle} »', {'codexGearTitle': codexGearTitle}));
      }
    }
    recompute();
    return lines;
  }

  /// What the pages taken add to the hero's stats.
  Map<Bonus, double> codexBonuses() {
    final out = <Bonus, double>{};
    void add(Bonus b, double v) => out[b] = (out[b] ?? 0) + v;
    for (var t = 0; t < codexTiers; t++) {
      if (codexClaimed.contains(codexGearPage(t))) add(codexGearBonus[t].$1, codexGearBonus[t].$2);
    }
    for (var i = 0; i < legendNames.length; i++) {
      if (codexClaimed.contains(codexLegendPage(i))) add(codexLegendBonus[i].$1, codexLegendBonus[i].$2);
    }
    for (final e in codexLandBonus.entries) {
      if (codexClaimed.contains(codexLandPage(e.key))) add(e.value.$1, e.value.$2);
    }
    // The title keeps the set bonus when later books add pages.
    if (codexGearAll || seasonTitles.contains(codexGearTitle)) codexGearAllBonus.forEach(add);
    if (codexLandAll || seasonTitles.contains(codexLandTitle)) codexLandAllBonus.forEach(add);
    if (codexLegendAll || seasonTitles.contains(codexLegendTitle)) codexLegendAllBonus.forEach(add);
    return out;
  }

  List<Object> codexToJson() => [codexGear.toList(), mobKills, codexClaimed.toList()];

  void codexFromJson(Object? o) {
    if (o is! List || o.length < 3) return;
    try {
      for (final v in o[0] as List) {
        final k = '$v';
        if (RegExp(r'^[gl]\d\.\d$').hasMatch(k)) codexGear.add(k);
      }
      (o[1] as Map).forEach((k, v) {
        if (v is num && mobById.containsKey('$k')) mobKills['$k'] = v.toInt().clamp(0, codexMobGoal);
      });
      codexClaimed.addAll([for (final v in o[2] as List) '$v']);
    } catch (_) {}
  }
}

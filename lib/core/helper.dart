import 'dart:math' as math;

import 'content.dart';
import 'hero.dart';

/// Trợ chiến (1.14.0): call another player's hero (a friend, a bang
/// member, or any stronger player from the board) into an ải as an ally run
/// by the game, as companions are. A friend called in earns Hiệp nghĩa:
/// lượng, and titles as it adds up. Built for heroes stuck at an ải in the
/// level 10-40 stretch, where most players stopped.

/// Calls a hero may make in a Vietnam day, each player's hero once.
const int helpCallsPerDay = 3;

/// Where an ally may be called: ordinary and Ác Mộng ải. Never where there
/// is a board or a duel (tower, bosses, Tâm Ma, Ma Vực, Hung Thú, arenas),
/// nor in a bí cảnh.
bool helperAllowed(DungeonDef d) =>
    !(d.isTower || d.isWorldBoss || d.isArena || d.isRealm || d.isTamMa || d.isMaVuc || d.isBeast);

/// How hard the ally hits next to the hero: their hits are worked out on
/// the hero's attack (as a companion's), times this, from the two lực
/// chiến. A much stronger ally carries the fight but not alone.
double helperMul(int helperPower, int heroPower) =>
    math.pow(math.max(1, helperPower) / math.max(1, heroPower), 0.6).clamp(0.7, 2.2).toDouble();

/// Basic hit and skill power before [helperMul], as a companion at full
/// hảo cảm.
const double helperHit = 0.665;
const double helperSkill = 0.81;

/// Where a candidate came from, shown on their card and in analytics.
enum HelperSource { friend, guild, master }

const helperSourceNames = {
  HelperSource.friend: 'Hảo hữu',
  HelperSource.guild: 'Đồng môn bang',
  HelperSource.master: 'Cao thủ',
};

/// Lượng for one Hiệp nghĩa (being called in once), on the helper's side.
int hiepNghiaGold(int level, int rebirths) => ((300 + 40 * level) * (1 + 0.5 * rebirths)).round();

/// Hiệp nghĩa totals that give a title.
const hiepNghiaTitles = {10: 'Trượng Nghĩa', 50: 'Hiệp Can Nghĩa Đảm', 200: 'Nghĩa Bạc Vân Thiên'};

extension HelperCalls on HeroData {
  void helpRollDay(String day) {
    if (helpDay == day) return;
    helpDay = day;
    helpUsed.clear();
  }

  int helpsLeft(String day) {
    helpRollDay(day);
    return math.max(0, helpCallsPerDay - helpUsed.length);
  }

  bool canCallHelper(String row, String day) => helpsLeft(day) > 0 && !helpUsed.contains(row);

  void useHelper(String row, String day) {
    helpRollDay(day);
    if (!helpUsed.contains(row)) helpUsed.add(row);
  }

  /// Takes [n] Hiệp nghĩa that came in; the lines to show.
  List<String> takeHiepNghia(int n) {
    if (n <= 0) return const [];
    final before = hnTotal;
    hnTotal += n;
    final g = hiepNghiaGold(level, rebirths) * n;
    gold += g;
    final lines = ['+$n Hiệp nghĩa (tổng $hnTotal)', '+$g lượng'];
    hiepNghiaTitles.forEach((need, t) {
      if (before < need && hnTotal >= need && seasonTitles.add(t)) lines.add('Danh hiệu « $t »');
    });
    return lines;
  }
}

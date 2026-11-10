import 'dart:math' as math;

import 'arena.dart';
import 'content.dart';
import 'hero.dart';
import 'hero_look.dart';
import 'sects.dart';
import 'tam_ma.dart';

/// Ngộ Đạo (1.12.0): the climb past the last rebirth. Once a hero is in
/// the sixth life at level 99 with a full bar, EXP also builds Đạo hạnh
/// (it still condenses into Linh Phách Đơn as before). Đạo hạnh fills
/// tầng after tầng, nine to a cảnh giới; each tầng adds a little HP,
/// attack and defence, with no ceiling. Going from the ninth tầng into the
/// next cảnh giới takes Linh Phách Đơn and a won Độ kiếp: a duel with the
/// hero's own heart demon, a little stronger every cảnh giới.
class DaoStage {
  const DaoStage(this.name, this.color);
  final String name;
  final int color;
}

const daoStages = <DaoStage>[
  DaoStage('Luyện Khí', 0xFFB8D8B0),
  DaoStage('Trúc Cơ', 0xFF8CE07A),
  DaoStage('Kim Đan', 0xFFFFD34A),
  DaoStage('Nguyên Anh', 0xFF6FC8E8),
  DaoStage('Hóa Thần', 0xFFC88CFF),
  DaoStage('Luyện Hư', 0xFF9FB8FF),
  DaoStage('Hợp Thể', 0xFFFF9A5A),
  DaoStage('Đại Thừa', 0xFFFF6A6A),
  // The last one has no ninth tầng: it goes on for ever.
  DaoStage('Chân Tiên', 0xFFFFF4C8),
];

const int daoLayers = 9;

/// Đạo hạnh (EXP) from tầng [lv] to lv + 1. 20 million is about twenty
/// minutes in U Minh Huyết Hải for a top hero (60M an hour, measured with
/// tool/exp99_probe_test.dart); each tầng asks 10% more, so the first cảnh
/// giới takes about 4.5 hours of farming, Kim Đan about a day and Hóa Thần
/// about a week.
int daoCost(int lv) => (daoBase * math.pow(daoGrowth, lv) / 100000).round() * 100000;
const double daoBase = 20000000;
const double daoGrowth = 1.1;

/// Cảnh giới index of tầng [lv] (0 for Luyện Khí), -1 before the first.
int daoStageOf(int lv) => lv <= 0 ? -1 : math.min((lv - 1) ~/ daoLayers, daoStages.length - 1);

/// Tầng within its cảnh giới, 1..9 (and on past 9 in Chân Tiên).
int daoLayerOf(int lv) => lv <= 0 ? 0 : lv - daoStageOf(lv) * daoLayers;

String daoName(int lv) => lv <= 0 ? 'Chưa nhập đạo' : '${daoStages[daoStageOf(lv)].name} tầng ${daoLayerOf(lv)}';

int daoColor(int lv) => lv <= 0 ? 0xFFB8A888 : daoStages[daoStageOf(lv)].color;

/// Whether going on from tầng [lv] means a new cảnh giới, so an Độ kiếp.
bool daoAtGate(int lv) => lv > 0 && lv % daoLayers == 0 && lv ~/ daoLayers < daoStages.length;

/// Linh Phách Đơn for the Độ kiếp at tầng [lv].
int kiepPills(int lv) => 50 * (lv ~/ daoLayers);

/// Tiên Ngọc (1.13.0, for Tiên khí) for a won Độ kiếp into cảnh giới
/// [stage], and for each new tầng.
int kiepJade(int stage) => 5 * stage;
const int daoLayerJade = 1;

/// Bonus per tầng, and per cảnh giới entered past the first.
const double daoHpAtk = 0.005;
const double daoDef = 0.003;
const double daoStageHpAtk = 0.02;

Map<Bonus, double> daoBonuses(int lv) {
  if (lv <= 0) return const {};
  final stages = daoStageOf(lv);
  final ha = daoHpAtk * lv + daoStageHpAtk * stages;
  return {Bonus.hpPct: ha, Bonus.atkPct: ha, Bonus.defPct: daoDef * lv};
}

/// The Độ kiếp duel into cảnh giới [stage] (1-based index into
/// [daoStages]): the hero's heart demon, a little stronger than the hero
/// and with one twist more every three cảnh giới.
const double kiepTime = 120;
double kiepMul(int stage) => 0.6 + 0.025 * stage;

List<int> kiepAffixes(int stage) {
  const order = [TmAffix.thorns, TmAffix.regen, TmAffix.rage, TmAffix.guard, TmAffix.iron];
  final n = math.min(order.length, 1 + (stage - 1) ~/ 3);
  return [for (var i = 0; i < n; i++) order[(stage - 1 + i) % order.length].index];
}

extension NgoDao on HeroData {
  bool get daoOpen => rebirths >= maxRebirths;

  /// Đạo hạnh toward the next tầng, as a part of what it costs.
  double get daoProgress => (daoExp / daoCost(daoLv)).clamp(0.0, 1.0);

  /// At the ninth tầng with a full bar: only an Độ kiếp goes on.
  bool get daoWaiting => daoAtGate(daoLv) && daoExp >= daoCost(daoLv);

  bool get canKiep => daoOpen && daoWaiting && soulPills >= kiepPills(daoLv);

  /// Cảnh giới the next Độ kiếp leads into.
  int get kiepStage => daoStageOf(daoLv) + 1;

  ArenaRival kiepRival() {
    final m = ridingMount;
    return ArenaRival(
      name: 'Tâm Ma Kiếp',
      hanh: hanh,
      level: level,
      rebirths: rebirths,
      power: (power * kiepMul(kiepStage)).round(),
      female: female,
      title: title,
      mount: m?.id ?? '',
      mountLv: m == null ? 1 : mountLevels[m.id] ?? 1,
      skin: m == null ? '' : mountSkin[m.id] ?? '',
      look: lookRow(this),
    );
  }

  DungeonDef kiepDef() => DungeonDef(
        id: 'kiep',
        name: 'Độ Kiếp · ${daoStages[kiepStage].name}',
        mapId: huyetHaiMap.id,
        level: level,
        waves: const [],
        timeLimit: kiepTime,
        rival: kiepRival(),
        kiep: kiepStage,
        tmAffixes: kiepAffixes(kiepStage),
      );

  /// The Độ kiếp duel is over: on a win, pay and step into the new cảnh
  /// giới. A loss costs nothing; the hero may try again.
  List<String> kiepResult(bool won) {
    if (!won) return const ['Tâm ma chưa trừ, đạo tâm chưa vững. Hãy thử lại.'];
    if (!canKiep) return const [];
    final pills = kiepPills(daoLv);
    soulPills -= pills;
    daoExp -= daoCost(daoLv);
    daoLv++;
    daoNotified = false;
    final jade = kiepJade(kiepStage - 1);
    tienJade += jade;
    final name = daoName(daoLv);
    notices.add(Notice('Độ kiếp thành công: $name!', color: daoColor(daoLv), big: true));
    recompute();
    gainDao(0);
    return [
      'Bước vào $name',
      '-$pills Linh Phách Đơn',
      '+$jade Tiên Ngọc',
      'Sinh lực, Công lực +${(daoStageHpAtk * 100).round()}% thêm',
    ];
  }

  /// Adds [amount] Đạo hạnh, climbing tầng until a gate or the bar runs
  /// out. At a gate the bar fills and stops there.
  void gainDao(double amount) {
    if (!daoOpen) return;
    daoExp += amount.round();
    var up = false;
    while (!daoAtGate(daoLv) && daoExp >= daoCost(daoLv)) {
      daoExp -= daoCost(daoLv);
      daoLv++;
      tienJade += daoLayerJade;
      up = true;
      notices.add(Notice('Ngộ Đạo: ${daoName(daoLv)}', color: daoColor(daoLv), big: true));
    }
    if (daoAtGate(daoLv) && daoExp >= daoCost(daoLv)) {
      daoExp = daoCost(daoLv);
      if (!daoNotified) {
        daoNotified = true;
        notices.add(Notice('Đạo hạnh viên mãn! Về Chuyển sinh để Độ kiếp vào ${daoStages[kiepStage].name}.',
            color: 0xFFFFD34A, big: true));
      }
    }
    if (up) recompute();
  }
}

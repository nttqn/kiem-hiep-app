import 'dart:math' as math;

import 'gems.dart';
import 'hero.dart';

/// Sư đồ (1.19.0): a strong hero (level [mentorMinLevel] or reborn) takes
/// up to [mentorMaxDisciples] new heroes (no rebirth, level up to
/// [discipleMaxLevel] when they ask) as đệ tử.
///
/// * The đệ tử gets +[discipleExpBonus] monster EXP until xuất sư (the
///   first rebirth), a gift at each level milestone reached after the
///   master took them, and a daily Truyền công from the master.
/// * The master is paid Tinh Hoa and Thần Thiết as each đệ tử passes a
///   milestone, read from the đệ tử's public board row (so nobody can claim
///   a level they do not have), and the most at xuất sư.
///
/// Requests, answers and Truyền công go through Firestore
/// (`mentor/{toRow}/in/{fromRow}`, services/guild.dart); masters who take
/// đệ tử list themselves in `mentors/{row}`.
const int mentorMinLevel = 90;
const int discipleMaxLevel = 60;
const int mentorMaxDisciples = 3;
const double discipleExpBonus = 0.1;

/// Truyền công: EXP for the đệ tử as a share of their level's need, and
/// the Tinh Hoa it gives the master for sending it.
const double truyenCongShare = 0.1;
const int truyenCongEssence = 1;

/// Level milestones; one more step after them is xuất sư.
const List<int> mentorMilestones = [20, 30, 40, 50, 60, 70, 80, 90, 99];
int get mentorSteps => mentorMilestones.length + 1;

String mentorStepName(int i) => i >= mentorMilestones.length ? 'Xuất sư' : 'Cấp ${mentorMilestones[i]}';

/// Steps a hero at [level] with [rebirths] has passed.
int mentorStepsReached(int level, int rebirths) =>
    rebirths > 0 ? mentorMilestones.length + 1 : mentorMilestones.where((m) => level >= m).length;

class DiscipleGift {
  const DiscipleGift(this.gold, this.pots, this.gems, this.gemTier, {this.pills = 0});
  final int gold, pots, gems, gemTier, pills;
}

/// The đệ tử's gift at each step.
const List<DiscipleGift> discipleGifts = [
  DiscipleGift(20000, 30, 0, 0),
  DiscipleGift(40000, 30, 2, 2),
  DiscipleGift(80000, 40, 2, 3),
  DiscipleGift(150000, 40, 3, 3),
  DiscipleGift(250000, 50, 3, 4),
  DiscipleGift(400000, 50, 2, 4),
  DiscipleGift(600000, 60, 3, 4),
  DiscipleGift(900000, 60, 3, 5),
  DiscipleGift(1500000, 80, 3, 5),
  DiscipleGift(2000000, 100, 3, 5, pills: 10),
];

/// The master's pay at each step of a đệ tử: Tinh Hoa and Thần Thiết.
const List<(int, int)> mentorPay = [
  (3, 0),
  (3, 0),
  (5, 1),
  (5, 1),
  (8, 1),
  (8, 2),
  (10, 2),
  (10, 2),
  (15, 3),
  (30, 10),
];

const String discipleTitle = 'Cao Đồ Danh Môn';
const String mentorTitle1 = 'Danh Sư';
const String mentorTitle3 = 'Nhất Đại Tông Sư';

/// A đệ tử as their master keeps them: board row, name and element as last
/// seen, steps already paid, and level/rebirths last read from the board.
class Disciple {
  Disciple(this.row, this.name, this.hanh, this.paid, {this.level = 0, this.rebirths = 0});
  final String row;
  String name;
  int hanh;
  int paid;
  int level, rebirths;

  int get reached => mentorStepsReached(level, rebirths);
  bool get graduated => rebirths > 0;

  List<Object> toJson() => [row, name, hanh, paid, level, rebirths];

  static Disciple? fromJson(Object? o) {
    if (o is! List || o.length < 6) return null;
    try {
      return Disciple(o[0] as String, o[1] as String, (o[2] as num).toInt().clamp(0, 4),
          (o[3] as num).toInt().clamp(0, mentorSteps),
          level: (o[4] as num).toInt().clamp(0, 99), rebirths: (o[5] as num).toInt().clamp(0, 9));
    } catch (_) {
      return null;
    }
  }
}

extension Mentor on HeroData {
  bool get canTeach => level >= mentorMinLevel || rebirths > 0;
  bool get canBaiSu => rebirths == 0 && level <= discipleMaxLevel && sdMaster.isEmpty;
  bool get hasMaster => sdMaster.isNotEmpty;

  /// Đệ tử not yet xuất sư: they hold the master's seats.
  int get activeDisciples => disciples.where((d) => !d.graduated).length;
  bool get seatFree => activeDisciples < mentorMaxDisciples;

  /// Monster EXP while learning under a master.
  double get discipleExp => hasMaster && rebirths == 0 ? discipleExpBonus : 0;

  /// Things to take on the Sư đồ tab that need no network: a gift due, a
  /// Truyền công seen, pay for a đệ tử's steps.
  int get mentorBadge =>
      (discipleGiftReady ? 1 : 0) +
      (sdTcReady && rebirths == 0 ? 1 : 0) +
      disciples.where((d) => mentorPayDue(d) > 0).length;

  // ------------------------------------------------------------ đệ tử

  /// Asked [row] to be the master; waits for an answer.
  void askMaster(String row, String name, int hanh) {
    sdPending = row;
    sdPendingName = name;
    sdPendingHanh = hanh;
  }

  /// The master said yes: gifts count from the steps not yet passed.
  void masterAccepted() {
    if (sdPending.isEmpty) return;
    sdMaster = sdPending;
    sdMasterName = sdPendingName;
    sdMasterHanh = sdPendingHanh;
    sdPending = '';
    sdPendingName = '';
    sdGiftNext = mentorStepsReached(level, rebirths);
  }

  /// Left the master, or was let go.
  void leaveMaster() {
    sdMaster = '';
    sdMasterName = '';
    sdTcReady = false;
  }

  int get discipleStepsReached => mentorStepsReached(level, rebirths);
  bool get discipleGiftReady => hasMaster && sdGiftNext < discipleStepsReached && sdGiftNext < mentorSteps;

  /// Takes the next step's gift; empty when none is due.
  List<String> takeDiscipleGift() {
    if (!discipleGiftReady) return const [];
    final i = sdGiftNext++;
    final g = discipleGifts[i];
    gold += g.gold;
    hpPots += g.pots;
    mpPots += g.pots ~/ 2;
    if (g.gems > 0) addGem(Gem(hanh, g.gemTier), g.gems);
    soulPills += g.pills;
    final lines = [
      'Quà sư môn · ${mentorStepName(i)}',
      '+${g.gold} lượng, +${g.pots} bình máu, +${g.pots ~/ 2} bình nội lực',
      if (g.gems > 0) '+${g.gems} ${Gem(hanh, g.gemTier).name}',
      if (g.pills > 0) '+${g.pills} Linh Phách Đơn',
    ];
    if (i == mentorSteps - 1 && seasonTitles.add(discipleTitle)) lines.add('Danh hiệu « $discipleTitle »');
    return lines;
  }

  /// Truyền công from the master today, taken once.
  int takeTruyenCong(String day) {
    if (!sdTcReady || sdTcDay == day || !hasMaster || rebirths > 0) return 0;
    sdTcReady = false;
    sdTcDay = day;
    final xp = (expNeeded * truyenCongShare).round();
    gainExp(xp.toDouble());
    return xp;
  }

  // ------------------------------------------------------------ sư phụ

  Disciple? discipleOf(String row) {
    for (final d in disciples) {
      if (d.row == row) return d;
    }
    return null;
  }

  /// Took [row] as đệ tử, now at [level]: steps already passed are not paid.
  bool acceptDisciple(String row, String name, int hanh, int level) {
    if (!canTeach || !seatFree || discipleOf(row) != null || level > discipleMaxLevel) return false;
    disciples.add(Disciple(row, name, hanh, mentorStepsReached(level, 0), level: level));
    return true;
  }

  void dropDisciple(String row) => disciples.removeWhere((d) => d.row == row);

  /// What the board says of a đệ tử now. Level only goes up (a hidden or
  /// stale row never takes pay back), rebirth only once.
  void seeDisciple(String row, String name, int hanh, int level, int rebirths) {
    final d = discipleOf(row);
    if (d == null) return;
    d.name = name;
    d.hanh = hanh;
    if (rebirths > d.rebirths) {
      d.rebirths = rebirths;
      d.level = level;
    } else if (rebirths == d.rebirths) {
      d.level = math.max(d.level, level);
    }
  }

  int mentorPayDue(Disciple d) => math.max(0, math.min(d.reached, mentorSteps) - d.paid);

  /// Pays every step [d] has passed since the last time.
  List<String> takeMentorPay(Disciple d) {
    final due = mentorPayDue(d);
    if (due <= 0) return const [];
    var ess = 0, iron = 0;
    for (var i = d.paid; i < d.paid + due; i++) {
      ess += mentorPay[i].$1;
      iron += mentorPay[i].$2;
    }
    final graduatedNow = d.paid + due >= mentorSteps;
    d.paid += due;
    essence += ess;
    divineIron += iron;
    final lines = ['Đệ tử ${d.name}: ${mentorStepName(d.paid - 1)}', '+$ess Tinh Hoa', if (iron > 0) '+$iron Thần Thiết'];
    if (graduatedNow) {
      sdGraduates++;
      if (seasonTitles.add(mentorTitle1)) lines.add('Danh hiệu « $mentorTitle1 »');
      if (sdGraduates >= 3 && seasonTitles.add(mentorTitle3)) lines.add('Danh hiệu « $mentorTitle3 »');
    }
    return lines;
  }

  void mentorRollDay(String day) {
    if (sdTcSentDay == day) return;
    sdTcSentDay = day;
    sdTcSent.clear();
  }

  bool canTruyenCong(String row, String day) {
    mentorRollDay(day);
    final d = discipleOf(row);
    return d != null && !d.graduated && !sdTcSent.contains(row);
  }

  /// Sent Truyền công to [row] today: a little Tinh Hoa for the trouble.
  void sentTruyenCong(String row, String day) {
    mentorRollDay(day);
    if (sdTcSent.add(row)) essence += truyenCongEssence;
  }

  // ------------------------------------------------------------ save

  List<Object> mentorToJson() => [
        sdMaster, sdMasterName, sdMasterHanh, sdPending, sdPendingName, sdPendingHanh, sdGiftNext, sdTcDay,
        sdTcReady ? 1 : 0, [for (final d in disciples) d.toJson()], sdTcSentDay, sdTcSent.toList(), sdGraduates,
        sdListing ? 1 : 0,
      ];

  void mentorFromJson(Object? o) {
    if (o is! List || o.length < 14) return;
    try {
      sdMaster = o[0] as String;
      sdMasterName = o[1] as String;
      sdMasterHanh = (o[2] as num).toInt().clamp(0, 4);
      sdPending = o[3] as String;
      sdPendingName = o[4] as String;
      sdPendingHanh = (o[5] as num).toInt().clamp(0, 4);
      sdGiftNext = (o[6] as num).toInt().clamp(0, mentorSteps);
      sdTcDay = o[7] as String;
      sdTcReady = o[8] == 1;
      disciples
        ..clear()
        ..addAll([for (final v in o[9] as List) ?Disciple.fromJson(v)]);
      sdTcSentDay = o[10] as String;
      sdTcSent
        ..clear()
        ..addAll([for (final v in o[11] as List) '$v']);
      sdGraduates = math.max(0, (o[12] as num).toInt());
      sdListing = o[13] == 1;
    } catch (_) {}
  }
}

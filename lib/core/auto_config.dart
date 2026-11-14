/// Cài đặt tự đánh: how the autopilot picks its fights, which skills it
/// casts, when it drinks and whether it walks off for loot. Kept per hero,
/// since every sect's skills differ.
enum AutoTarget {
  /// Whatever is closest (monsters already attacking count as closer).
  nearest,

  /// Quest and bounty monsters first (the default, as before 1.4.0).
  quest,

  /// Elites and bosses first, then quest monsters.
  strong,
}

const autoTargetNames = {
  AutoTarget.nearest: 'Gần nhất',
  AutoTarget.quest: 'Quái nhiệm vụ',
  AutoTarget.strong: 'Tinh anh, boss',
};

/// Potion thresholds the player may pick, as a share of the bar.
const autoHpSteps = [0.25, 0.35, 0.42, 0.5, 0.6, 0.7];
const autoMpSteps = [0.1, 0.22, 0.35, 0.5];

class AutoConfig {
  AutoTarget target = AutoTarget.quest;

  /// Sect skill indexes the autopilot leaves for the player.
  final Set<int> skillsOff = {};
  double hpPot = 0.42;
  double mpPot = 0.22;

  /// Walk over to dropped loot and grown linh thảo.
  bool loot = true;

  /// Wait for a crowd (3+) or a boss before the tuyệt kỹ.
  bool saveUltimate = true;

  /// Tự cộng điểm: on a level-up, spread potential points by the sect's
  /// build and learn skills. Tự mặc đồ: put on a picked-up piece that is
  /// better than the one worn. Switched on for heroes made in the game from
  /// 1.5.0 (SaveService.create: most new players never opened the character
  /// screen and died with points unspent); off for heroes made before, who
  /// build by hand.
  bool points = false;
  bool gear = false;

  /// Tự đi nhiệm vụ (1.14.0): while the autopilot fights, head for the ải
  /// or field the story quest needs after a short countdown the player can
  /// cancel, and go on to the next one after clearing a quest ải. On for
  /// every hero, old ones too; the funnel showed autopilot players stalling
  /// at dungeon quests.
  bool questGo = true;

  bool get isDefault =>
      target == AutoTarget.quest && skillsOff.isEmpty && hpPot == 0.42 && mpPot == 0.22 && loot && saveUltimate &&
      questGo;

  List<Object> toJson() =>
      [target.index, skillsOff.toList(), hpPot, mpPot, loot, saveUltimate, points, gear, questGo];

  static AutoConfig fromJson(Object? raw) {
    final c = AutoConfig();
    if (raw is! List || raw.length < 6) return c;
    final t = raw[0];
    if (t is int && t >= 0 && t < AutoTarget.values.length) c.target = AutoTarget.values[t];
    for (final i in raw[1] as List? ?? const []) {
      if (i is int && i >= 0 && i < 10) c.skillsOff.add(i);
    }
    final hp = raw[2], mp = raw[3];
    if (hp is num) c.hpPot = hp.toDouble().clamp(0.1, 0.8);
    if (mp is num) c.mpPot = mp.toDouble().clamp(0.05, 0.8);
    c.loot = raw[4] != false;
    c.saveUltimate = raw[5] != false;
    // Saved before 1.5.0: those two did not exist, and the hero was built by hand.
    c.points = raw.length > 7 && raw[6] == true;
    c.gear = raw.length > 7 && raw[7] == true;
    c.questGo = raw.length <= 8 || raw[8] != false;
    return c;
  }
}

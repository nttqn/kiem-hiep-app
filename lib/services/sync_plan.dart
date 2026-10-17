/// What cloud sync should do with each save slot. Pure Dart so it can be
/// tested without Firebase.
library;

import 'dart:convert';

import '../core/hero.dart';

/// The few facts about one copy of a slot that sync decisions need.
class SlotInfo {
  const SlotInfo({
    required this.savedAt,
    required this.data,
    this.name = '',
    this.level = 0,
    this.sect = '',
    this.playSeconds = 0,
    this.rebirths = 0,
  });

  factory SlotInfo.ofHero(HeroData h) => SlotInfo(
        savedAt: h.savedAt,
        data: jsonEncode(h.toJson()),
        name: h.name,
        level: h.level,
        sect: h.sect.name,
        playSeconds: h.playSeconds,
        rebirths: h.rebirths,
      );

  /// Ms since epoch of the last write.
  final int savedAt;

  /// The full save JSON, compared to tell identical copies apart.
  final String data;
  final String name;
  final int level;
  final String sect;
  final double playSeconds;
  final int rebirths;

  /// "Cấp 50", with the rebirth count when there is one.
  String get levelText => rebirths > 0 ? 'Cấp $level · Chuyển sinh $rebirths' : 'Cấp $level';
}

/// How far a copy got: rebirths, then level, then play time (with half a
/// minute of slack). Positive when [a] is further along than [b].
int compareProgress(SlotInfo a, SlotInfo b) {
  if (a.rebirths != b.rebirths) return a.rebirths - b.rebirths;
  if (a.level != b.level) return a.level - b.level;
  final dt = a.playSeconds - b.playSeconds;
  return dt.abs() <= 30 ? 0 : dt.sign.toInt();
}

bool sameHero(SlotInfo a, SlotInfo b) => a.name == b.name && a.sect == b.sect;

/// Writing [to] over [from] would throw progress away: [to] is another
/// character, or the same one further back.
bool wouldLose(SlotInfo from, SlotInfo to) => !sameHero(from, to) || compareProgress(to, from) < 0;

enum SlotAction {
  /// Both sides empty or identical.
  none,

  /// Push the device copy up.
  upload,

  /// Take the cloud copy (the device slot is empty).
  restore,

  /// Both exist, differ, and the cloud one is newer: ask the player.
  ask,
}

/// Decides per slot. The device copy wins when it is the newer one, so
/// normal play just keeps uploading; a newer cloud copy (played on another
/// phone) is never applied over local progress without asking, and neither
/// is a device copy that is behind the cloud one or another character
/// (e.g. an old copy brought back by Android's own backup on reinstall).
List<SlotAction> planSync(List<SlotInfo?> local, List<SlotInfo?> cloud) {
  return [
    for (var i = 0; i < local.length; i++) _plan(local[i], i < cloud.length ? cloud[i] : null),
  ];
}

SlotAction _plan(SlotInfo? l, SlotInfo? c) {
  if (l == null && c == null) return SlotAction.none;
  if (c == null) return SlotAction.upload;
  if (l == null) return SlotAction.restore;
  if (l.data == c.data) return SlotAction.none;
  if (c.savedAt > l.savedAt) return SlotAction.ask;
  return wouldLose(c, l) ? SlotAction.ask : SlotAction.upload;
}

/// Of a slot's current copy and its backup, whether the backup is worth
/// offering: the slot is empty, holds another character, or is behind.
bool backupWorthOffering(SlotInfo? current, SlotInfo? backup) =>
    backup != null && (current == null || wouldLose(backup, current));

/// The backup to keep when [old] is about to be overwritten and [kept] is
/// the backup so far: whichever got further.
bool shouldStash(SlotInfo old, SlotInfo? kept) => kept == null || compareProgress(old, kept) > 0;

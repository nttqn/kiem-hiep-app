/// What cloud sync should do with each save slot. Pure Dart so it can be
/// tested without Firebase.
library;

/// The few facts about one copy of a slot that sync decisions need.
class SlotInfo {
  const SlotInfo({
    required this.savedAt,
    required this.data,
    this.name = '',
    this.level = 0,
    this.sect = '',
    this.playSeconds = 0,
  });

  /// Ms since epoch of the last write.
  final int savedAt;

  /// The full save JSON, compared to tell identical copies apart.
  final String data;
  final String name;
  final int level;
  final String sect;
  final double playSeconds;
}

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
/// phone) is never applied over local progress without asking.
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
  return c.savedAt > l.savedAt ? SlotAction.ask : SlotAction.upload;
}

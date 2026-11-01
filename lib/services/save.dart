import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/hero.dart';
import '../core/world_boss.dart' show vnDayKey;
import 'analytics.dart';
import 'cloud.dart';
import 'sync_plan.dart';

const int slotCount = 3;

/// Three character slots plus small settings, in shared preferences, with
/// every save mirrored to [CloudSave] when the player is signed in.
class SaveService extends ChangeNotifier {
  SaveService._();
  static final SaveService instance = SaveService._();

  final List<HeroData?> slots = List.filled(slotCount, null);

  /// Per slot, the furthest copy that was ever overwritten or deleted
  /// there, so a wrong sync choice or a stale restore can be undone.
  final List<HeroData?> backups = List.filled(slotCount, null);
  int active = -1;

  /// Time since the opened hero was last saved, for the closed-door
  /// training payout; set when a slot is opened, taken by the town.
  Duration? pendingAway;
  bool autoFight = true;

  HeroData get hero => slots[active]!;

  static String _key(int i) => 'hero_slot_$i';
  static String _bakKey(int i) => 'hero_slot_${i}_bak';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      autoFight = prefs.getBool('auto_fight') ?? true;
      owner = prefs.getString('save_owner');
      ownerWho = prefs.getString('save_owner_who') ?? '';
      for (var i = 0; i < slotCount; i++) {
        final raw = prefs.getString(_key(i));
        if (raw == null) continue;
        try {
          slots[i] = HeroData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('slot $i unreadable: $e');
        }
      }
      for (var i = 0; i < slotCount; i++) {
        final raw = prefs.getString(_bakKey(i));
        if (raw == null) continue;
        try {
          backups[i] = HeroData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Saves the active slot, stamps it and queues the cloud upload.
  Future<void> save() async {
    if (active < 0 || slots[active] == null) return;
    slots[active]!.savedAt = DateTime.now().millisecondsSinceEpoch;
    Analytics.instance.track(active, slots[active]!);
    await writeSlot(active);
    CloudSave.instance.queueUpload(active);
  }

  /// Writes [slot] to the device as it is, without touching its stamp.
  Future<void> writeSlot(int slot) async {
    notifyListeners();
    final h = slots[slot];
    if (h == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(slot), jsonEncode(h.toJson()));
    } catch (_) {}
  }

  /// Puts a hero from the cloud into [slot], keeping the old copy as the
  /// backup when it was further along or another character.
  Future<void> replaceSlot(int slot, HeroData h) async {
    final old = slots[slot];
    if (old != null && wouldLose(SlotInfo.ofHero(old), SlotInfo.ofHero(h))) await _stash(slot, old);
    slots[slot] = h;
    await writeSlot(slot);
  }

  Future<void> _stash(int slot, HeroData old, {bool force = false}) async {
    final kept = backups[slot];
    if (!force && !shouldStash(SlotInfo.ofHero(old), kept == null ? null : SlotInfo.ofHero(kept))) return;
    backups[slot] = old;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bakKey(slot), jsonEncode(old.toJson()));
    } catch (_) {}
  }

  /// Swaps [slot] with [from] (its local backup, or the cloud one): the
  /// current copy becomes the backup so the swap can be undone.
  Future<void> restore(int slot, HeroData from) async {
    final cur = slots[slot];
    if (cur != null) {
      await _stash(slot, cur, force: true);
    } else if (identical(backups[slot], from)) {
      backups[slot] = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_bakKey(slot));
      } catch (_) {}
    }
    slots[slot] = from;
    from.savedAt = DateTime.now().millisecondsSinceEpoch;
    await writeSlot(slot);
    await CloudSave.instance.pushRestored(slot);
  }

  Future<void> create(int slot, HeroData h) async {
    Analytics.instance.log('hero_create', {'sect': h.sect.name});
    slots[slot] = h;
    active = slot;
    h.seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    h.bornDay = vnDayKey();
    await save();
  }

  Future<void> delete(int slot) async {
    final old = slots[slot];
    if (old != null) await _stash(slot, old);
    slots[slot] = null;
    if (active == slot) active = -1;
    notifyListeners();
    CloudSave.instance.deleteSlot(slot);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(slot));
    } catch (_) {}
  }

  Future<void> setAuto(bool v) async {
    autoFight = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_fight', v);
    } catch (_) {}
  }

  // ------------------------------------------------------------ owner

  /// The cloud account these device slots belong to (its uid and how it is
  /// shown), null before any sign-in. Signing in to another account must
  /// not push them into it unasked.
  String? owner;
  String ownerWho = '';

  bool get hasHeroes => slots.any((s) => s != null);

  Future<void> setOwner(String? uid, String who) async {
    owner = uid;
    ownerWho = who;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (uid == null) {
        await prefs.remove('save_owner');
        await prefs.remove('save_owner_who');
      } else {
        await prefs.setString('save_owner', uid);
        await prefs.setString('save_owner_who', who);
      }
    } catch (_) {}
  }

  static String _archiveKey(String uid) => 'save_archive_$uid';

  /// Puts every slot and backup aside on this device under [uid] (the
  /// account they belong to) and empties the slots, so another account can
  /// play here; [restoreArchive] brings them back when [uid] signs in again.
  Future<void> archiveAndClear(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (uid != null && (hasHeroes || backups.any((b) => b != null))) {
        await prefs.setString(
            _archiveKey(uid),
            jsonEncode({
              'slots': [for (final h in slots) h?.toJson()],
              'backups': [for (final h in backups) h?.toJson()],
            }));
      }
      for (var i = 0; i < slotCount; i++) {
        slots[i] = null;
        backups[i] = null;
        await prefs.remove(_key(i));
        await prefs.remove(_bakKey(i));
      }
    } catch (e) {
      debugPrint('archive failed: $e');
    }
    active = -1;
    notifyListeners();
  }

  /// Brings back what [archiveAndClear] put aside for [uid], into empty
  /// slots; true if there was something.
  Future<bool> restoreArchive(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_archiveKey(uid));
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      HeroData? read(Object? j) => j is Map<String, dynamic> ? HeroData.fromJson(j) : null;
      final s = m['slots'] as List, b = m['backups'] as List;
      for (var i = 0; i < slotCount && i < s.length; i++) {
        slots[i] ??= read(s[i]);
        if (i < b.length) backups[i] ??= read(b[i]);
        await writeSlot(i);
        final bk = backups[i];
        if (bk != null) await prefs.setString(_bakKey(i), jsonEncode(bk.toJson()));
      }
      await prefs.remove(_archiveKey(uid));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('archive unreadable: $e');
      return false;
    }
  }
}

String todayKey() {
  final d = DateTime.now();
  return '${d.year}-${d.month}-${d.day}';
}

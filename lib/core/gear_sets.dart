import 'dart:math' as math;

import 'hero.dart';
import 'items.dart';

/// Bộ trang bị (1.27.0): a hero keeps [gearSetCount] saved builds, each the
/// worn piece of every slot and the potential points, and puts one on in a
/// tap. Pieces are found again by [Item.uid]; saving a set locks its pieces
/// so a bulk sale or a full bag never takes them.
const int gearSetCount = 3;

class GearSet {
  GearSet(this.uids, this.spent, this.power);

  /// [Item.uid] of the piece worn in each slot when saved.
  final Map<Slot, int> uids;

  /// Potential points in str, dex, vit, ene when saved.
  final List<int> spent;

  /// Lực chiến when saved, shown on the card.
  final int power;

  Map<String, dynamic> toJson() => {
        'u': {for (final e in uids.entries) '${e.key.index}': e.value},
        'p': spent,
        'w': power,
      };

  static GearSet? fromJson(Object? o) {
    if (o is! Map) return null;
    final u = <Slot, int>{};
    final um = o['u'];
    if (um is Map) {
      um.forEach((k, v) {
        final i = int.tryParse('$k') ?? -1;
        if (i >= 0 && i < Slot.values.length && v is num && v > 0) u[Slot.values[i]] = v.toInt();
      });
    }
    final p = o['p'];
    final spent = p is List && p.length == 4 ? [for (final v in p) math.max(0, (v as num).toInt())] : [0, 0, 0, 0];
    return GearSet(u, spent, (o['w'] as num?)?.toInt() ?? 0);
  }
}

/// What putting a set on did.
class GearSetResult {
  int changed = 0, missing = 0, tooHigh = 0;
  bool points = false;
}

extension GearSets on HeroData {
  /// The piece carried (worn or in the bag) with this [Item.uid].
  Item? itemByUid(int uid) {
    if (uid <= 0) return null;
    for (final it in equip.values) {
      if (it.uid == uid) return it;
    }
    for (final it in bag) {
      if (it.uid == uid) return it;
    }
    return null;
  }

  int _uidOf(Item it) {
    if (it.uid > 0) return it.uid;
    // Skips a number another piece already carries (one given away by a
    // hero whose count ran ahead).
    do {
      itemUid++;
    } while (itemByUid(itemUid) != null);
    it.uid = itemUid;
    return it.uid;
  }

  /// Saves what is worn and the potential points into set [i].
  void saveGearSet(int i) {
    if (i < 0 || i >= gearSetCount) return;
    final u = <Slot, int>{};
    for (final e in equip.entries) {
      u[e.key] = _uidOf(e.value);
      e.value.locked = true;
    }
    gearSets[i] = GearSet(u, List.of(spent), power);
  }

  void clearGearSet(int i) {
    if (i >= 0 && i < gearSetCount) gearSets[i] = null;
  }

  /// Set [i] is what the hero wears now, points included.
  bool gearSetWorn(int i) {
    final s = i >= 0 && i < gearSetCount ? gearSets[i] : null;
    if (s == null || s.uids.isEmpty) return false;
    for (final e in s.uids.entries) {
      if (equip[e.key]?.uid != e.value) return false;
    }
    for (var k = 0; k < 4; k++) {
      if (spent[k] != s.spent[k]) return false;
    }
    return true;
  }

  /// Puts set [i] on: each saved piece still carried and wearable, then
  /// its potential points (free, as many as the hero has). Slots whose
  /// piece is gone keep what is worn.
  GearSetResult applyGearSet(int i) {
    final r = GearSetResult();
    final s = i >= 0 && i < gearSetCount ? gearSets[i] : null;
    if (s == null) return r;
    for (final e in s.uids.entries) {
      final it = itemByUid(e.value);
      if (it == null || it.slot != e.key) {
        r.missing++;
      } else if (it.level > level) {
        r.tooHigh++;
      } else if (!identical(equip[e.key], it)) {
        equipItem(it);
        r.changed++;
      }
    }
    final want = s.spent.fold<int>(0, (a, b) => a + b);
    final have = potentialTotal;
    var same = true;
    for (var k = 0; k < 4; k++) {
      if (spent[k] != s.spent[k]) same = false;
    }
    if (!same && want <= have) {
      for (var k = 0; k < 4; k++) {
        spent[k] = s.spent[k];
      }
      freePoints = have - want;
      r.points = true;
    }
    recompute();
    return r;
  }
}

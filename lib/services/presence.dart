import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/clock.dart';
import 'chat.dart';
import 'cloud.dart';

/// Which phone is playing a hero (1.8.1): `presence/{uid}/{slot}` in the
/// Realtime Database holds this device's id and a heartbeat. Opening a hero
/// another phone played in the last few minutes asks first; a phone whose
/// hero was taken over stops uploading it, so two phones can no longer
/// overwrite each other's saves (a player lost a Nguyệt thẻ that way).
class Presence {
  Presence._();
  static final Presence instance = Presence._();

  /// Heartbeat interval, and how long a silent phone still counts as playing.
  static const Duration beat = Duration(minutes: 2);
  static const Duration stale = Duration(minutes: 5);

  String _device = '';
  int? _slot;
  Timer? _timer;

  /// The slot another phone took over while this one had it open; its
  /// uploads stop until it is opened here again.
  final ValueNotifier<int?> lostSlot = ValueNotifier(null);

  bool blocks(int slot) => lostSlot.value == slot;

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _device = p.getString('device_id') ?? '';
      if (_device.isEmpty) {
        final r = math.Random.secure();
        _device = List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
        await p.setString('device_id', _device);
      }
    } catch (_) {
      _device = 'd${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  DatabaseReference? _ref(int slot) {
    final cloud = CloudSave.instance;
    final uid = cloud.user?.uid;
    if (!cloud.available || uid == null) return null;
    return FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: ChatService.dbUrl).ref('presence/$uid/$slot');
  }

  // The account's marks, kept current by a listener so the hero list never
  // waits on the network: a one-off read on a cold or refused connection
  // took up to 20 s per tap in 1.8.1's first build.
  StreamSubscription<DatabaseEvent>? _sub;
  String? _subUid;
  Object? _cache;
  bool _heard = false;

  void _watch() {
    final cloud = CloudSave.instance;
    final uid = cloud.user?.uid;
    if (!cloud.available || uid == null || uid == _subUid) return;
    _sub?.cancel();
    _subUid = uid;
    _heard = false;
    _cache = null;
    _sub = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: ChatService.dbUrl)
        .ref('presence/$uid')
        .onValue
        .listen((e) {
      _cache = e.snapshot.value;
      _heard = true;
    }, onError: (Object e) {
      // Rules not published yet, or offline: no check, never a wait.
      debugPrint('presence watch: $e');
      _heard = true;
      _cache = null;
    });
  }

  /// Starts listening as soon as a player is signed in (called on start
  /// and from the hero list), so the answer is there before a tap.
  void warmUp() => _watch();

  /// Minutes since another phone last played [slot], or null when no other
  /// phone has it now (or the check cannot be made). Waits at most about a
  /// second, only the first time.
  Future<int?> otherPhone(int slot) async {
    _watch();
    if (_subUid == null) return null;
    for (var i = 0; i < 10 && !_heard; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final all = _cache;
    // Keys 0-2 may come back as a list.
    final v = all is Map ? all['$slot'] : (all is List && slot < all.length ? all[slot] : null);
    if (v is! Map) return null;
    final dev = v['device'], at = v['at'];
    if (dev is! String || at is! num || dev == _device) return null;
    final ago = GameClock.nowMs() - at.toInt();
    if (ago > stale.inMilliseconds) return null;
    return math.max(0, ago ~/ 60000);
  }

  /// This phone plays [slot] now: marks it (in the background, never
  /// holding the player up), and keeps the mark fresh.
  void claim(int slot) {
    release();
    if (lostSlot.value == slot) lostSlot.value = null;
    final ref = _ref(slot);
    if (ref == null) return;
    _slot = slot;
    ref
        .set({'device': _device, 'at': ServerValue.timestamp})
        .timeout(const Duration(seconds: 10))
        .catchError((Object e) => debugPrint('presence claim: $e'));
    _timer = Timer.periodic(beat, (_) => _beat(slot));
  }

  Future<void> _beat(int slot) async {
    final ref = _ref(slot);
    if (ref == null || _slot != slot) return;
    try {
      // The listener's copy is current; a one-off read only without it.
      final all = _heard ? _cache : null;
      final v = _heard
          ? (all is Map ? all['$slot'] : (all is List && slot < all.length ? all[slot] : null))
          : (await ref.get().timeout(const Duration(seconds: 6))).value;
      if (v is Map && v['device'] is String && v['device'] != _device) {
        // Another phone opened this hero: stop writing it from here.
        _timer?.cancel();
        _timer = null;
        _slot = null;
        lostSlot.value = slot;
        return;
      }
      await ref.set({'device': _device, 'at': ServerValue.timestamp});
    } catch (e) {
      debugPrint('presence beat: $e');
    }
  }

  /// The account is being deleted: every mark of it goes.
  Future<void> forget() async {
    _timer?.cancel();
    _timer = null;
    _slot = null;
    final uid = CloudSave.instance.user?.uid;
    if (!CloudSave.instance.available || uid == null) return;
    try {
      await FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: ChatService.dbUrl)
          .ref('presence/$uid')
          .remove()
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('presence forget: $e');
    }
  }

  /// Back on the hero list: the mark goes (if it is still this phone's).
  void release() {
    _timer?.cancel();
    _timer = null;
    final slot = _slot;
    _slot = null;
    if (slot == null) return;
    final ref = _ref(slot);
    if (ref == null) return;
    () async {
      try {
        final v = (await ref.get()).value;
        if (v is Map && v['device'] == _device) await ref.remove();
      } catch (e) {
        debugPrint('presence release: $e');
      }
    }();
  }
}

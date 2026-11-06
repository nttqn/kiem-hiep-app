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

  /// Minutes since another phone last played [slot], or null when no other
  /// phone has it now (or the check cannot be made).
  Future<int?> otherPhone(int slot) async {
    final ref = _ref(slot);
    if (ref == null) return null;
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 6));
      final v = snap.value;
      if (v is! Map) return null;
      final dev = v['device'], at = v['at'];
      if (dev is! String || at is! num || dev == _device) return null;
      final ago = GameClock.nowMs() - at.toInt();
      if (ago > stale.inMilliseconds) return null;
      return math.max(0, ago ~/ 60000);
    } catch (e) {
      debugPrint('presence check: $e');
      return null;
    }
  }

  /// This phone plays [slot] now: marks it, and keeps the mark fresh.
  Future<void> claim(int slot) async {
    release();
    if (lostSlot.value == slot) lostSlot.value = null;
    final ref = _ref(slot);
    if (ref == null) return;
    _slot = slot;
    try {
      await ref.set({'device': _device, 'at': ServerValue.timestamp}).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('presence claim: $e');
    }
    _timer = Timer.periodic(beat, (_) => _beat(slot));
  }

  Future<void> _beat(int slot) async {
    final ref = _ref(slot);
    if (ref == null || _slot != slot) return;
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 6));
      final v = snap.value;
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

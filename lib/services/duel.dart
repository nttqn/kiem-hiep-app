import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../core/duel.dart';
import 'cloud.dart';

/// Tỷ võ rooms over Firebase Realtime Database (trial build):
///
/// * `duels/{code}`: `h` host uid, `hi` host's [DuelInfo], `at` created,
///   then `g` and `gi` for the guest who joins with the code.
/// * `duels/{code}/s`: the host's latest state, about [duelSendHz] a second.
/// * `duels/{code}/i`: the guest's latest input.
/// * `duels/{code}/q`: 'h' or 'g', whoever walked out.
///
/// The host's connection dropping removes the room.
class DuelService {
  DuelService._();
  static final DuelService instance = DuelService._();

  static const _url = 'https://kiem-hiep-4da54-default-rtdb.asia-southeast1.firebasedatabase.app';

  CloudSave get _cloud => CloudSave.instance;
  bool get available => _cloud.available;
  String? get uid => _cloud.user?.uid;

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _url);
  DatabaseReference _room(String code) => _db.ref('duels/$code');

  /// Opens a room as [me]; returns its code.
  Future<String> create(DuelInfo me) async {
    final db = _db;
    db.goOnline();
    final r = math.Random();
    for (var tries = 0; tries < 5; tries++) {
      final code = duelCode(r);
      final ref = _room(code);
      final old = await ref.get().timeout(const Duration(seconds: 10));
      if (old.exists) continue;
      await ref.onDisconnect().remove();
      await ref.set({'h': me.uid, 'hi': me.toJson(), 'at': ServerValue.timestamp}).timeout(const Duration(seconds: 10));
      return code;
    }
    throw StateError('no free code');
  }

  /// The guest's hero once someone joins [code].
  Stream<DuelInfo> guestOf(String code) => _room(code).child('gi').onValue.where((e) => e.snapshot.value is Map).map(
        (e) => DuelInfo.fromJson(e.snapshot.value as Map));

  /// Joins [code] as [me]: the host's hero, or why not.
  Future<(DuelInfo?, String?)> join(String code, DuelInfo me) async {
    try {
      _db.goOnline();
      final snap = await _room(code).get().timeout(const Duration(seconds: 10));
      if (!snap.exists || snap.value is! Map) return (null, 'Không tìm thấy phòng $code');
      final m = snap.value as Map;
      if (m['g'] != null) return (null, 'Phòng đã đủ người');
      if (m['h'] == me.uid) return (null, 'Không thể tự đấu với chính mình');
      await _room(code).update({'g': me.uid, 'gi': me.toJson()}).timeout(const Duration(seconds: 10));
      await _room(code).child('q').onDisconnect().set('g');
      return (DuelInfo.fromJson(m['hi'] as Map), null);
    } catch (e) {
      debugPrint('duel join failed: $e');
      return (null, 'Không vào được phòng, kiểm tra mạng rồi thử lại');
    }
  }

  void sendState(String code, Map<String, Object> s) => _room(code).child('s').set(s).catchError((Object e) {
        debugPrint('duel send failed: $e');
      });

  void sendInput(String code, DuelInput i) => _room(code).child('i').set(i.toJson()).catchError((Object e) {
        debugPrint('duel input failed: $e');
      });

  Stream<Map> states(String code) =>
      _room(code).child('s').onValue.where((e) => e.snapshot.value is Map).map((e) => e.snapshot.value as Map);

  Stream<DuelInput> inputs(String code) => _room(code)
      .child('i')
      .onValue
      .where((e) => e.snapshot.value is Map)
      .map((e) => DuelInput.fromJson(e.snapshot.value as Map));

  /// 'h' or 'g' once a side walks out. (Only this child is watched: the
  /// whole room would download every state twice.)
  Stream<String> quits(String code) =>
      _room(code).child('q').onValue.map((e) => '${e.snapshot.value ?? ''}').where((q) => q.isNotEmpty);

  Future<void> leave(String code, {required bool host}) async {
    try {
      await _room(code).child('q').set(host ? 'h' : 'g').timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// The host clears the room once both have seen the end.
  Future<void> close(String code) async {
    try {
      await Future<void>.delayed(const Duration(seconds: 3));
      await _room(code).remove().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

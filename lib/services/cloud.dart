import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/hero.dart';
import 'analytics.dart';
import 'leaderboard.dart';
import 'save.dart';
import 'sync_plan.dart';

/// Online save: the three slots mirrored to Firestore under the signed-in
/// player (`users/{uid}/slots/{0..2}`), so reinstalling or changing phone
/// (Android or iPhone) keeps progress. A cloud copy about to be replaced by
/// one that is behind it (or another character) is first kept in
/// `users/{uid}/backups/{slot}`.
///
/// Everything degrades to offline play: no Firebase config, no network or
/// a failed sign-in just leaves [available] or [user] unset.
class CloudSave extends ChangeNotifier {
  CloudSave._();
  static final CloudSave instance = CloudSave._();

  bool available = false;
  bool busy = false;
  User? user;
  String? message;
  DateTime? lastSync;

  /// Slots whose newer cloud copy waits for the player to choose.
  final List<int> conflicts = [];
  final Map<int, SlotInfo> cloudSlots = {};
  final Map<int, SlotInfo> cloudBackups = {};

  bool _googleReady = false;
  Timer? _debounce;
  final Set<int> _dirty = {};
  AppLifecycleListener? _lifecycle;

  /// From ios/Runner/GoogleService-Info.plist (Firebase app for iOS).
  static const _iosClientId =
      '567144551092-ovrpcjdcms2ab9kncugbkp3semi0v73s.apps.googleusercontent.com';
  static const _iosOptions = FirebaseOptions(
    apiKey: 'AIzaSyDRySooHWft6bOtj5b3J4cO5hpgySWpd1U',
    appId: '1:567144551092:ios:070c1348ea16a330a9bde1',
    messagingSenderId: '567144551092',
    projectId: 'kiem-hiep-4da54',
    storageBucket: 'kiem-hiep-4da54.firebasestorage.app',
    iosBundleId: 'com.trungsmail.kiemhiep',
    iosClientId: _iosClientId,
  );

  bool get isApplePlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      // Reads google-services.json / GoogleService-Info.plist; throws when
      // the game was built without them.
      // Android reads google-services.json through Gradle; on iOS the
      // options are given here, so the plist need not be in the bundle.
      await Firebase.initializeApp(options: isApplePlatform ? _iosOptions : null)
          .timeout(const Duration(seconds: 8));
      available = true;
    } catch (e) {
      debugPrint('cloud save off: $e');
      return;
    }
    user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
    _lifecycle ??= AppLifecycleListener(onPause: flush, onDetach: flush);
    notifyListeners();
    if (user != null) unawaited(sync());
  }

  // ------------------------------------------------------------ sign-in

  Future<bool> signInGoogle() => _signIn(() async {
        try {
          final g = GoogleSignIn.instance;
          if (!_googleReady) {
            await g.initialize(clientId: isApplePlatform ? _iosClientId : null);
            _googleReady = true;
          }
          final account = await g.authenticate();
          final idToken = account.authentication.idToken;
          if (idToken == null) throw StateError('no id token');
          await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled || isApplePlatform) rethrow;
          // Credential Manager fails on some Android phones (old Play
          // services, OEM builds): sign in through a browser page instead.
          _logFail('gsi_${e.code.name}', e.description);
          await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
        }
      });

  void _logFail(String code, Object? detail) {
    final d = '$detail';
    Analytics.instance.log('signin_fail', {
      'code': code,
      'detail': d.length > 90 ? d.substring(0, 90) : d,
    });
  }

  Future<bool> signInApple() => _signIn(() async {
        final apple = AppleAuthProvider()..addScope('email');
        await FirebaseAuth.instance.signInWithProvider(apple);
      });

  Future<bool> _signIn(Future<void> Function() how) async {
    if (!available || busy) return false;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await how();
      user = FirebaseAuth.instance.currentUser;
      busy = false;
      await sync();
      return user != null;
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) _logFail('gsi_${e.code.name}', e.description);
      message = e.code == GoogleSignInExceptionCode.canceled ? null : 'Đăng nhập Google thất bại (${e.code.name})';
    } on FirebaseAuthException catch (e) {
      _logFail('fb_${e.code}', e.message);
      message = e.code == 'web-context-canceled' || e.code == 'canceled'
          ? null
          : 'Không đăng nhập được (${e.code}), thử lại sau';
    } catch (e) {
      debugPrint('sign-in failed: $e');
      _logFail('other', e);
      message = 'Không đăng nhập được, thử lại sau';
    }
    busy = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    await flush();
    try {
      await FirebaseAuth.instance.signOut();
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    user = null;
    conflicts.clear();
    cloudSlots.clear();
    cloudBackups.clear();
    lastSync = null;
    notifyListeners();
  }

  /// Shown in the UI: email, else the provider's display name.
  String get who => user?.email ?? user?.displayName ?? 'Đã đăng nhập';

  // ------------------------------------------------------------ data

  CollectionReference<Map<String, dynamic>> get _slots =>
      FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('slots');

  CollectionReference<Map<String, dynamic>> get _backups =>
      FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('backups');

  static SlotInfo _info(HeroData h) => SlotInfo.ofHero(h);

  static Map<String, dynamic> _doc(SlotInfo info) => {
        'data': info.data,
        'savedAt': info.savedAt,
        'name': info.name,
        'level': info.level,
        'sect': info.sect,
        'playSeconds': info.playSeconds,
        'rebirths': info.rebirths,
        'updated': FieldValue.serverTimestamp(),
      };

  /// Reads a slot or backup document, or null when it is not one.
  static (int, SlotInfo)? _read(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final i = int.tryParse(d.id);
    final m = d.data();
    if (i == null || i < 0 || i >= slotCount || m['data'] is! String) return null;
    return (
      i,
      SlotInfo(
        savedAt: (m['savedAt'] as num?)?.toInt() ?? 0,
        data: m['data'] as String,
        name: m['name'] as String? ?? '',
        level: (m['level'] as num?)?.toInt() ?? 0,
        sect: m['sect'] as String? ?? '',
        playSeconds: (m['playSeconds'] as num?)?.toDouble() ?? 0,
        rebirths: (m['rebirths'] as num?)?.toInt() ?? 0,
      )
    );
  }

  /// The cloud backup of [slot] as a hero, if there is a readable one.
  HeroData? cloudBackupHero(int slot) {
    final b = cloudBackups[slot];
    if (b == null) return null;
    try {
      return HeroData.fromJson(jsonDecode(b.data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Pulls the cloud copies, uploads what is newer here, restores slots
  /// that are empty here, and lists the rest in [conflicts].
  Future<void> sync() async {
    if (!available || user == null || busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      final snap = await _slots.get().timeout(const Duration(seconds: 15));
      cloudSlots.clear();
      for (final d in snap.docs) {
        final r = _read(d);
        if (r != null) cloudSlots[r.$1] = r.$2;
      }
      cloudBackups.clear();
      try {
        final bak = await _backups.get().timeout(const Duration(seconds: 15));
        for (final d in bak.docs) {
          final r = _read(d);
          if (r != null) cloudBackups[r.$1] = r.$2;
        }
      } catch (e) {
        debugPrint('backups unreadable: $e');
      }
      final save = SaveService.instance;
      final local = [for (final h in save.slots) h == null ? null : _info(h)];
      final plan = planSync(local, [for (var i = 0; i < slotCount; i++) cloudSlots[i]]);
      conflicts.clear();
      for (var i = 0; i < slotCount; i++) {
        switch (plan[i]) {
          case SlotAction.upload:
            await _upload(i, save.slots[i]!);
          case SlotAction.restore:
            _apply(i, cloudSlots[i]!);
          case SlotAction.ask:
            conflicts.add(i);
          case SlotAction.none:
            break;
        }
      }
      lastSync = DateTime.now();
    } catch (e) {
      debugPrint('sync failed: $e');
      message = 'Không kết nối được máy chủ, sẽ thử lại sau';
    }
    busy = false;
    notifyListeners();
  }

  /// The player picked the cloud copy of [slot].
  Future<void> takeCloud(int slot) async {
    final c = cloudSlots[slot];
    if (c != null) _apply(slot, c);
    conflicts.remove(slot);
    notifyListeners();
  }

  /// The player kept both: the cloud copy of [slot] goes into the empty
  /// device slot [into] (and up to the cloud there).
  Future<void> takeCloudInto(int slot, int into) async {
    final c = cloudSlots[slot];
    if (c == null || into < 0 || SaveService.instance.slots[into] != null) return;
    _apply(into, c);
    final h = SaveService.instance.slots[into];
    if (h != null) {
      try {
        await _upload(into, h);
      } catch (e) {
        queueUpload(into);
      }
    }
  }

  /// The player kept this device's copy of [slot].
  Future<void> keepLocal(int slot) async {
    conflicts.remove(slot);
    final h = SaveService.instance.slots[slot];
    if (h != null) {
      // Make it the newest so other devices see it as such.
      h.savedAt = DateTime.now().millisecondsSinceEpoch;
      await SaveService.instance.writeSlot(slot);
      await _upload(slot, h);
    }
    notifyListeners();
  }

  void _apply(int slot, SlotInfo c) {
    try {
      final h = HeroData.fromJson(jsonDecode(c.data) as Map<String, dynamic>);
      SaveService.instance.replaceSlot(slot, h);
    } catch (e) {
      debugPrint('cloud slot $slot unreadable: $e');
    }
  }

  Future<void> _upload(int slot, HeroData h) async {
    final info = _info(h);
    final old = cloudSlots[slot];
    if (old == null || old.data != info.data) {
      if (old != null && wouldLose(old, info)) await _stash(slot, old);
      await _slots.doc('$slot').set(_doc(info));
      cloudSlots[slot] = info;
    }
    await Leaderboard.instance.submit(slot, h);
  }

  /// Keeps [old] as the cloud backup of [slot] if it got further than the
  /// backup already there.
  Future<void> _stash(int slot, SlotInfo old) async {
    if (!shouldStash(old, cloudBackups[slot])) return;
    await _backups.doc('$slot').set(_doc(old));
    cloudBackups[slot] = old;
  }

  /// After a backup was restored into [slot] on this device: push it now,
  /// overriding any pending choice for that slot.
  Future<void> pushRestored(int slot) async {
    conflicts.remove(slot);
    final h = SaveService.instance.slots[slot];
    if (!available || user == null || h == null) {
      notifyListeners();
      return;
    }
    try {
      await _upload(slot, h);
      lastSync = DateTime.now();
    } catch (e) {
      debugPrint('restore upload failed: $e');
      queueUpload(slot);
    }
    notifyListeners();
  }

  /// Called after every local save; uploads at most every five minutes (and
  /// on app pause), which keeps a busy day inside Firestore's free writes.
  void queueUpload(int slot) {
    if (!available || user == null || conflicts.contains(slot)) return;
    _dirty.add(slot);
    _debounce ??= Timer(const Duration(minutes: 5), flush);
  }

  /// Uploads pending slots now (also on app pause).
  Future<void> flush() async {
    _debounce?.cancel();
    _debounce = null;
    if (!available || user == null || _dirty.isEmpty) return;
    final slots = List<int>.of(_dirty);
    _dirty.clear();
    try {
      for (final i in slots) {
        final h = SaveService.instance.slots[i];
        if (h != null) await _upload(i, h);
      }
      lastSync = DateTime.now();
      notifyListeners();
    } catch (e) {
      // Firestore queues writes offline; anything else retries next save.
      _dirty.addAll(slots);
      debugPrint('upload failed: $e');
    }
  }

  /// Deletes every cloud save and the account itself (Play Store policy:
  /// players must be able to do this in the app). Saves on this device
  /// stay. Firebase may ask the player to confirm their sign-in first.
  Future<bool> deleteAccount() async {
    final u = user;
    if (!available || u == null || busy) return false;
    busy = true;
    message = null;
    _debounce?.cancel();
    _debounce = null;
    _dirty.clear();
    notifyListeners();
    try {
      await Leaderboard.instance.withdraw();
      for (final col in [_slots, _backups]) {
        final snap = await col.get();
        for (final d in snap.docs) {
          await d.reference.delete();
        }
      }
      try {
        await u.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;
        // Old sign-in: confirm it, then try again.
        if (u.providerData.any((p) => p.providerId == 'apple.com')) {
          await u.reauthenticateWithProvider(AppleAuthProvider());
        } else {
          final g = GoogleSignIn.instance;
          if (!_googleReady) {
            await g.initialize(clientId: isApplePlatform ? _iosClientId : null);
            _googleReady = true;
          }
          final account = await g.authenticate();
          await u.reauthenticateWithCredential(
              GoogleAuthProvider.credential(idToken: account.authentication.idToken));
        }
        await u.delete();
      }
      if (_googleReady) await GoogleSignIn.instance.signOut();
      user = null;
      cloudSlots.clear();
      cloudBackups.clear();
      conflicts.clear();
      lastSync = null;
      message = 'Đã xóa tài khoản và dữ liệu trên mây.';
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('delete account failed: $e');
      message = 'Chưa xóa được tài khoản, thử lại sau.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteSlot(int slot) async {
    _dirty.remove(slot);
    final old = cloudSlots.remove(slot);
    if (!available || user == null) return;
    try {
      if (old != null) await _stash(slot, old);
      await _slots.doc('$slot').delete();
      await Leaderboard.instance.withdraw(slot: slot);
    } catch (_) {}
  }
}

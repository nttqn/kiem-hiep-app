import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/clock.dart';
import '../core/hero.dart';
import '../core/premium.dart';
import 'analytics.dart';
import 'chat.dart';
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

  /// Signed in to an account other than the one this device's heroes
  /// belong to: nothing syncs until the player picks [useThisAccount] or
  /// [bringHeroesHere].
  bool switchPending = false;

  /// Something waits for the player's choice (a badge on the cloud button).
  bool get needsChoice => switchPending || conflicts.isNotEmpty;
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
    if (kIsWeb) {
      _clockDone();
      return;
    }
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
      _clockDone();
      return;
    }
    unawaited(syncClock());
    user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
    _lifecycle ??= AppLifecycleListener(onPause: flush, onDetach: flush, onResume: syncClock);
    notifyListeners();
    if (user != null) unawaited(sync());
  }

  // ------------------------------------------------------------ clock

  final Completer<void> _clockReady = Completer<void>();

  /// Done once the first ask for the server's time has an answer (or has
  /// failed): opening a hero waits for it a moment, so a phone set ahead
  /// gets no early day.
  Future<void> get clockReady => _clockReady.future;

  void _clockDone() {
    if (!_clockReady.isCompleted) _clockReady.complete();
  }

  bool _clockBusy = false;

  /// Asks Firebase for the server's time ([GameClock]); also each time the
  /// app comes back.
  Future<void> syncClock() async {
    if (!available || _clockBusy) {
      _clockDone();
      return;
    }
    _clockBusy = true;
    final db = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: ChatService.dbUrl);
    try {
      db.goOnline();
      await db.ref('.info/connected').onValue.firstWhere((e) => e.snapshot.value == true).timeout(
            const Duration(seconds: 8),
          );
      final off = await db.ref('.info/serverTimeOffset').once().timeout(const Duration(seconds: 5));
      final ms = (off.snapshot.value as num?)?.toInt() ?? 0;
      GameClock.synced(DateTime.now().millisecondsSinceEpoch + ms);
    } catch (e) {
      debugPrint('server time unknown: $e');
    } finally {
      // The chat keeps its own connection while open.
      if (!ChatService.instance.isOpen) db.goOffline();
      _clockBusy = false;
      _clockDone();
    }
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
    switchPending = false;
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

  CollectionReference<Map<String, dynamic>> get _grants =>
      FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('grants');

  /// Lines about purchases given back after the last sync, for the town.
  final List<String> restoredGrants = [];

  /// Writes a purchase to this account's ledger (no-op when signed out).
  Future<void> recordGrant(String id, PaidGrant g) async {
    if (!available || user == null) return;
    try {
      await _grants.doc(id).set(g.toJson()).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('grant record failed: $e');
    }
  }

  /// Gives back to the heroes on this device any ledger purchase their save
  /// lost (an older copy from another phone came over it).
  Future<void> _reapplyGrants() async {
    final save = SaveService.instance;
    try {
      final snap = await _grants.get().timeout(const Duration(seconds: 10));
      final grants = [for (final d in snap.docs) ?PaidGrant.fromJson(d.data())];
      for (var i = 0; i < slotCount; i++) {
        final h = save.slots[i];
        if (h == null) continue;
        var changed = false;
        for (final g in grants) {
          if (!g.fits(h, i)) continue;
          final line = h.reapplyGrant(g);
          if (line != null) {
            restoredGrants.add('${h.name}: $line');
            changed = true;
          }
        }
        if (changed) {
          await save.writeSlot(i);
          await _upload(i, h);
        }
      }
    } catch (e) {
      debugPrint('grants unreadable: $e');
    }
  }

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
        'oldNames': info.oldNames,
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
        oldNames: [for (final v in m['oldNames'] as List? ?? const []) '$v'],
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
    final save = SaveService.instance;
    final uid = user!.uid;
    if (save.owner != uid) {
      // Another account's heroes are here: ask before anything moves.
      if (save.owner != null && save.hasHeroes) {
        switchPending = true;
        notifyListeners();
        return;
      }
      // Nobody else's heroes (or none known, from before owners were kept):
      // this account takes the device, with what it left here before.
      if (save.owner != null) await save.archiveAndClear(save.owner);
      await save.restoreArchive(uid);
      await save.setOwner(uid, who);
    }
    switchPending = false;
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
      await _reapplyGrants();
      lastSync = DateTime.now();
    } catch (e) {
      debugPrint('sync failed: $e');
      message = 'Không kết nối được máy chủ, sẽ thử lại sau';
    }
    busy = false;
    notifyListeners();
  }

  /// The player chose to play this account here: the other account's
  /// heroes are put aside on the device (they are also in that account's
  /// cloud) and come back when it signs in again; this account's own
  /// heroes come down from its cloud.
  Future<void> useThisAccount() async {
    final u = user;
    if (u == null) return;
    final save = SaveService.instance;
    await save.archiveAndClear(save.owner);
    await save.restoreArchive(u.uid);
    await save.setOwner(u.uid, who);
    switchPending = false;
    _dirty.clear();
    notifyListeners();
    await sync();
  }

  /// The player chose to move the heroes on this device into this account.
  Future<void> bringHeroesHere() async {
    final u = user;
    if (u == null) return;
    await SaveService.instance.setOwner(u.uid, who);
    switchPending = false;
    notifyListeners();
    await sync();
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
      h.savedAt = GameClock.nowMs();
      await SaveService.instance.writeSlot(slot);
      await _upload(slot, h);
    }
    notifyListeners();
  }

  void _apply(int slot, SlotInfo c) {
    try {
      final h = HeroData.fromJson(jsonDecode(c.data) as Map<String, dynamic>);
      // The same hero from another phone: keep what was paid for here.
      final old = SaveService.instance.slots[slot];
      if (old != null && old.seed != 0 && old.seed == h.seed) h.mergePaid(old);
      SaveService.instance.replaceSlot(slot, h);
    } catch (e) {
      debugPrint('cloud slot $slot unreadable: $e');
    }
  }

  Future<void> _upload(int slot, HeroData h) async {
    // Never into an account these heroes do not belong to.
    if (SaveService.instance.owner != user?.uid) return;
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

  /// Deletes this account's cloud saves, backups and leaderboard rows, but
  /// not the account (for one that got another account's heroes), then
  /// signs out.
  Future<bool> wipeCloudSaves() async {
    if (!available || user == null || busy) return false;
    busy = true;
    message = null;
    _debounce?.cancel();
    _debounce = null;
    _dirty.clear();
    notifyListeners();
    try {
      await Leaderboard.instance.withdraw();
      for (final col in [_slots, _backups]) {
        final snap = await col.get().timeout(const Duration(seconds: 15));
        for (final d in snap.docs) {
          await d.reference.delete();
        }
      }
      cloudSlots.clear();
      cloudBackups.clear();
      conflicts.clear();
      busy = false;
      // The heroes on this device belong to no account now; signing out
      // keeps them from going straight back up.
      await SaveService.instance.setOwner(null, '');
      await signOut();
      message = 'Đã xóa bản lưu trên mây và đăng xuất. Nhân vật trên máy vẫn còn.';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('wipe failed: $e');
      busy = false;
      message = 'Chưa xóa được bản lưu trên mây, thử lại sau.';
      notifyListeners();
      return false;
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
      switchPending = false;
      lastSync = null;
      // The heroes left here belong to no account now.
      await SaveService.instance.setOwner(null, '');
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
    if (!available || user == null || SaveService.instance.owner != user!.uid) return;
    try {
      if (old != null) await _stash(slot, old);
      await _slots.doc('$slot').delete();
      await Leaderboard.instance.withdraw(slot: slot);
    } catch (_) {}
  }
}

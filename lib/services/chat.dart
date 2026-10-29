import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/chat.dart';
import '../core/hero.dart';
import 'cloud.dart';

/// Kênh Thế Giới over Firebase Realtime Database (billed by download, not
/// per message read, so a hundred lines per open stays cheap):
///
/// * `chat/msgs/{pushId}`: the messages; the newest [chatShown] are shown.
/// * `chat/last/{uid}`: when that player last sent; the rules refuse a new
///   message within [chatCooldown] of it, by server time.
/// * `chat/bans/{uid}`: set by hand in the Firebase console to mute someone.
/// * `chat/reports/{msgId}/{uid}`: reports, read in the console.
///
/// The connection is only open while the chat screen is.
class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const _url = 'https://kiem-hiep-4da54-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Shown oldest first.
  final List<ChatMsg> messages = [];
  bool loading = false;
  String? error;
  bool banned = false;

  /// When this player last sent, server ms.
  int? lastSent;
  int _offset = 0;

  final Set<String> blocked = {};
  final Set<String> reported = {};
  bool rulesAccepted = false;

  /// Messages to show instead of Firebase (dev build screenshots).
  List<ChatMsg>? debugMessages;

  final List<StreamSubscription<DatabaseEvent>> _subs = [];
  int _opens = 0;

  CloudSave get _cloud => CloudSave.instance;
  bool get available => debugMessages != null || _cloud.available;
  bool get canSend => debugMessages != null || _cloud.user != null;
  String? get myUid => debugMessages != null ? 'me' : _cloud.user?.uid;

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _url);

  /// Server time now, as best known.
  int get now => DateTime.now().millisecondsSinceEpoch + _offset;

  Duration get wait => chatWait(lastSent, now);

  /// Messages this player wants to see: not blocked, not reported.
  List<ChatMsg> get visible =>
      [for (final m in messages) if (!blocked.contains(m.uid) && !reported.contains(m.id)) m];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      blocked.addAll(prefs.getStringList('chat_blocked') ?? const []);
      reported.addAll(prefs.getStringList('chat_reported') ?? const []);
      rulesAccepted = prefs.getBool('chat_rules') ?? false;
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('chat_blocked', blocked.toList());
      // Message ids only matter while the message can still be shown.
      await prefs.setStringList('chat_reported', reported.take(300).toList());
      await prefs.setBool('chat_rules', rulesAccepted);
    } catch (_) {}
  }

  Future<void> acceptRules() async {
    rulesAccepted = true;
    notifyListeners();
    await _savePrefs();
  }

  /// Starts listening (the chat screen opened).
  Future<void> open() async {
    _opens++;
    if (_opens > 1) return;
    final dbg = debugMessages;
    if (dbg != null) {
      messages
        ..clear()
        ..addAll(dbg);
      notifyListeners();
      return;
    }
    if (!_cloud.available) return;
    error = null;
    loading = true;
    messages.clear();
    notifyListeners();
    try {
      final db = _db;
      db.goOnline();
      final q = db.ref('chat/msgs').limitToLast(chatShown);
      _subs.add(q.onChildAdded.listen((e) {
        final m = ChatMsg.fromMap(e.snapshot.key ?? '', e.snapshot.value);
        if (m == null) return;
        // Push ids sort by time, so a late arrival goes in its place.
        var i = messages.length;
        while (i > 0 && messages[i - 1].id.compareTo(m.id) > 0) {
          i--;
        }
        messages.insert(i, m);
        loading = false;
        notifyListeners();
      }, onError: _failed));
      _subs.add(q.onChildRemoved.listen((e) {
        messages.removeWhere((m) => m.id == e.snapshot.key);
        notifyListeners();
      }, onError: _failed));
      // An empty channel sends no child event; this ends the spinner then.
      unawaited(q.get().timeout(const Duration(seconds: 15)).then((_) {
        loading = false;
        notifyListeners();
      }, onError: _failed));
      final off = await db.ref('.info/serverTimeOffset').once().timeout(const Duration(seconds: 10));
      _offset = (off.snapshot.value as num?)?.toInt() ?? 0;
      await _readMine();
    } catch (e) {
      _failed(e);
    }
  }

  void _failed(Object e) {
    debugPrint('chat failed: $e');
    if (_opens == 0) return;
    loading = false;
    error = 'Không tải được kênh chat, thử lại sau.';
    notifyListeners();
  }

  /// This player's last send and mute, for the countdown.
  Future<void> _readMine() async {
    final uid = myUid;
    if (uid == null || debugMessages != null) return;
    try {
      final db = _db;
      final last = await db.ref('chat/last/$uid').get().timeout(const Duration(seconds: 10));
      lastSent = (last.value as num?)?.toInt();
      final ban = await db.ref('chat/bans/$uid').get().timeout(const Duration(seconds: 10));
      banned = ban.exists;
      notifyListeners();
    } catch (e) {
      debugPrint('chat own state failed: $e');
    }
  }

  /// Stops listening (the chat screen closed).
  void close() {
    if (_opens == 0) return;
    _opens--;
    if (_opens > 0) return;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    if (debugMessages == null && _cloud.available) _db.goOffline();
  }

  /// Sends [raw] as [h]; null when sent, else why not.
  Future<String?> send(HeroData h, String raw) async {
    final text = chatClean(raw);
    if (text.isEmpty) return 'Chưa nhập gì';
    if (banned) return 'Bạn đã bị cấm chat';
    final w = wait;
    if (w > Duration.zero) return 'Gửi lại sau ${chatWaitLabel(w)}';
    final uid = myUid;
    if (uid == null) return 'Đăng nhập để chat';
    final name = chatCensor(h.name.length > 24 ? h.name.substring(0, 24) : h.name);
    if (debugMessages != null) {
      messages.add(ChatMsg(
        id: 'z${messages.length}',
        uid: uid,
        name: name,
        hanh: h.hanh.index,
        level: h.level,
        rebirths: h.rebirths,
        text: text,
        at: now,
      ));
      lastSent = now;
      notifyListeners();
      return null;
    }
    final db = _db;
    final key = db.ref('chat/msgs').push().key!;
    try {
      // One write, so the rules see the message and the new send time
      // together.
      await db.ref().update({
        'chat/msgs/$key': {
          'uid': uid,
          'name': name,
          'hanh': h.hanh.index,
          'level': h.level,
          'rebirths': h.rebirths,
          'text': text,
          'at': ServerValue.timestamp,
        },
        'chat/last/$uid': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 10));
      lastSent = now;
      notifyListeners();
      unawaited(_sweep());
      return null;
    } on TimeoutException {
      return 'Mạng chậm, thử lại sau';
    } catch (e) {
      debugPrint('chat send failed: $e');
      // Refused: muted, or the cooldown by server time.
      await _readMine();
      if (banned) return 'Bạn đã bị cấm chat';
      if (wait > Duration.zero) return 'Gửi lại sau ${chatWaitLabel(wait)}';
      return 'Không gửi được, thử lại sau';
    }
  }

  /// Deletes a few messages past [chatKeep], so the channel never grows
  /// without end. Every sender does a little of it.
  Future<void> _sweep() async {
    try {
      final old = await _db
          .ref('chat/msgs')
          .orderByChild('at')
          .endAt(now - chatKeep.inMilliseconds)
          .limitToFirst(5)
          .get()
          .timeout(const Duration(seconds: 10));
      for (final c in old.children) {
        await c.ref.remove();
      }
    } catch (e) {
      debugPrint('chat sweep failed: $e');
    }
  }

  /// Reports [m] to the moderators and hides it here.
  Future<void> report(ChatMsg m) async {
    reported.add(m.id);
    notifyListeners();
    await _savePrefs();
    final uid = myUid;
    if (uid == null || debugMessages != null) return;
    try {
      await _db.ref('chat/reports/${m.id}/$uid').set(true).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('chat report failed: $e');
    }
  }

  Future<void> block(String uid) async {
    blocked.add(uid);
    notifyListeners();
    await _savePrefs();
  }

  Future<void> unblockAll() async {
    blocked.clear();
    notifyListeners();
    await _savePrefs();
  }
}

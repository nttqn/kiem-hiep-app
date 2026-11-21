import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/guild.dart';
import '../core/guild_war.dart';
import '../core/hero.dart';
import '../core/mentor.dart' show mentorMaxDisciples;
import 'leaderboard.dart';
import 'save.dart';

/// A bang as read from `guilds/{id}`.
class GuildInfo {
  GuildInfo({
    required this.id,
    required this.name,
    required this.leader,
    this.leaderName = '',
    this.officers = const [],
    this.notice = '',
    this.open = true,
    this.minLv = guildOpenLevel,
    this.pts = 0,
    this.n = 0,
  });

  final String id, name, leader, leaderName, notice;
  final List<String> officers;
  final bool open;
  final int minLv;

  /// Cống hiến of all members and their count, as last written by one of
  /// them (for the list of bangs; a bang's own screen sums its members).
  final int pts, n;

  int get level => guildLevelOf(pts);

  static GuildInfo? fromDoc(String id, Map<String, dynamic>? m) {
    if (m == null) return null;
    try {
      return GuildInfo(
        id: id,
        name: m['name'] as String,
        leader: m['leader'] as String,
        leaderName: m['leaderName'] as String? ?? '',
        officers: [for (final v in m['officers'] as List? ?? const []) '$v'],
        notice: m['notice'] as String? ?? '',
        open: m['open'] as bool? ?? true,
        minLv: (m['minLv'] as num?)?.toInt() ?? guildOpenLevel,
        pts: (m['pts'] as num?)?.toInt() ?? 0,
        n: (m['n'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A member (`guilds/{id}/members/{row}`) or an application (`.../apps/{row}`).
class GuildMember {
  GuildMember({
    required this.row,
    required this.uid,
    required this.name,
    required this.hanh,
    required this.level,
    required this.rebirths,
    required this.power,
    this.role = roleMember,
    this.contrib = 0,
    this.bw = 0,
    this.bd = 0,
    this.ww = 0,
    this.wp = 0,
  });

  final String row, uid, name;
  final int hanh, level, rebirths, power, role, contrib;

  /// Boss Bang week and damage in it.
  final int bw, bd;

  /// Bang chiến week and Chiến công in it (1.16.0; written apart, see
  /// [GuildService.pushWar], so older rules never see them in a row).
  final int ww, wp;

  /// Chiến công that counts in week [week].
  int warIn(int week) => ww == week ? wp : 0;

  static GuildMember? fromDoc(String row, Map<String, dynamic>? m) {
    if (m == null) return null;
    try {
      return GuildMember(
        row: row,
        uid: m['uid'] as String,
        name: m['name'] as String,
        hanh: (m['hanh'] as num).toInt().clamp(0, 4),
        level: (m['level'] as num).toInt(),
        rebirths: (m['rebirths'] as num?)?.toInt() ?? 0,
        power: (m['power'] as num?)?.toInt() ?? 0,
        role: (m['role'] as num?)?.toInt().clamp(0, 2) ?? 0,
        contrib: (m['contrib'] as num?)?.toInt() ?? 0,
        bw: (m['bw'] as num?)?.toInt() ?? 0,
        bd: (m['bd'] as num?)?.toInt() ?? 0,
        ww: (m['ww'] as num?)?.toInt() ?? 0,
        wp: (m['wp'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, Object> toMap() => {
        'uid': uid,
        'name': name,
        'hanh': hanh,
        'level': level,
        'rebirths': rebirths,
        'power': power,
        'role': role,
        'contrib': contrib,
        'bw': bw,
        'bd': bd,
      };

  /// [h] (row [row] of player [uid]) as a member with [role].
  static GuildMember of(String row, String uid, HeroData h, int role) => GuildMember(
        row: row,
        uid: uid,
        name: h.name.length > 24 ? h.name.substring(0, 24) : h.name,
        hanh: h.hanh.index,
        level: h.level,
        rebirths: h.rebirths,
        power: h.power,
        role: role,
        contrib: h.guildContrib,
        bw: h.gBossWeek,
        bd: h.gBossDmg,
      );

  LbEntry toEntry() =>
      LbEntry(id: row, name: name, hanh: hanh, level: level, rebirths: rebirths, power: power, tower: 0);
}

class GuildChat {
  const GuildChat(this.id, this.row, this.name, this.text, this.at);
  final String id, row, name, text;
  final DateTime? at;
}

/// A gift a friend sent (`gifts/{toRow}/in/{fromRow}`).
class FriendGift {
  const FriendGift(this.from, this.name, this.hanh, this.day);
  final String from, name, day;
  final int hanh;
}

/// Bang hội and Hảo hữu over Firestore (1.13.0). Only signed-in players
/// take part; rows are `{uid}_{slot}` as on the boards.
///
/// * `guilds/{id}`: the bang; `guilds/{id}/members|apps|chat/...`.
/// * `guildNames/{name lowercased}`: keeps names unique.
/// * `gifts/{toRow}/in/{fromRow}`: a friend's gift of the day.
class GuildService extends ChangeNotifier {
  GuildService._();
  static final GuildService instance = GuildService._();

  /// In-memory stand-in for Firestore (tests and dev screenshots).
  bool debug = false;
  final Map<String, GuildInfo> _dGuilds = {};
  final Map<String, Map<String, GuildMember>> _dMembers = {};
  final Map<String, Map<String, GuildMember>> _dApps = {};
  final Map<String, List<GuildChat>> _dChat = {};
  final Map<String, Map<String, FriendGift>> _dGifts = {};
  String debugUid = 'me';

  Leaderboard get _lb => Leaderboard.instance;
  bool get available => debug || _lb.available;
  String? get uid => debug ? debugUid : _lb.myUid;

  /// This hero's row, null when not signed in.
  String? get myRow {
    final u = uid;
    final slot = SaveService.instance.active;
    return u == null || slot < 0 ? null : '${u}_$slot';
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _guilds => _db.collection('guilds');
  static const _t = Duration(seconds: 10);

  static String nameKey(String name) => name.trim().toLowerCase();

  /// Why [name] cannot be a bang's name, or null. Its lowercase form is a
  /// document id (guildNames/{key}), which cannot hold "/" nor be "." or
  /// "..", nor start and end with "__" (1.13.1: such a name failed as
  /// "thử lại sau").
  static String? badName(String name) {
    final k = nameKey(name);
    if (k.contains('/')) return 'Tên bang không được có dấu /';
    if (k == '.' || k == '..' || (k.startsWith('__') && k.endsWith('__'))) return 'Tên bang này không dùng được';
    return null;
  }

  /// What a player is told when making a bang failed.
  static String createErrorText(Object e) {
    if (e is FirebaseException) {
      return switch (e.code) {
        'permission-denied' =>
          'Máy chủ không nhận bang này. Thử một tên khác chỉ có chữ, số và khoảng trắng; nếu vẫn bị, hãy báo cho nhà phát triển.',
        'unavailable' || 'deadline-exceeded' => 'Mạng yếu, chưa lập được bang. Thử lại sau.',
        _ => 'Không lập được bang (${e.code}). Thử lại sau.',
      };
    }
    return 'Mạng yếu, chưa lập được bang. Thử lại sau.';
  }

  // ------------------------------------------------------------ reads

  Future<GuildInfo?> guild(String id) async {
    if (debug) return _dGuilds[id];
    final d = await _guilds.doc(id).get().timeout(_t);
    return GuildInfo.fromDoc(d.id, d.data());
  }

  /// Bangs to join: the biggest first.
  Future<List<GuildInfo>> top({int limit = 30}) async {
    if (debug) return (_dGuilds.values.toList()..sort((a, b) => b.pts.compareTo(a.pts))).take(limit).toList();
    final snap = await _guilds.orderBy('pts', descending: true).limit(limit).get().timeout(_t);
    return [for (final d in snap.docs) ?GuildInfo.fromDoc(d.id, d.data())];
  }

  /// The bang called [name], if any.
  Future<GuildInfo?> find(String name) async {
    final key = nameKey(name);
    if (debug) {
      for (final g in _dGuilds.values) {
        if (nameKey(g.name) == key) return g;
      }
      return null;
    }
    final d = await _db.collection('guildNames').doc(key).get().timeout(_t);
    final gid = d.data()?['gid'] as String?;
    return gid == null ? null : guild(gid);
  }

  Future<List<GuildMember>> members(String gid) async {
    if (debug) return [...?_dMembers[gid]?.values];
    final snap = await _guilds.doc(gid).collection('members').limit(60).get().timeout(_t);
    return [for (final d in snap.docs) ?GuildMember.fromDoc(d.id, d.data())];
  }

  Future<List<GuildMember>> apps(String gid) async {
    if (debug) return [...?_dApps[gid]?.values];
    final snap = await _guilds.doc(gid).collection('apps').limit(30).get().timeout(_t);
    return [for (final d in snap.docs) ?GuildMember.fromDoc(d.id, d.data())];
  }

  Future<GuildMember?> member(String gid, String row) async {
    if (debug) return _dMembers[gid]?[row];
    final d = await _guilds.doc(gid).collection('members').doc(row).get().timeout(_t);
    return GuildMember.fromDoc(d.id, d.data());
  }

  /// The bang this hero leads per the server, when its save has none
  /// (1.13.1: played on two devices, the one without the bang on its save
  /// showed "Chưa vào bang" to the Bang chủ).
  Future<(GuildInfo, GuildMember)?> ledByMe() async {
    final u = uid, row = myRow;
    if (u == null || row == null) return null;
    final List<GuildInfo> led;
    if (debug) {
      led = [for (final g in _dGuilds.values) if (g.leader == u) g];
    } else {
      final snap = await _guilds.where('leader', isEqualTo: u).limit(5).get().timeout(_t);
      led = [for (final d in snap.docs) ?GuildInfo.fromDoc(d.id, d.data())];
    }
    for (final g in led) {
      final m = await member(g.id, row);
      if (m != null) return (g, m);
    }
    return null;
  }

  // ------------------------------------------------------------ membership

  /// Makes bang [name] with this hero as Bang chủ; its id, or an error
  /// message (taken name, offline).
  Future<(String?, String?)> create(HeroData h, String name, {String notice = '', bool open = true}) async {
    final u = uid, row = myRow;
    if (u == null || row == null) return (null, 'Cần đăng nhập');
    name = name.trim();
    final bad = badName(name);
    if (bad != null) return (null, bad);
    try {
      if (await find(name) != null) return (null, 'Tên bang đã có người dùng');
    } catch (e) {
      return (null, createErrorText(e));
    }
    final me = GuildMember.of(row, u, h, roleLeader);
    if (debug) {
      final id = 'g${_dGuilds.length + 1}';
      _dGuilds[id] = GuildInfo(id: id, name: name, leader: u, leaderName: h.name, notice: notice, open: open);
      _dMembers[id] = {row: me};
      return (id, null);
    }
    try {
      final g = _guilds.doc();
      final b = _db.batch()
        ..set(_db.collection('guildNames').doc(nameKey(name)), {'gid': g.id, 'uid': u})
        ..set(g, {
          'name': name,
          'leader': u,
          'leaderName': me.name,
          'officers': <String>[],
          'notice': notice,
          'open': open,
          'minLv': guildOpenLevel,
          'pts': 0,
          'n': 1,
          'created': FieldValue.serverTimestamp(),
        })
        ..set(g.collection('members').doc(row), me.toMap());
      await b.commit().timeout(_t);
      return (g.id, null);
    } catch (e) {
      debugPrint('guild create failed: $e');
      return (null, createErrorText(e));
    }
  }

  /// Joins [g] at once when it takes anyone, else applies. True when now
  /// a member.
  Future<bool> join(GuildInfo g, HeroData h) async {
    final u = uid, row = myRow;
    if (u == null || row == null) return false;
    final me = GuildMember.of(row, u, h, roleMember);
    // Already in it (1.13.1): a save from another device, or one older than
    // the joining, has no bang on it; writing the row again as a plain
    // member was refused (a Bang chủ cannot demote themselves).
    if (await member(g.id, row) != null) return true;
    if (g.open && h.level + h.rebirths * 100 >= g.minLv) {
      if (debug) {
        (_dMembers[g.id] ??= {})[row] = me;
        return true;
      }
      await _guilds.doc(g.id).collection('members').doc(row).set(me.toMap()).timeout(_t);
      return true;
    }
    if (debug) {
      (_dApps[g.id] ??= {})[row] = me;
      return false;
    }
    await _guilds.doc(g.id).collection('apps').doc(row).set({...me.toMap(), 'at': FieldValue.serverTimestamp()}).timeout(_t);
    return false;
  }

  /// Bang chủ or Phó bang lets [a] in.
  Future<void> accept(String gid, GuildMember a) async {
    final m = GuildMember(
        row: a.row, uid: a.uid, name: a.name, hanh: a.hanh, level: a.level, rebirths: a.rebirths, power: a.power);
    if (debug) {
      _dApps[gid]?.remove(a.row);
      (_dMembers[gid] ??= {})[a.row] = m;
      return;
    }
    final g = _guilds.doc(gid);
    await (_db.batch()
          ..set(g.collection('members').doc(a.row), m.toMap())
          ..delete(g.collection('apps').doc(a.row)))
        .commit()
        .timeout(_t);
  }

  Future<void> reject(String gid, String row) async {
    if (debug) {
      _dApps[gid]?.remove(row);
      return;
    }
    await _guilds.doc(gid).collection('apps').doc(row).delete().timeout(_t);
  }

  /// Leaves (own [row]) or puts out (someone else's).
  Future<void> remove(String gid, String row) async {
    if (debug) {
      _dMembers[gid]?.remove(row);
      return;
    }
    await _guilds.doc(gid).collection('members').doc(row).delete().timeout(_t);
  }

  /// Bang chủ makes [m] Phó bang or Thành viên.
  Future<void> setRole(GuildInfo g, GuildMember m, int role) async {
    final officers = {...g.officers};
    role == roleVice ? officers.add(m.uid) : officers.remove(m.uid);
    if (debug) {
      _dMembers[g.id]![m.row] = GuildMember.fromDoc(m.row, {...m.toMap(), 'role': role})!;
      _dGuilds[g.id] = GuildInfo.fromDoc(g.id, {..._infoMap(g), 'officers': officers.toList()})!;
      return;
    }
    final ref = _guilds.doc(g.id);
    await (_db.batch()
          ..update(ref.collection('members').doc(m.row), {'role': role})
          ..update(ref, {'officers': officers.toList()}))
        .commit()
        .timeout(_t);
  }

  /// Bang chủ hands the bang to [m] and becomes a member.
  Future<void> handOver(GuildInfo g, String myRow, GuildMember m) async {
    final officers = {...g.officers}..remove(m.uid);
    if (debug) {
      final mine = _dMembers[g.id]![myRow]!;
      _dMembers[g.id]![myRow] = GuildMember.fromDoc(myRow, {...mine.toMap(), 'role': roleMember})!;
      _dMembers[g.id]![m.row] = GuildMember.fromDoc(m.row, {...m.toMap(), 'role': roleLeader})!;
      _dGuilds[g.id] = GuildInfo.fromDoc(
          g.id, {..._infoMap(g), 'leader': m.uid, 'leaderName': m.name, 'officers': officers.toList()})!;
      return;
    }
    final ref = _guilds.doc(g.id);
    await (_db.batch()
          ..update(ref, {'leader': m.uid, 'leaderName': m.name, 'officers': officers.toList()})
          ..update(ref.collection('members').doc(m.row), {'role': roleLeader})
          ..update(ref.collection('members').doc(myRow), {'role': roleMember}))
        .commit()
        .timeout(_t);
  }

  /// Bang chủ closes the bang (members are put out first).
  Future<void> disband(GuildInfo g, List<GuildMember> members) async {
    if (debug) {
      _dGuilds.remove(g.id);
      _dMembers.remove(g.id);
      _dApps.remove(g.id);
      return;
    }
    final ref = _guilds.doc(g.id);
    final b = _db.batch();
    for (final m in members) {
      b.delete(ref.collection('members').doc(m.row));
    }
    b
      ..delete(ref)
      ..delete(_db.collection('guildNames').doc(nameKey(g.name)));
    await b.commit().timeout(_t);
  }

  Future<void> setSettings(GuildInfo g, {String? notice, bool? open, int? minLv}) async {
    final m = {'notice': ?notice, 'open': ?open, 'minLv': ?minLv};
    if (m.isEmpty) return;
    if (debug) {
      _dGuilds[g.id] = GuildInfo.fromDoc(g.id, {..._infoMap(g), ...m})!;
      return;
    }
    await _guilds.doc(g.id).update(m).timeout(_t);
  }

  /// Writes this hero's member row (cống hiến, Boss Bang, looks) and the
  /// bang's sums for the list of bangs.
  Future<void> pushMine(String gid, HeroData h, int role, {List<GuildMember>? all}) async {
    final u = uid, row = myRow;
    if (u == null || row == null) return;
    final me = GuildMember.of(row, u, h, role);
    if (debug) {
      (_dMembers[gid] ??= {})[row] = me;
      return;
    }
    try {
      final ref = _guilds.doc(gid);
      await ref.collection('members').doc(row).update(me.toMap()..remove('role')).timeout(_t);
      if (all != null) {
        final pts = all.fold<int>(0, (a, m) => a + (m.row == row ? me.contrib : m.contrib));
        await ref.update({'pts': pts, 'n': all.length, 'by': row}).timeout(_t);
      }
    } catch (e) {
      debugPrint('guild push failed: $e');
    }
  }

  Map<String, dynamic> _infoMap(GuildInfo g) => {
        'name': g.name,
        'leader': g.leader,
        'leaderName': g.leaderName,
        'officers': g.officers,
        'notice': g.notice,
        'open': g.open,
        'minLv': g.minLv,
        'pts': g.pts,
        'n': g.n,
      };

  // ------------------------------------------------------------ chat

  Stream<List<GuildChat>> chat(String gid) {
    if (debug) return Stream.value([...?_dChat[gid]]);
    return _guilds
        .doc(gid)
        .collection('chat')
        .orderBy('at', descending: true)
        .limit(40)
        .snapshots()
        .map((s) => [
              for (final d in s.docs.reversed)
                GuildChat(d.id, d.data()['row'] as String? ?? '', d.data()['name'] as String? ?? '',
                    d.data()['text'] as String? ?? '', (d.data()['at'] as Timestamp?)?.toDate()),
            ]);
  }

  Future<bool> say(String gid, HeroData h, String text) async {
    final u = uid, row = myRow;
    text = text.trim();
    if (u == null || row == null || text.isEmpty) return false;
    if (text.length > 120) text = text.substring(0, 120);
    if (debug) {
      (_dChat[gid] ??= []).add(GuildChat('${_dChat[gid]!.length}', row, h.name, text, DateTime.now()));
      return true;
    }
    try {
      await _guilds.doc(gid).collection('chat').add({
        'row': row,
        'uid': u,
        'name': h.name.length > 24 ? h.name.substring(0, 24) : h.name,
        'text': text,
        'at': FieldValue.serverTimestamp(),
      }).timeout(_t);
      return true;
    } catch (e) {
      debugPrint('guild chat failed: $e');
      return false;
    }
  }

  // ------------------------------------------------------------ Hảo hữu

  /// Board rows of [rows] (friends), read fresh; missing ones are left out.
  Future<List<LbEntry>> rows(List<String> rows) async {
    if (rows.isEmpty) return const [];
    if (debug) {
      return [for (final r in rows) ?await _lb.profile(r)];
    }
    final out = <LbEntry>[];
    for (var i = 0; i < rows.length; i += 10) {
      final part = rows.sublist(i, i + 10 > rows.length ? rows.length : i + 10);
      final snap = await _db
          .collection('leaderboard')
          .where(FieldPath.documentId, whereIn: part)
          .get()
          .timeout(_t);
      out.addAll([for (final d in snap.docs) ?LbEntry.fromDoc(d.id, d.data())]);
    }
    return out;
  }

  Future<bool> sendGift(HeroData h, String to, String day) async {
    final u = uid, row = myRow;
    if (u == null || row == null) return false;
    final g = FriendGift(row, h.name, h.hanh.index, day);
    if (debug) {
      (_dGifts[to] ??= {})[row] = g;
      return true;
    }
    try {
      await _db.collection('gifts').doc(to).collection('in').doc(row).set({
        'uid': u,
        'name': h.name.length > 24 ? h.name.substring(0, 24) : h.name,
        'hanh': h.hanh.index,
        'level': h.level,
        'day': day,
        'at': FieldValue.serverTimestamp(),
      }).timeout(_t);
      return true;
    } catch (e) {
      debugPrint('gift failed: $e');
      return false;
    }
  }

  Future<List<FriendGift>> inbox() async {
    final row = myRow;
    if (row == null) return const [];
    if (debug) return [...?_dGifts[row]?.values];
    final snap = await _db.collection('gifts').doc(row).collection('in').limit(50).get().timeout(_t);
    return [
      for (final d in snap.docs)
        FriendGift(d.id, d.data()['name'] as String? ?? '?', (d.data()['hanh'] as num?)?.toInt().clamp(0, 4) ?? 0,
            d.data()['day'] as String? ?? ''),
    ];
  }

  Future<void> dropGift(String from) async {
    final row = myRow;
    if (row == null) return;
    if (debug) {
      _dGifts[row]?.remove(from);
      return;
    }
    await _db.collection('gifts').doc(row).collection('in').doc(from).delete().timeout(_t);
  }

  // ------------------------------------------------------------ Trợ chiến

  /// In-memory `helps` for tests: to row → from row → times.
  final Map<String, Map<String, int>> dHelps = {};

  /// Tells row [to] that [h] called them into a fight: one Hiệp nghĩa,
  /// counted up in `helps/{to}/in/{fromRow}` until they take it (1.14.0).
  /// Needs a sign-in; false when it could not be written.
  Future<bool> sendHelp(HeroData h, String to, String day) async {
    final u = uid, row = myRow;
    // Never one of this account's own heroes.
    if (u == null || row == null || to.startsWith('${u}_')) return false;
    if (debug) {
      final m = dHelps[to] ??= {};
      m[row] = (m[row] ?? 0) + 1;
      return true;
    }
    try {
      await _db.collection('helps').doc(to).collection('in').doc(row).set({
        'uid': u,
        'name': h.name.length > 24 ? h.name.substring(0, 24) : h.name,
        'hanh': h.hanh.index,
        'level': h.level,
        'day': day,
        'n': FieldValue.increment(1),
        'at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(_t);
      return true;
    } catch (e) {
      debugPrint('help failed: $e');
      return false;
    }
  }

  /// Board rows of those who called, from the last [takeHelps].
  List<String> lastHelpRows = const [];

  /// Takes every Hiệp nghĩa waiting for this hero: (times, names of those
  /// who called), the docs removed. (0, []) when none or offline.
  Future<(int, List<String>)> takeHelps() async {
    final row = myRow;
    lastHelpRows = const [];
    if (row == null) return (0, const <String>[]);
    if (debug) {
      final m = dHelps.remove(row) ?? {};
      lastHelpRows = m.keys.toList();
      return (m.values.fold<int>(0, (a, b) => a + b), m.keys.toList());
    }
    try {
      final col = _db.collection('helps').doc(row).collection('in');
      final snap = await col.limit(50).get().timeout(_t);
      if (snap.docs.isEmpty) return (0, const <String>[]);
      var n = 0;
      final rows = <String>[];
      final names = <String>[];
      final batch = _db.batch();
      for (final d in snap.docs) {
        // Each caller calls a hero at most once a day; a doc left a long
        // time still counts no more than a month of calls.
        n += ((d.data()['n'] as num?)?.toInt() ?? 1).clamp(1, 31);
        names.add(d.data()['name'] as String? ?? '?');
        rows.add(d.id);
        batch.delete(d.reference);
      }
      // Paid only once they are gone, so nothing is paid twice.
      await batch.commit().timeout(_t);
      lastHelpRows = rows;
      return (n, names);
    } catch (e) {
      debugPrint('helps read failed: $e');
      return (0, const <String>[]);
    }
  }

  // ------------------------------------------------------------ Bang chiến

  /// In-memory `guildWar` for tests: week → gid → row.
  final Map<int, Map<String, WarRow>> dWar = {};

  /// Writes this hero's Chiến công to their member row, then the bang's sum
  /// for the week to `guildWar/{week}/g/{gid}` (1.16.0). [all] are the
  /// members as just read. False when it could not be written.
  Future<bool> pushWar(GuildInfo g, HeroData h, List<GuildMember> all) async {
    final u = uid, row = myRow;
    if (u == null || row == null) return false;
    final week = h.gwWeek;
    final mine = h.warPtsFor(g.id);
    final sum = all.fold<int>(0, (a, m) => a + (m.row == row ? mine : m.warIn(week)));
    final n = all.isEmpty ? 1 : all.length;
    if (debug) {
      final ms = _dMembers[g.id];
      final me = ms?[row];
      if (me != null) {
        ms![row] = GuildMember.fromDoc(row, {...me.toMap(), 'ww': week, 'wp': mine})!;
      }
      if (sum > 0) (dWar[week] ??= {})[g.id] = WarRow(g.id, g.name, sum, n);
      return true;
    }
    try {
      final ref = _guilds.doc(g.id);
      await ref.collection('members').doc(row).update({'ww': week, 'wp': mine}).timeout(_t);
      if (sum > 0) {
        await _db.collection('guildWar').doc('$week').collection('g').doc(g.id).set({
          'name': g.name,
          'wp': sum,
          'n': n,
          'by': row,
          'at': FieldValue.serverTimestamp(),
        }).timeout(_t);
      }
      return true;
    } catch (e) {
      debugPrint('war push failed: $e');
      return false;
    }
  }

  /// Week [week]'s board: the bangs with the most Chiến công first,
  /// impossible rows left out.
  Future<List<WarRow>> warBoard(int week, {int limit = 50}) async {
    final List<WarRow> rows;
    if (debug) {
      rows = [...?dWar[week]?.values]..sort((a, b) => b.pts.compareTo(a.pts));
    } else {
      final snap = await _db
          .collection('guildWar')
          .doc('$week')
          .collection('g')
          .orderBy('wp', descending: true)
          .limit(limit + 10)
          .get()
          .timeout(_t);
      rows = [for (final d in snap.docs) ?WarRow.fromDoc(d.id, d.data())];
    }
    return rows.where((r) => warPlausible(r.pts, r.n)).take(limit).toList();
  }

  // ------------------------------------------------------------ Sư đồ

  /// In-memory stand-ins for tests: `mentor` inboxes (to → from → message)
  /// and the `mentors` listing (row → ad).
  final Map<String, Map<String, MentorMsg>> dMentorIn = {};
  final Map<String, MentorAd> dMentors = {};

  /// Leaves message [kind] (one of [MentorMsg.kinds]) for row [to] in
  /// `mentor/{to}/in/{myRow}` (1.19.0); a newer one replaces it.
  Future<bool> mentorSend(HeroData h, String to, String kind, String day) async {
    final u = uid, row = myRow;
    if (u == null || row == null || to.startsWith('${u}_') || !MentorMsg.kinds.contains(kind)) return false;
    final name = h.name.length > 24 ? h.name.substring(0, 24) : h.name;
    if (debug) {
      (dMentorIn[to] ??= {})[row] = MentorMsg(row, name, h.hanh.index, h.level, day, kind);
      return true;
    }
    try {
      await _db.collection('mentor').doc(to).collection('in').doc(row).set({
        'uid': u,
        'name': name,
        'hanh': h.hanh.index,
        'level': h.level,
        'day': day,
        'k': kind,
        'at': FieldValue.serverTimestamp(),
      }).timeout(_t);
      return true;
    } catch (e) {
      debugPrint('mentor send failed: $e');
      return false;
    }
  }

  /// Messages waiting for this hero.
  Future<List<MentorMsg>> mentorInbox() async {
    final row = myRow;
    if (row == null) return const [];
    if (debug) return [...?dMentorIn[row]?.values];
    final snap = await _db.collection('mentor').doc(row).collection('in').limit(50).get().timeout(_t);
    return [for (final d in snap.docs) ?MentorMsg.fromDoc(d.id, d.data())];
  }

  /// Removes the message from [from] once dealt with.
  Future<void> mentorDrop(String from) async {
    final row = myRow;
    if (row == null) return;
    if (debug) {
      dMentorIn[row]?.remove(from);
      return;
    }
    try {
      await _db.collection('mentor').doc(row).collection('in').doc(from).delete().timeout(_t);
    } catch (e) {
      debugPrint('mentor drop failed: $e');
    }
  }

  /// Lists this hero as a master taking đệ tử (`mentors/{row}`), or takes
  /// the listing down.
  Future<bool> mentorList(HeroData h, bool on, int seatsUsed) async {
    final u = uid, row = myRow;
    if (u == null || row == null) return false;
    final ad = MentorAd(row, h.name.length > 24 ? h.name.substring(0, 24) : h.name, h.hanh.index, h.level, h.rebirths,
        h.power, seatsUsed);
    if (debug) {
      if (on) {
        dMentors[row] = ad;
      } else {
        dMentors.remove(row);
      }
      return true;
    }
    try {
      final ref = _db.collection('mentors').doc(row);
      if (on) {
        await ref.set({...ad.toMap(), 'uid': u, 'at': FieldValue.serverTimestamp()}).timeout(_t);
      } else {
        await ref.delete().timeout(_t);
      }
      return true;
    } catch (e) {
      debugPrint('mentor list failed: $e');
      return false;
    }
  }

  /// Masters taking đệ tử, the most recently seen first, full ones left out.
  Future<List<MentorAd>> mentors({int limit = 40}) async {
    final List<MentorAd> all;
    if (debug) {
      all = dMentors.values.toList();
    } else {
      final snap = await _db.collection('mentors').orderBy('at', descending: true).limit(limit).get().timeout(_t);
      all = [for (final d in snap.docs) ?MentorAd.fromDoc(d.id, d.data())];
    }
    final me = uid;
    return [for (final a in all) if (a.n < mentorMaxDisciples && (me == null || !a.row.startsWith('${me}_'))) a];
  }

  // ------------------------------------------------------------ Kết duyên

  /// In-memory `bond` inboxes for tests: to → from → message.
  final Map<String, Map<String, BondMsg>> dBondIn = {};

  /// Leaves message [kind] (one of [BondMsg.kinds]) for row [to] in
  /// `bond/{to}/in/{myRow}` (1.20.0); a newer one replaces it.
  Future<bool> bondSend(HeroData h, String to, String kind, String day) async {
    final u = uid, row = myRow;
    if (u == null || row == null || to.startsWith('${u}_') || !BondMsg.kinds.contains(kind)) return false;
    final name = h.name.length > 24 ? h.name.substring(0, 24) : h.name;
    if (debug) {
      (dBondIn[to] ??= {})[row] = BondMsg(row, name, h.hanh.index, h.level, h.rebirths, day, kind);
      return true;
    }
    try {
      await _db.collection('bond').doc(to).collection('in').doc(row).set({
        'uid': u,
        'name': name,
        'hanh': h.hanh.index,
        'level': h.level,
        'rb': h.rebirths,
        'day': day,
        'k': kind,
        'at': FieldValue.serverTimestamp(),
      }).timeout(_t);
      return true;
    } catch (e) {
      debugPrint('bond send failed: $e');
      return false;
    }
  }

  /// Kết duyên messages waiting for this hero.
  Future<List<BondMsg>> bondInbox() async {
    final row = myRow;
    if (row == null) return const [];
    if (debug) return [...?dBondIn[row]?.values];
    final snap = await _db.collection('bond').doc(row).collection('in').limit(50).get().timeout(_t);
    return [for (final d in snap.docs) ?BondMsg.fromDoc(d.id, d.data())];
  }

  /// Removes the message from [from] once dealt with.
  Future<void> bondDrop(String from) async {
    final row = myRow;
    if (row == null) return;
    if (debug) {
      dBondIn[row]?.remove(from);
      return;
    }
    try {
      await _db.collection('bond').doc(row).collection('in').doc(from).delete().timeout(_t);
    } catch (e) {
      debugPrint('bond drop failed: $e');
    }
  }
}

/// A Sư đồ message (`mentor/{to}/in/{from}`): a request to be taken as
/// đệ tử ('req'), the master's yes ('ok'), today's Truyền công ('tc'), or
/// the end of it from either side ('bye').
class MentorMsg {
  const MentorMsg(this.from, this.name, this.hanh, this.level, this.day, this.kind);
  final String from, name, day, kind;
  final int hanh, level;

  static const kinds = ['req', 'ok', 'tc', 'bye'];

  static MentorMsg? fromDoc(String id, Map<String, dynamic> m) {
    final k = m['k'];
    if (k is! String || !kinds.contains(k)) return null;
    return MentorMsg(id, m['name'] as String? ?? '?', (m['hanh'] as num?)?.toInt().clamp(0, 4) ?? 0,
        (m['level'] as num?)?.toInt().clamp(1, 99) ?? 1, m['day'] as String? ?? '', k);
  }
}

/// A master's listing in `mentors/{row}`.
class MentorAd {
  const MentorAd(this.row, this.name, this.hanh, this.level, this.rebirths, this.power, this.n);
  final String row, name;
  final int hanh, level, rebirths, power, n;

  Map<String, Object> toMap() =>
      {'name': name, 'hanh': hanh, 'level': level, 'rebirths': rebirths, 'power': power, 'n': n};

  static MentorAd? fromDoc(String id, Map<String, dynamic> m) {
    try {
      return MentorAd(id, m['name'] as String, (m['hanh'] as num).toInt().clamp(0, 4), (m['level'] as num).toInt(),
          (m['rebirths'] as num?)?.toInt() ?? 0, (m['power'] as num?)?.toInt() ?? 0, (m['n'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return null;
    }
  }
}

/// A bang on the Bang chiến board (`guildWar/{week}/g/{gid}`).
class WarRow {
  const WarRow(this.gid, this.name, this.pts, this.n);
  final String gid, name;
  final int pts, n;

  static WarRow? fromDoc(String id, Map<String, dynamic> m) {
    try {
      return WarRow(id, m['name'] as String, (m['wp'] as num).toInt(), (m['n'] as num?)?.toInt() ?? 1);
    } catch (_) {
      return null;
    }
  }
}

/// A Kết duyên message (`bond/{to}/in/{from}`): a proposal ('req'), the
/// yes ('ok'), the day's Tương tư ('tt'), or no / parting ('bye').
class BondMsg {
  const BondMsg(this.from, this.name, this.hanh, this.level, this.rebirths, this.day, this.kind);
  final String from, name, day, kind;
  final int hanh, level, rebirths;

  static const kinds = ['req', 'ok', 'tt', 'bye'];

  static BondMsg? fromDoc(String id, Map<String, dynamic> m) {
    final k = m['k'];
    if (k is! String || !kinds.contains(k)) return null;
    return BondMsg(id, m['name'] as String? ?? '?', (m['hanh'] as num?)?.toInt().clamp(0, 4) ?? 0,
        (m['level'] as num?)?.toInt().clamp(1, 99) ?? 1, (m['rb'] as num?)?.toInt().clamp(0, 9) ?? 0,
        m['day'] as String? ?? '', k);
  }
}

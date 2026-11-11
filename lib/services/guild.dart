import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/guild.dart';
import '../core/hero.dart';
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
  });

  final String row, uid, name;
  final int hanh, level, rebirths, power, role, contrib;

  /// Boss Bang week and damage in it.
  final int bw, bd;

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
}

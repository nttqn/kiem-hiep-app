/// Kênh Thế Giới: one public chat for every signed-in player. The rules
/// here are mirrored by the server's (database.rules.json), which is what
/// actually enforces them.
const int chatMaxLen = 120;

/// The newest this many messages are shown.
const int chatShown = 100;

/// One message per player per this long.
const Duration chatCooldown = Duration(minutes: 10);

/// Older messages may be swept by any sender.
const Duration chatKeep = Duration(days: 3);

class ChatMsg {
  const ChatMsg({
    required this.id,
    required this.uid,
    required this.name,
    required this.hanh,
    required this.level,
    required this.rebirths,
    required this.text,
    required this.at,
  });

  final String id;
  final String uid;
  final String name;
  final int hanh;
  final int level;
  final int rebirths;
  final String text;

  /// Server time, ms since epoch.
  final int at;

  static ChatMsg? fromMap(String id, Object? v) {
    if (v is! Map) return null;
    try {
      return ChatMsg(
        id: id,
        uid: v['uid'] as String,
        name: v['name'] as String,
        hanh: (v['hanh'] as num).toInt().clamp(0, 4),
        level: (v['level'] as num).toInt(),
        rebirths: (v['rebirths'] as num?)?.toInt() ?? 0,
        // The sender's app filters too; filter again for old or modded ones.
        text: chatCensor(v['text'] as String),
        at: (v['at'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// How long until a player who last sent at [lastAt] (server ms) may send
/// again, at server time [now]; zero when they may.
Duration chatWait(int? lastAt, int now) {
  if (lastAt == null) return Duration.zero;
  final left = lastAt + chatCooldown.inMilliseconds - now;
  return left <= 0 ? Duration.zero : Duration(milliseconds: left);
}

/// `9:05` style countdown.
String chatWaitLabel(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// A message as it is sent: one line, trimmed, at most [chatMaxLen]
/// characters, swear words starred. Empty when nothing is left.
String chatClean(String raw) {
  var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  // The server counts UTF-16 units (an emoji is two); never split one.
  if (t.length > chatMaxLen) {
    var end = chatMaxLen;
    final c = t.codeUnitAt(end - 1);
    if (c >= 0xD800 && c <= 0xDBFF) end--;
    t = t.substring(0, end).trimRight();
  }
  return chatCensor(t);
}

// Whole words only, with their accents: unaccented spellings such as
// "lon", "cac" or "buoi" are everyday words (lon, các, buổi).
const _swears = {
  'đụ', 'địt', 'đéo', 'đếch', 'lồn', 'cặc', 'buồi', 'đĩ', 'điếm', //
  'đm', 'dm', 'đmm', 'dmm', 'đcm', 'dcm', 'đcmm', 'dcmm', 'đkm', 'dkm', 'vcl', 'vkl', 'vcc', 'vl',
  'clm', 'cmm', 'cmn', 'cc', 'loz', 'lìn', 'đjt', 'djt', 'dit', 'đit', 'cak', 'kak',
  'fuck', 'fucking', 'fck', 'shit', 'bitch', 'dick', 'pussy', 'cunt',
};

// Repeated letters are folded first, so "địttt" and "vclll" are caught.
final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

bool _isSwear(String w) {
  final lower = w.toLowerCase();
  if (_swears.contains(lower)) return true;
  final folded = lower.replaceAllMapped(RegExp(r'(.)\1+', unicode: true), (m) => m[1]!);
  return _swears.contains(folded);
}

/// [text] with every swear word replaced by stars.
String chatCensor(String text) =>
    text.replaceAllMapped(_word, (m) => _isSwear(m[0]!) ? '*' * m[0]!.runes.length : m[0]!);

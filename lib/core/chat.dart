import 'i18n.dart';

/// Kênh Thế Giới: one public chat per language ([chatMsgsPath]). The rules
/// here are mirrored by the server's (database.rules.json), which is what
/// actually enforces them.
const int chatMaxLen = 120;

/// The newest this many messages are shown.
const int chatShown = 100;

/// One message per player per this long.
const Duration chatCooldown = Duration(minutes: 2);

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
  // Taiwanese net slang written in Latin letters (e04 = 幹你娘, g8 = 雞巴).
  'e04', 'g8', 'sb',
};

// Chinese has no spaces between words, so these are found anywhere in the
// text, also with spaces or symbols slipped between the characters
// ("幹 你.娘"). Traditional and Simplified, Taiwan and Hong Kong slang.
// Characters that are also everyday words alone (幹 in 幹嘛, 操 in 操作,
// 草, 靠) are only caught inside the phrases below.
const _cjkSwears = [
  '幹你娘', '幹您娘', '幹恁娘', '幹拎娘', '幹林娘', '干你娘', '姦你娘', '幹你老師', '幹你老母', '淦',
  '操你媽', '操你妈', '操你娘', '操你祖宗', '肏', '屌你老母', '屌你', '屌', '屄', '閪', '𨳒', '撚',
  '雞巴', '鸡巴', '機巴', '機八', '雞八', '雞掰', '機掰', '鸡掰', '雞歪', '機歪',
  '他媽的', '他妈的', '你媽的', '你妈的', '媽的', '妈的', '你媽', '你妈', '尼瑪', '尼玛', '草泥馬', '草泥马',
  '媽逼', '妈逼', '傻逼', '傻屄', '煞筆', '煞笔', '沙比', '傻B',
  '賤人', '贱人', '賤貨', '贱货', '婊子', '臭婊', '王八蛋', '狗娘養的', '狗娘养的', '死全家',
  '靠北', '靠杯', '靠夭', '三小', '仆街', '冚家鏟', '冚家铲', '腦殘', '脑残', '智障', '白癡', '白痴',
];

final RegExp _cjkSwear = () {
  // Longest first, so 他媽的 is starred whole rather than just 媽的.
  final terms = [..._cjkSwears]..sort((a, b) => b.runes.length.compareTo(a.runes.length));
  const gap = r'[\s\p{P}\p{S}_]*';
  String pattern(String t) => t.runes.map((r) => RegExp.escape(String.fromCharCode(r))).join(gap);
  return RegExp(terms.map(pattern).join('|'), unicode: true, caseSensitive: false);
}();

// Repeated letters are folded first, so "địttt" and "vclll" are caught.
final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

bool _isSwear(String w) {
  final lower = w.toLowerCase();
  if (_swears.contains(lower)) return true;
  final folded = lower.replaceAllMapped(RegExp(r'(.)\1+', unicode: true), (m) => m[1]!);
  return _swears.contains(folded);
}

/// [text] with every swear word replaced by stars: Vietnamese and English
/// by whole words, Chinese anywhere in the text.
String chatCensor(String text) => text
    .replaceAllMapped(_word, (m) => _isSwear(m[0]!) ? '*' * m[0]!.runes.length : m[0]!)
    .replaceAllMapped(_cjkSwear, (m) => '*' * m[0]!.runes.length);

/// Where the world channel of players in [lang] lives in the Realtime
/// Database. Vietnamese keeps the original path, so older app versions
/// still share it; every other language has its own room.
String chatMsgsPath(Lang lang) => lang == Lang.vi ? 'chat/msgs' : 'chat/rooms/${lang.code}';

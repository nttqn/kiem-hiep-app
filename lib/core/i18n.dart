/// Localization, gettext style: the Vietnamese text itself is the key.
///
/// `tr('Vào game')` returns the line for the language in use, or the
/// Vietnamese when that language has none yet, so a half-translated build
/// still plays. Placeholders are named in braces and filled from [args]:
/// `tr('Cấp {level}', {'level': h.level})`.
///
/// Text built from data (`sect.name`, `mob.name`, `skill.desc`…) stays
/// Vietnamese in the core and is passed through [tr] where it is shown, so
/// saves, ids, sims and comparisons never see a translated string.
///
/// The tables live in `assets/i18n/<lang>.json`; `node tool/i18n.js`
/// collects every key from `lib/` into them. Pure Dart: the core uses it
/// too, and with no table loaded (tests, sims) every call is the identity.
library;

import 'dart:math' as math;

/// Languages the game can be played in, in the order the setting lists them.
enum Lang {
  vi('vi', 'Tiếng Việt'),
  zhHant('zh_Hant', '繁體中文');

  const Lang(this.code, this.label);

  /// File name under assets/i18n/ and the value kept in prefs.
  final String code;

  /// Always in the language itself.
  final String label;

  static Lang? byCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

Lang _lang = Lang.vi;
Map<String, String> _table = const {};

/// The language in use.
Lang get currentLang => _lang;

/// Puts [lang] in use with its table ([table] is empty for Vietnamese).
void setLanguage(Lang lang, Map<String, String> table) {
  _lang = lang;
  _table = lang == Lang.vi ? const {} : table;
  _composedCache.clear();
}

/// [vi] in the language in use, with `{name}` placeholders filled from [args].
///
/// A name built from parts (an item's "Huyền Thiết Côn", a gem's tier) has
/// no line of its own: when every word of it is covered by keys, longest
/// first, those are joined instead (with no spaces in Chinese).
///
/// A String placeholder value goes through the table too, so data text
/// handed in as-is (a map's name, a title constant) comes out translated;
/// numbers and text already translated are left alone.
String tr(String vi, [Map<String, Object?>? args]) {
  var s = _table[vi];
  if ((s == null || s.isEmpty) && _table.isNotEmpty && args == null) s = _composed(vi);
  if (s == null || s.isEmpty) s = vi;
  if (args != null) {
    for (final e in args.entries) {
      final v = e.value;
      s = s!.replaceAll('{${e.key}}', v is String && _table.isNotEmpty ? tr(v) : '$v');
    }
  }
  return s!;
}

final Map<String, String?> _composedCache = {};

String? _composed(String vi) {
  if (!vi.contains(' ') || vi.length > 60) return null;
  return _composedCache.putIfAbsent(vi, () {
    final words = vi.trim().split(RegExp(r'\s+'));
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      String? hit;
      var n = 0;
      for (var len = math.min(4, words.length - i); len >= 1; len--) {
        final t = _table[words.sublist(i, i + len).join(' ')];
        if (t != null && t.isNotEmpty) {
          hit = t;
          n = len;
          break;
        }
      }
      // A number or symbol passes through; an unknown word means no match.
      if (hit == null) {
        if (RegExp(r'^[\d+★·×x%.,:()\-]+$').hasMatch(words[i])) {
          hit = words[i];
          n = 1;
        } else {
          return null;
        }
      }
      out.add(hit);
      i += n;
    }
    return out.join(_lang == Lang.zhHant ? '' : ' ');
  });
}

/// The language a phone set to [languageCode]/[scriptCode]/[countryCode]
/// gets on first launch: Traditional Chinese for Taiwan, Hong Kong and
/// Macau (or any zh-Hant), Vietnamese for everyone else, as before.
Lang defaultLangFor(String languageCode, String? scriptCode, String? countryCode) {
  if (languageCode == 'zh' &&
      (scriptCode == 'Hant' || const {'TW', 'HK', 'MO'}.contains(countryCode))) {
    return Lang.zhHant;
  }
  return Lang.vi;
}

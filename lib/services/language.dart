import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n.dart';
import 'analytics.dart';
import 'dart:async';

/// The language the game is shown in (see core/i18n.dart): the player's
/// choice once made, else the phone's (Traditional Chinese on zh-TW/HK/MO
/// phones, Vietnamese everywhere else).
class LanguageService {
  LanguageService._();
  static final instance = LanguageService._();

  static const _key = 'lang';

  final ValueNotifier<Lang> lang = ValueNotifier(Lang.vi);

  Future<void> load() async {
    Lang? l;
    try {
      final prefs = await SharedPreferences.getInstance();
      l = Lang.byCode(prefs.getString(_key));
    } catch (_) {}
    if (l == null) {
      final loc = PlatformDispatcher.instance.locale;
      l = defaultLangFor(loc.languageCode, loc.scriptCode, loc.countryCode);
    }
    await _apply(l);
  }

  Future<void> set(Lang l) async {
    await _apply(l);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, l.code);
    } catch (_) {}
  }

  Future<void> _apply(Lang l) async {
    var table = const <String, String>{};
    if (l != Lang.vi) {
      try {
        final raw = jsonDecode(await rootBundle.loadString('assets/i18n/${l.code}.json')) as Map<String, dynamic>;
        table = {
          for (final e in raw.entries)
            if (e.value is String && (e.value as String).isNotEmpty) e.key: e.value as String,
        };
      } catch (e) {
        // A broken table must never stop the game: play in Vietnamese.
        debugPrint('i18n: $l table failed: $e');
        l = Lang.vi;
      }
    }
    setLanguage(l, table);
    lang.value = l;
    unawaited(Analytics.instance.setLang(l.code));
  }
}

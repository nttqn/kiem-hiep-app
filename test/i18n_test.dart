import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/i18n.dart';
import 'package:kiem_hiep/core/items.dart';
import 'package:kiem_hiep/core/sects.dart';

Map<String, String> _zh() => (jsonDecode(File('assets/i18n/zh_Hant.json').readAsStringSync()) as Map<String, dynamic>)
    .map((k, v) => MapEntry(k, v as String));

void main() {
  tearDown(() => setLanguage(Lang.vi, const {}));

  test('every line keeps the placeholders of its key', () {
    final ph = RegExp(r'\{\w+\}');
    Set<String> of(String s) => ph.allMatches(s).map((m) => m[0]!).toSet();
    final bad = [
      for (final e in _zh().entries)
        if (e.value.isNotEmpty && !of(e.key).containsAll(of(e.value)) || (e.value.isNotEmpty && !of(e.value).containsAll(of(e.key))))
          e.key,
    ];
    expect(bad, isEmpty);
  });

  test('Vietnamese is the identity; Chinese fills placeholders and names', () {
    expect(tr('Cấp {level}', {'level': 5}), 'Cấp 5');
    setLanguage(Lang.zhHant, _zh());
    expect(tr('Cấp {level}', {'level': 5}), '等級 5');
    // A data name handed in as a placeholder is translated too.
    expect(tr('Đến {mapName}', {'mapName': 'Tử Trúc Lâm'}), '前往紫竹林');
    // Composed item names, word by word.
    expect(tr('Huyền Thiết Côn'), '玄鐵棍');
    // Unknown text (a player's name) stays as it is.
    expect(tr('Tiểu Hiệp Xyz'), 'Tiểu Hiệp Xyz');
  });

  test('saved text stays Vietnamese while playing in Chinese', () {
    setLanguage(Lang.zhHant, _zh());
    final it = makeItem(
        slot: Slot.hat, level: 45, rarity: Rarity.rare, sect: sectOf(Hanh.kim), rng: math.Random(1));
    expect(it.name, 'Huyền Thiết Mão');
    expect(it.title, contains('玄鐵冠'));
    final h = HeroData(name: 'Tiểu Hiệp', hanh: Hanh.kim);
    expect(jsonEncode(h.toJson()), isNot(contains('等級')));
  });

  test('default language by phone locale', () {
    expect(defaultLangFor('zh', 'Hant', null), Lang.zhHant);
    expect(defaultLangFor('zh', null, 'TW'), Lang.zhHant);
    expect(defaultLangFor('zh', null, 'HK'), Lang.zhHant);
    expect(defaultLangFor('zh', 'Hans', 'CN'), Lang.vi);
    expect(defaultLangFor('vi', null, 'VN'), Lang.vi);
    expect(defaultLangFor('en', null, 'US'), Lang.vi);
  });
}

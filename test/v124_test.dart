import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/i18n.dart';
import 'package:kiem_hiep/core/newcomer.dart';
import 'package:kiem_hiep/core/quick_chat.dart';
import 'package:kiem_hiep/ui/quick_chat_button.dart';

Map<String, String> _table(String code) =>
    (jsonDecode(File('assets/i18n/$code.json').readAsStringSync()) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));

void main() {
  tearDown(() => setLanguage(Lang.vi, const {}));

  test('quick lines show in the reader language, typed text as written', () {
    expect(chatShow('Cảm ơn nhé!'), 'Cảm ơn nhé!');
    setLanguage(Lang.en, _table('en'));
    expect(chatShow('Cảm ơn nhé!'), 'Thank you!');
    expect(chatShow('cảm ơn nhé'), 'cảm ơn nhé');
    setLanguage(Lang.ko, _table('ko'));
    expect(chatShow('Vào bang mình nhé!'), '우리 방회에 들어와요!');
    // Every line has a translation in every language, and fits a message.
    for (final code in ['zh_Hant', 'ko', 'en']) {
      final t = _table(code);
      for (final p in quickPhrases) {
        expect(t[p], isNotEmpty, reason: '$code: $p');
        expect(p.length, lessThanOrEqualTo(120));
      }
    }
  });

  test('newcomers made in another language get a first week boost', () {
    final h = HeroData(name: 'A', hanh: Hanh.kim)..bornDay = '20261201';
    expect(newcomerOn(h, '20261201'), isFalse); // made before 1.24: no language
    h.bornLang = 'vi';
    expect(newcomerOn(h, '20261201'), isFalse);
    h.bornLang = 'en';
    expect(newcomerOn(h, '20261201'), isTrue);
    expect(newcomerOn(h, '20261207'), isTrue);
    expect(newcomerOn(h, '20261208'), isFalse);
    expect(newcomerUntil(h), '20261207');
    // Kept in the save.
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.bornLang, 'en');
    expect(HeroData.fromJson(jsonDecode(jsonEncode((HeroData(name: 'B', hanh: Hanh.moc)).toJson())) as Map<String, dynamic>).bornLang, '');
  });

  testWidgets('the quick chat sheet fits a small phone and sends a line', (t) async {
    setLanguage(Lang.en, _table('en'));
    t.view.physicalSize = const Size(700, 330);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final input = TextEditingController(text: 'hi');
    String? sent;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: QuickChatButton(input: input, onPhrase: (p) => sent = p)))));
    await t.tap(find.byType(QuickChatButton));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('👍'));
    await t.pumpAndSettle();
    expect(input.text, 'hi👍');
    await t.tap(find.byType(QuickChatButton));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Thank you!'), 50, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('Thank you!'));
    await t.pumpAndSettle();
    expect(sent, 'Cảm ơn nhé!');
  });
}

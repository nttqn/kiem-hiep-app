import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/news.dart';
import 'package:kiem_hiep/services/news.dart';
import 'package:kiem_hiep/ui/news_dialog.dart';
import 'package:kiem_hiep/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  layoutTests();

  test('a notice needs a title; bad links and days are dropped', () {
    expect(NewsDef.fromMap('a', {'body': 'x'}), isNull);
    final n = NewsDef.fromMap('b', {
      'title': '  Game mới  ',
      'body': r'Dòng 1\nDòng 2',
      'image': 'javascript:alert(1)',
      'link': 'https://play.google.com/store/apps/details?id=x',
      'linkIos': 'ftp://nope',
      'from': 20261120,
      'until': 'mai',
      'order': 2,
      'popup': true,
    })!;
    expect(n.title, 'Game mới');
    expect(n.body, 'Dòng 1\nDòng 2');
    expect(n.image, '');
    expect(n.linkIos, '');
    expect(n.from, '20261120');
    expect(n.until, '');
    expect(n.order, 2);
    expect(n.popup, isTrue);
    expect(n.buttonLabel, 'Tải ngay');
  });

  test('a Play-only promo stays off iPhone; plain news shows everywhere', () {
    const play = NewsDef(id: 'p', title: 'p', link: 'https://play.google.com/x');
    const both = NewsDef(id: 'b', title: 'b', link: 'https://play.google.com/x', linkIos: 'https://apps.apple.com/x');
    const plain = NewsDef(id: 'n', title: 'n');
    expect(NewsDef.visible([play, both, plain], '20261120', ios: true).map((n) => n.id), ['b', 'n']);
    expect(NewsDef.visible([play, both, plain], '20261120', ios: false).length, 3);
    expect(both.linkFor(ios: true), 'https://apps.apple.com/x');
  });

  test('days and order', () {
    const old = NewsDef(id: 'old', title: 'o', from: '20261101');
    const fresh = NewsDef(id: 'new', title: 'n', from: '20261118');
    const pinned = NewsDef(id: 'pin', title: 'p', from: '20261001', order: 1);
    const later = NewsDef(id: 'later', title: 'l', from: '20261125');
    const gone = NewsDef(id: 'gone', title: 'g', until: '20261117');
    expect(NewsDef.visible([old, fresh, pinned, later, gone], '20261118', ios: false).map((n) => n.id),
        ['pin', 'new', 'old']);
  });
}

/// The board and an open notice fit a small landscape phone with the
/// game's fonts at the largest text (see v1130_small_phone_test.dart).
Future<void> _fonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await l.load();
  }

  await load('BeVietnam', ['BeVietnamPro-Regular.ttf', 'BeVietnamPro-Bold.ttf', 'BeVietnamPro-ExtraBold.ttf']);
  await load('Playfair', ['PlayfairDisplay.ttf']);
}

void layoutTests() {
  setUpAll(_fonts);
  final news = [
    NewsDef(
      id: 'promo',
      title: 'Game mới: Võ Lâm Quyết Đấu — đấu võ 2.5D năm môn phái, tải miễn phí',
      tag: 'Game mới',
      body: List.filled(12, 'Đánh tay đôi với năm môn phái, rèn trang bị, leo bảng Tỉ Võ.').join('\n'),
      link: 'https://play.google.com/store/apps/details?id=x',
      button: 'Tải ngay miễn phí',
      from: '20261118',
      order: 1,
    ),
    for (var i = 0; i < 8; i++)
      NewsDef(id: 'n$i', title: 'Bảo trì máy chủ lúc 23h ngày ${20 + i}/11', tag: 'Bảo trì', body: 'Nội dung $i'),
  ];
  for (final open in [false, true]) {
    testWidgets('Bảng tin ${open ? 'notice' : 'list'} fits 700x330 at x1.1', (tester) async {
      SharedPreferences.setMockInitialValues({});
      NewsService.instance.debugNews = news;
      addTearDown(() => NewsService.instance.debugNews = null);
      tester.view.physicalSize = const Size(700, 330) * 2.75;
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (c, child) =>
            MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.1)), child: child!),
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showNewsDialog(c, first: open ? news.first : null),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text(open ? 'Tải ngay miễn phí' : 'Bảng tin'), findsOneWidget);
    });
  }
}

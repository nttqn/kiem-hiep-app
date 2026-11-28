// App Store Connect "Review Information" screenshots, one per IAP product:
// the shop card (or the Lệnh Bài button) framed, iPhone 6.3" landscape
// (2622x1206). flutter test tool/iap_review_shots_test.dart --update-goldens
// → build/shots/review_<sku>.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiem_hiep/core/clock.dart';
import 'package:kiem_hiep/core/festival.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/premium.dart';
import 'package:kiem_hiep/services/purchase.dart';
import 'package:kiem_hiep/services/save.dart';
import 'package:kiem_hiep/ui/fest_screen.dart';
import 'package:kiem_hiep/ui/offers_view.dart';
import 'package:kiem_hiep/ui/pass_screen.dart';
import 'package:kiem_hiep/ui/shop_screen.dart';
import 'package:kiem_hiep/ui/theme.dart';

/// Shown prices (only for the picture; the store sets the real ones).
const _prices = {
  skuMonthCard: '49.000 ₫',
  skuStarter: '25.000 ₫',
  skuNoAds: '49.000 ₫',
  skuStarPack: '49.000 ₫',
  skuPass: '99.000 ₫',
  skuGoldPack: '25.000 ₫',
  skuGoldChest: '199.000 ₫',
  skuGoldVault: '399.000 ₫',
  skuFest: '49.000 ₫',
  skuSoulPack: '99.000 ₫',
};

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
  // The SDK's icon font, found from flutter_tester (bin/cache/artifacts/...).
  var d = File(Platform.resolvedExecutable).parent;
  while (d.path != d.parent.path && !d.path.endsWith('artifacts')) {
    d = d.parent;
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('${d.path}/material_fonts/materialicons-regular.otf').readAsBytesSync())));
  await icons.load();
}

final _frame = ValueNotifier<Rect?>(null);

Future<void> _shot(WidgetTester tester, Widget screen, String sku, Finder target, {bool card = true, Finder? scroller, Finder? scrollTo}) async {
  tester.view.physicalSize = const Size(874, 402) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  _frame.value = null;
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    debugShowCheckedModeBanner: false,
    home: Stack(children: [
      Positioned.fill(child: screen),
      ValueListenableBuilder<Rect?>(
        valueListenable: _frame,
        builder: (_, r, _) => r == null
            ? const SizedBox()
            : Positioned.fromRect(
                rect: r.inflate(4),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54A), width: 4),
                    ),
                  ),
                ),
              ),
      ),
    ]),
  ));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump(const Duration(milliseconds: 300));
  if (card) {
    await tester.scrollUntilVisible(target, 150, scrollable: find.descendant(of: find.byType(OffersView), matching: find.byType(Scrollable)).first);
  }
  if (scroller != null) {
    await tester.scrollUntilVisible(scrollTo ?? target, 150, scrollable: scroller);
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 500));
  final box = card ? find.ancestor(of: target.first, matching: find.byType(Panel)).first : target.first;
  _frame.value = tester.getRect(box);
  await tester.pump();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/shots/review_$sku.png'));
}

void main() {
  setUpAll(_fonts);
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final iap = PurchaseService.instance;
    iap.products.clear();
    _prices.forEach((id, p) {
      iap.products[id] = ProductDetails(id: id, title: id, description: '', price: p, rawPrice: 0, currencyCode: 'VND');
    });
    final h = HeroData(name: 'Lãng Khách', hanh: Hanh.kim)..level = 82 // lv80+ shows Rương/Kho Ngân Lượng
      ..beastSouls = 12; // shows Hộp Tinh Phách
    h.recompute();
    SaveService.instance.slots[0] = h;
    SaveService.instance.active = 0;
  });

  const cards = {
    skuMonthCard: 'Nguyệt thẻ',
    skuGoldPack: 'Hòm Ngân Lượng',
    skuGoldChest: 'Rương Ngân Lượng',
    skuGoldVault: 'Kho Ngân Lượng',
    skuStarPack: 'Gói Thăng Tinh',
    skuStarter: 'Gói tân thủ',
    skuNoAds: 'Bỏ quảng cáo',
    skuSoulPack: 'Hộp Tinh Phách',
  };
  cards.forEach((sku, title) {
    testWidgets(sku, (tester) async {
      await _shot(tester, const ShopScreen(tab: 2), sku, find.text(title));
    });
  });

  testWidgets(skuPass, (tester) async {
    await _shot(tester, const PassScreen(), skuPass, find.ancestor(of: find.textContaining('Mở Hào Kiệt'), matching: find.byType(LButton)), card: false);
  });

  // Gói lễ hội only shows while a festival is on: the clock is put on
  // Đông Chí (2026-12-20).
  testWidgets(skuFest, (tester) async {
    final real = GameClock.deviceMs;
    GameClock.deviceMs = () => DateTime.utc(2026, 12, 20, 5).millisecondsSinceEpoch;
    addTearDown(() => GameClock.deviceMs = real);
    await _shot(tester, const FestScreen(), skuFest,
        find.ancestor(of: find.text('Gói lễ hội'), matching: find.byType(Panel)), card: false,
        scroller: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
        scrollTo: find.text('Gói lễ hội'));
  });
}

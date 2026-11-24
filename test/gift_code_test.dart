import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/mail.dart';

void main() {
  test('code key: spaces dropped, upper case, safe characters only', () {
    expect(giftCodeKey(' kh ios 2026 '), 'KHIOS2026');
    expect(giftCodeKey('tan-thu_1'), 'TAN-THU_1');
    expect(giftCodeKey('ab'), isNull);
    expect(giftCodeKey('a/b/c'), isNull);
    expect(giftCodeKey('quà'), isNull);
    expect(giftCodeKey('X' * 25), isNull);
  });

  test('a code gives its gift once per hero and never Nguyệt thẻ', () {
    final gift = giftCodeFromMap('IOS', {'gold': 5000, 'iron': 3, 'card': 30, 'uid': 'someone'})!;
    expect(gift.id, 'code:IOS');
    expect(gift.card, 0);
    expect(gift.uid, '');
    expect(gift.title, isNotEmpty);
    final h = HeroData(name: 'Thử', hanh: Hanh.kim);
    final gold = h.gold, iron = h.divineIron;
    final lines = h.claimMail(gift, '20261124', math.Random(1));
    expect(lines, isNotEmpty);
    expect(h.gold, gold + 5000);
    expect(h.divineIron, iron + 3);
    expect(h.claimMail(gift, '20261124', math.Random(1)), isEmpty);
    expect(h.gold, gold + 5000);
  });

  test('a code for another language is not a code here', () {
    expect(giftCodeFromMap('KR', {'gold': 1, 'lang': 'ko'}), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/i18n.dart';
import 'package:kiem_hiep/core/live_event.dart';
import 'package:kiem_hiep/core/mail.dart';
import 'package:kiem_hiep/core/news.dart';

void main() {
  tearDown(() => setLanguage(Lang.vi, const {}));

  const gift = {
    'title': 'Quà mừng Đông Chí',
    'title_zh_Hant': '冬至賀禮',
    'body': 'Chúc đại hiệp an khang',
    'body_zh_Hant': '祝大俠安康',
    'gold': 50000,
  };

  test('mail shows the playing language, Vietnamese when no translation', () {
    expect(MailDef.fromMap('m', gift)!.title, 'Quà mừng Đông Chí');
    setLanguage(Lang.zhHant, const {'x': 'x'});
    final zh = MailDef.fromMap('m', gift)!;
    expect(zh.title, '冬至賀禮');
    expect(zh.body, '祝大俠安康');
    // Same document, same id: one gift whatever the language.
    expect(zh.id, 'm');
    expect(zh.gold, 50000);
    // Blank translation falls back to the plain field.
    expect(MailDef.fromMap('m', {...gift, 'title_zh_Hant': '  '})!.title, 'Quà mừng Đông Chí');
  });

  test('lang limits a document to some languages', () {
    expect(MailDef.fromMap('m', {...gift, 'lang': 'zh_Hant'}), isNull);
    expect(MailDef.fromMap('m', {...gift, 'lang': 'vi'}), isNotNull);
    expect(NewsDef.fromMap('n', {'title': 'Game mới', 'lang': 'vi, zh_Hant'}), isNotNull);
    setLanguage(Lang.zhHant, const {'x': 'x'});
    expect(MailDef.fromMap('m', {...gift, 'lang': 'zh_Hant'}), isNotNull);
    expect(MailDef.fromMap('m', {...gift, 'lang': 'vi'}), isNull);
    expect(MailDef.fromMap('m', {...gift, 'lang': ''}), isNotNull);
  });

  test('news reads every text field in the playing language', () {
    const doc = {
      'title': 'Bảo trì',
      'title_zh_Hant': '維護公告',
      'body': 'Máy chủ bảo trì',
      'body_zh_Hant': '伺服器維護',
      'tag': 'Bảo trì',
      'tag_zh_Hant': '維護',
      'button': 'Xem',
      'button_zh_Hant': '查看',
      'link': 'https://example.com',
    };
    setLanguage(Lang.zhHant, const {'x': 'x'});
    final n = NewsDef.fromMap('n', doc)!;
    expect([n.title, n.body, n.tag, n.buttonLabel], ['維護公告', '伺服器維護', '維護', '查看']);
    setLanguage(Lang.vi, const {});
    expect(NewsDef.fromMap('n', doc)!.title, 'Bảo trì');
  });

  test('events: Chinese name or a generic one, never the Vietnamese; lang filter', () {
    const ev = {'name': 'Đại hội cuối tuần', 'desc': 'Giang hồ mở hội', 'exp': 2};
    expect(LiveEvent.fromMap('e', ev)!.name, 'Đại hội cuối tuần');
    setLanguage(Lang.zhHant, const {'Sự kiện': '活動'});
    final plain = LiveEvent.fromMap('e', ev)!;
    expect(plain.name, '活動');
    expect(plain.desc, '');
    expect(plain.exp, 2);
    final zh = LiveEvent.fromMap('e', {...ev, 'name_zh_Hant': '週末大會', 'desc_zh_Hant': '江湖盛會'})!;
    expect([zh.name, zh.desc], ['週末大會', '江湖盛會']);
    expect(LiveEvent.fromMap('e', {...ev, 'lang': 'vi'}), isNull);
    expect(LiveEvent.fromMap('e', {...ev, 'lang': 'vi,zh_Hant'}), isNotNull);
  });
}

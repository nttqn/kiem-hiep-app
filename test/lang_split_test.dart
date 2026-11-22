import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/i18n.dart';
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/leaderboard.dart';

void main() {
  test('rows without a language are Vietnamese', () {
    expect(Lang.ofRow(null), Lang.vi);
    expect(Lang.ofRow('zh_Hant'), Lang.zhHant);
    expect(Lang.ofRow('xx'), Lang.vi);
    expect(Lang.ofRow(5), Lang.vi);
    expect([Lang.vi.tag, Lang.zhHant.tag], ['VN', '繁中']);
  });

  test('leaderboard rows read the language', () {
    const row = {'name': 'Kiều Phong', 'hanh': 0, 'level': 50, 'power': 1000};
    expect(LbEntry.fromDoc('u_0', row)!.lang, Lang.vi);
    expect(LbEntry.fromDoc('u_0', {...row, 'lang': 'zh_Hant'})!.lang, Lang.zhHant);
  });

  test('bangs of the player language come first, each part biggest first', () {
    GuildInfo g(String id, int pts, [String? lang]) =>
        GuildInfo.fromDoc(id, {'name': id, 'leader': 'x', 'pts': pts, 'lang': ?lang})!;
    final all = [g('a', 900), g('b', 100, 'zh_Hant'), g('c', 500, 'vi'), g('d', 300, 'zh_Hant')];
    expect(all.first.lang, '');
    expect(all.first.language, Lang.vi);
    expect([for (final x in GuildService.sortForLang(all, Lang.zhHant)) x.id], ['d', 'b', 'a', 'c']);
    expect([for (final x in GuildService.sortForLang(all, Lang.vi)) x.id], ['a', 'c', 'd', 'b']);
  });
}

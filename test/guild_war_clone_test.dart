import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/services/guild.dart';
import 'package:kiem_hiep/services/leaderboard.dart';

/// One save copied onto four accounts stood in one bang (Chiến Thần,
/// 2026-11-25): it counts once in Bang chiến, and one slot can be banned
/// without the account's other heroes.
void main() {
  LbEntry lb(String id, int power, {int hs = 0, int play = 0}) =>
      LbEntry(id: id, name: id, hanh: 2, level: 99, rebirths: 6, power: power, tower: 0, hs: hs, play: play);
  GuildMember gm(String row, int wp) => GuildMember(
      row: row, uid: row.split('_').first, name: row, hanh: 2, level: 99, rebirths: 6, power: 1, ww: 5, wp: wp);

  test('a slot ban hides that slot only; an account ban hides all', () {
    expect(Leaderboard.bannedRow({'abc_1'}, 'abc_1'), isTrue);
    expect(Leaderboard.bannedRow({'abc_1'}, 'abc_0'), isFalse);
    expect(Leaderboard.bannedRow({'abc'}, 'abc_0'), isTrue);
    expect(Leaderboard.bannedRow({'abc'}, 'abcd_0'), isFalse);
    expect(Leaderboard.bannedRow(const {}, 'abc_0'), isFalse);
  });

  test('copies of one save are one group, by hero mark or play time', () {
    final g = Leaderboard.heroGroups([
      lb('a_0', 8224238, hs: 77),
      lb('b_0', 8224238, hs: 77),
      lb('c_0', 8224238, play: 90000),
      lb('d_0', 8224238, hs: 77, play: 90000),
      lb('e_1', 4581284, hs: 12),
    ]);
    expect(g['a_0'], 'a_0');
    expect(g['b_0'], 'a_0');
    expect(g['d_0'], 'a_0');
    // c_0 shares only the play time with d_0, which came after it.
    expect(g['c_0'], 'c_0');
    expect(g['e_1'], 'e_1');
  });

  test('a bang counts a copied hero once, at its best copy, and no banned row', () {
    final all = [gm('a_0', 179), gm('b_0', 179), gm('c_0', 60), gm('d_0', 180), gm('e_1', 50), gm('f_0', 40)];
    final groups = {'a_0': 'a_0', 'b_0': 'a_0', 'c_0': 'a_0', 'd_0': 'a_0', 'e_1': 'e_1', 'f_0': 'f_0'};
    expect(GuildService.warTotal(all, groups, const {}, 'e_1', 55, 5), (180 + 55 + 40, 3));
    expect(GuildService.warTotal(all, groups, {'f'}, 'e_1', 55, 5), (180 + 55, 2));
    // Unknown groups (board unread): every row counts, as before.
    expect(GuildService.warTotal(all, const {}, const {}, 'e_1', 55, 5), (179 + 179 + 60 + 180 + 55 + 40, 6));
    // This hero's row not read yet still counts.
    expect(GuildService.warTotal(all, groups, const {}, 'z_0', 9, 5), (180 + 50 + 40 + 9, 4));
  });
}

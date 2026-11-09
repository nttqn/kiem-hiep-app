import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/ngo_dao.dart';
import 'package:kiem_hiep/core/sects.dart';
import 'package:kiem_hiep/services/leaderboard.dart';

HeroData _maxed() {
  final h = HeroData(name: 'T', hanh: Hanh.hoa)
    ..rebirths = maxRebirths
    ..level = maxLevel;
  h.exp = h.expNeedAt(maxLevel);
  h.recompute();
  return h;
}

void main() {
  test('cảnh giới names, layers and gates', () {
    expect(daoName(0), 'Chưa nhập đạo');
    expect(daoName(1), 'Luyện Khí tầng 1');
    expect(daoName(9), 'Luyện Khí tầng 9');
    expect(daoName(10), 'Trúc Cơ tầng 1');
    expect(daoName(73), 'Chân Tiên tầng 1');
    expect(daoName(90), 'Chân Tiên tầng 18');
    expect(daoAtGate(8), isFalse);
    expect(daoAtGate(9), isTrue);
    expect(daoAtGate(72), isTrue);
    // Chân Tiên has no ninth-tầng gate: it goes on.
    expect(daoAtGate(81), isFalse);
    expect(daoCost(0), 20000000);
    expect(daoCost(10), greaterThan(daoCost(9)));
  });

  test('EXP past the last rebirth builds Đạo hạnh as well as pills, and stops at a gate', () {
    final h = _maxed();
    final atk = h.stats.atk;
    h.gainExp(daoCost(0) / 4); // x4 at six rebirths
    expect(h.daoLv, 1);
    expect(h.soulPills, greaterThan(0));
    h.recompute();
    expect(h.stats.atk, greaterThan(atk));
    for (var i = 0; i < 400; i++) {
      h.gainExp(5e8);
    }
    expect(h.daoLv, 9);
    expect(h.daoWaiting, isTrue);
    expect(h.daoExp, daoCost(9));
    expect(h.notices.where((n) => n.text.contains('Độ kiếp')).length, 1);
  });

  test('no Đạo hạnh before the sixth rebirth', () {
    final h = _maxed()..rebirths = 5;
    h.gainExp(1e9);
    expect(h.daoLv, 0);
    expect(h.daoExp, 0);
  });

  test('Độ kiếp: a loss costs nothing, a win pays pills and enters the next cảnh giới', () {
    final h = _maxed()
      ..daoLv = 9
      ..daoExp = daoCost(9) + 0
      ..soulPills = 10;
    expect(h.canKiep, isFalse); // 50 pills
    h.soulPills = 70;
    expect(h.canKiep, isTrue);
    expect(h.kiepStage, 1);
    final d = h.kiepDef();
    expect(d.isKiep, isTrue);
    expect(d.isArena, isTrue);
    expect(d.rival!.power, (h.power * kiepMul(1)).round());
    h.kiepResult(false);
    expect(h.daoLv, 9);
    expect(h.soulPills, 70);
    final lines = h.kiepResult(true);
    expect(lines.first, contains('Trúc Cơ tầng 1'));
    expect(h.daoLv, 10);
    expect(h.daoExp, 0);
    expect(h.soulPills, 20);
    expect(daoBonuses(10)[Bonus.atkPct], closeTo(0.05 + 0.02, 1e-9));
  });

  test('Ngộ Đạo is saved and loaded', () {
    final h = _maxed()
      ..daoLv = 23
      ..daoExp = 123456789
      ..daoNotified = true;
    final back = HeroData.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(back.daoLv, 23);
    expect(back.daoExp, 123456789);
    expect(back.daoNotified, isTrue);
    // Old saves have none.
    final fresh = HeroData.fromJson(jsonDecode(jsonEncode(HeroData(name: 'N', hanh: Hanh.kim).toJson())) as Map<String, dynamic>);
    expect(fresh.daoLv, 0);
  });

  test('the Cấp độ board ranks Ngộ Đạo above a bare level 99', () {
    expect(rankScore(6, 99, 0), 699000);
    expect(rankScore(6, 99, 12), greaterThan(rankScore(6, 99, 11)));
    expect(rankScore(6, 99, 1), greaterThan(rankScore(6, 98, 0)));
    final e = LbEntry.fromDoc('u_0', {'name': 'A', 'hanh': 1, 'level': 99, 'rebirths': 6, 'power': 1, 'rk': 699005, 'dao': 5})!;
    expect(LbBoard.rank.valueOf(e), 699005);
    final old = LbEntry.fromDoc('u_1', {'name': 'B', 'hanh': 1, 'level': 50, 'rebirths': 2, 'power': 1})!;
    expect(old.rk, 250000);
  });
}

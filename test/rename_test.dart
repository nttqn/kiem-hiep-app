import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_hiep/core/hanh.dart';
import 'package:kiem_hiep/core/hero.dart';
import 'package:kiem_hiep/core/rename.dart';
import 'package:kiem_hiep/services/sync_plan.dart';

void main() {
  const t0 = 1800000000000;

  test('rename once a week, the old name kept and saved', () {
    final h = HeroData(name: 'Cũ', hanh: Hanh.kim);
    expect(h.canRename(t0), isTrue);
    expect(h.rename('Mới', t0), isTrue);
    expect(h.name, 'Mới');
    expect(h.oldNames, ['Cũ']);
    expect(h.canRename(t0 + renameCooldownMs - 1), isFalse);
    expect(h.rename('Khác', t0 + 3600000), isFalse);
    expect(h.canRename(t0 + renameCooldownMs), isTrue);
    final back = HeroData.fromJson(h.toJson());
    expect(back.name, 'Mới');
    expect(back.oldNames, ['Cũ']);
    expect(back.renamedAt, t0);
  });

  test('bad names are refused', () {
    final h = HeroData(name: 'A', hanh: Hanh.kim);
    expect(h.renameProblem('   '), isNotNull);
    expect(h.renameProblem('A'), isNotNull);
    expect(h.renameProblem('x' * (nameMaxLength + 1)), isNotNull);
    expect(h.renameProblem(' Tiêu Dao '), isNull);
    expect(h.rename(' Tiêu Dao ', t0), isTrue);
    expect(h.name, 'Tiêu Dao');
  });

  test('cloud sync still sees a renamed hero as the same one', () {
    final h = HeroData(name: 'Cũ', hanh: Hanh.thuy);
    final before = SlotInfo.ofHero(h);
    h.rename('Mới', t0);
    final after = SlotInfo.ofHero(h);
    expect(sameHero(before, after), isTrue);
    expect(sameHero(after, before), isTrue);
    expect(sameHero(after, SlotInfo.ofHero(HeroData(name: 'Người khác', hanh: Hanh.thuy))), isFalse);
  });
}

import 'dart:math' as math;

import 'gems.dart';
import 'hero.dart';
import 'realm.dart' show realmChestGold;

/// Kỳ ngộ (1.20.0): now and then a field kill turns up a chance meeting:
/// an ẩn sĩ passing on some công lực, an old chest under a tree, herbs by a
/// spring, a tiên nhân's blessing, a torn bí kíp page, a hidden master's
/// challenge, a ma đầu running wild, a falling star. Most pay at once (so
/// the autopilot gets them too); the challenger and the ma đầu are fights.
///
/// Each kind seen [kyPageNeed] times fills its page of Kỳ ngộ phổ (in Đồ
/// giám), taken once for a gift; all pages and the totals give titles.

/// Chance per field kill, and per boss or tinh anh; at most [kyDaily] a
/// Vietnam day, from level [kyMinLevel].
const double kyChance = 0.005;
const double kyBigChance = 0.08;
const int kyDaily = 5;
const int kyMinLevel = 8;

enum KyNgo {
  anSi('Ẩn sĩ truyền công', 'Một ẩn sĩ đi ngang truyền cho bạn chút công lực.', 20),
  ruongCo('Rương cổ gốc cây', 'Dưới gốc cổ thụ lộ ra một rương báu bị chôn quên.', 20),
  linhDuoc('Linh dược ven suối', 'Bên suối mọc một khóm linh thảo, đủ chế thêm dược.', 15),
  tienChi('Tiên nhân chỉ lộ', 'Tiên nhân điểm hóa: một lúc luyện công được nhiều EXP và lượng hơn.', 12),
  biKip('Bí kíp tàn trang', 'Gió cuốn tới một trang bí kíp rách.', 10),
  caoThu('Cao thủ ẩn danh', 'Một cao thủ che mặt chặn đường thách đấu. Thắng thì có quà.', 12),
  maDau('Ma đầu tác loạn', 'Ma đầu cùng lâu la kéo tới. Hạ nó để lấy chiến lợi phẩm lớn.', 7),
  thienThach('Thiên thạch rơi', 'Một ngôi sao băng rơi gần đó, để lại khoáng thạch quý.', 4);

  const KyNgo(this.label, this.desc, this.weight);
  final String label, desc;
  final int weight;
}

KyNgo rollKyNgo(math.Random r) {
  final total = KyNgo.values.fold<int>(0, (a, k) => a + k.weight);
  var x = r.nextInt(total);
  for (final k in KyNgo.values) {
    if (x < k.weight) return k;
    x -= k.weight;
  }
  return KyNgo.anSi;
}

/// Ẩn sĩ: EXP as a share of the level's bar.
const double kyAnSiShare = 0.12;

/// Tiên nhân chỉ lộ: fighting seconds of +[kyBlessBonus] EXP and lượng.
const double kyBlessSec = 600;
const double kyBlessBonus = 0.3;

/// Linh dược: herbs of the land's tier, and potions.
const int kyHerbs = 4;
const int kyPots = 20;

/// The fights: elite keys, names, and how much tougher than the land.
const String kyCaoThuKey = 'ky_caothu';
const String kyMaDauKey = 'ky_madau';
const String kyCaoThuName = 'Cao Thủ Ẩn Danh';
const String kyMaDauName = 'Ma Đầu Tác Loạn';
const int kyMaDauMinions = 4;

/// Tinh Hoa from the fights, from level [kyEssenceLevel].
const int kyEssenceLevel = 50;
const int kyCaoThuEssence = 3;
const int kyMaDauEssence = 5;

/// The ma đầu's Mảnh Hoàng Kim chance (bosses' level rule).
const double kyMaDauShardChance = 0.3;

/// Thiên thạch: Thần Thiết once reborn, else gems a tier up.
const int kyStarIron = 2;
const int kyStarGems = 2;

/// Kỳ ngộ phổ: meetings of a kind that fill its page.
const int kyPageNeed = 3;
const String kyAllTitle = 'Phúc Duyên Thâm Hậu';
const Map<int, String> kyTotalTitles = {50: 'Kỳ Duyên Khách', 200: 'Thiên Mệnh Chi Tử'};

/// Lượng in an old chest at [level].
int kyChestGold(int level, int rebirths, double goldMul) =>
    (realmChestGold(level) * 3 * (1 + rebirthGold * rebirths) * goldMul).round();

/// A page's gift: lượng, gems of tier [kyPageGemTier] and Tinh Hoa.
int kyPageGold(int level, int rebirths) => ((2000 + 300 * level) * (1 + rebirthGold * rebirths)).round();
const int kyPageGems = 2;
const int kyPageGemTier = 3;
const int kyPageEssence = 5;

extension KyNgoHero on HeroData {
  void kyRollDay(String day) {
    if (kyDay == day) return;
    kyDay = day;
    kyToday = 0;
  }

  int kyLeft(String day) {
    kyRollDay(day);
    return math.max(0, kyDaily - kyToday);
  }

  bool get kyOpen => level >= kyMinLevel || rebirths > 0;

  /// Rolls a meeting off a field kill; the kind when one happens.
  KyNgo? rollKy(String day, bool big, math.Random rng, {KyNgo? force}) {
    if (!kyOpen || kyLeft(day) <= 0) return null;
    if (force == null && rng.nextDouble() >= (big ? kyBigChance : kyChance)) return null;
    var k = force ?? rollKyNgo(rng);
    if (k == KyNgo.biKip && !manualOpen) k = KyNgo.anSi;
    kyToday++;
    kyTotal++;
    kyCount[k.name] = (kyCount[k.name] ?? 0) + 1;
    return k;
  }

  /// Titles for the totals reached; the lines to show.
  List<String> kyTitles() => [
        for (final e in kyTotalTitles.entries)
          if (kyTotal >= e.key && seasonTitles.add(e.value)) 'Danh hiệu « ${e.value} »',
      ];

  /// Pays a meeting that needs no fight; the lines to show (the world adds
  /// the chest's drops and the fights itself). [herbTier] is the land's.
  List<String> payKy(KyNgo k, math.Random rng, {int herbTier = 0}) {
    switch (k) {
      case KyNgo.anSi:
        final xp = (expNeeded * kyAnSiShare).round();
        gainExp(xp.toDouble());
        return ['+${(xp * (1 + rebirthExp * rebirths)).round()} EXP'];
      case KyNgo.ruongCo:
        final g = kyChestGold(level, rebirths, goldMul);
        gold += g;
        return ['+$g lượng'];
      case KyNgo.linhDuoc:
        addHerb(herbTier, kyHerbs);
        hpPots += kyPots;
        mpPots += kyPots ~/ 2;
        return ['+$kyHerbs linh thảo, +$kyPots bình máu, +${kyPots ~/ 2} bình nội lực'];
      case KyNgo.tienChi:
        kyBless = kyBlessSec;
        return ['+${(kyBlessBonus * 100).round()}% EXP và lượng trong ${kyBlessSec ~/ 60} phút luyện công'];
      case KyNgo.biKip:
        return [gainManualPage(rng)];
      case KyNgo.thienThach:
        if (rebirths > 0) {
          divineIron += kyStarIron;
          return ['+$kyStarIron Thần Thiết'];
        }
        final g = Gem(hanh, math.min(maxDropTier, dropTier(level, boss: true) + 1));
        addGem(g, kyStarGems);
        return ['+$kyStarGems ${g.name}'];
      case KyNgo.caoThu || KyNgo.maDau:
        return const [];
    }
  }

  /// Tinh Hoa for beating a fight's foe (the world drops the items).
  int kyFightEssence(KyNgo k) {
    if (level < kyEssenceLevel && rebirths == 0) return 0;
    final e = k == KyNgo.maDau ? kyMaDauEssence : kyCaoThuEssence;
    essence += e;
    return e;
  }

  /// Counts Tiên nhân chỉ lộ down while fighting.
  void tickKyBless(double dt) {
    if (kyBless <= 0) return;
    kyBless = math.max(0, kyBless - dt);
    if (kyBless == 0) notices.add(Notice('Tiên nhân chỉ lộ đã hết', color: 0xFFB8A890));
  }

  double get kyBlessMul => kyBless > 0 ? 1 + kyBlessBonus : 1.0;

  // ------------------------------------------------------------ phổ

  int kySeen(KyNgo k) => kyCount[k.name] ?? 0;
  bool kyPageReady(KyNgo k) => kySeen(k) >= kyPageNeed && !kyClaimed.contains(k.name);
  int get kyPagesReady => KyNgo.values.where(kyPageReady).length;

  List<String> kyClaimPage(KyNgo k) {
    if (!kyPageReady(k)) return const [];
    kyClaimed.add(k.name);
    final g = kyPageGold(level, rebirths);
    gold += g;
    final gem = Gem(hanh, kyPageGemTier);
    addGem(gem, kyPageGems);
    essence += kyPageEssence;
    final lines = ['Kỳ ngộ phổ · ${k.label}', '+$g lượng', '+$kyPageGems ${gem.name}', '+$kyPageEssence Tinh Hoa'];
    if (kyClaimed.length >= KyNgo.values.length && seasonTitles.add(kyAllTitle)) lines.add('Danh hiệu « $kyAllTitle »');
    return lines;
  }

  // ------------------------------------------------------------ save

  List<Object> kyToJson() => [kyDay, kyToday, kyTotal, kyCount, kyClaimed.toList(), kyBless];

  void kyFromJson(Object? o) {
    if (o is! List || o.length < 6) return;
    try {
      kyDay = o[0] as String;
      kyToday = (o[1] as num).toInt().clamp(0, kyDaily);
      kyTotal = math.max(0, (o[2] as num).toInt());
      kyCount
        ..clear()
        ..addAll({
          for (final e in (o[3] as Map).entries)
            if (KyNgo.values.any((k) => k.name == e.key)) '${e.key}': math.max(0, (e.value as num).toInt()),
        });
      kyClaimed
        ..clear()
        ..addAll([for (final v in o[4] as List) if (KyNgo.values.any((k) => k.name == v)) '$v']);
      kyBless = ((o[5] as num).toDouble()).clamp(0, kyBlessSec);
    } catch (_) {}
  }
}

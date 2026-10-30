import 'dart:math' as math;

import 'content.dart';
import 'hero.dart';
import 'items.dart';

// ------------------------------------------------------------- offline

/// Time away that counts toward closed-door training.
const Duration offlineCap = Duration(hours: 8);
const Duration offlineMin = Duration(minutes: 5);

class OfflineReward {
  const OfflineReward(this.away, this.exp, this.gold);
  final Duration away;
  final int exp;
  final int gold;
}

/// What [h] earned while the game was closed for [away]: about two kills a
/// minute at the hero's level, a small fraction of active play.
OfflineReward? offlineReward(HeroData h, Duration away) {
  if (away < offlineMin) return null;
  final t = away > offlineCap ? offlineCap : away;
  final minutes = t.inSeconds / 60;
  final exp = (mobExpAt(h.level) * 2 * minutes).round();
  final gold = ((1 + 0.4 * h.level) * 1.0 * minutes).round();
  return OfflineReward(t, h.expFull ? 0 : exp, gold);
}

// ------------------------------------------------------------- login gifts

enum GiftKind { gold, hpPots, mpPots, item }

class LoginGift {
  const LoginGift(this.kind, this.label, {this.amount = 0, this.rarity});
  final GiftKind kind;
  final String label;
  final int amount;
  final Rarity? rarity;
}

/// The seven-day cycle, scaled to the hero's level.
List<LoginGift> loginGifts(int level) {
  int g(double k) => ((200 + level * 40) * k).round();
  return [
    LoginGift(GiftKind.gold, 'Lượng', amount: g(1)),
    const LoginGift(GiftKind.hpPots, 'Kim Sang Dược', amount: 20),
    LoginGift(GiftKind.gold, 'Lượng', amount: g(1.5)),
    const LoginGift(GiftKind.mpPots, 'Ngưng Thần Đan', amount: 20),
    const LoginGift(GiftKind.item, 'Trang bị Quý', rarity: Rarity.rare),
    LoginGift(GiftKind.gold, 'Lượng', amount: g(3)),
    const LoginGift(GiftKind.item, 'Trang bị Hiếm', rarity: Rarity.epic),
  ];
}

/// Gives today's gift if not taken yet. Returns a line describing it, or
/// null if already claimed today.
String? claimLoginGift(HeroData h, String today, math.Random rng) {
  if (h.lastLoginDate == today) return null;
  final gift = loginGifts(h.level)[h.loginDay % 7];
  String line;
  switch (gift.kind) {
    case GiftKind.gold:
      h.gold += gift.amount;
      line = '+${gift.amount} lượng';
    case GiftKind.hpPots:
      h.hpPots += gift.amount;
      line = '+${gift.amount} Kim Sang Dược';
    case GiftKind.mpPots:
      h.mpPots += gift.amount;
      line = '+${gift.amount} Ngưng Thần Đan';
    case GiftKind.item:
      final it = makeItem(
        slot: Slot.values[rng.nextInt(Slot.values.length)],
        level: h.level,
        rarity: gift.rarity!,
        sect: h.sect,
        rng: rng,
      );
      h.addItem(it);
      line = '${it.name} [${it.rarity.label}]';
  }
  h.lastLoginDate = today;
  h.loginDay = (h.loginDay + 1) % 7;
  final month = h.monthCheckIn(today, rng);
  h.recompute();
  return [line, ...month].join('\n');
}

// ------------------------------------------------------------- achievements

class AchDef {
  const AchDef(this.id, this.name, this.desc, this.title, this.goal, this.gold, this.progress);
  final String id;
  final String name;
  final String desc;

  /// Title (danh hiệu) the player may wear once this is claimed.
  final String title;
  final int goal;
  final int gold;
  final int Function(HeroData h) progress;

  bool reached(HeroData h) => progress(h) >= goal;
}

int _threeStars(HeroData h) => h.dungeonStars.values.where((s) => s >= 3).length;
int _cleared(HeroData h) => h.dungeonStars.values.where((s) => s > 0).length;

final achievements = <AchDef>[
  AchDef('kill100', 'Sơ nhập giang hồ', 'Hạ 100 quái', 'Tân Thủ', 100, 300, (h) => h.kills),
  AchDef('kill1000', 'Trảm yêu trừ ma', 'Hạ 1.000 quái', 'Hiệp Khách', 1000, 2000, (h) => h.kills),
  AchDef('kill10000', 'Vạn nhân địch', 'Hạ 10.000 quái', 'Vạn Nhân Địch', 10000, 20000, (h) => h.kills),
  AchDef('lv10', 'Tiểu thành', 'Đạt cấp 10', 'Thiếu Hiệp', 10, 500, (h) => h.level),
  AchDef('lv30', 'Đại thành', 'Đạt cấp 30', 'Đại Hiệp', 30, 4000, (h) => h.level),
  AchDef('lv50', 'Nhất đại tông sư', 'Đạt cấp 50', 'Tông Sư', 50, 12000, (h) => h.level),
  AchDef('lv80', 'Võ lâm chí tôn', 'Đạt cấp 80', 'Võ Lâm Chí Tôn', 80, 50000, (h) => h.level),
  AchDef('lv90', 'Thiên hạ vô song', 'Đạt cấp 90', 'Vô Song', 90, 80000, (h) => h.level),
  AchDef('lv99', 'Phá toái hư không', 'Đạt cấp 99', 'Võ Thánh', 99, 150000, (h) => h.level),
  AchDef('cs1', 'Tái sinh', 'Chuyển sinh lần đầu', 'Tái Sinh Hiệp Khách', 1, 100000, (h) => h.rebirths),
  AchDef('cs5', 'Ngũ chuyển', 'Chuyển sinh 5 lần', 'Ngũ Chuyển Chân Nhân', 5, 500000, (h) => h.rebirths),
  AchDef('boss1', 'Hạ đầu lĩnh', 'Đánh bại 1 đầu lĩnh', 'Dũng Sĩ', 1, 400, (h) => h.bossKills),
  AchDef('boss25', 'Săn đầu lĩnh', 'Đánh bại 25 đầu lĩnh', 'Thợ Săn Đầu Lĩnh', 25, 8000, (h) => h.bossKills),
  AchDef('dungeon5', 'Vượt ải', 'Vượt 5 ải khác nhau', 'Phá Trận Sư', 5, 2500, _cleared),
  AchDef('dungeonAll', 'Thông quan', 'Vượt cả 14 ải', 'Thông Quan Thiên Hạ', 14, 25000, _cleared),
  AchDef('star5', 'Thần tốc', '3 sao ở 5 ải', 'Phong Tốc', 5, 4000, _threeStars),
  AchDef('starAll', 'Hoàn mỹ', '3 sao ở cả 14 ải', 'Hoàn Mỹ Vô Khuyết', 14, 40000, _threeStars),
  AchDef('main10', 'Hành hiệp', 'Hoàn thành 10 nhiệm vụ chính tuyến', 'Nghĩa Sĩ', 10, 2000, (h) => h.mainQuest),
  AchDef('mainAll', 'Diệt ma', 'Hoàn thành toàn bộ chính tuyến', 'Cứu Thế Anh Hùng', mainQuests.length, 30000,
      (h) => h.mainQuest),
  AchDef('lh1', 'Luân hồi', 'Hoàn thành một hồi Luân Hồi', 'Luân Hồi Hiệp Khách', 1, 60000, (h) => h.rbDone),
  AchDef('lh5', 'Ngũ thế luân hồi', 'Hoàn thành cả 5 hồi Luân Hồi', 'Võ Lâm Chí Tôn', 5, 600000, (h) => h.rbDone),
  AchDef('plus5', 'Thợ rèn', 'Cường hóa một món lên +5', 'Thiết Thủ', 5, 1500, (h) => h.bestPlus),
  AchDef('plus10', 'Thần binh', 'Cường hóa một món lên +10', 'Thần Binh Chủ', 10, 15000, (h) => h.bestPlus),
  AchDef('legend', 'Bảo vật', 'Sở hữu một trang bị Truyền thuyết', 'Bảo Chủ', 1, 5000,
      (h) => [...h.bag, ...h.equip.values].any((i) => i.rarity == Rarity.legend) || h.ownedLegend ? 1 : 0),
];

final Map<String, AchDef> achById = {for (final a in achievements) a.id: a};

/// Reached but not yet claimed.
List<AchDef> claimable(HeroData h) =>
    [for (final a in achievements) if (!h.achClaimed.contains(a.id) && a.reached(h)) a];

bool claimAchievement(HeroData h, AchDef a) {
  if (h.achClaimed.contains(a.id) || !a.reached(h)) return false;
  h.achClaimed.add(a.id);
  h.gold += a.gold;
  return true;
}

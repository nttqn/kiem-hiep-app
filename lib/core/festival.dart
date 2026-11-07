import 'dart:math' as math;

import 'alchemy.dart';
import 'content.dart';
import 'costumes.dart';
import 'gems.dart';
import 'hanh.dart';
import 'hero.dart';
import 'live_event.dart';
import 'mount_skins.dart';
import 'world_boss.dart' show vnDayKey;

/// Lễ hội theo mùa (1.11.0): a festival runs for a few weeks with its own
/// land (monsters at the hero's level), a currency dropped there, three
/// daily tasks and an exchange shop that stays open [FestDef.shopDays] after
/// the land closes. The dates are in the app; a console event with
/// `fest: <id>` (live_event.dart) can open one on other days too.
/// Đông Chí first; Tết reuses all of it with its own [FestDef].
class FestDef {
  const FestDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.from,
    required this.until,
    this.shopDays = 5,
    required this.coin,
    required this.landName,
    required this.landDesc,
    required this.theme,
    required this.mobs,
    required this.boss,
    required this.costume,
    required this.skin,
    required this.title,
    required this.shop,
  });

  final String id, name, desc;

  /// Vietnam days, both inclusive.
  final String from, until;
  final int shopDays;

  /// The currency's name ('Hoa Tuyết').
  final String coin;
  final String landName, landDesc;
  final MapTheme theme;
  final List<String> mobs;
  final String boss;

  /// Rewards kept for good: an outfit, a mount look, a title.
  final String costume, skin, title;
  final List<FestItem> shop;
}

enum FestReward { costume, skin, title, gold, gems, stones, shards, iron, soulPills, pill, souls }

class FestItem {
  const FestItem(this.id, this.reward, this.price, this.limit, {this.n = 1, this.pill = ''});
  final String id;
  final FestReward reward;
  final int price;

  /// Times it can be bought this festival.
  final int limit;
  final int n;
  final String pill;
}

/// Coins a kill drops (elites and bosses more), and the day's cap from kills.
const double festCoinChance = 0.4;
const int festEliteCoins = 6;
const int festBossCoins = 25;
const int festDayCap = 260;

/// Daily tasks: kills on the festival land (two steps) and its boss.
const int festKillsA = 60, festKillsB = 180;
const int festTaskCoins = 40, festBossTaskCoins = 60;

/// Gói lễ hội (store product, once a festival a hero).
const String skuFest = 'kh_goi_le_hoi';
const int festPackCoins = 800;
const int festPackStones = 30;

const festivals = <FestDef>[
  FestDef(
    id: 'dongchi',
    name: 'Lễ hội Đông Chí',
    desc: 'Đêm dài nhất năm, giang hồ treo đèn đón đông. Băng yêu từ Tuyết Lĩnh tràn xuống, '
        'hạ chúng nhặt Hoa Tuyết đổi ngoại trang, thú cưỡi và bảo vật.',
    from: '20261215',
    until: '20270104',
    coin: 'Hoa Tuyết',
    landName: 'Tuyết Lĩnh Đăng Hội',
    landDesc: 'Đèn lồng đỏ trên núi tuyết, băng yêu kéo về phá hội. Quái mạnh theo cấp của bạn.',
    theme: MapTheme.snow,
    mobs: ['fdSnowman', 'fdBoar', 'fdLantern'],
    boss: 'fdDragon',
    costume: 'fest_hanmai',
    skin: 'nau_tuyet',
    title: 'Đông Chí Hiệp Khách',
    shop: [
      FestItem('costume', FestReward.costume, 1500, 1),
      FestItem('skin', FestReward.skin, 900, 1),
      FestItem('title', FestReward.title, 500, 1),
      FestItem('stones', FestReward.stones, 90, 15, n: 5),
      FestItem('shards', FestReward.shards, 110, 12, n: 3),
      FestItem('iron', FestReward.iron, 70, 15, n: 5),
      FestItem('gems', FestReward.gems, 50, 20, n: 1),
      FestItem('souls', FestReward.souls, 160, 5, n: 1),
      FestItem('lpd', FestReward.soulPills, 180, 5, n: 1),
      FestItem('songboi', FestReward.pill, 45, 10, pill: 'songboi'),
      FestItem('gold', FestReward.gold, 30, 30, n: 1),
    ],
  ),
];

final Map<String, FestDef> festById = {for (final f in festivals) f.id: f};

/// The festival whose land is open on [day] (in-app dates or a console
/// event), or null.
FestDef? festOn(String day) {
  for (final f in festivals) {
    if (f.from.compareTo(day) <= 0 && f.until.compareTo(day) >= 0) return f;
  }
  for (final e in eventsOn(day)) {
    final f = festById[e.fest];
    if (f != null) return f;
  }
  return null;
}

/// The festival whose shop is open on [day] (its days plus [FestDef.shopDays]).
FestDef? festShopOn(String day) {
  final open = festOn(day);
  if (open != null) return open;
  for (final f in festivals) {
    if (f.from.compareTo(day) <= 0 && dayAfter(f.until, f.shopDays).compareTo(day) >= 0) return f;
  }
  return null;
}

String dayAfter(String day, int n) {
  final d = DateTime.utc(int.parse(day.substring(0, 4)), int.parse(day.substring(4, 6)), int.parse(day.substring(6, 8)))
      .add(Duration(days: n));
  return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

/// "15/12" for a day key.
String dayLabel(String day) => '${int.parse(day.substring(6, 8))}/${int.parse(day.substring(4, 6))}';

const String festMapPrefix = 'fest_';
bool isFestMap(MapDef m) => m.id.startsWith(festMapPrefix);

/// Monster strength by rebirths, so a reborn hero meets a fair fight there
/// (Cửu U is 8 at five, Huyết Hải 16 at six): a little easier than those,
/// a festival is for everyone.
const festMulByRebirth = [1.0, 1.4, 2.0, 2.8, 3.8, 5.0, 8.0];

/// The festival land for [h]: monsters at the hero's level.
MapDef festMap(FestDef f, HeroData h) {
  final lv = h.level.clamp(5, maxLevel);
  return MapDef(
    id: '$festMapPrefix${f.id}',
    name: f.landName,
    desc: f.landDesc,
    minLv: lv,
    maxLv: lv,
    theme: f.theme,
    mobs: f.mobs,
    boss: f.boss,
    mul: festMulByRebirth[h.rebirths.clamp(0, festMulByRebirth.length - 1)],
  );
}

/// Hero level to take part.
const int festOpenLevel = 10;


/// Short labels of a shop item for [h].
String festItemLabel(FestDef f, FestItem it, HeroData h) => switch (it.reward) {
      FestReward.costume => 'Ngoại trang ${costumeById[f.costume]?.name ?? ''}',
      FestReward.skin => 'Ngoại hình thú cưỡi ${skinById[f.skin]?.name ?? ''}',
      FestReward.title => 'Danh hiệu « ${f.title} »',
      FestReward.gold => '${_dots(festGold(h))} lượng',
      FestReward.gems => '${it.n} ${gemTierNames[festGemTier(h) - 1]}',
      FestReward.stones => '${it.n} Tinh Thạch',
      FestReward.shards => '${it.n} Mảnh Hoàng Kim',
      FestReward.iron => '${it.n} Thần Thiết',
      FestReward.souls => '${it.n} Hung Thú Tinh Phách',
      FestReward.soulPills => '${it.n} Linh Phách Đơn',
      FestReward.pill => pillById[it.pill]?.name ?? it.pill,
    };

int festGold(HeroData h) => 2000 * (h.level + 10) * (1 + h.rebirths);
int festGemTier(HeroData h) => math.min(maxRewardGemTier, 1 + (h.level + 20 * h.rebirths) ~/ 20);

String _dots(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

extension FestExtras on HeroData {
  bool get festOpenFor => level >= festOpenLevel || rebirths > 0;

  /// Moves to festival [f]: a new festival starts the coins and limits over.
  void festRoll(FestDef f, String day) {
    if (festId != f.id) {
      festId = f.id;
      festCoins = 0;
      festBought.clear();
      festPack = false;
    }
    if (festDay != day) {
      festDay = day;
      festEarned = 0;
      festKills = 0;
      festBoss = 0;
      festTasks = 0;
    }
  }

  /// A kill on the festival land: coins (up to the day's cap) and task
  /// progress. What came in, or 0.
  int festKill(MobDef m, {bool elite = false, required math.Random rng}) {
    final day = vnDayKey();
    final f = festOn(day);
    if (f == null) return 0;
    festRoll(f, day);
    festKills++;
    if (m.boss) festBoss++;
    var n = m.boss ? festBossCoins : (elite ? festEliteCoins : (rng.nextDouble() < festCoinChance ? 1 : 0));
    n = math.min(n, math.max(0, festDayCap - festEarned));
    festEarned += n;
    festCoins += n;
    return n;
  }

  /// The day's tasks: (label, done, ready to claim, coins).
  List<(String, int, int, int)> festTaskList() => [
        ('Hạ $festKillsA quái lễ hội', math.min(festKills, festKillsA), festKillsA, festTaskCoins),
        ('Hạ $festKillsB quái lễ hội', math.min(festKills, festKillsB), festKillsB, festTaskCoins),
        ('Hạ boss lễ hội 1 lần', math.min(festBoss, 1), 1, festBossTaskCoins),
      ];

  bool festTaskTaken(int i) => festTasks & (1 << i) != 0;

  int get festTasksReady {
    final day = vnDayKey();
    final f = festOn(day);
    if (f == null) return 0;
    festRoll(f, day);
    var n = 0;
    final t = festTaskList();
    for (var i = 0; i < t.length; i++) {
      if (!festTaskTaken(i) && t[i].$2 >= t[i].$3) n++;
    }
    return n;
  }

  /// Takes task [i]'s coins (not counted against the kill cap).
  int festClaimTask(int i) {
    final day = vnDayKey();
    final f = festOn(day);
    if (f == null) return 0;
    festRoll(f, day);
    final t = festTaskList();
    if (i < 0 || i >= t.length || festTaskTaken(i) || t[i].$2 < t[i].$3) return 0;
    festTasks |= 1 << i;
    festCoins += t[i].$4;
    return t[i].$4;
  }

  int festBoughtOf(FestItem it) => festBought[it.id] ?? 0;

  bool festOwned(FestDef f, FestItem it) => switch (it.reward) {
        FestReward.costume => ownedCostumes.contains(f.costume),
        FestReward.skin => ownedSkins.contains(f.skin),
        FestReward.title => seasonTitles.contains(f.title),
        _ => false,
      };

  bool festCanBuy(FestDef f, FestItem it) =>
      festId == f.id && festCoins >= it.price && festBoughtOf(it) < it.limit && !festOwned(f, it);

  /// Buys [it]; the line to show, or null.
  String? festBuy(FestDef f, FestItem it, math.Random rng) {
    final day = vnDayKey();
    if (festShopOn(day)?.id != f.id) return null;
    if (festId != f.id) festRoll(f, day);
    if (!festCanBuy(f, it)) return null;
    festCoins -= it.price;
    festBought[it.id] = festBoughtOf(it) + 1;
    final label = festItemLabel(f, it, this);
    switch (it.reward) {
      case FestReward.costume:
        ownedCostumes.add(f.costume);
      case FestReward.skin:
        ownedSkins.add(f.skin);
        final s = skinById[f.skin];
        if (s != null && ownsMount(s.mount)) mountSkin[s.mount] = s.id;
      case FestReward.title:
        seasonTitles.add(f.title);
      case FestReward.gold:
        gold += festGold(this);
      case FestReward.gems:
        for (var i = 0; i < it.n; i++) {
          addGem(Gem(Hanh.values[rng.nextInt(5)], festGemTier(this)));
        }
      case FestReward.stones:
        starStones += it.n;
      case FestReward.shards:
        goldShards += it.n;
      case FestReward.iron:
        divineIron += it.n;
      case FestReward.souls:
        beastSouls += it.n;
      case FestReward.soulPills:
        soulPills += it.n;
      case FestReward.pill:
        this.pills[it.pill] = (this.pills[it.pill] ?? 0) + 1;
    }
    recompute();
    return label;
  }

  /// Gói lễ hội bought (always delivers, even after the land closed).
  List<String> grantFestPack() {
    final day = vnDayKey();
    final f = festShopOn(day) ?? festById[festId] ?? festivals.first;
    festRoll(f, day);
    festCoins += festPackCoins;
    starStones += festPackStones;
    festPack = true;
    return ['+$festPackCoins ${f.coin}', '+$festPackStones Tinh Thạch'];
  }
}

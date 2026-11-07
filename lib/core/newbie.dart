import 'items.dart';

/// Tân thủ thất nhật: seven gifts for a new hero, one for each Vietnam day
/// they open the game (days need not be in a row), the last an outfit and
/// a mount, so a new player has a reason to come back the next day.
const int newbieDays = 7;

/// Heroes from before the gifts existed still get them while this low.
const int newbieLegacyLevel = 30;

class NewbieGift {
  const NewbieGift({
    this.gold = 0,
    this.hpPots = 0,
    this.mpPots = 0,
    this.gems = 0,
    this.gemTier = 1,
    this.item,
    this.costume = '',
    this.mount = '',
  });

  final int gold, hpPots, mpPots, gems, gemTier;

  /// A piece of gear of this rarity at the hero's level.
  final Rarity? item;

  /// Outfit and mount ids; one already owned pays [newbieOwnedGold] instead.
  final String costume, mount;
}

/// Gold instead of an outfit or mount the hero already has.
const int newbieOwnedGold = 50000;

const newbieGifts = <NewbieGift>[
  NewbieGift(gold: 5000, hpPots: 30),
  NewbieGift(gems: 2, gemTier: 2, mpPots: 20),
  NewbieGift(gold: 20000, item: Rarity.rare),
  NewbieGift(gems: 3, gemTier: 3, hpPots: 30),
  NewbieGift(costume: 'thanhsam'),
  NewbieGift(gold: 50000, item: Rarity.epic),
  NewbieGift(mount: 'bachma', gems: 2, gemTier: 4),
];

/// Quà mốc cấp: early levels pay at once, so the first hour feels like
/// progress (most new players left within a few days).
const levelGifts = <int, NewbieGift>{
  5: NewbieGift(gold: 2000, hpPots: 20),
  // 1.7.0: the first mount the day riding opens.
  10: NewbieGift(item: Rarity.rare, mpPots: 15, mount: 'nau'),
  15: NewbieGift(gold: 6000, gems: 2, gemTier: 1),
  20: NewbieGift(item: Rarity.epic, hpPots: 20),
  25: NewbieGift(gold: 15000, gems: 2, gemTier: 2),
  // 1.10.0: on to the first rebirth (nearly half the board was a hero of
  // level 50-99 never reborn).
  30: NewbieGift(gold: 30000, gems: 2, gemTier: 2, hpPots: 30),
  40: NewbieGift(item: Rarity.epic, gems: 2, gemTier: 3),
  50: NewbieGift(gold: 80000, gems: 3, gemTier: 3, mpPots: 30),
  60: NewbieGift(item: Rarity.legend, gems: 2, gemTier: 4),
  70: NewbieGift(gold: 150000, gems: 3, gemTier: 4, hpPots: 50),
  80: NewbieGift(item: Rarity.legend, gems: 3, gemTier: 4),
  90: NewbieGift(gold: 300000, item: Rarity.legend, gems: 3, gemTier: 5),
};

/// The next Quà mốc cấp above [level], if any.
int? nextLevelGift(int level) {
  for (final l in levelGifts.keys) {
    if (l > level) return l;
  }
  return null;
}

/// Below this level a death in the field costs no EXP, and a low HP bar
/// drinks a potion by itself.
const int newbieShieldLevel = 20;

/// No interstitial ads for a new hero below this level (1.7.0): the first
/// quarter hour decides whether a player stays.
const int newbieNoAdsLevel = 15;

bool newbieAdFree(int level, int rebirths) => rebirths == 0 && level < newbieNoAdsLevel;
const double newbieAutoPotion = 0.35;

/// Tân thủ: monsters hit a new hero (no rebirth) softer until this level,
/// half as hard at level 1 (1.5.0: nearly every new player died before
/// level 3, melee sects over and over among the wolves).
const int newbieEaseLevel = 12;

double newbieDamageTaken(int level, int rebirths) =>
    rebirths > 0 || level >= newbieEaseLevel ? 1 : 0.5 + 0.5 * (level - 1) / (newbieEaseLevel - 1);

/// How many camp friends join a monster the hero attacks: none for a hero
/// this new, one a little later, then two.
/// Potions a hero under [newbieShieldLevel] is topped up to when they fall.
const int newbieRevivePots = 10;

int newbieAggroFriends(int level, int rebirths) => rebirths > 0 ? 2 : (level < 6 ? 0 : (level < 10 ? 1 : 2));

/// Short labels of [g], for the gift board.
List<String> newbieLabels(NewbieGift g, {String Function(String id)? costumeName, String Function(String id)? mountName}) => [
      if (g.gold > 0) '${_dots(g.gold)} lượng',
      if (g.item != null) 'Trang bị ${g.item!.label}',
      if (g.gems > 0) '${g.gems} ngọc bậc ${g.gemTier}',
      if (g.hpPots > 0) '${g.hpPots} Kim Sang Dược',
      if (g.mpPots > 0) '${g.mpPots} Ngưng Thần Đan',
      if (g.costume.isNotEmpty) 'Ngoại trang ${costumeName?.call(g.costume) ?? g.costume}',
      if (g.mount.isNotEmpty) 'Thú cưỡi ${mountName?.call(g.mount) ?? g.mount}',
    ];

String _dots(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

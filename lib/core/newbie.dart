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
  10: NewbieGift(item: Rarity.rare, mpPots: 15),
  15: NewbieGift(gold: 6000, gems: 2, gemTier: 1),
  20: NewbieGift(item: Rarity.epic, hpPots: 20),
  25: NewbieGift(gold: 15000, gems: 2, gemTier: 2),
};

/// Below this level a death in the field costs no EXP, and a low HP bar
/// drinks a potion by itself.
const int newbieShieldLevel = 20;
const double newbieAutoPotion = 0.35;

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

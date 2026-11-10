import 'dart:math' as math;

import 'content.dart';
import 'hero.dart';
import 'ngo_dao.dart';
import 'weekly_hunt.dart';
import 'world_boss.dart';

/// Bang hội (1.13.0): players band together. A bang grows with its
/// members' cống hiến (Điểm danh, Quyên góp, Boss Bang), and its level
/// gives every member a little more EXP and gold, more seats and more of
/// the Bang hội shop. Boss Bang is fought by the whole bang over a week:
/// its summed damage opens chests for everyone who hit it.
///
/// The bang itself lives in Firestore (services/guild.dart); this is what
/// one hero keeps of it and the rules both sides share.
const int guildOpenLevel = 30;
const int guildCreateGold = 500000;
const int guildNameMin = 2, guildNameMax = 16;
const int guildNoticeMax = 120;
const int guildMaxApplied = 3;

/// Cống hiến (all members, ever) for each bang level from 1.
const List<int> guildLevelExp = [0, 3000, 8000, 18000, 35000, 60000, 100000, 160000, 250000, 400000];
int get guildMaxLevel => guildLevelExp.length;

int guildLevelOf(int contrib) {
  var lv = 1;
  for (var i = 1; i < guildLevelExp.length; i++) {
    if (contrib >= guildLevelExp[i]) lv = i + 1;
  }
  return lv;
}

int guildMaxMembers(int lv) => 20 + 2 * lv;

/// EXP and gold for each member, per bang level.
const double guildPerkPerLv = 0.005;

/// Roles in a bang.
const int roleMember = 0, roleVice = 1, roleLeader = 2;
String guildRoleName(int r) => const ['Thành viên', 'Phó bang', 'Bang chủ'][r.clamp(0, 2)];

/// Điểm danh: once a day.
const int guildSignContrib = 20;

/// Quyên góp: gold for [guildContribPerDonate] cống hiến, up to
/// [guildDonatesPerDay] a day.
const int guildDonatesPerDay = 3;
const int guildContribPerDonate = 30;
int guildDonateGold(int level, int rebirths) => 2000 * level * (1 + rebirths);

// ------------------------------------------------------------- Boss Bang

const int guildBossRuns = 3;
const double guildBossTime = 60;
const int guildBossRunContrib = 15;

/// The week's Boss Bang: the Boss Thế Giới roster in turn, by week.
MobDef guildBossOf(String day) => mobById[worldBossRotation[(huntWeekOf(day) + 3) % worldBossRotation.length]]!;

DungeonDef guildBossDef(String day) {
  final boss = guildBossOf(day);
  return DungeonDef(
    id: 'guildboss',
    name: 'Boss Bang · ${boss.name}',
    mapId: mapOfMob(boss.id)!.id,
    level: 99,
    waves: const [],
    timeLimit: guildBossTime,
    worldBoss: boss.id,
    guild: true,
  );
}

/// Most a hero can add to Boss Bang in a week (the Boss Thế Giới day cap,
/// [guildBossRuns] of its 7 runs, for 7 days); the rules hold the same.
int guildBossWeekCap(int rebirths, int level) => worldBossDayCap(rebirths, level) * 3;

/// The bang's summed damage that opens each chest.
const List<int> guildBossTiers = [300000000, 1000000000, 3000000000, 8000000000, 20000000000];

class GuildChest {
  const GuildChest(this.coins, this.iron, this.pills, this.jade);
  final int coins, iron, pills, jade;
}

const List<GuildChest> guildBossChests = [
  GuildChest(60, 1, 0, 0),
  GuildChest(100, 2, 0, 0),
  GuildChest(150, 3, 5, 0),
  GuildChest(220, 4, 10, 1),
  GuildChest(300, 6, 20, 2),
];

// ------------------------------------------------------------- shop

enum GuildWare { pills, iron, shards, stones, jade }

class GuildOffer {
  const GuildOffer(this.ware, this.name, this.n, this.price, this.limit, this.minLv);
  final GuildWare ware;
  final String name;
  final int n, price, limit, minLv;
}

const List<GuildOffer> guildShop = [
  GuildOffer(GuildWare.pills, 'Linh Phách Đơn', 5, 150, 5, 1),
  GuildOffer(GuildWare.iron, 'Thần Thiết', 3, 120, 5, 1),
  GuildOffer(GuildWare.shards, 'Mảnh Hoàng Kim', 5, 200, 4, 3),
  GuildOffer(GuildWare.stones, 'Đá Thăng Tinh', 10, 180, 4, 4),
  GuildOffer(GuildWare.jade, 'Tiên Ngọc', 1, 400, 2, 6),
];

extension Guild on HeroData {
  bool get guildOpen => level >= guildOpenLevel || rebirths > 0;
  bool get inGuild => guildId.isNotEmpty;

  /// What the bang's level adds to EXP and gold (0 outside one).
  double get guildPerk => inGuild ? guildPerkPerLv * guildLv : 0;

  /// Joined (or made) bang [id]: its cống hiến starts from nothing.
  void joinGuild(String id, String name, int role, int lv) {
    guildId = id;
    guildName = name;
    guildRole = role;
    guildLv = lv;
    guildContrib = 0;
    guildApplied.clear();
  }

  /// Out of the bang (left, kicked or disbanded). Bang coins stay.
  void leaveGuild() {
    guildId = '';
    guildName = '';
    guildRole = roleMember;
    guildLv = 0;
    guildContrib = 0;
  }

  void guildRollDay(String day) {
    if (gDay != day) {
      gDay = day;
      gSigned = false;
      gDonated = 0;
      gBossRuns = 0;
    }
    final w = huntWeekOf(day);
    if (gBossWeek != w) {
      gBossWeek = w;
      gBossDmg = 0;
      gBossClaimed = 0;
    }
    if (gShopWeek != w) {
      gShopWeek = w;
      gShopBought.clear();
    }
  }

  void _contrib(int n) {
    guildContrib += n;
    guildCoins += n;
  }

  bool guildSign(String day) {
    guildRollDay(day);
    if (!inGuild || gSigned) return false;
    gSigned = true;
    _contrib(guildSignContrib);
    return true;
  }

  int get guildDonateCost => guildDonateGold(level, rebirths);

  bool guildDonate(String day) {
    guildRollDay(day);
    if (!inGuild || gDonated >= guildDonatesPerDay || gold < guildDonateCost) return false;
    gold -= guildDonateCost;
    gDonated++;
    _contrib(guildContribPerDonate);
    return true;
  }

  int guildBossLeft(String day) {
    guildRollDay(day);
    return guildBossRuns - gBossRuns;
  }

  bool guildBossStart(String day) {
    if (!inGuild || guildBossLeft(day) <= 0) return false;
    gBossRuns++;
    return true;
  }

  /// A Boss Bang run is over: its damage adds to this week's.
  List<String> guildBossReward(int damage) {
    lastDungeonGold = 0;
    if (damage <= 0) return const ['Chưa gây sát thương.'];
    gBossDmg = math.min(gBossDmg + damage, guildBossWeekCap(rebirths, level));
    _contrib(guildBossRunContrib);
    final g = (worldBossGold(damage) * goldMul).round();
    gold += g;
    lastDungeonGold = g;
    return ['Sát thương: $damage', '+$guildBossRunContrib cống hiến, +$guildBossRunContrib xu Bang', '+$g lượng'];
  }

  /// Chest [i] of this week's Boss Bang, opened by the bang's summed
  /// damage [total]; only for those who hit the boss this week.
  bool guildChestReady(int i, int total) =>
      inGuild && gBossDmg > 0 && total >= guildBossTiers[i] && gBossClaimed & (1 << i) == 0;

  List<String> guildTakeChest(int i, int total) {
    if (!guildChestReady(i, total)) return const [];
    gBossClaimed |= 1 << i;
    final c = guildBossChests[i];
    guildCoins += c.coins;
    divineIron += c.iron;
    soulPills += c.pills;
    final lines = ['+${c.coins} xu Bang', '+${c.iron} Thần Thiết', if (c.pills > 0) '+${c.pills} Linh Phách Đơn'];
    if (c.jade > 0 && daoOpen) {
      tienJade += c.jade;
      lines.add('+${c.jade} Tiên Ngọc');
    }
    return lines;
  }

  int guildBoughtOf(GuildOffer o) => gShopBought[o.ware.name] ?? 0;

  /// Why [o] can't be bought now, or null.
  String? guildBuyBlock(GuildOffer o, String day) {
    guildRollDay(day);
    if (!inGuild) return 'Cần vào bang';
    if (guildLv < o.minLv) return 'Bang cấp ${o.minLv}';
    if (guildBoughtOf(o) >= o.limit) return 'Hết lượt tuần';
    if (o.ware == GuildWare.jade && !daoOpen) return 'Cần Ngộ Đạo';
    if (guildCoins < o.price) return 'Thiếu xu Bang';
    return null;
  }

  bool guildBuy(GuildOffer o, String day) {
    if (guildBuyBlock(o, day) != null) return false;
    guildCoins -= o.price;
    gShopBought[o.ware.name] = guildBoughtOf(o) + 1;
    switch (o.ware) {
      case GuildWare.pills:
        soulPills += o.n;
      case GuildWare.iron:
        divineIron += o.n;
      case GuildWare.shards:
        goldShards += o.n;
      case GuildWare.stones:
        starStones += o.n;
      case GuildWare.jade:
        tienJade += o.n;
    }
    return true;
  }
}

// ------------------------------------------------------------- Hảo hữu

/// A friend: their board row (`{uid}_{slot}`), and their name and element
/// as last seen.
class Friend {
  Friend(this.row, this.name, this.hanh);
  final String row;
  String name;
  int hanh;

  List<Object> toJson() => [row, name, hanh];

  static Friend? fromJson(Object? o) {
    if (o is! List || o.length < 3) return null;
    try {
      return Friend(o[0] as String, o[1] as String, (o[2] as num).toInt().clamp(0, 4));
    } catch (_) {
      return null;
    }
  }
}

const int maxFriends = 30;

/// Gifts taken a day, and what one gives: about a Sư môn duty's gold,
/// half again per rebirth as monsters' gold grows (rebirthGold), so ten a
/// day are a small daily treat (41,600 at rebirth 6, level 99), not an
/// income (was 300 × level × (rebirths + 1): 2 million a day).
const int friendGiftsPerDay = 10;
int friendGiftGold(int level, int rebirths) => ((50 + 10 * level) * (1 + rebirthGold * rebirths)).round();

extension Friends on HeroData {
  bool isFriend(String row) => friends.any((f) => f.row == row);

  bool addFriend(String row, String name, int hanh) {
    if (isFriend(row) || friends.length >= maxFriends) return false;
    friends.add(Friend(row, name, hanh));
    return true;
  }

  void removeFriend(String row) => friends.removeWhere((f) => f.row == row);

  void friendRollDay(String day) {
    if (friendDay == day) return;
    friendDay = day;
    friendSent.clear();
    friendTaken = 0;
  }

  bool canGift(String row, String day) {
    friendRollDay(day);
    return isFriend(row) && !friendSent.contains(row);
  }

  void markGifted(String row, String day) {
    friendRollDay(day);
    friendSent.add(row);
  }

  int giftsLeft(String day) {
    friendRollDay(day);
    return friendGiftsPerDay - friendTaken;
  }

  /// Takes one gift that came in; 0 when today's are used up.
  int takeGift(String day) {
    if (giftsLeft(day) <= 0) return 0;
    friendTaken++;
    final g = friendGiftGold(level, rebirths);
    gold += g;
    return g;
  }
}

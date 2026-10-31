import 'dart:math' as math;

import 'content.dart';

/// Bí cảnh: a wide hidden land behind each field map, explored one run at a
/// time. The map starts under fog; somewhere in it are three trận nhãn
/// (each guarded by a Hộ Trận Sứ), treasure chests, old stone shrines that
/// bless the run, and travellers held by monsters. Lighting the three trận
/// nhãn breaks the seal on the lair, and beating its master ends the run.
///
/// The layout is drawn anew from a seed every run, so no two are the same.
class RealmDef {
  const RealmDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.mapId,
    required this.level,
  });

  final String id;
  final String name;
  final String desc;

  /// The field map whose land, monsters and master the realm borrows.
  final String mapId;

  /// Opens two levels below this; monsters never come weaker than it.
  final int level;

  MapDef get map => mapById[mapId]!;
  int get openLv => math.max(1, level - 2);
}

const realms = <RealmDef>[
  RealmDef(id: 'r1', name: 'Thanh Phong Cốc', mapId: 'ngoaithanh', level: 6,
      desc: 'Thung lũng gió xanh sau Lạc An, sơn tặc giấu của cướp trong hang đá.'),
  RealmDef(id: 'r2', name: 'Tử Trúc Mê Lâm', mapId: 'truclam', level: 13,
      desc: 'Rừng trúc tím bày trận cổ, người lạc vào ít ai tìm được lối ra.'),
  RealmDef(id: 'r3', name: 'U Minh Địa Huyệt', mapId: 'hacphong', level: 22,
      desc: 'Hang sâu dưới Hắc Phong Động, mộ cổ chôn theo nhiều báu vật.'),
  RealmDef(id: 'r4', name: 'Lâu Lan Phế Thành', mapId: 'hoangsa', level: 31,
      desc: 'Tòa thành vùi trong cát, kho báu thương đoàn còn nằm dưới đổ nát.'),
  RealmDef(id: 'r5', name: 'Hàn Băng Cổ Động', mapId: 'bangnguyen', level: 41,
      desc: 'Băng động ngàn năm, bia đá khắc võ công tiền nhân ẩn trong tuyết.'),
  RealmDef(id: 'r6', name: 'Xích Viêm Cấm Địa', mapId: 'hoadiem', level: 51,
      desc: 'Miệng núi lửa bị phong ấn, linh khí hỏa hệ dồi dào nhất thiên hạ.'),
  RealmDef(id: 'r7', name: 'Huyết Ma Mật Cảnh', mapId: 'magiao', level: 64,
      desc: 'Mật địa của Huyết Ma Giáo, nơi giam giữ người các phái bị bắt.'),
  RealmDef(id: 'r8', name: 'Vân Tiêu Tiên Cảnh', mapId: 'vanvu', level: 78,
      desc: 'Tiên cảnh trên tầng mây, chỉ hiện ra khi sương tan.'),
  RealmDef(id: 'r9', name: 'Kiếm Mộ Hoa Sơn', mapId: 'hoason', level: 92,
      desc: 'Mộ kiếm của các đời kiếm khách, kiếm hồn vẫn canh giữ di vật.'),
];

final Map<String, RealmDef> realmById = {for (final r in realms) r.id: r};

/// The realm's land.
const double realmWidth = 5200, realmHeight = 3400;

/// Seconds a run lasts.
const double realmTime = 600;

/// Runs a day for free, and more for a rewarded ad.
const int realmFreeRuns = 3;
const int realmAdRuns = 2;

const int realmChests = 6;
const int realmPillars = 3;
const int realmShrines = 3;
const int realmCaptives = 2;

/// The fog lifts in cells of this size, within [realmSight] of the hero.
const double fogCell = 200;
const double realmSight = 520;
final int fogCols = (realmWidth / fogCell).ceil();
final int fogRows = (realmHeight / fogCell).ceil();

/// Share of the land to uncover for the exploration star.
const double realmExploreStar = 0.7;

/// Monster level in a realm: the hero's own, within the realm's band.
int realmLevel(RealmDef r, int heroLevel) => heroLevel.clamp(r.level, math.max(r.level, r.map.maxLv));

/// A star for the master, one for every chest, one for the land uncovered.
int realmStarsFor({required bool boss, required int chests, required double explored}) =>
    !boss ? 0 : 1 + (chests >= realmChests ? 1 : 0) + (explored >= realmExploreStar ? 1 : 0);

/// The run as a [DungeonDef], so the battle screen, revive and results
/// treat it like any other trial.
DungeonDef realmDungeon(int i, int heroLevel) {
  final r = realms[i];
  return DungeonDef(
    id: r.id,
    name: r.name,
    mapId: r.mapId,
    level: realmLevel(r, heroLevel),
    waves: const [],
    timeLimit: realmTime,
    realm: i + 1,
  );
}

enum PoiKind { chest, pillar, shrine, captive, lair, merchant, vault, lever, star }

/// Biến cố: one or two of these happen in every run.
enum RealmEvent {
  merchant('Thương nhân bí ẩn', 'một thương nhân lạ bày hàng giá hời đâu đó'),
  wanderer('Ma đầu lang bạt', 'một ma đầu sẽ truy đuổi bạn, hạ được thì thưởng lớn'),
  starfall('Mưa sao băng', 'giữa chừng sao rơi quanh bạn, nhặt lấy rương sao'),
  vault('Mật thất cơ quan', 'bật 3 cơ quan đúng thứ tự để mở mật thất');

  const RealmEvent(this.label, this.desc);
  final String label, desc;
}

/// The three lever marks of a mật thất, in the order they are drawn.
const vaultSymbols = ['Nhật', 'Nguyệt', 'Tinh'];

/// When the stars fall, and how many.
const double starfallFrom = 100, starfallTo = 260;
const int starfallChests = 5;

/// When the ma đầu shows up.
const double wandererAt = 75;

/// Blessings of the stone shrines, for the rest of the run.
enum RealmBuff {
  power('Công lực +25%'),
  swift('Thân pháp: tốc chạy +30%'),
  vigor('Hồi xuân: hồi 2% sinh lực mỗi giây');

  const RealmBuff(this.label);
  final String label;
}

/// A place of interest in a realm.
class Poi {
  Poi(this.kind, this.x, this.y, {this.index = 0});
  final PoiKind kind;
  final double x, y;

  /// Shrine: its [RealmBuff]; captive: who they are; lever: its mark in
  /// [vaultSymbols].
  final int index;

  /// Opened, lit, prayed at or freed.
  bool done = false;

  /// The Hộ Trận Sứ of a trận nhãn, by mob uid (-1 once there is none).
  int guard = -1;
}

/// Travellers to free, and what they say.
const realmCaptiveLines = <(String, String)>[
  ('Tiều phu', 'Đa tạ đại hiệp! Lão chỉ vào rừng đốn củi thì bị bắt.'),
  ('Thương nhân', 'Hàng hóa mất cả rồi, chút lộ phí này xin tặng ân nhân.'),
  ('Tiểu đệ tử', 'Sư phụ sai đệ tử đi hái thuốc, không ngờ gặp nạn.'),
  ('Thôn nữ', 'Ân cứu mạng này, tiểu nữ xin ghi lòng tạc dạ.'),
  ('Lão tiêu sư', 'Tiêu cục bị cướp, may có đại hiệp ra tay.'),
  ('Thư sinh', 'Tại hạ lên kinh ứng thí, lạc đường vào chốn này.'),
];

/// Where camps go, as (x, y, kind, count): kind indexes the map's monsters.
class RealmCamp {
  const RealmCamp(this.x, this.y, this.kind, this.count);
  final double x, y;
  final int kind;
  final int count;
}

/// One run's layout.
class RealmLayout {
  RealmLayout(this.pois, this.camps, {this.events = const [], this.vaultOrder = const []});
  final List<Poi> pois;
  final List<RealmCamp> camps;

  /// This run's biến cố.
  final List<RealmEvent> events;

  /// The lever marks ([vaultSymbols] indexes) in the order that opens the
  /// mật thất.
  final List<int> vaultOrder;

  Iterable<Poi> of(PoiKind k) => pois.where((p) => p.kind == k);
  Poi get lair => pois.firstWhere((p) => p.kind == PoiKind.lair);

  /// Entrance of every realm: the west edge, halfway up.
  static const double gateX = 260;
  static double get gateY => realmHeight / 2;

  static RealmLayout generate(int seed, {int kinds = 3, RealmEvent? force}) {
    final r = math.Random(seed);
    final placed = <List<double>>[];
    const w = realmWidth, h = realmHeight;

    bool free(double x, double y, double gap) =>
        placed.every((p) => (p[0] - x) * (p[0] - x) + (p[1] - y) * (p[1] - y) >= gap * gap) &&
        (x - gateX) * (x - gateX) + (y - gateY) * (y - gateY) >= 700 * 700;

    (double, double) spot(double x0, double x1, double gap) {
      for (var i = 0; i < 400; i++) {
        final x = x0 + r.nextDouble() * (x1 - x0);
        final y = 260 + r.nextDouble() * (h - 520);
        if (free(x, y, gap)) {
          placed.add([x, y]);
          return (x, y);
        }
      }
      final x = x0 + r.nextDouble() * (x1 - x0), y = 260 + r.nextDouble() * (h - 520);
      placed.add([x, y]);
      return (x, y);
    }

    final pois = <Poi>[];
    // The lair at the far east; the trận nhãn spread across the land, one
    // in each third, so the run crosses all of it.
    final (lx, ly) = spot(w - 520, w - 380, 600);
    pois.add(Poi(PoiKind.lair, lx, ly));
    for (var i = 0; i < realmPillars; i++) {
      final (x, y) = spot(900 + i * (w - 1700) / 3, 900 + (i + 1) * (w - 1700) / 3, 700);
      pois.add(Poi(PoiKind.pillar, x, y));
    }
    for (var i = 0; i < realmChests; i++) {
      final (x, y) = spot(700, w - 300, 450);
      pois.add(Poi(PoiKind.chest, x, y));
    }
    final buffs = [...RealmBuff.values]..shuffle(r);
    for (var i = 0; i < realmShrines; i++) {
      final (x, y) = spot(700, w - 700, 450);
      pois.add(Poi(PoiKind.shrine, x, y, index: buffs[i % buffs.length].index));
    }
    final who = [for (var i = 0; i < realmCaptiveLines.length; i++) i]..shuffle(r);
    for (var i = 0; i < realmCaptives; i++) {
      final (x, y) = spot(800, w - 600, 450);
      pois.add(Poi(PoiKind.captive, x, y, index: who[i]));
    }
    // Biến cố: one, half the time two.
    final events = ([...RealmEvent.values]..shuffle(r)).take(r.nextBool() ? 2 : 1).toList();
    if (force != null && !events.contains(force)) events[0] = force;
    var vaultOrder = const <int>[];
    if (events.contains(RealmEvent.merchant)) {
      final (x, y) = spot(900, w - 900, 450);
      pois.add(Poi(PoiKind.merchant, x, y));
    }
    if (events.contains(RealmEvent.vault)) {
      final (x, y) = spot(1000, w - 900, 700);
      pois.add(Poi(PoiKind.vault, x, y));
      // The levers in a ring around the door, their marks shuffled.
      final marks = [0, 1, 2]..shuffle(r);
      final a0 = r.nextDouble() * math.pi * 2;
      for (var i = 0; i < 3; i++) {
        final a = a0 + i * math.pi * 2 / 3;
        pois.add(Poi(PoiKind.lever, (x + math.cos(a) * 260).clamp(220.0, w - 220),
            (y + math.sin(a) * 180).clamp(220.0, h - 220), index: marks[i]));
      }
      vaultOrder = [0, 1, 2]..shuffle(r);
    }

    // Camps: by every trận nhãn and captive and some chests, then scattered,
    // thicker toward the east.
    final camps = <RealmCamp>[];
    int kindAt(double x) => ((x / w) * 2.2 + r.nextDouble() * 0.9).floor().clamp(0, kinds - 1);
    for (final p in pois) {
      if (p.kind == PoiKind.lair || p.kind == PoiKind.shrine || p.kind == PoiKind.merchant || p.kind == PoiKind.lever) {
        continue;
      }
      if (p.kind == PoiKind.chest && r.nextDouble() < 0.4) continue;
      final a = r.nextDouble() * math.pi * 2;
      final cx = (p.x + math.cos(a) * 150).clamp(120.0, w - 120);
      final cy = (p.y + math.sin(a) * 110).clamp(160.0, h - 120);
      camps.add(RealmCamp(cx, cy, kindAt(cx), 3 + r.nextInt(2)));
    }
    final campPts = <List<double>>[for (final c in camps) [c.x, c.y]];
    var tries = 0;
    while (camps.length < 30 && tries < 3000) {
      tries++;
      // East-weighted: the square root pushes points right.
      final x = 800 + math.sqrt(r.nextDouble()) * (w - 1100);
      final y = 220 + r.nextDouble() * (h - 440);
      if (campPts.any((p) => (p[0] - x) * (p[0] - x) + (p[1] - y) * (p[1] - y) < 380 * 380)) continue;
      if ((x - gateX) * (x - gateX) + (y - gateY) * (y - gateY) < 650 * 650) continue;
      if ((x - lx) * (x - lx) + (y - ly) * (y - ly) < 420 * 420) continue;
      campPts.add([x, y]);
      camps.add(RealmCamp(x, y, kindAt(x), 3 + r.nextInt(3)));
    }
    return RealmLayout(pois, camps, events: events, vaultOrder: vaultOrder);
  }
}

/// What the thương nhân bí ẩn sells.
enum MerchantWare { epicItem, gem, potions }

class MerchantOffer {
  const MerchantOffer(this.ware, this.label, this.price);
  final MerchantWare ware;
  final String label;
  final int price;
}

/// The thương nhân's three offers at [level]; [gemTier] is the gem sold.
List<MerchantOffer> merchantOffers(int level, int gemTier, int potionPrice) => [
      MerchantOffer(MerchantWare.epicItem, 'Trang bị Hiếm cấp $level', realmChestGold(level) * 12),
      MerchantOffer(MerchantWare.gem, 'Ngọc ngũ hành bậc $gemTier', realmChestGold(level) * 5),
      MerchantOffer(MerchantWare.potions, '20 Kim Sang Dược (giảm nửa giá)', potionPrice * 10),
    ];

/// Gold in a chest at [level]: about a dungeon's repeat clear.
int realmChestGold(int level) => 40 + level * 6;

/// EXP for freeing a captive, as a share of the level's bar.
const double realmCaptiveExp = 0.02;

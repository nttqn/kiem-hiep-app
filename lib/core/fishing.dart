import 'dart:math' as math;

import 'content.dart';
import 'i18n.dart';

/// Câu cá: a pond by the gate of every field map. Each cast uses a bait;
/// a bite must be struck in time, then the line held by tapping while the
/// needle crosses the green mark. Catches are sold on the spot and logged
/// in the Ngư phổ; finishing a pond's page pays once.
const int fishOpenLevel = 10;
const int fishBaitPerDay = 20;
const int fishAdBait = 10;

/// Pond centre and half sizes on a field map: in the cleared ground by the
/// gate, below the start.
const double pondDx = 360, pondDy = 190, pondRx = 92, pondRy = 46;

/// How close the hero must stand to the pond's centre to cast.
const double pondReach = 150;

enum FishRarity { common, fine, rare, legend }

const fishRarityNames = ['Thường', 'Hiếm', 'Quý', 'Huyền thoại'];
const fishRarityColors = [0xFFD8D0C0, 0xFF6AC8FF, 0xFFC88CFF, 0xFFFFD34A];

/// Catch weights by rarity, and per rarity the green mark's width (share
/// of the bar), needle sweeps per second, and strikes needed.
const fishWeights = [60, 28, 10, 2];
const fishZone = [0.30, 0.22, 0.15, 0.11];
const fishSpeed = [0.75, 1.0, 1.3, 1.6];
const fishHits = [1, 2, 2, 3];

class FishDef {
  const FishDef(this.id, this.name, this.map, this.rarity, this.desc);
  final String id, name, map;
  final FishRarity rarity;
  final String desc;

  int get mapIndex => maps.indexWhere((m) => m.id == map);

  /// How far along the pond is (0 = first map): its place in the list for
  /// the first nine, by level for the later regions (1.26).
  int get tier => _laterPonds[map] ?? mapIndex;

  /// Gold the trader pays.
  int get price => ((20 + 30 * tier) * const [1, 3, 8, 30][rarity.index]).round();
}

/// The ponds of the regions added after the first nine maps, as tiers.
const _laterPonds = {'mieucuong': 3, 'tayvuc': 5, 'donghai': 7, 'conlon': 8};

// ---------------------------------------------------------------- 1.26

/// A fish's usual weight in cân by rarity, growing with the pond's tier.
double fishAvgWeight(FishDef f) => const [1.2, 2.5, 5.0, 12.0][f.rarity.index] * (1 + 0.15 * f.tier);

/// The catch's weight in tenths of a cân: from about half the usual to
/// twice it, light ones the most common.
int rollFishWeight(FishDef f, math.Random rng) {
  final k = 0.55 + 1.45 * math.pow(rng.nextDouble(), 1.8);
  return math.max(1, (fishAvgWeight(f) * k * 10).round());
}

/// "12,4 cân" from tenths.
String fishWeightText(int tenths) => tr('{p0} cân', {'p0': '${tenths ~/ 10},${tenths % 10}'});

/// Câu cá tuần points for a catch: its weight, counted more for rarer fish.
int fishPoints(FishDef f, int tenths) => math.max(1, (tenths * const [2, 4, 8, 16][f.rarity.index] / 10).round());

/// Most points one week may count (the board packs week and points).
const int fishWeekMax = 999999;

/// The Câu cá tuần board's value: week first, as Săn quái tuần.
int fishScore(int week, int pts) => week * 1000000 + pts.clamp(0, fishWeekMax);

/// Ngư tệ for a catch, spent at the Ngư phủ.
const fishCoinsOf = [1, 3, 8, 30];

/// Ngư tệ for finishing a page of the Ngư phổ.
const int fishBookCoins = 50;

class FishWeekReward {
  const FishWeekReward(this.iron, this.coins, this.title);
  final int iron, coins;
  final String title;
}

FishWeekReward? fishWeekReward(int place) => switch (place) {
      1 => const FishWeekReward(8, 300, 'Ngư Vương'),
      <= 3 => const FishWeekReward(5, 200, ''),
      <= 10 => const FishWeekReward(3, 120, ''),
      <= 50 => const FishWeekReward(1, 60, ''),
      _ => null,
    };

enum FishWare { bait, iron, shards, gem, pill, page }

/// A Ngư phủ ware: its Ngư tệ price and how many a week.
class FishOffer {
  const FishOffer(this.id, this.kind, this.name, this.price, this.perWeek, {this.count = 1, this.tier = 0, this.pill = ''});
  final String id;
  final FishWare kind;
  final String name;
  final int price, perWeek, count, tier;
  final String pill;
}

/// Baits bought at the Ngư phủ, five at a time.
const int fishShopBait = 5;

List<FishOffer> fishShop(int level) {
  final gemTier = level < 50 ? 3 : level < 80 ? 4 : 5;
  return [
    const FishOffer('bait', FishWare.bait, 'Mồi câu ×5', 12, 10, count: fishShopBait),
    const FishOffer('shards', FishWare.shards, '2 Mảnh Hoàng Kim', 30, 5, count: 2),
    const FishOffer('iron', FishWare.iron, 'Thần Thiết', 45, 5),
    FishOffer('gem', FishWare.gem, tr('Ngọc cấp {gemTier} (hành ngẫu nhiên)', {'gemTier': gemTier}), 20 * gemTier, 3, tier: gemTier),
    const FishOffer('page', FishWare.page, 'Trang bí kíp', 35, 3),
    const FishOffer('taytuy', FishWare.pill, 'Tẩy Tủy Đan', 90, 2, pill: 'taytuy'),
  ];
}

const fishes = <FishDef>[
  FishDef('diecvang', 'Cá Diếc Vàng', 'ngoaithanh', FishRarity.common, 'Loài cá quen thuộc ở ao làng.'),
  FishDef('chepco', 'Cá Chép Cỏ', 'ngoaithanh', FishRarity.fine, 'Mập mạp, được dân thành Lạc An ưa chuộng.'),
  FishDef('chephong', 'Chép Hồng Lạc An', 'ngoaithanh', FishRarity.rare, 'Vảy hồng như cánh đào tháng ba.'),
  FishDef('lyngu', 'Lý Ngư Hóa Long', 'ngoaithanh', FishRarity.legend, 'Tương truyền vượt vũ môn sẽ hóa rồng.'),
  FishDef('rotruc', 'Cá Rô Trúc', 'truclam', FishRarity.common, 'Nấp dưới bóng trúc, cắn câu rất nhanh.'),
  FishDef('trevan', 'Cá Trê Vằn', 'truclam', FishRarity.fine, 'Râu dài, thân vằn như đốt trúc.'),
  FishDef('ngoctruc', 'Ngọc Trúc Ngư', 'truclam', FishRarity.rare, 'Trong suốt như ngọc bích.'),
  FishDef('tutrucvuong', 'Tử Trúc Ngư Vương', 'truclam', FishRarity.legend, 'Vua cá của rừng trúc tím, trăm năm mới hiện.'),
  FishDef('camu', 'Cá Mù Hang', 'hacphong', FishRarity.common, 'Sống trong bóng tối, không có mắt.'),
  FishDef('lattinh', 'Lươn Lân Tinh', 'hacphong', FishRarity.fine, 'Phát sáng xanh lờ mờ dưới nước ngầm.'),
  FishDef('hacnguyet', 'Hắc Nguyệt Ngư', 'hacphong', FishRarity.rare, 'Vây đen như vầng trăng khuyết.'),
  FishDef('uminh', 'U Minh Long Ngư', 'hacphong', FishRarity.legend, 'Cá rồng từ mạch nước dưới đáy động.'),
  FishDef('lockhat', 'Cá Lóc Ốc Đảo', 'hoangsa', FishRarity.common, 'Chịu khát giỏi, sống trong ốc đảo.'),
  FishDef('sakim', 'Sa Kim Ngư', 'hoangsa', FishRarity.fine, 'Vảy lấp lánh như cát vàng.'),
  FishDef('baothach', 'Bảo Thạch Ngư', 'hoangsa', FishRarity.rare, 'Trán gắn viên đá đỏ như hồng ngọc.'),
  FishDef('samacvuong', 'Sa Mạc Thần Ngư', 'hoangsa', FishRarity.legend, 'Thương đoàn đồn rằng nó dẫn đường tìm nước.'),
  FishDef('hoibang', 'Cá Hồi Băng', 'bangnguyen', FishRarity.common, 'Thịt chắc, ngọt lịm sau mùa tuyết.'),
  FishDef('tuyetly', 'Tuyết Lý Ngư', 'bangnguyen', FishRarity.fine, 'Trắng muốt, lạnh buốt khi chạm tay.'),
  FishDef('hanngoc', 'Hàn Ngọc Ngư', 'bangnguyen', FishRarity.rare, 'Thân như băng tạc, nội lực tinh thuần.'),
  FishDef('bangphach', 'Băng Phách Côn Ngư', 'bangnguyen', FishRarity.legend, 'Cá khổng lồ ngủ dưới lớp băng ngàn năm.'),
  FishDef('chaythan', 'Cá Than Hồng', 'hoadiem', FishRarity.common, 'Bơi được trong suối nóng bốc khói.'),
  FishDef('diemlan', 'Diễm Lân Ngư', 'hoadiem', FishRarity.fine, 'Vảy đỏ rực như than đang cháy.'),
  FishDef('phuongvi', 'Phượng Vĩ Ngư', 'hoadiem', FishRarity.rare, 'Đuôi xòe như lông phượng hoàng.'),
  FishDef('hoalong', 'Hỏa Long Ngư', 'hoadiem', FishRarity.legend, 'Thở ra lửa, nung chảy cả lưỡi câu thường.'),
  FishDef('cahao', 'Cá Hào Thành', 'magiao', FishRarity.common, 'Sống trong hào nước quanh tổng đàn.'),
  FishDef('huyetlan', 'Huyết Lân Ngư', 'magiao', FishRarity.fine, 'Vảy đỏ thẫm, ăn cả máu tanh.'),
  FishDef('maanh', 'Ma Ảnh Ngư', 'magiao', FishRarity.rare, 'Lúc ẩn lúc hiện như bóng ma.'),
  FishDef('thienma', 'Thiên Ma Giao Ngư', 'magiao', FishRarity.legend, 'Thú nuôi của giáo chủ đời trước.'),
  FishDef('vanngu', 'Vân Ngư', 'vanvu', FishRarity.common, 'Bơi giữa nước và mây, nhẹ như bông.'),
  FishDef('thanhvan', 'Thanh Vân Lý', 'vanvu', FishRarity.fine, 'Xanh như trời sau mưa.'),
  FishDef('tienhac', 'Tiên Hạc Ngư', 'vanvu', FishRarity.rare, 'Mỏ dài như hạc, nghe nói hiểu tiếng người.'),
  FishDef('bachlong', 'Bạch Long Ngư', 'vanvu', FishRarity.legend, 'Con cháu của Bạch Long Vương.'),
  FishDef('kiemngu', 'Kiếm Ngư', 'hoason', FishRarity.common, 'Mõm nhọn như mũi kiếm.'),
  FishDef('tungphong', 'Tùng Phong Ngư', 'hoason', FishRarity.fine, 'Vây như lá tùng, bơi ngược thác.'),
  FishDef('kiemhon', 'Kiếm Hồn Ngư', 'hoason', FishRarity.rare, 'Thấm kiếm khí của các bậc tiền bối.'),
  FishDef('hoasonthan', 'Hoa Sơn Thần Ngư', 'hoason', FishRarity.legend, 'Kẻ câu được nó, kiếm pháp tự thông.'),
  // 1.26: the ponds of the later regions.
  FishDef('casuoi', 'Cá Lăng Suối', 'mieucuong', FishRarity.common, 'Nấp dưới thác nước giữa rừng Miêu Cương.'),
  FishDef('cotrung', 'Cổ Trùng Ngư', 'mieucuong', FishRarity.fine, 'Trong bụng nuôi một con cổ trùng nhỏ.'),
  FishDef('thatsac', 'Thất Sắc Ngư', 'mieucuong', FishRarity.rare, 'Đổi màu bảy lần mỗi khi trời đổ mưa.'),
  FishDef('kimtam', 'Kim Tằm Ngư Vương', 'mieucuong', FishRarity.legend, 'Vạn Độc Cổ Vương nuôi nó bằng kim tằm.'),
  FishDef('sathach', 'Sa Thạch Ngư', 'tayvuc', FishRarity.common, 'Màu đỏ như đá núi Tây Vực.'),
  FishDef('bachcot', 'Bạch Cốt Ngư', 'tayvuc', FishRarity.fine, 'Xương trắng lộ ra dưới lớp vảy mỏng.'),
  FishDef('baihoa', 'Bái Hỏa Ngư', 'tayvuc', FishRarity.rare, 'Bái Hỏa giáo thờ nó như một ngọn lửa nhỏ.'),
  FishDef('luuly', 'Lưu Ly Thần Ngư', 'tayvuc', FishRarity.legend, 'Thân trong như lưu ly, sống trong suối ngầm sa mạc.'),
  FishDef('cathu', 'Cá Thu Đảo', 'donghai', FishRarity.common, 'Từng đàn thu bạc lượn quanh các đảo.'),
  FishDef('mucquang', 'Mực Lân Quang', 'donghai', FishRarity.fine, 'Phát sáng xanh khi bị kéo khỏi mặt nước.'),
  FishDef('ngoctrai', 'Ngọc Trai Ngư', 'donghai', FishRarity.rare, 'Ngậm trong miệng một viên ngọc trai.'),
  FishDef('longcung', 'Long Cung Ngư', 'donghai', FishRarity.legend, 'Thị vệ của Đông Hải Long Vương, vảy xanh như ngọc.'),
  FishDef('tuyetlinh', 'Tuyết Linh Ngư', 'conlon', FishRarity.common, 'Bơi dưới lớp băng mỏng của suối tiên.'),
  FishDef('ngocho', 'Ngọc Hồ Ngư', 'conlon', FishRarity.fine, 'Sống trong hồ nước xanh như ngọc trên đỉnh núi.'),
  FishDef('tienlien', 'Tiên Liên Ngư', 'conlon', FishRarity.rare, 'Ngủ dưới lá sen tuyết nghìn năm.'),
  FishDef('conlonthan', 'Côn Lôn Thần Ngư', 'conlon', FishRarity.legend, 'Cưỡi mây mà bơi, tương truyền là thú cưỡi của tiên nhân.'),
];

final Map<String, FishDef> fishById = {for (final f in fishes) f.id: f};

List<FishDef> fishOfMap(String mapId) => fishes.where((f) => f.map == mapId).toList();

/// What bites in the pond of map [mapId].
FishDef rollFish(String mapId, math.Random rng) {
  final pool = fishOfMap(mapId);
  final total = pool.fold<int>(0, (s, f) => s + fishWeights[f.rarity.index]);
  var r = rng.nextInt(total);
  for (final f in pool) {
    r -= fishWeights[f.rarity.index];
    if (r < 0) return f;
  }
  return pool.first;
}

/// Gold for finishing a page of the Ngư phổ of pond tier [i].
int fishBookGold(int i) => 3000 + 3000 * i;

/// A map's pond tier (as [FishDef.tier]), -1 without a pond.
int pondTier(String mapId) => _laterPonds[mapId] ?? maps.indexWhere((m) => m.id == mapId);

/// Field maps with a pond, in the order the map list shows them.
List<MapDef> get pondMaps => [for (final m in fieldMaps) if (fishOfMap(m.id).isNotEmpty) m];

/// First catch of a kind pays this many times its price on top.
const int fishFirstBonus = 5;

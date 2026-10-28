import 'dart:math' as math;

import 'content.dart';

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

  /// Gold the trader pays.
  int get price => ((20 + 30 * mapIndex) * const [1, 3, 8, 30][rarity.index]).round();
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

/// Gold for finishing map index [i]'s page of the Ngư phổ.
int fishBookGold(int i) => 3000 + 3000 * i;

/// First catch of a kind pays this many times its price on top.
const int fishFirstBonus = 5;

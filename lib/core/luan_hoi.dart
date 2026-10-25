import 'content.dart';

/// Tinh anh: a named, much tougher take on an ordinary monster that appears
/// on [map] only while a quest or bounty wants it.
class EliteDef {
  const EliteDef(this.id, this.name, this.mob, this.map, {this.hpMul = 7, this.atkMul = 1.25});
  final String id, name;

  /// Monster it is drawn and fights as.
  final String mob;
  final String map;
  final double hpMul, atkMul;
}

const lhElites = <EliteDef>[
  // Hồi I · Tàn Hồn Thiên Ma.
  EliteDef('lh1a', 'Ma Ảnh Thích Khách', 'bambooAssassin', 'truclam'),
  EliteDef('lh1b', 'Sa Mạc Ma Đao', 'horseBandit', 'hoangsa'),
  EliteDef('lh1c', 'Huyết Ảnh Hộ Pháp', 'cultist', 'magiao'),
  EliteDef('lh1d', 'Phản Đồ Ma Kiếm', 'renegade', 'vanvu'),
  EliteDef('lh1e', 'Thiên Ma Tàn Hồn', 'swordSoul', 'hoason', hpMul: 26, atkMul: 1.7),
  // Hồi II · Huyết Ma Phục Khởi.
  EliteDef('lh2a', 'Huyết Nhãn Viên Vương', 'ape', 'truclam'),
  EliteDef('lh2b', 'Huyết Hạt Sứ Giả', 'scorpion', 'hoangsa'),
  EliteDef('lh2c', 'Huyết Thủ Tả Sứ', 'assassin', 'magiao'),
  EliteDef('lh2d', 'Huyết Thủ Hữu Sứ', 'renegade', 'vanvu'),
  EliteDef('lh2e', 'Huyết Thủ Nhân Đồ', 'assassin', 'hoason', hpMul: 30, atkMul: 1.8),
  // Hồi III · Ngũ Hành Loạn Thế.
  EliteDef('lh3a', 'Mộc Linh Tướng', 'ape', 'truclam'),
  EliteDef('lh3b', 'Thổ Linh Tướng', 'lavaGolem', 'hacphong'),
  EliteDef('lh3c', 'Thủy Linh Tướng', 'iceSpirit', 'bangnguyen'),
  EliteDef('lh3d', 'Hỏa Linh Tướng', 'fireSpirit', 'hoadiem'),
  EliteDef('lh3e', 'Kim Linh Tướng', 'swordGolem', 'vanvu'),
  EliteDef('lh3f', 'Ngũ Hành Ma Tôn', 'cloudSpirit', 'hoason', hpMul: 34, atkMul: 1.9),
  // Hồi IV · Thất Sát Môn: the seven stars of the Dipper.
  EliteDef('lh4a', 'Tham Lang Sát', 'bambooAssassin', 'truclam'),
  EliteDef('lh4b', 'Cự Môn Sát', 'spider', 'hacphong'),
  EliteDef('lh4c', 'Lộc Tồn Sát', 'horseBandit', 'hoangsa'),
  EliteDef('lh4d', 'Văn Khúc Sát', 'assassin', 'bangnguyen'),
  EliteDef('lh4e', 'Liêm Trinh Sát', 'fireWolf', 'hoadiem'),
  EliteDef('lh4f', 'Vũ Khúc Sát', 'renegade', 'vanvu'),
  EliteDef('lh4g', 'Phá Quân Sát Môn Chủ', 'assassin', 'hoason', hpMul: 38, atkMul: 2.0),
  // Hồi V · Võ Lâm Chí Tôn: masters met on the road to Hoa Sơn.
  EliteDef('lh5a', 'Trúc Lâm Kiếm Ẩn', 'renegade', 'truclam'),
  EliteDef('lh5b', 'Hắc Phong Đao Khách', 'bandit', 'hacphong'),
  EliteDef('lh5c', 'Tuyết Sơn Kiếm Tiên', 'renegade', 'bangnguyen'),
  EliteDef('lh5d', 'Hỏa Diệm Đao Vương', 'horseBandit', 'hoadiem'),
  EliteDef('lh5e', 'Ma Giáo Kiếm Si', 'cultist', 'magiao'),
  EliteDef('lh5f', 'Vân Vụ Kiếm Thánh', 'renegade', 'vanvu'),
  EliteDef('lh5g', 'Kiếm Thánh Vô Danh', 'renegade', 'hoason', hpMul: 45, atkMul: 2.2),
];

final Map<String, EliteDef> eliteById = {for (final e in lhElites) e.id: e};

class ChapterDef {
  const ChapterDef(this.title, this.intro, this.quests);
  final String title, intro;
  final List<QuestDef> quests;
}

/// Main-quest gold for a quest that opens at [lv], on the story's curve.
int _gold(int lv) => (2.2 * lv * lv + 300).round() ~/ 10 * 10;

QuestDef _q(String title, String story, QuestType type, String target, int lv,
        {int count = 1, double exp = 0.6, bool item = false}) =>
    QuestDef(
        title: title, story: story, type: type, target: target, count: count, minLv: lv,
        gold: _gold(lv), expFactor: exp, item: item);

QuestDef _kill(String title, String story, String mob, int count, int lv) =>
    _q(title, story, QuestType.kill, mob, lv, count: count);
QuestDef _elite(String title, String story, String id, int lv, {bool last = false}) =>
    _q(title, story, QuestType.elite, id, lv, exp: last ? 1.5 : 0.8, item: true);
QuestDef _dungeon(String title, String story, String id, int lv) =>
    _q(title, story, QuestType.dungeon, id, lv, exp: 0.7, item: true);
QuestDef _boss(String title, String story, String id, int lv) =>
    _q(title, story, QuestType.boss, id, lv, exp: 0.8);

/// Luân Hồi: one story chapter per rebirth, walking the hero from level 10
/// back up to 99 across the old maps.
final luanHoi = <ChapterDef>[
  ChapterDef(
    'Tàn Hồn Thiên Ma',
    'Thiên Ma Lão Tổ đã ngã xuống trên đỉnh Hoa Sơn, nhưng tàn hồn của lão '
        'thoát đi, nương vào thuộc hạ cũ để hồi sinh. Tái sinh với thân thể mới, '
        'ngươi phải lần theo ma khí trước khi lão tụ đủ hồn phách.',
    [
      _kill('Dấu vết lạ', 'Rắn độc Tử Trúc Lâm bỗng hung dữ khác thường, mắt đỏ ngầu ma khí.',
          'snake', 25, 10),
      _elite('Kẻ chăn rắn', 'Một thích khách mang ma khí đang điều khiển bầy rắn. Hạ hắn để tra hỏi.',
          'lh1a', 13),
      _kill('Thi khí trỗi dậy', 'Hắn khai tàn hồn đã đi về Hắc Phong Động; cương thi lại thức giấc.',
          'zombie', 30, 18),
      _dungeon('Thâm xứ Hắc Phong', 'Ma khí đặc nhất nằm sâu trong lòng động. Xông vào xem thực hư.',
          'a6', 25),
      _elite('Ma đao trên cát', 'Thủ lĩnh mã tặc được ma khí ban sức mạnh, cướp phá khắp Hoàng Sa Mạc.',
          'lh1b', 31),
      _boss('Yêu vương mất trí', 'Tàn hồn từng trú trong Tuyết Sơn Yêu Vương, khiến nó điên loạn.',
          'yetiKing', 40),
      _kill('Hỏa linh cuồng loạn', 'Hỏa Diệm Sơn phun trào dữ dội, hỏa linh tràn xuống chân núi.',
          'fireSpirit', 35, 48),
      _elite('Hộ pháp áo máu', 'Một hộ pháp Huyết Ma Giáo đang dâng huyết tế cho tàn hồn.',
          'lh1c', 58),
      _dungeon('Bí tịch phong ấn', 'Trong mật thất giáo chủ có bí tịch phong ấn ma hồn. Phải đoạt lấy.',
          'a14', 70),
      _elite('Ma kiếm phản đồ', 'Phản đồ kiếm phái đã nhận ma hồn làm sư phụ, canh giữ đường lên Hoa Sơn.',
          'lh1d', 78),
      _kill('Kiếm hồn ô nhiễm', 'Kiếm hồn trên Hoa Sơn bị ma khí làm vẩn đục, phải tiễn chúng về cõi lặng.',
          'swordSoul', 40, 88),
      _elite('Phong ấn tàn hồn', 'Tàn hồn Thiên Ma đã tụ hình. Dùng bí tịch phong ấn lão lần cuối.',
          'lh1e', 95, last: true),
    ],
  ),
  ChapterDef(
    'Huyết Ma Phục Khởi',
    'Dư đảng Huyết Ma Giáo tôn một kẻ tên Huyết Thủ Nhân Đồ làm giáo chủ mới. '
        'Hắn thu máu cao thủ khắp võ lâm để luyện thần công. Ngươi lại lên đường.',
    [
      _kill('Thích khách trở lại', 'Thích khách Trúc Lâm phục kích khách qua đường, trên áo thêu huyết thủ.',
          'bambooAssassin', 25, 10),
      _elite('Viên vương mắt đỏ', 'Giáo đồ cho bầy vượn uống huyết đan; vượn chúa hóa cuồng.',
          'lh2a', 13),
      _kill('Dơi hút máu', 'Bầy dơi Hắc Phong Động bị bắt để lấy máu tế lễ. Phá kế hoạch của chúng.',
          'bat', 35, 18),
      _dungeon('Tế đàn mộ địa', 'Tế đàn đầu tiên dựng giữa Cương Thi Mộ Địa. Phá hủy nó.',
          'a5', 21),
      _elite('Sứ giả bọ cạp', 'Huyết Hạt Sứ Giả chở huyết đan qua sa mạc. Chặn đường hắn.',
          'lh2b', 32),
      _kill('Tuyết quái bị bắt', 'Giáo đồ bắt tuyết quái làm vật tế. Giải thoát cao nguyên.',
          'yeti', 35, 40),
      _dungeon('Địa cung dung nham', 'Huyết đan được luyện trong lòng núi lửa. Đập vỡ lò luyện.',
          'a11', 50),
      _elite('Tả sứ', 'Huyết Thủ Tả Sứ trấn giữ tổng đàn cũ, tay nhuốm máu trăm người.',
          'lh2c', 60),
      _boss('Giáo chủ cũ', 'Huyết đan làm xác Huyết Ma Giáo Chủ cũ đứng dậy. Đưa hắn về đất.',
          'demonLord', 68),
      _elite('Hữu sứ', 'Huyết Thủ Hữu Sứ mai phục trên Vân Vụ Sơn, chờ chặn đường ngươi.',
          'lh2d', 79),
      _dungeon('Kiếm trủng nhuốm máu', 'Nhân Đồ dùng kiếm trủng Hoa Sơn làm huyết trì. Xông vào.',
          'a17', 90),
      _elite('Huyết Thủ Nhân Đồ', 'Giáo chủ mới đã luyện thành thần công. Trận chiến cuối cùng.',
          'lh2e', 96, last: true),
    ],
  ),
  ChapterDef(
    'Ngũ Hành Loạn Thế',
    'Ngũ hành mất cân bằng: mưa lửa ở phương nam, tuyết giữa mùa hạ. Năm Linh '
        'Tướng ngũ hành bị tà thuật đánh thức, chiếm giữ năm phương. Phải hàng '
        'phục chúng để trời đất quân bình.',
    [
      _kill('Mộc khí hỗn loạn', 'Rừng trúc mọc điên cuồng, vượn đen trở nên hung hãn.', 'ape', 25, 10),
      _elite('Mộc Linh Tướng', 'Mộc Linh Tướng ngự trong rừng trúc. Hàng phục nó trước tiên.',
          'lh3a', 14),
      _kill('Tơ độc giăng lối', 'Nhện độc giăng tơ kín lối vào Hắc Phong Động.', 'spider', 30, 18),
      _elite('Thổ Linh Tướng', 'Đất đá trong động tự kết thành Thổ Linh Tướng.', 'lh3b', 23),
      _kill('Bão cát', 'Bão cát không ngừng, sa lang thừa cơ tấn công thương đoàn.', 'sandWolf', 35, 30),
      _elite('Thủy Linh Tướng', 'Băng nguyên đóng băng tới tận chân trời. Thủy Linh Tướng ở trung tâm.',
          'lh3c', 41),
      _elite('Hỏa Linh Tướng', 'Hỏa Linh Tướng khiến núi lửa phun trào không dứt.', 'lh3d', 51),
      _dungeon('Ma điện tà thuật', 'Tà thuật đánh thức Linh Tướng phát ra từ Huyết Ma Điện.', 'a13', 62),
      _elite('Kim Linh Tướng', 'Kim khí tụ trên Vân Vụ Sơn thành Kim Linh Tướng sắc như kiếm.',
          'lh3e', 80),
      _boss('Long vương hỗn loạn', 'Bạch Long Vương bị ngũ hành loạn khí làm cuồng bạo.', 'whiteDragon', 82),
      _kill('Hổ vàng hộ sơn', 'Kim Mao Hổ chặn mọi lối lên đỉnh, nơi kẻ chủ mưu chờ đợi.', 'goldTiger', 40, 89),
      _elite('Ngũ Hành Ma Tôn', 'Kẻ đánh thức Linh Tướng hấp thụ cả năm hành. Quân bình trời đất.',
          'lh3f', 96, last: true),
    ],
  ),
  ChapterDef(
    'Thất Sát Môn',
    'Thất Sát Môn, tổ chức sát thủ bí ẩn, nhận lệnh truy sát kẻ đã chuyển sinh. '
        'Bảy sát tinh mang tên bảy ngôi sao Bắc Đẩu lần lượt xuất hiện.',
    [
      _kill('Mũi tên trong đêm', 'Đêm qua có kẻ bắn tên vào phòng trọ. Lần theo dấu chân vào rừng trúc.',
          'bambooAssassin', 30, 10),
      _elite('Tham Lang', 'Tham Lang Sát, sát tinh thứ nhất, chờ trong rừng trúc.', 'lh4a', 14),
      _elite('Cự Môn', 'Cự Môn Sát giăng bẫy trong Hắc Phong Động.', 'lh4b', 20),
      _elite('Lộc Tồn', 'Lộc Tồn Sát cải trang mã tặc giữa sa mạc.', 'lh4c', 30),
      _dungeon('Băng cốc mai phục', 'Thất Sát Môn mai phục trong Băng Phong Cốc. Phá vòng vây.', 'a9', 40),
      _elite('Văn Khúc', 'Văn Khúc Sát, kẻ ám sát bằng thơ, đợi ngươi trên băng nguyên.', 'lh4d', 43),
      _elite('Liêm Trinh', 'Liêm Trinh Sát cưỡi hỏa lang tuần tra Hỏa Diệm Sơn.', 'lh4e', 52),
      _kill('Hắc y khắp nơi', 'Sát thủ hắc y tụ về tổng đàn ma giáo cũ. Dọn sạch chúng.', 'assassin', 40, 60),
      _elite('Vũ Khúc', 'Vũ Khúc Sát, kiếm pháp nhanh nhất Thất Sát Môn.', 'lh4f', 77),
      _dungeon('Long đàm hội kiến', 'Môn chủ hẹn gặp ở Bạch Long Đàm. Đây là cái bẫy.', 'a16', 82),
      _kill('Kiếm khôi canh đỉnh', 'Môn chủ điều khiển kiếm khôi canh giữ Hoa Sơn.', 'swordGolem', 40, 88),
      _elite('Phá Quân', 'Phá Quân Sát Môn Chủ, kẻ đứng sau mọi lệnh truy sát. Kết thúc tất cả.',
          'lh4g', 96, last: true),
    ],
  ),
  ChapterDef(
    'Võ Lâm Chí Tôn',
    'Hoa Sơn Luận Kiếm lần thứ năm sắp mở. Cao thủ ẩn danh khắp nơi gửi chiến thư '
        'thách đấu kẻ đã năm lần chuyển sinh. Chỉ người thắng tất cả mới xứng '
        'danh Võ Lâm Chí Tôn.',
    [
      _kill('Chiến thư Hoa Sơn', 'Chiến thư đầu tiên hẹn ngươi ở rừng trúc. Dọn đường trước đã.', 'snake', 30, 10),
      _elite('Kiếm ẩn trúc lâm', 'Trúc Lâm Kiếm Ẩn, ẩn sĩ ba mươi năm không rút kiếm.', 'lh5a', 14),
      _dungeon('Thanh Xà Cốc', 'Muốn gặp cao thủ kế tiếp, phải vượt Thanh Xà Cốc.', 'a4', 16),
      _elite('Đao khách Hắc Phong', 'Hắc Phong Đao Khách, một đao chém đứt thác nước.', 'lh5b', 22),
      _boss('Cự Hạt Vương', 'Thử thách giữa đường: hạ Cự Hạt Vương trong sa mạc.', 'scorpionKing', 34),
      _elite('Kiếm tiên tuyết sơn', 'Tuyết Sơn Kiếm Tiên luyện kiếm giữa bão tuyết.', 'lh5c', 42),
      _elite('Đao vương hỏa diệm', 'Hỏa Diệm Đao Vương, đao nóng như dung nham.', 'lh5d', 52),
      _elite('Kiếm si ma giáo', 'Ma Giáo Kiếm Si, kẻ si mê kiếm đạo tới mức nhập ma.', 'lh5e', 64),
      _dungeon('Mật thất giáo chủ', 'Bí kíp kiếm đạo cuối cùng nằm trong mật thất giáo chủ.', 'a14', 70),
      _elite('Kiếm thánh Vân Vụ', 'Vân Vụ Kiếm Thánh chỉ ra tay khi mây phủ kín núi.', 'lh5f', 80),
      _kill('Kiếm hồn Hoa Sơn', 'Kiếm hồn của các đời minh chủ thử thách người lên đỉnh.', 'swordSoul', 40, 88),
      _elite('Luận kiếm đỉnh cao', 'Kiếm Thánh Vô Danh đợi trên Luận Kiếm Đài. Thắng trận này, ngươi là Võ Lâm Chí Tôn.',
          'lh5g', 97, last: true),
    ],
  ),
];

/// An elite the world should put on the current map.
class WantedElite {
  const WantedElite(this.key, this.name, this.mob, this.level, this.hpMul, this.atkMul);
  final String key, name, mob;
  final int level;
  final double hpMul, atkMul;
}

const _roman = ['I', 'II', 'III', 'IV', 'V'];

/// "Luân Hồi II" for chapter index 1.
String chapterLabel(int i) => 'Luân Hồi ${_roman[i.clamp(0, _roman.length - 1)]}';

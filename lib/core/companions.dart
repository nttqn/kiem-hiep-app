import 'dart:math' as math;

import 'costumes.dart';
import 'hanh.dart';
import 'sects.dart';

/// Hiệp khách đồng hành: wandering fighters of the five sects who join the
/// hero in the field and in dungeons (not in the tower, Lôi đài or Boss Thế
/// Giới). One comes along at a time; monsters ignore them, they fight with
/// their sect's skills and grow with hảo cảm (friendship), raised with gifts.
/// Each hảo cảm milestone tells a little more of their story.
class CompanionDef {
  const CompanionDef({
    required this.id,
    required this.name,
    required this.title,
    required this.hanh,
    required this.desc,
    required this.unlock,
    required this.price,
    required this.bonus,
    required this.base,
    required this.perLv,
    required this.look,
    required this.stories,
    this.female = false,
  });

  final String id, name, title;
  final Hanh hanh;
  final bool female;
  final String desc;

  /// Hero level to meet them, and gold to have them join.
  final int unlock, price;

  /// What they raise for the hero while along.
  final Bonus bonus;
  final double base, perLv;

  /// Outfit colours over their sect's look.
  final CostumeDef look;

  /// Their story, told at hảo cảm [storyBonds].
  final List<String> stories;

  SectDef get sect => sectOf(hanh);

  double bonusAt(int bond) => base + perLv * (bond - 1);
}

const int maxBond = 10;

/// Hảo cảm that tells each story line.
const storyBonds = [1, 4, 7, 10];

/// Hảo cảm at which each of the sect's active skills (by index) joins.
const companionSkillBond = {0: 1, 1: 3, 2: 5, 4: 7, 6: 10};

/// Gold for a gift from hảo cảm [bond] to the next.
int bondCost(int bond) => (2500 * math.pow(bond, 1.8)).round();

/// Basic hit damage, times the hero's attack.
double companionHit(int bond) => 0.35 + 0.035 * (bond - 1);

/// Skill damage, times the skill's power on the hero's attack.
double companionSkillMul(int bond) => 0.45 + 0.04 * (bond - 1);

/// Seconds between basic hits; skill cooldowns are the sect's times this.
const double companionHitCd = 1.1;
const double companionSkillCd = 1.5;

/// Hảo cảm → gear look tier.
int companionGearTier(int bond) => const [1, 1, 1, 2, 2, 2, 3, 3, 3, 4][(bond - 1).clamp(0, 9)];

CostumeDef _look(String id, int robe, int trim, int pants, {int cape = 0, int blade = 0, int glow = 0}) =>
    CostumeDef(
      id: id, name: '', desc: '', source: CostumeSource.gold, need: 0,
      robe: robe, trim: trim, pants: pants, cape: cape, blade: blade, glow: glow,
    );

final companions = <CompanionDef>[
  CompanionDef(
    id: 'tueminh', name: 'Tuệ Minh', title: 'Tiểu hòa thượng Kim Cang Tự', hanh: Hanh.kim,
    desc: 'Côn pháp vững chãi, hay niệm Phật mỗi lần ra đòn.',
    unlock: 20, price: 3000, bonus: Bonus.defPct, base: 0.04, perLv: 0.006,
    look: _look('c_tueminh', 0xFFE8A040, 0xFF7A2A1A, 0xFF5A3A1A),
    stories: [
      'Tuệ Minh xuống núi khất thực, thấy thiếu hiệp một mình đánh sơn tặc liền xin đi theo "để tích công đức".',
      'Bên lửa trại, Tuệ Minh kể sư phụ bắt chú quét chùa mười năm mới cho cầm côn.',
      'Tuệ Minh lỡ ăn một cái bánh bao nhân thịt rồi cả đêm tụng kinh sám hối. Thiếu hiệp hứa giữ bí mật.',
      'Trụ trì gửi thư gọi về, Tuệ Minh viết thư đáp: "Đệ tử đang hộ pháp cho một người tốt."',
    ],
  ),
  CompanionDef(
    id: 'lamdiep', name: 'Lam Diệp', title: 'Y nữ Bách Độc Môn', hanh: Hanh.moc, female: true,
    desc: 'Tinh thông trăm loại độc, cũng tinh thông trăm loại thuốc giải.',
    unlock: 30, price: 12000, bonus: Bonus.dotPct, base: 0.06, perLv: 0.01,
    look: _look('c_lamdiep', 0xFF3A7A5A, 0xFFB8E0A0, 0xFF1E3A2A, blade: 0xFFB8F0A0),
    stories: [
      'Lam Diệp bị đồng môn hãm hại rơi xuống vực. Thiếu hiệp cứu nàng, nàng trả ơn bằng... một lọ độc dược.',
      'Nàng dạy cách nhận ra nấm độc: "Cây nào đẹp nhất thì đừng ăn."',
      'Lam Diệp kể nàng học độc để chữa độc, vì cha mẹ nàng đã chết bởi một chén trà.',
      'Kẻ hạ độc năm xưa đã tìm ra. Lam Diệp tha cho hắn: "Thuốc giải tốt nhất là buông bỏ."',
    ],
  ),
  CompanionDef(
    id: 'thanhvan', name: 'Tô Thanh Vân', title: 'Kiếm khách Bích Thủy Am', hanh: Hanh.thuy, female: true,
    desc: 'Kiếm nhanh như sương sớm, lời ít như nước hồ thu.',
    unlock: 40, price: 30000, bonus: Bonus.cdr, base: 0.02, perLv: 0.003,
    look: _look('c_thanhvan', 0xFFBFDCF0, 0xFF2A5A8A, 0xFFE0ECF4, cape: 0xFF8AB8E0, blade: 0xFFE0F4FF),
    stories: [
      'Tô Thanh Vân đuổi theo kẻ trộm kiếm phổ, tình cờ cùng đường với thiếu hiệp.',
      'Mỗi sáng nàng luyện kiếm trên mặt hồ, bảo rằng nước có lặng thì kiếm mới trong.',
      'Kiếm phổ bị trộm hóa ra là bản giả; bản thật nàng đã thuộc lòng từ năm mười tuổi.',
      'Sư thái truyền chức chưởng môn, Tô Thanh Vân xin hoãn ba năm để còn đi giang hồ cùng bằng hữu.',
    ],
  ),
  CompanionDef(
    id: 'macliet', name: 'Mạc Liệt', title: 'Đao khách Liệt Hỏa Bang', hanh: Hanh.hoa,
    desc: 'Uống rượu như nước, vung đao như lửa.',
    unlock: 50, price: 60000, bonus: Bonus.critDmg, base: 0.08, perLv: 0.012,
    look: _look('c_macliet', 0xFF7A1A14, 0xFFE8A040, 0xFF2A1A14, cape: 0xFF3A1A10, blade: 0xFFFFC8A0),
    stories: [
      'Mạc Liệt thua thiếu hiệp một trận rượu nên phải làm hộ vệ một tháng. Một tháng đã qua lâu rồi.',
      'Hắn có vết sẹo dài trên lưng, bảo là bị gấu cào. Thật ra là đỡ đao cho một đứa trẻ.',
      'Liệt Hỏa Bang mời hắn về làm phó bang chủ. Hắn đáp: "Ở đây rượu ngon hơn."',
      'Mạc Liệt rèn lại thanh đao gãy của cha, khắc thêm tên thiếu hiệp lên sống đao.',
    ],
  ),
  CompanionDef(
    id: 'truongphong', name: 'Cổ Trường Phong', title: 'Lão đạo Huyền Thổ Quán', hanh: Hanh.tho,
    desc: 'Lão đạo sĩ say khướt, kiếm khí vẫn kinh người.',
    unlock: 60, price: 120000, bonus: Bonus.hpPct, base: 0.05, perLv: 0.007,
    look: _look('c_truongphong', 0xFF8A7A5A, 0xFF3A2A1A, 0xFF4A3A2A, cape: 0xFF5A4A30, blade: 0xFFF0E8C8),
    stories: [
      'Lão đạo say rượu nằm giữa đường, tự xưng biết trước thiên cơ và bảo thiếu hiệp "có duyên".',
      'Cổ Trường Phong từng là đệ nhất kiếm Huyền Thổ Quán, bỏ kiếm ba mươi năm vì một lần lỡ tay.',
      'Lão dạy thế Thái Cực khởi thủ: "Người mạnh nhất là người không cần rút kiếm."',
      'Lần đầu sau ba mươi năm, lão lại rút kiếm, chỉ để đứng chắn trước thiếu hiệp.',
    ],
  ),
];

final Map<String, CompanionDef> companionById = {for (final c in companions) c.id: c};

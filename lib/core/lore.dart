import 'sects.dart';

/// Giang Hồ Ký Sự: a short story for each bí cảnh, five pages each, found
/// while exploring. A whole chapter grants a small lasting bonus; all nine
/// a title.
class LoreChapter {
  const LoreChapter(this.realm, this.title, this.pages, this.bonus, this.value);

  /// The bí cảnh (RealmDef.id) whose pages these are.
  final String realm;
  final String title;
  final List<String> pages;
  final Bonus bonus;
  final double value;
}

const int lorePagesPer = 5;

/// Chances a page turns up: at a stone shrine, from a freed captive, in a
/// Tàng Bảo Đồ chest dug on that land. The master and the mật thất always
/// give one.
const double loreShrineChance = 0.5;
const double loreCaptiveChance = 0.6;
const double loreTreasureChance = 0.15;

/// For every chapter whole.
const String loreTitle = 'Giang Hồ Bác Văn';
const Map<Bonus, double> loreAllBonus = {Bonus.hpPct: 0.03, Bonus.atkPct: 0.03};

const loreChapters = <LoreChapter>[
  LoreChapter('r1', 'Truyện Hắc Hổ', [
    'Năm ấy Lạc An mất mùa, một tiều phu tên Hổ dẫn dân đói lên núi Thanh Phong dựng trại.',
    'Ban đầu họ chỉ chặn đường xin gạo của nhà giàu, chưa từng làm hại ai.',
    'Rồi một kẻ lạ mang đao vàng tới, dạy Hổ một bộ đao pháp hung hiểm.',
    'Từ đó trại Hắc Hổ cướp cả thương đoàn; kẻ lạ biến mất cùng nửa số vàng.',
    'Chuôi đao vàng ấy khắc một chữ "Huyết", dấu vết đầu tiên của Huyết Ma Giáo.',
  ], Bonus.hpPct, 0.02),
  LoreChapter('r2', 'Trận đồ trúc tím', [
    'Rừng trúc tím vốn là vườn thuốc của một vị y tiên họ Lam.',
    'Y tiên trồng trúc theo trận Bát Quái để giữ linh thảo khỏi kẻ trộm.',
    'Người mất đi, trận đồ không ai mở được, rắn độc kéo về làm tổ.',
    'Thanh Xà Vương nuốt phải linh thảo trăm năm nên thông tuệ khác thường.',
    'Lời trăn trối của y tiên: "Kẻ nào phá trận, hãy dùng thuốc cứu người."',
  ], Bonus.atkPct, 0.02),
  LoreChapter('r3', 'Mộ tướng quân', [
    'Dưới Hắc Phong Động là mộ vị tướng giữ thành Lạc An thuở trước.',
    'Tướng quân chết trận, quân sĩ chôn theo cả binh khí và ấn tín.',
    'Một đạo sĩ giang hồ đào trộm mộ, đánh thức oán khí ngàn người.',
    'Thi Vương chính là xác tướng quân, vẫn mặc giáp, vẫn giữ cửa thành dưới lòng đất.',
    'Trên bia mộ còn đọc được: "Thành còn thì người còn."',
  ], Bonus.defPct, 0.02),
  LoreChapter('r4', 'Cát vùi Lâu Lan', [
    'Lâu Lan từng là chợ lớn nhất trên con đường tơ lụa phía tây.',
    'Một đêm bão cát nổi lên ba ngày, cả thành chìm xuống không dấu vết.',
    'Mã tặc đời sau lần theo bản đồ cũ, đào được kho vàng của thương hội.',
    'Cự Hạt Vương làm tổ ngay trên kho vàng, ai đến gần đều không trở về.',
    'Người sống sót duy nhất kể rằng bão cát hôm ấy có tiếng tụng kinh.',
  ], Bonus.crit, 0.01),
  LoreChapter('r5', 'Bia đá trong tuyết', [
    'Trong băng động có chín tấm bia khắc võ công của một kiếm khách vô danh.',
    'Ông luyện kiếm giữa tuyết sáu mươi năm, kiếm khí đóng băng cả thác nước.',
    'Trước khi mất, ông xóa tấm bia thứ mười, sợ đời sau học được mà hại người.',
    'Tuyết Sơn Yêu Vương canh giữ hang, có lẽ từng là con vật ông nuôi.',
    'Tấm bia cuối chỉ còn một câu: "Kiếm lạnh, lòng đừng lạnh."',
  ], Bonus.critDmg, 0.05),
  LoreChapter('r6', 'Lửa phong ấn', [
    'Miệng núi lửa này bị năm vị chưởng môn hợp sức phong ấn.',
    'Bên dưới là Hỏa Kỳ Lân, thần thú giữ mạch lửa của đất trời.',
    'Huyết Ma Giáo muốn lấy máu Kỳ Lân luyện ma công bất tử.',
    'Ấn phong yếu dần, mỗi trăm năm lại cần người hiệp nghĩa đến thắp lại.',
    'Năm vị chưởng môn để lại lời: "Ngũ hành tương sinh, lửa cũng biết thương người."',
  ], Bonus.skillDmg, 0.03),
  LoreChapter('r7', 'Sổ đen Huyết Ma', [
    'Mật cảnh là nơi Huyết Ma Giáo giam giữ người các phái bị bắt.',
    'Giáo chủ đời đầu vốn là đệ tử bị trục xuất của một danh môn chính phái.',
    'Hắn lập giáo để báo thù, nhưng con cháu hắn chỉ còn biết giết chóc.',
    'Trong sổ đen có tên cả những chưởng môn âm thầm cấu kết với ma giáo.',
    'Trang cuối sổ bị xé, chỉ còn dấu ấn hình con rồng trắng.',
  ], Bonus.aspd, 0.02),
  LoreChapter('r10', 'Hải tặc Đông Hải', [
    'Quần đảo phía đông vốn là làng chài yên bình, ngư dân thờ Long Vương giữ biển.',
    'Một năm nọ, đoàn thuyền buồm đen kéo tới, cờ thêu đầu lâu và một chữ "Huyết".',
    'Hải tặc ép dân đảo lặn tìm ngọc trai dâng cho Huyết Ma Giáo đổi lấy binh khí.',
    'Long Vương nổi giận vì biển bị vấy máu, sóng dữ đánh chìm thuyền cả hai phe.',
    'Lão ngư cuối cùng trên đảo nói: "Biển không có chủ, chỉ có người biết ơn biển."',
  ], Bonus.hpPct, 0.03),
  LoreChapter('r8', 'Rồng trắng trên mây', [
    'Tiên cảnh chỉ hiện ra khi sương tan, mỗi năm vài ngày.',
    'Bạch Long Vương từng là thần hộ sơn, được các phái thờ phụng.',
    'Phản đồ các phái trốn lên đây, dùng tà thuật trói buộc thần long.',
    'Dấu ấn rồng trắng trong sổ đen chính là tín vật của bọn phản đồ.',
    'Khi long hồn được giải thoát, mây tầng tầng sẽ tan như chưa từng có.',
  ], Bonus.dodge, 0.01),
  LoreChapter('r9', 'Luận kiếm Hoa Sơn', [
    'Mỗi hai mươi năm, cao thủ thiên hạ lên Hoa Sơn luận kiếm.',
    'Kẻ thua chôn kiếm của mình nơi đây, lâu dần thành Kiếm Mộ.',
    'Kiếm hồn của họ không cam lòng, ngày đêm vẫn so chiêu với nhau.',
    'Thiên Ma Lão Tổ từng thua một trận duy nhất, và chưa bao giờ quên.',
    'Câu khắc trên đá: "Kiếm pháp cao nhất là biết lúc nào tra kiếm vào vỏ."',
  ], Bonus.atkPct, 0.03),
];

final Map<String, LoreChapter> loreByRealm = {for (final c in loreChapters) c.realm: c};

/// A page's key in the save: realm id and page index.
String loreKey(String realm, int page) => '$realm:$page';

int get lorePageCount => loreChapters.length * lorePagesPer;

/// How a bonus reads on the board.
String loreBonusLabel(Bonus b, double v) {
  final pct = '+${(v * 100).toStringAsFixed(v * 100 % 1 == 0 ? 0 : 1)}%';
  return switch (b) {
    Bonus.hpPct => 'Sinh lực $pct',
    Bonus.atkPct => 'Công lực $pct',
    Bonus.defPct => 'Phòng thủ $pct',
    Bonus.crit => 'Chí mạng $pct',
    Bonus.critDmg => 'Sát thương chí mạng $pct',
    Bonus.skillDmg => 'Sát thương kỹ năng $pct',
    Bonus.aspd => 'Tốc đánh $pct',
    Bonus.dodge => 'Né tránh $pct',
    _ => pct,
  };
}

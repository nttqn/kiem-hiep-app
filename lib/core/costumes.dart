import 'arena.dart';
import 'sect_duty.dart';

/// Ngoại trang: outfits that only change how the hero looks. Each one is
/// earned once (tower, rebirth, level 99, Boss Thế Giới, a Lôi đài season)
/// or bought with gold, and kept for good.
enum CostumeSource { tower, rebirth, level, worldBoss, gold, arena, sect }

class CostumeDef {
  const CostumeDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.source,
    required this.need,
    required this.robe,
    required this.trim,
    required this.pants,
    this.cape = 0,
    this.blade = 0,
    this.glow = 0,
    this.aura = 0,
    this.armor = 0,
  });

  final String id, name, desc;
  final CostumeSource source;

  /// Tower floor, rebirth count, level, Boss Thế Giới milestone index, gold
  /// price or Lôi đài tier, by [source].
  final int need;

  // Look: outfit colours, then optional cape, blade and glow colours (0
  // keeps the gear's), drifting motes, and a floor for the armour look tier.
  final int robe, trim, pants, cape, blade, glow, aura, armor;

  String get howTo => switch (source) {
        CostumeSource.tower => 'Vượt Tháp Thử Luyện tầng $need',
        CostumeSource.rebirth => 'Chuyển sinh lần $need',
        CostumeSource.level => 'Đạt cấp $need',
        CostumeSource.worldBoss => 'Boss Thế Giới: nhận mốc ${const ['100 nghìn', '500 nghìn', '2 triệu', '6 triệu', '15 triệu'][need]} sát thương',
        CostumeSource.gold => 'Mua với ${_thousands(need)} lượng',
        CostumeSource.arena => 'Kết thúc một mùa Lôi đài ở hạng ${arenaTiers[need].name}',
        CostumeSource.sect => 'Sư môn: đạt chức ${sectRanks[need].name}',
      };
}

String _thousands(int n) {
  final s = '$n';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

const costumes = <CostumeDef>[
  CostumeDef(
    id: 'thanhsam', name: 'Thanh Sam Thư Sinh', desc: 'Áo xanh nho nhã của kẻ sĩ giang hồ.',
    source: CostumeSource.gold, need: 150000,
    robe: 0xFF3F8A8A, trim: 0xFFE8E2D4, pants: 0xFF24484A,
  ),
  CostumeDef(
    id: 'bachy', name: 'Bạch Y Kiếm Khách', desc: 'Bạch y phiêu dật, một kiếm tung hoành.',
    source: CostumeSource.tower, need: 30,
    robe: 0xFFF2F2F0, trim: 0xFF9AA4AE, pants: 0xFFD8DCE0, cape: 0xFFE8ECF0, blade: 0xFFE8F4FF,
  ),
  CostumeDef(
    id: 'hacklong', name: 'Hắc Long Bào', desc: 'Long bào đen viền vàng của bậc tái sinh.',
    source: CostumeSource.rebirth, need: 1,
    robe: 0xFF22222A, trim: 0xFFE8C547, pants: 0xFF14141A, cape: 0xFF2A1A12,
  ),
  CostumeDef(
    id: 'tuvan', name: 'Tử Vân Đạo Bào', desc: 'Đạo bào tím như mây chiều trên đỉnh tháp.',
    source: CostumeSource.tower, need: 60,
    robe: 0xFF6A3A9A, trim: 0xFFE8D8F8, pants: 0xFF3A2258, cape: 0xFF4A2A72, aura: 0xFFC8A0FF,
  ),
  CostumeDef(
    id: 'phuong', name: 'Phượng Hoàng Y', desc: 'Lông vũ phượng hoàng rực lửa, thưởng dũng sĩ diệt boss.',
    source: CostumeSource.worldBoss, need: 3,
    robe: 0xFFD8401E, trim: 0xFFFFC84A, pants: 0xFF7A1A10, cape: 0xFFFF8A2A, glow: 0xFFFF8A3D, aura: 0xFFFFB03A,
  ),
  CostumeDef(
    id: 'tuyetanh', name: 'Tuyết Ảnh Dạ Hành', desc: 'Dạ hành y đen tuyền, ánh kiếm như tuyết.',
    source: CostumeSource.gold, need: 500000,
    robe: 0xFF1A1E2A, trim: 0xFFBFE8FF, pants: 0xFF10121A, blade: 0xFFBFE8FF, glow: 0xFF7FDBFF,
  ),
  CostumeDef(
    id: 'huyetma', name: 'Huyết Y Ma Tôn', desc: 'Huyết y nhuốm sát khí, đao kiếm đỏ như máu.',
    source: CostumeSource.rebirth, need: 3,
    robe: 0xFF5A0E12, trim: 0xFF1A0A0A, pants: 0xFF2A0608, cape: 0xFF1A0A0A, blade: 0xFFFF5A4A,
    glow: 0xFFFF2A2A, aura: 0xFFFF3A3A,
  ),
  CostumeDef(
    id: 'bangtam', name: 'Băng Tâm Tiên Y', desc: 'Tiên y trong như băng, thưởng cao thủ diệt boss.',
    source: CostumeSource.worldBoss, need: 4,
    robe: 0xFFCFEFFF, trim: 0xFF3F8FC8, pants: 0xFFE8F6FF, cape: 0xFFA8DCF8, blade: 0xFFBFE8FF,
    glow: 0xFF7FDBFF, aura: 0xFFBFE8FF,
  ),
  CostumeDef(
    id: 'minhchu', name: 'Võ Lâm Minh Chủ', desc: 'Lễ phục của minh chủ võ lâm, áo lam choàng đỏ.',
    source: CostumeSource.level, need: 99,
    robe: 0xFF22386A, trim: 0xFFE8C547, pants: 0xFF14203E, cape: 0xFFB3261E, armor: 3,
  ),
  CostumeDef(
    id: 'kimgiap', name: 'Kim Giáp Thần Tướng', desc: 'Kim giáp của thần tướng ngũ chuyển, rực sáng hào quang.',
    source: CostumeSource.rebirth, need: 5,
    robe: 0xFFE8B83A, trim: 0xFF8A2A1A, pants: 0xFF5A3A1A, cape: 0xFFB3261E, glow: 0xFFFFD45A,
    aura: 0xFFFFE07A, armor: 4,
  ),
  CostumeDef(
    id: 'loidai', name: 'Lôi Đài Bá Chủ', desc: 'Chiến bào tím viền vàng của kẻ đứng vững trên lôi đài.',
    source: CostumeSource.arena, need: 4,
    robe: 0xFF3A2A5A, trim: 0xFFFFD34A, pants: 0xFF1E1630, cape: 0xFF8A1A2A, glow: 0xFFC8A0FF, armor: 3,
  ),
  CostumeDef(
    id: 'chiton', name: 'Chí Tôn Chiến Bào', desc: 'Bạch bào choàng đỏ, chỉ dành cho bậc Võ Lâm Chí Tôn.',
    source: CostumeSource.arena, need: 6,
    robe: 0xFFF4F0E6, trim: 0xFFFF6A4A, pants: 0xFFD8D0C0, cape: 0xFFFF6A4A, glow: 0xFFFF8A5A,
    aura: 0xFFFFC07A, armor: 4,
  ),
  CostumeDef(
    id: 'truonglao', name: 'Trưởng Lão Bào', desc: 'Áo nâu viền lục của bậc trưởng lão, nghiêm cẩn mà ung dung.',
    source: CostumeSource.sect, need: 4,
    robe: 0xFF5A4030, trim: 0xFF7ACB8A, pants: 0xFF3A2A20, cape: 0xFF2E5A3E, armor: 2,
  ),
  CostumeDef(
    id: 'chuongmon', name: 'Chưởng Môn Lễ Phục', desc: 'Lễ phục chưởng môn, áo đen thêu vàng, khoác hồng bào.',
    source: CostumeSource.sect, need: 6,
    robe: 0xFF1E1A22, trim: 0xFFFFD34A, pants: 0xFF141018, cape: 0xFF9A1E2A, glow: 0xFFFFD34A,
    aura: 0xFFFFE8A0, armor: 3,
  ),
];

final Map<String, CostumeDef> costumeById = {for (final c in costumes) c.id: c};

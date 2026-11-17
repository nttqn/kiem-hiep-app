import 'alchemy.dart';
import 'content.dart' show maps;
import 'gems.dart';
import 'hero.dart';
import 'ngo_dao.dart';
import 'tang_bao.dart' show tbdDailyDrops, tbdMaxHeld;

/// Túi đồ (1.15.0): everything a hero collects that is not gear, counted
/// rather than slotted, so it never takes a bag slot. Each entry says what
/// it is for and where it comes from.
enum BagKind { use, mat, coin }

extension BagKindLabel on BagKind {
  String get label => switch (this) {
        BagKind.use => 'Tiêu hao',
        BagKind.mat => 'Nguyên liệu',
        BagKind.coin => 'Tiền tệ',
      };
}

/// What the item's detail panel can do with it.
enum BagAction { none, pill, soulToIron }

class BagEntry {
  const BagEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.count,
    required this.use,
    required this.source,
    required this.color,
    this.art = '',
    this.glyph = '',
    this.gem,
    this.pill,
    this.action = BagAction.none,
    this.note = '',
  });

  final String id, name;
  final BagKind kind;
  final int count;

  /// Công dụng and cách kiếm, as shown in the detail panel.
  final String use, source;
  final int color;

  /// A painted icon under assets/art/icons ('' for none), else a glyph
  /// name the UI turns into a Material icon, or a gem drawn as a gem.
  final String art, glyph;
  final Gem? gem;
  final PillDef? pill;
  final BagAction action;

  /// A line about the hero's own state (buff time left, pills eaten...).
  final String note;
}

/// The regions herb [tier] grows in.
String herbRegions(int tier) => [
      for (var i = 0; i < maps.length; i++)
        if (herbTierOfMap(i) == tier) maps[i].name,
    ].join(', ');

String _mins(double sec) {
  final m = (sec / 60).ceil();
  return m >= 60 ? '${m ~/ 60} giờ ${m % 60} phút' : '$m phút';
}

/// The hero's bag entries: owned ones, plus the ones a hero at this stage
/// should know how to get even with none yet.
List<BagEntry> bagEntries(HeroData h) {
  final out = <BagEntry>[
    BagEntry(
      id: 'hp',
      name: 'Kim Sang Dược',
      kind: BagKind.use,
      count: h.hpPots,
      color: 0xFFE84B4A,
      art: 'item_hp',
      glyph: 'drink',
      use: 'Hồi sinh lực trong trận (nút bình đỏ hoặc phím Q). Tự đánh cũng tự uống khi máu thấp.',
      source: 'Mua ở Tiệm (Thành), luyện Hồi Xuân Đan, thưởng nhiệm vụ, quà đăng nhập, hòm thư.',
    ),
    BagEntry(
      id: 'mp',
      name: 'Ngưng Thần Đan',
      kind: BagKind.use,
      count: h.mpPots,
      color: 0xFF4A7AE8,
      art: 'item_mp',
      glyph: 'drink',
      use: 'Hồi nội lực trong trận (nút bình xanh hoặc phím E) để tung chiêu liên tục.',
      source: 'Mua ở Tiệm (Thành), luyện Hồi Xuân Đan, thưởng nhiệm vụ, quà đăng nhập, hòm thư.',
    ),
    for (final p in pills)
      if ((h.pills[p.id] ?? 0) > 0)
        BagEntry(
          id: 'pill:${p.id}',
          name: p.name,
          kind: BagKind.use,
          count: h.pills[p.id]!,
          color: p.color,
          art: 'pill_${p.id}',
          pill: p,
          action: BagAction.pill,
          use: p.desc +
              (p.kind == PillKind.buff ? ' Thời gian cộng dồn tối đa ${maxBuffMinutes ~/ 60} giờ.' : ''),
          source: 'Luyện ở Luyện đan (Thành, từ cấp $alchemyOpenLevel) bằng thảo dược và lượng; '
              'đôi khi có trong rương thưởng, Lệnh Bài và quà sự kiện.',
          note: switch (p.kind) {
            PillKind.buff => h.buffLeft(p.id) > 0 ? 'Đang có hiệu lực: còn ${_mins(h.buffLeft(p.id))}.' : '',
            PillKind.potential => 'Đã dùng ${h.potentialPills}/$maxPotentialPills viên.',
            PillKind.potions => '',
          },
        ),
    if (h.tbdMaps > 0)
      BagEntry(
        id: 'tbd',
        name: 'Tàng Bảo Đồ',
        kind: BagKind.use,
        count: h.tbdMaps,
        color: 0xFFD8A040,
        art: 'item_tbd',
        glyph: 'map',
        use: 'Ra bản đồ luyện công, bấm nút "Tàng Bảo Đồ" để đọc: bản đồ đánh dấu một điểm đào. '
            'Đến đó đào được rương, đôi khi gặp phục kích, thủ vệ hoặc lối vào bí cảnh.',
        source: 'Quái ngoài bản đồ luyện công thỉnh thoảng rơi (boss và tinh anh rơi nhiều hơn), '
            'tối đa $tbdDailyDrops tấm mỗi ngày, giữ tối đa $tbdMaxHeld tấm.',
        note: h.tbdSpot != null ? 'Đang có một điểm đào chưa đào.' : '',
      ),
    for (var t = 0; t < herbNames.length; t++)
      if (h.herbs[t] > 0 || h.alchemyOpen)
        BagEntry(
          id: 'herb:$t',
          name: herbNames[t],
          kind: BagKind.mat,
          count: h.herbs[t],
          color: herbColors[t],
          art: 'herb_${t + 1}',
          glyph: 'herb',
          use: 'Thảo dược bậc ${t + 1}: nguyên liệu luyện đan ở Luyện đan (Thành).',
          source: 'Hái cây thuốc mọc trên bản đồ ${herbRegions(t)}; quái ở đó thỉnh thoảng rơi, '
              'boss và tinh anh luôn rơi. Trồng thêm ở Trang viên.',
        ),
    for (final e in (h.gemBag.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
      if (e.value > 0 && Gem.parse(e.key) != null)
        BagEntry(
          id: 'gem:${e.key}',
          name: Gem.parse(e.key)!.name,
          kind: BagKind.mat,
          count: e.value,
          color: 0xFF9FD8FF,
          gem: Gem.parse(e.key),
          use: 'Khảm vào lỗ ngọc của trang bị (Thợ rèn → Khảm ngọc). Ngọc cùng hành với phái được x1.5; '
              'ghép 3 viên cùng loại thành 1 viên bậc cao hơn.',
          source: 'Quái rơi ngẫu nhiên, boss luôn rơi; Ải Ác Mộng, Kỳ Trân Các, Lôi đài, Võ Lâm Đại Hội, '
              'Lệnh Bài và hòm thư.',
        ),
    if (h.goldShards > 0 || h.goldOpen)
      BagEntry(
        id: 'shard',
        name: 'Mảnh Hoàng Kim',
        kind: BagKind.mat,
        count: h.goldShards,
        color: 0xFFFFC83A,
        art: 'mat_shard',
        use: 'Rèn đồ Hoàng Kim theo bộ, đúc lại đồ Hoàng Kim lên cấp hiện tại và mua trong tiệm Hoàng Kim '
            '(Thợ rèn → Hoàng Kim).',
        source: 'Mốc sát thương Boss Thế Giới, Boss Hoàng Kim, Tháp Thử Luyện tầng 40 trở lên, Ải Ác Mộng, '
            'rương Năng động tuần, thưởng mùa Lôi đài, boss và tinh anh cấp cao, Sư môn, Bang hội, Lệnh Bài.',
      ),
    if (h.soulPills > 0 || h.level >= maxLevel || h.rebirths > 0)
      BagEntry(
        id: 'soulpill',
        name: 'Linh Phách Đơn',
        kind: BagKind.mat,
        count: h.soulPills,
        color: 0xFF9FE8FF,
        art: 'mat_soulpill',
        action: BagAction.soulToIron,
        use: 'Cần để Chuyển sinh${h.daoOpen ? ' và Độ kiếp (Ngộ Đạo)' : ''}. '
            'Đổi $soulPillsPerIron viên lấy 1 Thần Thiết.',
        source: 'Ngưng tụ từ EXP dư khi đã đầy thanh kinh nghiệm ở cấp $maxLevel; Boss Bang, tiệm Bang hội, '
            'Lệnh Bài, quà sự kiện.',
        note: h.rebirths < maxRebirths ? 'Chuyển sinh ${h.rebirths + 1} cần ${h.nextRebirthPills} viên.' : '',
      ),
    if (h.divineIron > 0 || h.rebirths > 0)
      BagEntry(
        id: 'iron',
        name: 'Thần Thiết',
        kind: BagKind.mat,
        count: h.divineIron,
        color: 0xFFB8C8E0,
        art: 'mat_iron',
        use: 'Thức tỉnh Thần binh (Thợ rèn → Thần binh) và nâng Tu vi Lưu phái.',
        source: 'Ải Ác Mộng 7 trở lên (vượt lần đầu được nhiều), mốc sát thương Boss Thế Giới, Tháp tầng 100+, '
            'Boss Hoàng Kim, Lôi đài, Boss Bang, Võ Lâm Đại Hội; đổi từ Linh Phách Đơn.',
      ),
    if (h.starStones > 0 || h.rebirths > 0)
      BagEntry(
        id: 'stone',
        name: 'Tinh Thạch',
        kind: BagKind.mat,
        count: h.starStones,
        color: 0xFFC8A0FF,
        art: 'mat_stone',
        use: 'Thăng Tinh trang bị đã cường hóa tối đa (bấm vào món đồ → Thăng Tinh), mỗi sao tăng chỉ số gốc.',
        source: 'Tâm Ma Ảo Cảnh (lần đầu qua tầng), Ma Vực (tầng mới mỗi tuần), Thượng Cổ Hung Thú, '
            'luyện hóa ngọc Thần/Tiên/Thánh, Lệnh Bài, tiệm Bang hội, Gói Thăng Tinh.',
      ),
    if (h.beastSouls > 0 || h.rebirths > 0)
      BagEntry(
        id: 'soul',
        name: 'Hung Thú Tinh Phách',
        kind: BagKind.mat,
        count: h.beastSouls,
        color: 0xFFFF7A5A,
        art: 'mat_soul',
        use: 'Cùng Tinh Thạch để Thăng Tinh hai sao cuối (★4, ★5).',
        source: 'Hạ Thượng Cổ Hung Thú lần đầu mỗi tuần ở mỗi độ khó, Lệnh Bài, Gói Thăng Tinh, quà sự kiện.',
      ),
    if (h.tienJade > 0 || h.daoOpen)
      BagEntry(
        id: 'jade',
        name: 'Tiên Ngọc',
        kind: BagKind.mat,
        count: h.tienJade,
        color: 0xFF7AE8C8,
        art: 'item_tienngoc',
        glyph: 'jade',
        use: 'Luyện Tiên khí cho trang bị đang mặc (Ngộ Đạo → Tiên khí), mỗi phẩm tăng chỉ số gốc.',
        source: 'Mỗi tầng Ngộ Đạo mới, mỗi lần Độ kiếp thắng, top bảng Boss Hoàng Kim, tiệm Bang hội, hòm thư.',
      ),
    if (h.arenaCoins > 0)
      BagEntry(
        id: 'arena',
        name: 'Uy danh',
        kind: BagKind.coin,
        count: h.arenaCoins,
        color: 0xFFFFD34A,
        glyph: 'arena',
        use: 'Đổi đồ ở Tiệm Uy danh (Lôi đài) và mở một số thú cưỡi.',
        source: 'Đấu Lôi đài, lương ngày theo bậc, thưởng mùa và thứ hạng, Võ Lâm Đại Hội.',
      ),
    if (h.sectCoins > 0)
      BagEntry(
        id: 'sect',
        name: 'Cống hiến Sư môn',
        kind: BagKind.coin,
        count: h.sectCoins,
        color: 0xFFE8C547,
        glyph: 'sect',
        use: 'Đổi trang bí kíp, Mảnh Hoàng Kim và vật phẩm ở Tàng Kinh Các (Sư môn).',
        source: 'Làm nhiệm vụ Sư môn mỗi ngày (cứ nhiệm vụ thứ 5 được gấp đôi).',
      ),
    if (h.guildCoins > 0)
      BagEntry(
        id: 'guild',
        name: 'Xu Bang',
        kind: BagKind.coin,
        count: h.guildCoins,
        color: 0xFF8AD8FF,
        glyph: 'guild',
        use: 'Mua hàng trong tiệm Bang hội (làm mới mỗi thứ Hai).',
        source: 'Điểm danh và quyên góp cho bang, đánh Boss Bang.',
      ),
  ];
  return out;
}


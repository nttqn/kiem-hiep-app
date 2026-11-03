import 'hero.dart';
import 'mounts.dart';

/// Ngoại hình thú cưỡi (1.7.0): new colours and an aura for a mount the
/// hero owns. Looks only: the mount's stats stay the same.
enum SkinSource { gold, arena, iron, tower }

class MountSkin {
  const MountSkin({
    required this.id,
    required this.mount,
    required this.name,
    required this.c1,
    required this.c2,
    required this.c3,
    this.aura = 0,
    required this.source,
    required this.need,
  });

  final String id, mount, name;
  final int c1, c2, c3;

  /// Glow and sparkles round the mount, 0 for none.
  final int aura;
  final SkinSource source;

  /// Lượng, Uy danh or Thần Thiết price, or a tower floor, by [source].
  final int need;

  String get howTo => switch (source) {
        SkinSource.gold => '${fmtNeed(need)} lượng',
        SkinSource.arena => '${fmtNeed(need)} Uy danh',
        SkinSource.iron => '$need Thần Thiết',
        SkinSource.tower => 'Vượt Tháp tầng $need',
      };
}

String fmtNeed(int n) {
  if (n >= 1000000 && n % 1000000 == 0) return '${n ~/ 1000000} triệu';
  if (n >= 1000 && n % 1000 == 0) return '${n ~/ 1000}k';
  return '$n';
}

const mountSkins = <MountSkin>[
  MountSkin(id: 'nau_o', mount: 'nau', name: 'Ô Truy', c1: 0xFF2A2420, c2: 0xFF0E0C0A, c3: 0xFFE8C547,
      source: SkinSource.gold, need: 30000),
  MountSkin(id: 'bachma_ngoc', mount: 'bachma', name: 'Ngọc Long Câu', c1: 0xFFD8F0E4, c2: 0xFF7AC8A8, c3: 0xFF2A7A5A,
      aura: 0xFF9AF0C8, source: SkinSource.gold, need: 300000),
  MountSkin(id: 'hanhuyet_kim', mount: 'hanhuyet', name: 'Kim Diệm Bảo Mã', c1: 0xFFE8B83A, c2: 0xFFB8401A, c3: 0xFF8A1A1A,
      aura: 0xFFFFC34A, source: SkinSource.tower, need: 80),
  MountSkin(id: 'bachho_bang', mount: 'bachho', name: 'Băng Phách Hổ', c1: 0xFFD8F0FF, c2: 0xFF3A8AC8, c3: 0xFF6AD8FF,
      aura: 0xFF9FE8FF, source: SkinSource.arena, need: 8000),
  MountSkin(id: 'bachho_hac', mount: 'bachho', name: 'Hắc Sát Hổ', c1: 0xFF2E2A34, c2: 0xFFE8C547, c3: 0xFFB3261E,
      aura: 0xFFFF6A3A, source: SkinSource.arena, need: 15000),
  MountSkin(id: 'thanloc_anh', mount: 'thanloc', name: 'Anh Đào Lộc', c1: 0xFFF4C8D4, c2: 0xFFFFF0F4, c3: 0xFFD84A7A,
      aura: 0xFFFF9AC8, source: SkinSource.gold, need: 800000),
  MountSkin(id: 'kylan_lam', mount: 'kylan', name: 'Lam Diệm Kỳ Lân', c1: 0xFF2E6AD8, c2: 0xFF8AE8FF, c3: 0xFFFFC34A,
      aura: 0xFF6AB8FF, source: SkinSource.iron, need: 40),
  MountSkin(id: 'huyenminh_huyet', mount: 'huyenminh', name: 'Huyết Ngục Kỳ Lân', c1: 0xFF4A0E14, c2: 0xFFFF3A3A, c3: 0xFFFFC34A,
      aura: 0xFFFF3A4A, source: SkinSource.iron, need: 80),
  MountSkin(id: 'longma_kim', mount: 'longma', name: 'Kim Lân Long Mã', c1: 0xFFE8C547, c2: 0xFFFFF4C8, c3: 0xFF2E8AA0,
      aura: 0xFFFFE07A, source: SkinSource.gold, need: 2000000),
  MountSkin(id: 'cuusac_nguyet', mount: 'cuusac', name: 'Nguyệt Quang Lộc', c1: 0xFFC8D4F0, c2: 0xFFFFFFFF, c3: 0xFF6A7AD8,
      aura: 0xFFE8F0FF, source: SkinSource.iron, need: 120),
  MountSkin(id: 'phikiem_hoa', mount: 'phikiem', name: 'Xích Diệm Phi Kiếm', c1: 0xFFFFD8C8, c2: 0xFFFF5A2A, c3: 0xFF8A1A1A,
      aura: 0xFFFF7A3A, source: SkinSource.tower, need: 130),
  MountSkin(id: 'phikiem_tu', mount: 'phikiem', name: 'Tử Điện Phi Kiếm', c1: 0xFFE8D8FF, c2: 0xFFB04AFF, c3: 0xFFE8C547,
      aura: 0xFFC88CFF, source: SkinSource.arena, need: 20000),
  MountSkin(id: 'phikiem_bang', mount: 'phikiem', name: 'Hàn Băng Phi Kiếm', c1: 0xFFF0FAFF, c2: 0xFF9FE8FF, c3: 0xFF3A6AA8,
      aura: 0xFFBFF0FF, source: SkinSource.iron, need: 100),
];

final Map<String, MountSkin> skinById = {for (final s in mountSkins) s.id: s};

List<MountSkin> skinsOf(String mount) => [for (final s in mountSkins) if (s.mount == mount) s];

extension MountSkins on HeroData {
  bool ownsSkin(String id) => ownedSkins.contains(id);

  /// [m] as the hero has dressed it.
  MountDef dressed(MountDef m) {
    final s = skinById[mountSkin[m.id]];
    return s == null ? m : m.skinned(s.c1, s.c2, s.c3, s.aura);
  }

  bool canGetSkin(MountSkin s) {
    if (ownsSkin(s.id) || !ownsMount(s.mount)) return false;
    return switch (s.source) {
      SkinSource.gold => gold >= s.need,
      SkinSource.arena => arenaCoins >= s.need,
      SkinSource.iron => divineIron >= s.need,
      SkinSource.tower => towerBest >= s.need,
    };
  }

  /// Buys (or claims) [s] and puts it on.
  bool getSkin(MountSkin s) {
    if (!canGetSkin(s)) return false;
    switch (s.source) {
      case SkinSource.gold:
        gold -= s.need;
      case SkinSource.arena:
        arenaCoins -= s.need;
      case SkinSource.iron:
        divineIron -= s.need;
      case SkinSource.tower:
        break;
    }
    ownedSkins.add(s.id);
    mountSkin[s.mount] = s.id;
    return true;
  }

  /// Puts on skin [id] (null: the mount's own colours).
  void wearSkin(String mount, String? id) {
    if (id == null) {
      mountSkin.remove(mount);
    } else if (ownsSkin(id) && skinById[id]?.mount == mount) {
      mountSkin[mount] = id;
    }
  }
}

import 'hero.dart';
import 'items.dart';
import 'ngo_dao.dart';

/// Tiên khí (1.13.0): where Đạo hạnh goes besides the tầng bonuses. A worn
/// +[maxPlus] piece is forged phẩm by phẩm with Tiên Ngọc and gold, each
/// phẩm adding [tienBasePct] to its base stats. Phẩm n asks for the n-th
/// cảnh giới (Luyện Khí for the first, Chân Tiên for the ninth).
///
/// Tiên Ngọc comes from every new tầng of Ngộ Đạo, each won Độ kiếp, the
/// top of the Boss Hoàng Kim board and the Bang hội shop.
const List<int> tienJadeCost = [2, 3, 5, 7, 10, 14, 19, 25, 32];

/// Gold for phẩm [n] (1-based).
int tienGoldCost(int n) => 2000000 * n;

/// Why [it] can't go on to its next phẩm for [h], or null when it can.
String? tienBlock(HeroData h, Item it) {
  if (!h.daoOpen || h.daoLv <= 0) return 'Cần nhập Ngộ Đạo';
  if (it.tien >= maxTien) return 'Đã đạt Tiên phẩm tối đa';
  if (it.plus < maxPlus) return 'Cần cường hóa +$maxPlus';
  final n = it.tien + 1;
  if (daoStageOf(h.daoLv) < n - 1) return 'Cần cảnh giới ${daoStages[n - 1].name}';
  if (h.tienJade < tienJadeCost[n - 1]) return 'Thiếu Tiên Ngọc';
  if (h.gold < tienGoldCost(n)) return 'Thiếu ngân lượng';
  return null;
}

extension TienKhi on HeroData {
  /// Forges [it] one phẩm up; false (nothing spent) when [tienBlock]ed.
  bool tienForge(Item it) {
    if (tienBlock(this, it) != null) return false;
    final n = it.tien + 1;
    tienJade -= tienJadeCost[n - 1];
    gold -= tienGoldCost(n);
    it.tien = n;
    recompute();
    return true;
  }
}

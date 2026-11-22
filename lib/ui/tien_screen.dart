import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/items.dart';
import '../core/ngo_dao.dart';
import '../core/tien_khi.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';

const _jadeTint = Color(0xFF9FF0E0);

/// Tiên khí (1.13.0): forge the worn pieces phẩm by phẩm with Tiên Ngọc.
class TienScreen extends StatefulWidget {
  const TienScreen({super.key});

  @override
  State<TienScreen> createState() => _TienScreenState();
}

class _TienScreenState extends State<TienScreen> {
  HeroData get h => SaveService.instance.hero;
  String? _msg;

  void _forge(Item it) {
    if (!h.tienForge(it)) return;
    SaveService.instance.save();
    setState(() => _msg = tr('{itName} lên Tiên phẩm {tien}: chỉ số gốc +{p0}%.', {'itName': tr(it.name), 'tien': it.tien, 'p0': (tienBasePct * 100 * it.tien).round()}));
  }

  @override
  Widget build(BuildContext context) {
    final worn = [for (final s in Slot.values) ?h.equip[s]];
    return SubScreen(
      title: tr('Tiên khí'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 230, child: _info()),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: worn.isEmpty
                        ? Center(child: Text(tr('Chưa mặc trang bị.'), style: body))
                        : ListView(children: [for (final it in worn) _row(it)]),
                  ),
                  if (_msg != null)
                    Text(_msg!, style: small.copyWith(color: cream), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info() {
    final stage = daoStageOf(h.daoLv);
    return Panel(
      border: _jadeTint,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MatIcon(Mat.jade, size: 26),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('{tienJade} Tiên Ngọc', {'tienJade': h.tienJade}), style: titleStyle(18, color: _jadeTint))),
            ],
          ),
          Text(h.daoLv > 0 ? daoName(h.daoLv) : tr('Chưa nhập Ngộ Đạo'),
              style: small.copyWith(color: Color(daoColor(h.daoLv)))),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                Text(
                    tr('Mỗi Tiên phẩm: chỉ số gốc +{p0}% (tối đa phẩm {maxTien}, '
                    '+{p1}%). Món phải cường hóa +{maxPlus}.', {'p0': (tienBasePct * 100).round(), 'maxTien': maxTien, 'p1': (tienBasePct * 100 * maxTien).round(), 'maxPlus': maxPlus}),
                    style: body.copyWith(fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(tr('Phẩm n cần cảnh giới thứ n:'), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
                for (var i = 0; i < maxTien; i++)
                  Text(tr('Phẩm {p0}: {p1} · {p2} Tiên Ngọc · {p3} lượng', {'p0': i + 1, 'p1': tr(daoStages[i].name), 'p2': tienJadeCost[i], 'p3': fmt(tienGoldCost(i + 1))}),
                      style: small.copyWith(fontSize: 11, color: i <= stage ? cream : creamDim)),
                const SizedBox(height: 6),
                Text(tr('Nguồn Tiên Ngọc'), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
                Text(
                    tr('• +{daoLayerJade} mỗi tầng Ngộ Đạo mới\n'
                    '• Độ kiếp thành công: +5 × cảnh giới\n'
                    '• Top 10 Boss Hoàng Kim mỗi ngày\n'
                    '• Cửa hàng Bang hội', {'daoLayerJade': daoLayerJade}),
                    style: small.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Item it) {
    final block = tienBlock(h, it);
    final maxed = it.tien >= maxTien;
    final n = it.tien + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: it.tien > 0 ? _jadeTint.withValues(alpha: 0.7) : gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ItemTile(item: it, size: 42),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(it.title),
                    style: bold.copyWith(fontSize: 13, color: Color(it.color)), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  maxed
                      ? tr('Tiên phẩm {maxTien} · chỉ số gốc +{p0}%', {'maxTien': maxTien, 'p0': (tienBasePct * 100 * it.tien).round()})
                      : tr('Phẩm {tien} → {n}: {p0} Tiên Ngọc, {p1} lượng'
                          '{p2}', {'tien': it.tien, 'n': n, 'p0': tienJadeCost[n - 1], 'p1': fmt(tienGoldCost(n)), 'p2': block != null ? ' · $block' : ''}),
                  style: small.copyWith(fontSize: 11, color: block == null || maxed ? cream : creamDim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          LButton(
            label: maxed ? tr('Tối đa') : tr('Luyện'),
            small: true,
            color: const Color(0xFF2E8A7A),
            enabled: block == null,
            onTap: () => _forge(it),
          ),
        ],
      ),
    );
  }
}

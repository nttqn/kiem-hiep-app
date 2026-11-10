import 'package:flutter/material.dart';

import '../core/hero.dart';
import '../core/items.dart';
import '../core/ngo_dao.dart';
import '../core/tien_khi.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

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
    setState(() => _msg = '${it.name} lên Tiên phẩm ${it.tien}: chỉ số gốc +${(tienBasePct * 100 * it.tien).round()}%.');
  }

  @override
  Widget build(BuildContext context) {
    final worn = [for (final s in Slot.values) ?h.equip[s]];
    return SubScreen(
      title: 'Tiên khí',
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
                        ? Center(child: Text('Chưa mặc trang bị.', style: body))
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
              const Icon(Icons.diamond, color: _jadeTint, size: 22),
              const SizedBox(width: 6),
              Expanded(child: Text('${h.tienJade} Tiên Ngọc', style: titleStyle(18, color: _jadeTint))),
            ],
          ),
          Text(h.daoLv > 0 ? daoName(h.daoLv) : 'Chưa nhập Ngộ Đạo',
              style: small.copyWith(color: Color(daoColor(h.daoLv)))),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                Text(
                    'Mỗi Tiên phẩm: chỉ số gốc +${(tienBasePct * 100).round()}% (tối đa phẩm $maxTien, '
                    '+${(tienBasePct * 100 * maxTien).round()}%). Món phải cường hóa +$maxPlus.',
                    style: body.copyWith(fontSize: 12.5)),
                const SizedBox(height: 6),
                Text('Phẩm n cần cảnh giới thứ n:', style: bold.copyWith(color: goldLight, fontSize: 12.5)),
                for (var i = 0; i < maxTien; i++)
                  Text('Phẩm ${i + 1}: ${daoStages[i].name} · ${tienJadeCost[i]} Tiên Ngọc · ${fmt(tienGoldCost(i + 1))} lượng',
                      style: small.copyWith(fontSize: 11, color: i <= stage ? cream : creamDim)),
                const SizedBox(height: 6),
                Text('Nguồn Tiên Ngọc', style: bold.copyWith(color: goldLight, fontSize: 12.5)),
                Text(
                    '• +$daoLayerJade mỗi tầng Ngộ Đạo mới\n'
                    '• Độ kiếp thành công: +5 × cảnh giới\n'
                    '• Top 10 Boss Hoàng Kim mỗi ngày\n'
                    '• Cửa hàng Bang hội',
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
                Text(it.title,
                    style: bold.copyWith(fontSize: 13, color: Color(it.color)), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  maxed
                      ? 'Tiên phẩm $maxTien · chỉ số gốc +${(tienBasePct * 100 * it.tien).round()}%'
                      : 'Phẩm ${it.tien} → $n: ${tienJadeCost[n - 1]} Tiên Ngọc, ${fmt(tienGoldCost(n))} lượng'
                          '${block != null ? ' · $block' : ''}',
                  style: small.copyWith(fontSize: 11, color: block == null || maxed ? cream : creamDim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          LButton(
            label: maxed ? 'Tối đa' : 'Luyện',
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

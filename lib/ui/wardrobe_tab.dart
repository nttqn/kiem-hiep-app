import 'package:flutter/material.dart';

import '../core/costumes.dart';
import '../core/hero.dart';
import '../render/art_figures.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'theme.dart';

/// Ngoại trang tab: try any outfit on, wear the ones owned, buy the gold
/// ones, and hide the hat.
class WardrobeTab extends StatefulWidget {
  const WardrobeTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<WardrobeTab> createState() => _WardrobeTabState();
}

class _WardrobeTabState extends State<WardrobeTab> {
  HeroData get h => SaveService.instance.hero;

  /// Outfit being tried on; '' is the gear's own look.
  late String _sel = h.costume;
  String? _msg;

  void _wear(String id) {
    h.wearCostume(id);
    Analytics.instance.log('costume_wear', {'id': id.isEmpty ? 'none' : id});
    SaveService.instance.save();
    setState(() => _msg = id.isEmpty ? 'Đã mặc theo trang bị.' : 'Đã mặc ${costumeById[id]!.name}.');
    widget.onChanged();
  }

  void _buy(CostumeDef c) {
    if (!h.buyCostume(c.id)) {
      setState(() => _msg = 'Không đủ lượng (cần ${fmt(c.need)}).');
      return;
    }
    Analytics.instance.log('costume_buy', {'id': c.id});
    h.wearCostume(c.id);
    SaveService.instance.save();
    setState(() => _msg = 'Đã mua và mặc ${c.name}!');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = costumeById[_sel];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 250,
          child: Panel(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c?.name ?? 'Theo trang bị', style: titleStyle(18), textAlign: TextAlign.center),
                Text(c?.desc ?? 'Trang phục đổi theo nón, áo, đai, hài và vũ khí đang mặc.',
                    style: small.copyWith(fontSize: 11), textAlign: TextAlign.center),
                Expanded(
                  child: FittedBox(
                    child: FigurePreview(
                      hanh: h.hanh,
                      female: h.female,
                      scale: 2,
                      gear: HeroGear.of(h.equip, hideHat: h.hideHat),
                      costume: c,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Ẩn mũ', style: small.copyWith(color: cream))),
                    Switch(
                      value: h.hideHat,
                      activeThumbColor: goldLight,
                      onChanged: (v) {
                        setState(() => h.hideHat = v);
                        SaveService.instance.save();
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
                _action(c),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Ngoại trang', style: titleStyle(18))),
                    Text('Sưu tập ${h.ownedCostumes.length}/${costumes.length}', style: bold.copyWith(color: goldLight)),
                  ],
                ),
                Text('Chỉ đổi diện mạo, không đổi chỉ số. Chạm để mặc thử.', style: small.copyWith(fontSize: 11)),
                if (_msg != null) Text(_msg!, style: small.copyWith(color: cream)),
                const SizedBox(height: 6),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 3.3,
                    children: [
                      _tile(null),
                      for (final c in costumes) _tile(c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _action(CostumeDef? c) {
    final id = c?.id ?? '';
    if (h.costume == id) {
      return Text('Đang mặc', style: bold.copyWith(color: goldLight), textAlign: TextAlign.center);
    }
    if (c == null || h.ownedCostumes.contains(id)) {
      return LButton(label: 'Mặc', icon: Icons.checkroom, onTap: () => _wear(id));
    }
    if (c.source == CostumeSource.gold) {
      return LButton(
        label: 'Mua ${fmt(c.need)} lượng',
        icon: Icons.shopping_bag,
        color: jade,
        enabled: h.gold >= c.need,
        onTap: () => _buy(c),
      );
    }
    return Text('Mở khóa: ${c.howTo}', style: small.copyWith(color: cream), textAlign: TextAlign.center);
  }

  Widget _tile(CostumeDef? c) {
    final id = c?.id ?? '';
    final sel = _sel == id;
    final owned = c == null || h.ownedCostumes.contains(id);
    final robe = Color(c?.robe ?? 0xFF6A5A4A);
    final trim = Color(c?.trim ?? 0xFFD9A93B);
    return GestureDetector(
      onTap: () => setState(() {
        _sel = id;
        _msg = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? Color.lerp(lacquer, seal, 0.4) : lacquerDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? goldLight : gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Swatch: robe with its trim, and the cape when there is one.
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: robe,
                border: Border.all(color: trim, width: 4),
                boxShadow: c != null && c.aura != 0
                    ? [BoxShadow(color: Color(c.aura).withValues(alpha: 0.7), blurRadius: 8)]
                    : null,
              ),
              child: c == null ? const Icon(Icons.shield, size: 14, color: cream) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c?.name ?? 'Theo trang bị',
                      style: bold.copyWith(fontSize: 12.5, color: owned ? cream : creamDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    h.costume == id ? 'Đang mặc' : (owned ? 'Đã có' : c.howTo),
                    style: small.copyWith(fontSize: 10, color: h.costume == id ? goldLight : creamDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!owned) const Icon(Icons.lock, size: 14, color: creamDim),
          ],
        ),
      ),
    );
  }
}

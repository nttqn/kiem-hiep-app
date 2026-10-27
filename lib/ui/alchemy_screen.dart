import 'package:flutter/material.dart';

import '../core/alchemy.dart';
import '../core/content.dart';
import '../core/hero.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Luyện đan: herbs on hand, the furnace's recipes, and pills to take.
class AlchemyScreen extends StatefulWidget {
  const AlchemyScreen({super.key});

  @override
  State<AlchemyScreen> createState() => _AlchemyScreenState();
}

class _AlchemyScreenState extends State<AlchemyScreen> {
  HeroData get h => SaveService.instance.hero;

  void _changed(String msg) {
    SaveService.instance.save();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    setState(() {});
  }

  /// Regions where herb [tier] grows.
  String _where(int tier) => [
        for (var i = 0; i < maps.length; i++)
          if (herbTierOfMap(i) == tier) maps[i].name,
      ].join(', ');

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Luyện đan',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 210, child: _herbs()),
          const SizedBox(width: 8),
          Expanded(child: _recipes()),
          const SizedBox(width: 8),
          SizedBox(width: 250, child: _pills()),
        ],
      ),
    );
  }

  Widget _herbs() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dược liệu', style: titleStyle(18)),
          Text('Đi qua cây thuốc phát sáng ở bãi luyện công để hái; quái và đầu lĩnh cũng rơi.',
              style: small.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < herbNames.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        _herbDot(i),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${herbNames[i]} · ${h.herbs[i]}', style: bold.copyWith(fontSize: 13)),
                              Text(_where(i), style: small.copyWith(fontSize: 10), maxLines: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _herbDot(int tier, {double size = 16}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(herbColors[tier]),
          shape: BoxShape.circle,
          border: Border.all(color: lacquerDeep, width: 1.5),
        ),
      );

  Widget _recipes() {
    final open = h.alchemyOpen;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lò luyện đan', style: titleStyle(18)),
          if (!open) Text('Mở ở cấp $alchemyOpenLevel', style: bold.copyWith(color: const Color(0xFFFF9A7A))),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: [for (final p in pills) _recipe(p, open)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipe(PillDef p, bool open) {
    final can = open && h.canCraft(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: can ? goldLight : gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _pillIcon(p),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: bold.copyWith(color: Color(p.color))),
                Text(p.desc, style: small.copyWith(fontSize: 11)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < p.herbs.length; i++)
                      if (p.herbs[i] > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _herbDot(i, size: 11),
                            const SizedBox(width: 3),
                            Text('${herbNames[i]} ${h.herbs[i]}/${p.herbs[i]}',
                                style: small.copyWith(
                                    fontSize: 11, color: h.herbs[i] >= p.herbs[i] ? cream : const Color(0xFFFF8A7A))),
                          ],
                        ),
                    Text('${fmt(p.gold)} lượng',
                        style: small.copyWith(fontSize: 11, color: h.gold >= p.gold ? goldLight : const Color(0xFFFF8A7A))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LButton(
            label: 'Luyện',
            small: true,
            color: jade,
            enabled: can,
            onTap: () {
              if (!h.craft(p)) return;
              SoundService.instance.cue('magic');
              _changed('Luyện thành ${p.name}!');
            },
          ),
        ],
      ),
    );
  }

  Widget _pillIcon(PillDef p, {double size = 30}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [Colors.white, Color(p.color), Color.lerp(Color(p.color), Colors.black, 0.45)!],
            stops: const [0, 0.45, 1],
          ),
          border: Border.all(color: lacquerDeep, width: 1.5),
        ),
      );

  Widget _pills() {
    final owned = [for (final p in pills) if ((h.pills[p.id] ?? 0) > 0) p];
    final active = [for (final p in pills) if (h.buffLeft(p.id) > 0) p];
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Đan dược', style: titleStyle(18)),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final p in active)
              Text('${p.name}: còn ${(h.buffLeft(p.id) / 60).ceil()} phút',
                  style: small.copyWith(fontSize: 11.5, color: Color(p.color), fontWeight: FontWeight.w700)),
          ],
          Text('Thời gian bùa lợi chỉ trôi khi đang chơi. '
              'Tẩy Tủy Đan đã dùng: ${h.potentialPills}/$maxPotentialPills',
              style: small.copyWith(fontSize: 10.5)),
          const SizedBox(height: 6),
          Expanded(
            child: owned.isEmpty
                ? Center(child: Text('Chưa có đan dược nào.', style: small))
                : ListView(
                    children: [
                      for (final p in owned)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              _pillIcon(p, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${p.name} x${h.pills[p.id]}', style: bold.copyWith(fontSize: 13)),
                              ),
                              LButton(
                                label: 'Dùng',
                                small: true,
                                color: seal,
                                enabled: h.canUsePill(p),
                                onTap: () {
                                  if (!h.usePill(p)) return;
                                  SoundService.instance.cue('potion');
                                  _changed(switch (p.kind) {
                                    PillKind.buff => '${p.name}: ${p.desc}',
                                    PillKind.potions => '+10 Kim Sang Dược, +10 Ngưng Thần Đan',
                                    PillKind.potential => '+$potentialPerPill điểm tiềm năng!',
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

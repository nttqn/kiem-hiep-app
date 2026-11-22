import 'package:flutter/material.dart';

import '../core/alchemy.dart';
import '../core/content.dart';
import '../core/hero.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'sub_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';

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
          if (herbTierOfMap(i) == tier) tr(maps[i].name),
      ].join(', ');

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: tr('Luyện đan'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 190, child: _herbs()),
          const SizedBox(width: 8),
          Expanded(child: _recipes()),
          const SizedBox(width: 8),
          SizedBox(width: 262, child: _pills()),
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
          Text(tr('Dược liệu'), style: titleStyle(18)),
          Text(tr('Đi qua cây thuốc phát sáng ở bãi luyện công để hái; quái và đầu lĩnh cũng rơi.'),
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
                              Text('${tr(herbNames[i])} · ${h.herbs[i]}', style: bold.copyWith(fontSize: 13)),
                              Text(tr(_where(i)), style: small.copyWith(fontSize: 10), maxLines: 2),
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

  /// The herb's painted icon (1.16.2), a little larger than the dot it replaced.
  Widget _herbDot(int tier, {double size = 16}) => MatIcon(herbMat(tier), size: size + 6);

  Widget _recipes() {
    final open = h.alchemyOpen;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Lò luyện đan'), style: titleStyle(18)),
          if (!open) Text(tr('Mở ở cấp {alchemyOpenLevel}', {'alchemyOpenLevel': alchemyOpenLevel}), style: bold.copyWith(color: const Color(0xFFFF9A7A))),
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
                Text(tr(p.name), style: bold.copyWith(color: Color(p.color))),
                Text(tr(p.desc), style: small.copyWith(fontSize: 11)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < p.herbs.length; i++)
                      if (p.herbs[i] > 0)
                        // Wraps in a narrow column instead of overflowing.
                        Text.rich(
                          TextSpan(children: [
                            WidgetSpan(alignment: PlaceholderAlignment.middle, child: _herbDot(i, size: 11)),
                            TextSpan(text: ' ${tr(herbNames[i])} ${h.herbs[i]}/${p.herbs[i]}'),
                          ]),
                          style: small.copyWith(
                              fontSize: 11, color: h.herbs[i] >= p.herbs[i] ? cream : const Color(0xFFFF8A7A)),
                        ),
                    Text(tr('{p0} lượng', {'p0': fmt(p.gold)}),
                        style: small.copyWith(fontSize: 11, color: h.gold >= p.gold ? goldLight : const Color(0xFFFF8A7A))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LButton(
            label: tr('Luyện'),
            small: true,
            color: jade,
            enabled: can,
            onTap: () {
              if (!h.craft(p)) return;
              SoundService.instance.cue('magic');
              _changed(tr('Luyện thành {pName}!', {'pName': tr(p.name)}));
            },
          ),
        ],
      ),
    );
  }

  /// Every pill's painted icon (assets/art/icons/pill_{id}.webp, 1.11.2);
  /// the coloured dot stands in for one not there.
  Widget _pillIcon(PillDef p, {double size = 30}) => Image.asset('assets/art/icons/pill_${p.id}.webp',
      width: size * 1.25,
      height: size * 1.25,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _pillDot(p, size));

  Widget _pillDot(PillDef p, double size) => Container(
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
          Text(tr('Đan dược'), style: titleStyle(18)),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final p in active)
              Text(tr('{pName}: còn {p0} phút', {'pName': tr(p.name), 'p0': (h.buffLeft(p.id) / 60).ceil()}),
                  style: small.copyWith(fontSize: 11.5, color: Color(p.color), fontWeight: FontWeight.w700)),
          ],
          Text(tr('Thời gian bùa lợi chỉ trôi khi đang chơi, cộng dồn tối đa {p0} giờ. '
              'Tẩy Tủy Đan đã dùng: {potentialPills}/{maxPotentialPills}', {'p0': maxBuffMinutes ~/ 60, 'potentialPills': h.potentialPills, 'maxPotentialPills': maxPotentialPills}),
              style: small.copyWith(fontSize: 10.5)),
          const SizedBox(height: 6),
          Expanded(
            child: owned.isEmpty
                ? Center(child: Text(tr('Chưa có đan dược nào.'), style: small))
                : ListView(
                    children: [
                      for (final p in owned) _pillRow(p),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// One owned pill: name, then Uống đầy (buffs) and Dùng under it.
  Widget _pillRow(PillDef p) {
    final use = LButton(
      label: tr('Dùng'),
      small: true,
      color: seal,
      enabled: h.canUsePill(p),
      onTap: () {
        if (!h.usePill(p)) return;
        SoundService.instance.cue('potion');
        _changed(switch (p.kind) {
          PillKind.buff => '${tr(p.name)}: ${tr(p.desc)}',
          PillKind.potions => tr('+10 Kim Sang Dược, +10 Ngưng Thần Đan'),
          PillKind.potential => tr('+{potentialPerPill} điểm tiềm năng!', {'potentialPerPill': potentialPerPill}),
        });
      },
    );
    final name = Row(
      children: [
        _pillIcon(p, size: 24),
        const SizedBox(width: 8),
        Expanded(child: Text('${tr(p.name)} x${h.pills[p.id]}', style: bold.copyWith(fontSize: 13))),
        if (p.kind != PillKind.buff) use,
      ],
    );
    if (p.kind != PillKind.buff) return Padding(padding: const EdgeInsets.only(bottom: 6), child: name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          name,
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LButton(
                label: tr('Uống đầy'),
                small: true,
                color: jade,
                enabled: h.canUsePill(p),
                onTap: () {
                  final n = h.fillPill(p);
                  if (n == 0) return;
                  SoundService.instance.cue('potion');
                  _changed(tr('{pName} x{n}: còn {p0} phút', {'pName': tr(p.name), 'n': n, 'p0': (h.buffLeft(p.id) / 60).ceil()}));
                },
              ),
              const SizedBox(width: 6),
              use,
            ],
          ),
        ],
      ),
    );
  }
}

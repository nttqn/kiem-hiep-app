import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/pets.dart';
import '../render/art_chibi.dart';
import '../render/art_figures.dart';
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Spirit beasts: buy, tame (boss drops), level up and send one out.
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  HeroData get h => SaveService.instance.hero;

  void _changed() {
    SaveService.instance.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Linh thú',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final p in pets) Expanded(child: _card(p))],
      ),
    );
  }

  Widget _card(PetDef p) {
    final owned = h.ownsPet(p.id);
    final lv = h.petLevels[p.id] ?? 1;
    final out = h.activePet == p.id;
    final kills = h.bossKillsById[p.boss] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Panel(
        border: out ? goldLight : (owned ? hanhColor(p.hanh) : gold.withValues(alpha: 0.4)),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: hanhColor(p.hanh), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Expanded(child: Text(p.name, style: titleStyle(16, color: owned ? goldLight : creamDim))),
              ],
            ),
            Expanded(
              child: Opacity(
                opacity: owned ? 1 : 0.4,
                child: Center(child: PetPreview(look: p.look, size: 110)),
              ),
            ),
            Text(p.desc, style: small.copyWith(fontSize: 10.5), maxLines: 3),
            const SizedBox(height: 4),
            Text(owned ? 'Cấp $lv/$maxPetLevel · ${p.bonusText(lv)}' : p.bonusText(1),
                style: bold.copyWith(fontSize: 12, color: cream)),
            Text('Chưởng ${p.hanh.label}: ${(petPower(lv) * 100).round()}% công lực',
                style: small.copyWith(fontSize: 10.5)),
            const SizedBox(height: 6),
            if (owned) ...[
              LButton(
                label: out ? 'Đang theo' : 'Xuất chiến',
                small: true,
                color: out ? jade : seal,
                onTap: () {
                  h.setActivePet(p.id);
                  _changed();
                },
              ),
              const SizedBox(height: 4),
              LButton(
                label: lv >= maxPetLevel ? 'Tối đa' : 'Nâng ${fmt(petLevelCost(lv))}',
                small: true,
                color: const Color(0xFF7A5A1A),
                enabled: lv < maxPetLevel && h.gold >= petLevelCost(lv),
                onTap: () {
                  if (h.levelPet(p)) _changed();
                },
              ),
            ] else if (p.price > 0)
              LButton(
                label: 'Mua ${fmt(p.price)}',
                small: true,
                color: jade,
                enabled: h.gold >= p.price,
                onTap: () {
                  if (h.buyPet(p)) _changed();
                },
              )
            else
              Text(
                '${petSource(p)}\nĐã hạ ${kills.clamp(0, petPity)}/$petPity (chắc chắn rơi ở lần thứ $petPity)',
                style: small.copyWith(fontSize: 10.5, color: creamDim),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// A gently animated pet portrait.
class PetPreview extends StatefulWidget {
  const PetPreview({super.key, required this.look, this.size = 100});
  final String look;
  final double size;

  @override
  State<PetPreview> createState() => _PetPreviewState();
}

class _PetPreviewState extends State<PetPreview> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(widget.size),
        painter: _PetPainter(_t, widget.look),
      );
}

class _PetPainter extends CustomPainter {
  _PetPainter(this.t, this.look) : super(repaint: t);
  final ValueNotifier<double> t;
  final String look;

  @override
  void paint(Canvas c, Size s) {
    final time = t.value;
    final cycle = time % 3;
    c.save();
    c.translate(s.width * 0.48, s.height * 0.86);
    drawShadow(c, s.width * 0.22);
    final k = s.width / (look == 'crane' ? 80 : 62);
    c.scale(k);
    setClock(time);
    drawPetChibi(c, look, t: time, attack: cycle < 0.3 ? 1 - cycle / 0.3 : 0);
    c.restore();
  }

  @override
  bool shouldRepaint(_PetPainter old) => old.look != look;
}

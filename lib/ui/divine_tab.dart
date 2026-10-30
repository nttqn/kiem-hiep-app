import 'package:flutter/material.dart';

import '../core/divine.dart';
import '../core/hero.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'theme.dart';

/// Thợ rèn tab: awaken the weapon (Thần binh) with Thần Thiết and gold.
class DivineTab extends StatefulWidget {
  const DivineTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<DivineTab> createState() => _DivineTabState();
}

class _DivineTabState extends State<DivineTab> {
  HeroData get h => SaveService.instance.hero;

  void _upgrade() {
    final before = h.power;
    if (!h.upgradeDivine()) return;
    h.notices.clear();
    Analytics.instance.log('divine_up', {'lv': h.divine});
    SaveService.instance.save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${divineStage(h.divine)} tầng ${h.divine}! Lực chiến +${fmt(h.power - before)}'),
      duration: const Duration(seconds: 2),
    ));
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final lv = h.divine;
    final c = Color(lv > 0 ? divineColor(lv) : 0xFFB8A888);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: Panel(
            border: c,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(child: FittedBox(child: FigurePreview.of(h, scale: 2))),
                Text(lv > 0 ? '${divineStage(lv)} · tầng $lv/$divineMax' : 'Chưa thức tỉnh',
                    style: titleStyle(17, color: c)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hardware, color: Color(0xFF9FD8FF), size: 18),
                    const SizedBox(width: 4),
                    Text('${h.divineIron} Thần Thiết', style: bold.copyWith(color: const Color(0xFF9FD8FF))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            border: c,
            padding: const EdgeInsets.all(10),
            child: h.divineOpen ? _panel() : _locked(),
          ),
        ),
      ],
    );
  }

  Widget _locked() => Center(
        child: Text(
          'Thần binh mở sau lần chuyển sinh đầu tiên.\n'
          'Thần Thiết vẫn được cất giữ từ bây giờ: hiện có ${h.divineIron}.',
          style: body,
          textAlign: TextAlign.center,
        ),
      );

  Widget _panel() {
    final lv = h.divine;
    final maxed = lv >= divineMax;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Thức tỉnh vũ khí', style: titleStyle(18, color: goldLight)),
        Text(
          'Thần binh gắn với nhân vật, đổi vũ khí vẫn giữ nguyên. Mỗi tầng chắc chắn thành công.',
          style: small.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            children: [
              for (var i = 1; i <= divineMax; i++) ...[
                if (i == divineTier2From + 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                    child: Text('Bậc hai · mở ở Chuyển sinh $divineTier2Rebirths',
                        style: bold.copyWith(fontSize: 12, color: goldLight)),
                  ),
                _levelRow(i, lv),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                maxed
                    ? 'Đã đạt Tiên binh, tầng cao nhất.'
                    : h.divineTier2Locked
                        ? 'Tầng ${lv + 1} trở lên mở ở Chuyển sinh $divineTier2Rebirths.'
                        : 'Tầng ${lv + 1}: ${divineIronCost[lv]} Thần Thiết · ${fmt(divineGoldCost(lv))} lượng',
                style: bold.copyWith(fontSize: 13, color: maxed ? goldLight : cream),
              ),
            ),
            if (!maxed)
              LButton(
                label: 'Thức tỉnh',
                icon: Icons.auto_awesome,
                small: true,
                color: const Color(0xFF5A3A8A),
                enabled: h.canDivine,
                onTap: _upgrade,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Thần Thiết: Ải Ác Mộng 7 trở lên (vượt lần đầu được nhiều), mốc sát thương cao của Boss Thế Giới, '
          'vượt tháp tầng 100 trở lên, top Săn quái tuần, và quà Hòm thư.',
          style: small.copyWith(fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _levelRow(int i, int lv) {
    final done = i <= lv;
    final next = i == lv + 1;
    final col = Color(divineColor(i));
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: next ? lacquerLight : lacquerDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: done || next ? col.withValues(alpha: done ? 0.9 : 0.5) : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16, color: done ? col : creamDim),
          const SizedBox(width: 6),
          SizedBox(
            width: 104,
            child: Text('${divineStage(i)} $i', style: bold.copyWith(fontSize: 12.5, color: done ? col : cream)),
          ),
          Expanded(
            child: Text(divineLevelText(i),
                style: small.copyWith(fontSize: 11.5, color: done ? cream : creamDim),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

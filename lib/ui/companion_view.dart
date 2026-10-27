import 'package:flutter/material.dart';

import '../core/companions.dart';
import '../core/gold_sets.dart';
import '../core/hero.dart';
import '../render/art_figures.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'backdrop.dart';
import 'theme.dart';

/// Hiệp khách: meet, befriend and take along a companion of each sect.
class CompanionView extends StatefulWidget {
  const CompanionView({super.key});

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView> {
  HeroData get h => SaveService.instance.hero;

  void _changed() {
    SaveService.instance.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Hiệp khách đi cùng ở bãi luyện công và vượt ải (không vào tháp, Lôi đài, Boss Thế Giới). '
            'Quái không đánh họ; tặng quà để tăng hảo cảm, mở thêm chiêu và nghe chuyện của họ.',
            style: small.copyWith(fontSize: 11),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in companions) Expanded(child: _card(c))],
          ),
        ),
      ],
    );
  }

  Widget _card(CompanionDef c) {
    final owned = h.hasCompanion(c.id);
    final bond = h.companionBonds[c.id] ?? 1;
    final along = h.activeCompanion == c.id;
    final met = h.canMeetCompanion(c);
    final skills = companionSkillBond.entries.where((e) => e.key < c.sect.skills.length && bond >= e.value).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Panel(
        border: along ? goldLight : (owned ? hanhColor(c.hanh) : gold.withValues(alpha: 0.4)),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(c.name,
                style: titleStyle(c.name.length > 12 ? 14 : 16, color: owned ? goldLight : creamDim),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(c.title,
                style: small.copyWith(fontSize: 10.5, color: hanhColor(c.hanh)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Expanded(
              child: GestureDetector(
                onTap: owned ? () => _stories(c, bond) : null,
                child: Opacity(
                  opacity: owned ? 1 : 0.45,
                  child: FittedBox(
                    child: FigurePreview(
                      hanh: c.hanh,
                      female: c.female,
                      gear: companionGear(bond),
                      costume: c.look,
                      scale: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              owned ? 'Hảo cảm $bond/$maxBond' : (met ? 'Mời: ${fmt(c.price)} lượng' : 'Gặp ở cấp ${c.unlock}'),
              style: bold.copyWith(fontSize: 12, color: cream),
            ),
            Text('${bonusLabel(c.bonus)} +${(c.bonusAt(bond) * 100).toStringAsFixed(1)}%',
                style: small.copyWith(fontSize: 10.5)),
            Text('Đòn đánh ${(companionHit(bond) * 100).round()}% · $skills chiêu',
                style: small.copyWith(fontSize: 10.5)),
            const SizedBox(height: 5),
            if (owned) ...[
              LButton(
                label: along ? 'Đang đi cùng' : 'Đồng hành',
                small: true,
                color: along ? jade : seal,
                onTap: () {
                  h.setActiveCompanion(c.id);
                  _changed();
                },
              ),
              const SizedBox(height: 4),
              LButton(
                label: bond >= maxBond ? 'Tri kỷ' : 'Quà ${fmt(bondCost(bond))}',
                small: true,
                color: const Color(0xFF7A5A1A),
                enabled: bond < maxBond && h.gold >= bondCost(bond),
                onTap: () {
                  if (!h.giftCompanion(c)) return;
                  Analytics.instance.log('companion_gift', {'id': c.id, 'bond': bond + 1});
                  _changed();
                  if (storyBonds.contains(bond + 1)) _stories(c, bond + 1);
                },
              ),
            ] else
              LButton(
                label: met ? 'Mời đồng hành' : 'Chưa gặp',
                small: true,
                color: jade,
                enabled: met && h.gold >= c.price,
                onTap: () {
                  if (!h.hireCompanion(c)) return;
                  Analytics.instance.log('companion_hire', {'id': c.id});
                  _changed();
                  _stories(c, 1);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Their story so far; later parts show the hảo cảm they need.
  void _stories(CompanionDef c, int bond) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text('${c.name} · ${c.title}', style: titleStyle(18)),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.desc, style: small.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                for (var i = 0; i < c.stories.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      bond >= storyBonds[i] ? '• ${c.stories[i]}' : '• (Hảo cảm ${storyBonds[i]} để nghe tiếp)',
                      style: body.copyWith(height: 1.35, color: bond >= storyBonds[i] ? cream : creamDim),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }
}

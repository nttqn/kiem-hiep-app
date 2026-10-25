import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/gems.dart';
import '../core/hero.dart';
import '../core/meridians.dart';
import '../core/items.dart';
import '../core/sects.dart';
import '../services/save.dart';
import '../render/art_figures.dart';
import 'backdrop.dart';
import 'gem_tab.dart';
import 'refine_tab.dart';
import 'sub_screen.dart';
import 'theme.dart';

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key, this.tab = 0, this.forge = false});
  final int tab;
  final bool forge;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late int _tab = widget.tab;
  HeroData get h => SaveService.instance.hero;

  void _changed() {
    SaveService.instance.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const names = ['Thuộc tính', 'Kỹ năng', 'Hành trang', 'Khảm ngọc', 'Tẩy luyện'];
    return SubScreen(
      title: widget.forge && _tab >= 2 ? 'Thợ rèn' : 'Nhân vật',
      actions: [
        for (final i in widget.forge ? const [2, 3, 4] : const [0, 1, 2, 3])
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _TabChip(
              label: names[i],
              on: _tab == i,
              badge: i == 0 ? h.freePoints : (i == 1 ? h.skillPoints : 0),
              onTap: () => setState(() => _tab = i),
            ),
          ),
      ],
      child: switch (_tab) {
        0 => _attrs(),
        1 => _skills(),
        2 => _bag(),
        3 => GemTab(onChanged: () => setState(() {}), openItem: _itemDialog),
        _ => RefineTab(onChanged: () => setState(() {})),
      },
    );
  }

  // ---------------------------------------------------------- attributes

  Widget _attrs() {
    final st = h.stats;
    const names = ['Sức mạnh', 'Thân pháp', 'Sinh khí', 'Nội công'];
    const hints = [
      'Tăng công lực (phái ngoại công)',
      'Tăng chí mạng, né tránh, tốc đánh',
      'Tăng sinh lực và phòng thủ',
      'Tăng nội lực, công lực (phái nội công)',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Tiềm năng còn: ', style: body),
                    Text('${h.freePoints}', style: titleStyle(20)),
                    const Spacer(),
                    LButton(
                      label: 'Tự cộng',
                      small: true,
                      color: jade,
                      enabled: h.freePoints > 0,
                      onTap: () {
                        h.autoSpend();
                        _changed();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${names[i]}  ${st.attrs[i]}', style: bold),
                              Text(hints[i], style: small.copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                        _plus('+1', i, 1),
                        const SizedBox(width: 6),
                        _plus('+5', i, 5),
                      ],
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    Text('Gợi ý phái: ${_buildHint()}', style: small),
                    const Spacer(),
                    LButton(
                      label: 'Tẩy điểm (${fmt(h.resetCost)})',
                      small: true,
                      color: const Color(0xFF5A4A3A),
                      enabled: h.gold >= h.resetCost && h.spent.any((v) => v > 0),
                      onTap: () {
                        h.resetPoints();
                        _changed();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 300,
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${h.name} · ${h.sect.name}', style: titleStyle(18)),
                Text('Cấp ${h.level} · Lực chiến ${fmt(h.power)}', style: small.copyWith(color: goldLight)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: [
                      _stat('Sinh lực', fmt(st.maxHp)),
                      _stat('Nội lực', fmt(st.maxMp)),
                      _stat('Công lực', fmt(st.atk)),
                      _stat('Phòng thủ', fmt(st.def)),
                      _stat('Chí mạng', '${(st.crit * 100).toStringAsFixed(1)}%'),
                      _stat('ST chí mạng', '${(st.critDmg * 100).round()}%'),
                      _stat('Né tránh', '${(st.dodge * 100).toStringAsFixed(1)}%'),
                      _stat('Tốc đánh', '${(st.aspd * 100).round()}%'),
                      _stat('Tốc chạy', fmt(st.move)),
                      _stat('Hồi sinh lực', '${st.hpRegen.toStringAsFixed(1)}/giây'),
                      if (st.skillDmg > 0) _stat('Uy lực kỹ năng', '+${(st.skillDmg * 100).round()}%'),
                      if (st.cdr > 0) _stat('Giảm hồi chiêu', '${(st.cdr * 100).round()}%'),
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

  String _buildHint() {
    const names = ['Sức mạnh', 'Thân pháp', 'Sinh khí', 'Nội công'];
    final w = h.sect.autoBuild;
    final order = [0, 1, 2, 3]..sort((a, b) => w[b].compareTo(w[a]));
    return order.where((i) => w[i] > 0).map((i) => names[i]).join(' > ');
  }

  Widget _plus(String label, int attr, int n) => LButton(
        label: label,
        small: true,
        enabled: h.freePoints > 0,
        onTap: () {
          h.spendPoint(attr, n);
          _changed();
        },
      );

  Widget _stat(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(k, style: body.copyWith(color: creamDim)),
            const Spacer(),
            Text(v, style: bold),
          ],
        ),
      );

  // ---------------------------------------------------------- skills

  Widget _skills() {
    final s = h.sect;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _skillList(s)),
        const SizedBox(width: 10),
        SizedBox(width: 262, child: _meridianPanel()),
      ],
    );
  }

  Widget _meridianPanel() {
    final open = h.meridiansOpen;
    return Panel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kinh mạch', style: titleStyle(18)),
          Text(
            open
                ? 'Dồn điểm kỹ năng dư vào kinh mạch. Càng nhiều điểm, mỗi điểm càng ít tác dụng.'
                : 'Mở ở cấp $meridianLevel. Dùng điểm kỹ năng dư sau khi đã nâng đủ kỹ năng.',
            style: small.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < meridians.length; i++) _meridianRow(i, open),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meridianRow(int i, bool open) {
    final m = meridians[i];
    final n = h.meridianPts[i];
    final can = open && h.skillPoints > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hanhColor(m.hanh).withValues(alpha: open ? 0.7 : 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: hanhColor(m.hanh), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m.name} · $n điểm', style: bold.copyWith(fontSize: 12.5, color: open ? cream : creamDim)),
                Text(m.text(n), style: small.copyWith(fontSize: 11, color: hanhColor(m.hanh))),
              ],
            ),
          ),
          for (final k in const [1, 10])
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: can
                    ? () {
                        h.trainMeridian(i, k);
                        _changed();
                      }
                    : null,
                child: Container(
                  width: k == 1 ? 34 : 40,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: can ? seal : const Color(0xFF4A3E36),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: can ? goldLight : gold.withValues(alpha: 0.3)),
                  ),
                  child: Text('+$k', style: bold.copyWith(fontSize: 12, color: can ? cream : creamDim)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _skillList(SectDef s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Điểm kỹ năng: ', style: body),
            Text('${h.skillPoints}', style: titleStyle(20)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                h.breakthrough ? 'Đã đột phá: kỹ năng tới cấp $maxBreakLevel' : 'Cấp $breakthroughLevel: đột phá tới cấp $maxBreakLevel',
                style: small.copyWith(fontSize: 11, color: h.breakthrough ? const Color(0xFF8CE07A) : creamDim),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            LButton(
              label: 'Tự học',
              small: true,
              color: jade,
              enabled: h.skillPoints > 0,
              onTap: () {
                h.autoLearn();
                _changed();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 92,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: s.skills.length,
            // The tuyệt kỹ leads the list; the rest keep sect order.
            itemBuilder: (_, k) => _skillCard(s, (k + s.skills.length - 1) % s.skills.length),
          ),
        ),
      ],
    );
  }

  Widget _skillCard(SectDef s, int i) {
    final sk = s.skills[i];
    final lv = h.skillLv[i];
    final locked = !h.skillOpen(i);
    return Panel(
      padding: const EdgeInsets.all(8),
      border: sk.ultimate ? (locked ? const Color(0xFF8A3A2A) : seal) : (lv > 0 ? gold : const Color(0xFF6A5A4A)),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(painter: SkillGlyph(sk, h.hanh, locked: locked)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(sk.name, style: bold.copyWith(color: goldLight), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Text(locked ? 'Cấp ${sk.unlock} mở' : '$lv/${h.skillCap(i)}',
                        style: small.copyWith(color: locked ? const Color(0xFFFF8A7A) : cream)),
                  ],
                ),
                Text(sk.desc, style: small.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_skillNumbers(sk, math.max(1, lv)), style: small.copyWith(fontSize: 11, color: cream),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          LButton(
            label: '+',
            small: true,
            enabled: h.canLearn(i),
            onTap: () {
              h.learn(i);
              _changed();
            },
          ),
        ],
      ),
    );
  }

  String _skillNumbers(SkillDef s, int lv) {
    final p = s.powerAt(lv);
    if (s.isPassive) {
      return s.passive.entries.map((e) => '${_bonusName(e.key)} +${_pct(e.value * lv)}').join(' · ');
    }
    final cost = 'Nội lực ${s.mpAt(lv).round()} · Hồi ${s.cooldown.toStringAsFixed(1)}s';
    return switch (s.kind) {
      SkillKind.guard => 'Giảm ${_pct(math.min(0.7, p))} sát thương ${s.duration.round()}s · $cost',
      SkillKind.heal => 'Hồi ${_pct(p * 2)} sinh lực · $cost',
      SkillKind.shield => 'Khiên ${_pct(p)} sinh lực ${s.duration.round()}s · $cost',
      _ => '${(p * 100).round()}% công lực${s.ticks > 1 ? ' ×${s.ticks}' : ''}'
          '${s.count > 1 && s.kind != SkillKind.line ? ' ×${s.count}' : ''} · $cost',
    };
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(v < 0.1 ? 1 : 0)}%';

  String _bonusName(Bonus b) => switch (b) {
        Bonus.hpPct => 'Sinh lực',
        Bonus.mpPct => 'Nội lực',
        Bonus.atkPct => 'Công lực',
        Bonus.defPct => 'Phòng thủ',
        Bonus.crit => 'Chí mạng',
        Bonus.critDmg => 'ST chí mạng',
        Bonus.dodge => 'Né tránh',
        Bonus.aspd => 'Tốc đánh',
        Bonus.move => 'Tốc chạy',
        Bonus.regen => 'Hồi phục',
        Bonus.skillDmg => 'Uy lực kỹ năng',
        Bonus.cdr => 'Giảm hồi chiêu',
        Bonus.dotPct => 'Uy lực độc',
      };

  // ---------------------------------------------------------- bag

  Widget _bag() {
    final bag = List<Item>.of(h.bag)
      ..sort((a, b) {
        final r = b.rarity.index.compareTo(a.rarity.index);
        return r != 0 ? r : b.level.compareTo(a.level);
      });
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 250,
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(widget.forge ? 'Chọn món để cường hóa' : 'Đang trang bị', style: small),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final s in [Slot.hat, Slot.armor, Slot.belt, Slot.boots]) _slotTile(s),
                        ],
                      ),
                      Expanded(
                        child: FittedBox(
                          child: FigurePreview(
                              hanh: h.hanh, female: h.female, scale: 1.4, gear: HeroGear.of(h.equip)),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final s in [Slot.weapon, Slot.amulet, Slot.ring]) _slotTile(s),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Hành trang ${h.bag.length}/$bagSize', style: bold),
                    const Spacer(),
                    LButton(
                      label: 'Mặc đồ tốt nhất',
                      small: true,
                      color: jade,
                      onTap: () {
                        h.autoEquip();
                        _changed();
                      },
                    ),
                    const SizedBox(width: 6),
                    LButton(
                      label: 'Bán đồ Thường',
                      small: true,
                      enabled: h.bag.any((i) => i.rarity == Rarity.common),
                      onTap: () {
                        for (final it in List<Item>.of(h.bag)) {
                          if (it.rarity == Rarity.common) h.sell(it);
                        }
                        _changed();
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      height: 30,
                      child: Checkbox(
                        value: h.autoSellCommon,
                        onChanged: (v) {
                          h.autoSellCommon = v ?? false;
                          _changed();
                        },
                      ),
                    ),
                    Text('Tự bán đồ Thường khi nhặt', style: small),
                  ],
                ),
                Expanded(
                  child: bag.isEmpty
                      ? Center(child: Text('Hành trang trống. Ra ngoài luyện công để nhặt đồ!', style: small))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 60,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: bag.length,
                          itemBuilder: (_, i) => ItemTile(
                            item: bag[i],
                            onTap: () => _itemDialog(bag[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _slotTile(Slot s) {
    final it = h.equip[s];
    return ItemTile(
      item: it,
      slot: s,
      size: 48,
      onTap: it == null ? null : () => _itemDialog(it),
    );
  }

  Future<void> _itemDialog(Item it) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ItemDialog(item: it, forge: widget.forge),
    );
    _changed();
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.item, required this.forge});
  final Item item;
  final bool forge;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  String? _msg;
  Color _msgColor = cream;

  HeroData get h => SaveService.instance.hero;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final worn = h.equip[it.slot];
    final isWorn = worn == it;
    final rc = rarityColor(it.rarity);
    final cost = enhanceCost(it);
    final canEnhance = it.plus < maxPlus;
    return Dialog(
      backgroundColor: lacquer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: rc, width: 1.5)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 340),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _statsBlock(it, rc, isWorn ? 'Đang mặc' : 'Trong hành trang')),
              if (worn != null && !isWorn) ...[
                const VerticalDivider(color: gold),
                Expanded(child: _statsBlock(worn, rarityColor(worn.rarity), 'Đang mặc')),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isWorn)
                      LButton(
                        label: it.level > h.level ? 'Cần cấp ${it.level}' : 'Trang bị',
                        small: true,
                        color: jade,
                        enabled: it.level <= h.level,
                        onTap: () {
                          h.equipItem(it);
                          Navigator.pop(context);
                        },
                      )
                    else
                      LButton(
                        label: 'Tháo ra',
                        small: true,
                        enabled: h.bag.length < bagSize,
                        onTap: () {
                          h.unequip(it.slot);
                          Navigator.pop(context);
                        },
                      ),
                    const SizedBox(height: 6),
                    if (!isWorn)
                      LButton(
                        label: 'Bán ${fmt(it.sellPrice)}',
                        small: true,
                        color: const Color(0xFF5A4A3A),
                        onTap: () {
                          h.sell(it);
                          Navigator.pop(context);
                        },
                      ),
                    const Spacer(),
                    Text('Cường hóa', style: bold.copyWith(color: goldLight)),
                    Text(
                      canEnhance
                          ? '+${it.plus} → +${it.plus + 1} · tỉ lệ ${(enhanceChance(it.plus) * 100).round()}%'
                          : 'Đã đạt +$maxPlus',
                      style: small,
                    ),
                    const SizedBox(height: 4),
                    LButton(
                      label: canEnhance ? 'Rèn ${fmt(cost)} lượng' : 'Tối đa',
                      small: true,
                      color: widget.forge ? seal : const Color(0xFF7A3A1A),
                      enabled: canEnhance && h.gold >= cost,
                      onTap: _enhance,
                    ),
                    if (_msg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_msg!, style: bold.copyWith(color: _msgColor, fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enhance() {
    final it = widget.item;
    final cost = enhanceCost(it);
    if (h.gold < cost || it.plus >= maxPlus) return;
    h.gold -= cost;
    final ok = math.Random().nextDouble() < enhanceChance(it.plus);
    if (ok) {
      it.plus++;
      h.bestPlus = math.max(h.bestPlus, it.plus);
    }
    h.recompute();
    SaveService.instance.save();
    setState(() {
      _msg = ok ? 'Thành công! +${it.plus}' : 'Thất bại, mất ${fmt(cost)} lượng';
      _msgColor = ok ? const Color(0xFF8CE07A) : const Color(0xFFFF8A7A);
    });
  }

  Widget _statsBlock(Item it, Color rc, String where) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(where, style: small),
        Text(it.title, style: titleStyle(18, color: rc)),
        Text('${it.rarity.label} · ${it.slot.label} · Cấp ${it.level}', style: small.copyWith(color: rc)),
        const SizedBox(height: 6),
        for (final e in it.base.entries)
          Text('${e.key.label} ${e.key.format(e.value * (1 + 0.1 * it.plus))}', style: bold.copyWith(fontSize: 13)),
        for (final e in it.bonus.entries)
          Text('${e.key.label} ${e.key.format(e.value)}',
              style: body.copyWith(fontSize: 13, color: const Color(0xFF8AC8FF))),
        if (it.gems.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final g in it.gems)
            Row(
              children: [
                GemIcon(gem: g, size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    g == null ? 'Lỗ khảm trống' : '${g.name}: ${gemEffectText(g, banMenh: g.hanh == h.hanh)}',
                    style: small.copyWith(fontSize: 11.5, color: g == null ? creamDim : hanhColor(g.hanh)),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.on, required this.onTap, this.badge = 0});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: on ? seal : lacquer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? goldLight : gold.withValues(alpha: 0.5)),
        ),
        child: Text(badge > 0 ? '$label ($badge)' : label, style: bold.copyWith(fontSize: 13)),
      ),
    );
  }
}

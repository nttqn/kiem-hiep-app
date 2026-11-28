import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/essence.dart';
import '../core/gem_extras.dart';
import '../core/gems.dart';
import '../core/gold_extras.dart';
import '../core/gold_sets.dart';
import '../core/hero.dart';
import '../core/meridians.dart';
import '../core/items.dart';
import '../core/manuals.dart';
import '../core/sects.dart';
import '../core/star_up.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import 'bag_screen.dart';
import 'body_tab.dart';
import 'branch_dialog.dart';
import 'divine_tab.dart';
import 'engrave_tab.dart';
import 'gear_sets_tab.dart';
import 'gem_tab.dart';
import 'gold_tab.dart';
import 'manual_dialog.dart';
import 'refine_tab.dart';
import 'rename_dialog.dart';
import 'sub_screen.dart';
import 'theme.dart';
import 'wardrobe_tab.dart';
import '../core/i18n.dart';

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
    const names = ['Thuộc tính', 'Kỹ năng', 'Hành trang', 'Khảm ngọc', 'Tẩy luyện', 'Ngoại trang', 'Hoàng Kim', 'Thần binh', 'Luyện thể', 'Khắc ấn', 'Bộ đồ'];
    return SubScreen(
      title: widget.forge && _tab >= 2 ? tr('Thợ rèn') : tr('Nhân vật'),
      actions: [
        for (final i in widget.forge ? [2, 3, 4, if (h.goldOpen) 9, 6, 7] : [0, 1, 10, 3, 5, if (h.rebirths > 0) 8])
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: TabChip(
              label: tr(names[i]),
              on: _tab == i,
              badge: switch (i) {
                0 => h.freePoints,
                1 => h.skillPoints,
                6 => h.hkFresh ? 1 : 0,
                _ => 0,
              },
              onTap: () => setState(() => _tab = i),
            ),
          ),
      ],
      child: switch (_tab) {
        0 => _attrs(),
        1 => _skills(),
        2 => GearBagView(forge: widget.forge, onChanged: () => setState(() {})),
        3 => GemTab(onChanged: () => setState(() {}), openItem: _itemDialog),
        5 => WardrobeTab(onChanged: () => setState(() {})),
        6 => GoldTab(onChanged: () => setState(() {})),
        7 => DivineTab(onChanged: () => setState(() {})),
        8 => BodyTab(onChanged: () => setState(() {})),
        9 => EngraveTab(onChanged: () => setState(() {})),
        10 => GearSetsTab(onChanged: () => setState(() {})),
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
                    Text(tr('Tiềm năng còn: '), style: body),
                    Text('${h.freePoints}', style: titleStyle(20)),
                    const Spacer(),
                    LButton(
                      label: tr('Tự cộng'),
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
                // The four stats scroll on a short phone; Tẩy điểm stays.
                Expanded(
                  child: ListView(
                    children: [
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${tr(names[i])}  ${st.attrs[i]}', style: bold),
                              Text(tr(hints[i]), style: small.copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                        _plus('+1', i, 1),
                        const SizedBox(width: 6),
                        _plus('+5', i, 5),
                      ],
                    ),
                  ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(tr('Gợi ý phái: {p0}', {'p0': _buildHint()}),
                          style: small, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    LButton(
                      label: tr('Tẩy điểm ({p0})', {'p0': fmt(h.resetCost)}),
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
                Row(
                  children: [
                    Flexible(
                      child: Text('${h.name} · ${tr(h.sect.name)}',
                          style: titleStyle(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    InkWell(
                      onTap: () async {
                        if (await showRenameDialog(context) && mounted) setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit, color: goldLight, size: 18),
                      ),
                    ),
                  ],
                ),
                Text(tr('Cấp {level} · Lực chiến {p0}', {'level': h.level, 'p0': fmt(h.power)}), style: small.copyWith(color: goldLight)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: [
                      _stat(tr('Sinh lực'), fmt(st.maxHp)),
                      _stat(tr('Nội lực'), fmt(st.maxMp)),
                      _stat(tr('Công lực'), fmt(st.atk)),
                      _stat(tr('Phòng thủ'), fmt(st.def)),
                      _stat(tr('Chí mạng'), '${(st.crit * 100).toStringAsFixed(1)}%'),
                      _stat(tr('ST chí mạng'), '${(st.critDmg * 100).round()}%'),
                      _stat(tr('Né tránh'), '${(st.dodge * 100).toStringAsFixed(1)}%'),
                      _stat(tr('Tốc đánh'), '${(st.aspd * 100).round()}%'),
                      // 1.13.4: what is past a cap is turned, not lost.
                      if (st.overCrit > 0)
                        _stat(tr('Chí mạng dư → ST chí mạng'), '+${(st.overCrit * overCritToCritDmg * 100).round()}%'),
                      if (st.overDodge > 0)
                        _stat(tr('Né tránh dư → Sinh lực'), '+${(overDodgeHp(st.overDodge) * 100).round()}%'),
                      if (st.overAspd > 0)
                        _stat(tr('Tốc đánh dư → Công lực'), '+${(st.overAspd * overAspdToAtk * 100).round()}%'),
                      _stat(tr('Tốc chạy'), fmt(st.move)),
                      _stat(tr('Hồi sinh lực'), tr('{p0}/giây', {'p0': st.hpRegen.toStringAsFixed(1)})),
                      if (st.skillDmg > 0) _stat(tr('Uy lực kỹ năng'), '+${(st.skillDmg * 100).round()}%'),
                      if (st.cdr > 0) _stat(tr('Giảm hồi chiêu'), '${(st.cdr * 100).round()}%'),
                      if (st.dotPct > 0) _stat(tr('Uy lực độc/thiêu'), '+${(st.dotPct * 100).round()}%'),
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
    return order.where((i) => w[i] > 0).map((i) => tr(names[i])).join(' > ');
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
            Expanded(child: Text(k, style: body.copyWith(color: creamDim))),
            const SizedBox(width: 6),
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
          Row(
            children: [
              Expanded(child: Text(tr('Kinh mạch'), style: titleStyle(18))),
              LButton(
                label: tr('Tẩy ({p0})', {'p0': fmt(h.meridianResetCost)}),
                small: true,
                color: const Color(0xFF5A4A3A),
                enabled: h.gold >= h.meridianResetCost && h.meridianPts.any((v) => v > 0),
                onTap: _resetMeridians,
              ),
            ],
          ),
          Text(
            open
                ? tr('Dồn điểm kỹ năng dư vào kinh mạch. Càng nhiều điểm, mỗi điểm càng ít tác dụng. '
                    'Trần: Chí mạng {p0}%, Tốc đánh {p1}%; '
                    'phần dư đổi thành ST chí mạng và công lực.', {'p0': (critCap * 100).round(), 'p1': (aspdCap * 100).round()})
                : tr('Mở ở cấp {meridianLevel}. Dùng điểm kỹ năng dư sau khi đã nâng đủ kỹ năng.', {'meridianLevel': meridianLevel}),
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

  /// Whether the stat [b] feeds is already at its cap.
  bool _capped(Bonus b) => switch (b) {
        Bonus.crit => h.stats.crit >= critCap,
        Bonus.aspd => h.stats.aspd >= aspdCap,
        _ => false,
      };

  Future<void> _resetMeridians() async {
    final n = h.meridianPts.fold<int>(0, (a, b) => a + b);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(tr('Tẩy kinh mạch?'), style: titleStyle(18)),
        content: Text(tr('Trả lại {n} điểm kỹ năng từ kinh mạch để dồn lại, tốn {p0} lượng.', {'n': n, 'p0': fmt(h.meridianResetCost)}), style: body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Thôi'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Tẩy'))),
        ],
      ),
    );
    if (ok == true && h.resetMeridians()) _changed();
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
                Text(tr('{mName} · {n} điểm', {'mName': tr(m.name), 'n': n}), style: bold.copyWith(fontSize: 12.5, color: open ? cream : creamDim)),
                Text(m.text(n), style: small.copyWith(fontSize: 11, color: hanhColor(m.hanh))),
                if (_capped(m.bonus))
                  Text(tr('Đã chạm trần, phần dư đổi sang chỉ số khác (ít hơn)'),
                      style: small.copyWith(fontSize: 10.5, color: goldLight)),
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
            Text(tr('Điểm kỹ năng: '), style: body),
            Text('${h.skillPoints}', style: titleStyle(20)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                h.breakthrough ? tr('Đã đột phá: kỹ năng tới cấp {maxBreakLevel}', {'maxBreakLevel': maxBreakLevel}) : tr('Cấp {breakthroughLevel}: đột phá tới cấp {maxBreakLevel}', {'breakthroughLevel': breakthroughLevel, 'maxBreakLevel': maxBreakLevel}),
                style: small.copyWith(fontSize: 11, color: h.breakthrough ? const Color(0xFF8CE07A) : creamDim),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (h.branchOpen) ...[
              LButton(
                label: h.branchDef != null ? tr(h.branchDef!.name) : tr('Lưu phái •'),
                small: true,
                color: branchWaiting(h) ? seal : const Color(0xFF8A6A1A),
                onTap: () async {
                  await showBranchDialog(context, h);
                  _changed();
                },
              ),
              const SizedBox(width: 6),
            ],
            LButton(
              label: tr('Tự học'),
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
            child: SkillIcon(sk, h.hanh, locked: locked),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(tr(sk.name), style: bold.copyWith(color: goldLight), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Text(locked ? tr('Cấp {unlock} mở', {'unlock': sk.unlock}) : '$lv/${h.skillCap(i)}',
                        style: small.copyWith(color: locked ? const Color(0xFFFF8A7A) : cream)),
                  ],
                ),
                if (h.manualOf(sk.id) case final k?)
                  Text(tr('Bí kíp {p0} · tầng {p1}', {'p0': tr(manualKinds[k]!.name), 'p1': h.manualLevel(manualKey(sk.id, k))}),
                      style: small.copyWith(fontSize: 11, color: const Color(0xFFE0C8FF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                else
                  Text(tr(sk.desc), style: small.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_skillNumbers(h.castSkill(i), math.max(1, lv)), style: small.copyWith(fontSize: 11, color: cream),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LButton(
                label: '+',
                small: true,
                enabled: h.canLearn(i),
                onTap: () {
                  h.learn(i);
                  _changed();
                },
              ),
              if (h.manualOpen && !sk.isPassive) ...[
                const SizedBox(height: 4),
                _manualButton(sk),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the skill's bí kíp; shows the school it wears.
  Widget _manualButton(SkillDef sk) {
    final k = h.manualOf(sk.id);
    final any = manualKindsFor(sk).any((m) => h.manualPagesOf(manualKey(sk.id, m)) > 0);
    return GestureDetector(
      onTap: () async {
        await showManualDialog(context, h, sk);
        _changed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: k != null ? const Color(0xFF5A3A7A) : lacquer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: any ? const Color(0xFFC88CFF) : gold.withValues(alpha: 0.4)),
        ),
        child: Icon(Icons.menu_book, size: 18, color: any ? const Color(0xFFE0C8FF) : creamDim),
      ),
    );
  }

  String _skillNumbers(SkillDef s, int lv) {
    final p = s.powerAt(lv);
    if (s.isPassive) {
      return s.passive.entries.map((e) => '${_bonusName(e.key)} +${_pct(e.value * lv)}').join(' · ');
    }
    final cost = tr('Nội lực {p0} · Hồi {p1}s', {'p0': h.skillMp(s, lv).round(), 'p1': s.cooldown.toStringAsFixed(1)});
    return switch (s.kind) {
      SkillKind.guard => tr('Giảm {p0} sát thương {p1}s · {cost}', {'p0': _pct(math.min(0.7, p)), 'p1': s.duration.round(), 'cost': cost}),
      SkillKind.heal => tr('Hồi {p0} sinh lực · {cost}', {'p0': _pct(p * 2), 'cost': cost}),
      SkillKind.shield => tr('Khiên {p0} sinh lực {p1}s · {cost}', {'p0': _pct(p), 'p1': s.duration.round(), 'cost': cost}),
      _ => tr('{p0}% công lực{p1}'
          '{p2} · {cost}', {'p0': (p * 100).round(), 'p1': s.ticks > 1 ? tr(' ×{ticks}', {'ticks': s.ticks}) : '', 'p2': s.count > 1 && s.kind != SkillKind.line ? tr(' ×{count}', {'count': s.count}) : '', 'cost': cost}),
    };
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(v < 0.1 ? 1 : 0)}%';

  String _bonusName(Bonus b) => switch (b) {
        Bonus.hpPct => tr('Sinh lực'),
        Bonus.mpPct => tr('Nội lực'),
        Bonus.atkPct => tr('Công lực'),
        Bonus.defPct => tr('Phòng thủ'),
        Bonus.crit => tr('Chí mạng'),
        Bonus.critDmg => tr('ST chí mạng'),
        Bonus.dodge => tr('Né tránh'),
        Bonus.aspd => tr('Tốc đánh'),
        Bonus.move => tr('Tốc chạy'),
        Bonus.regen => tr('Hồi phục'),
        Bonus.skillDmg => tr('Uy lực kỹ năng'),
        Bonus.cdr => tr('Giảm hồi chiêu'),
        Bonus.dotPct => tr('Uy lực độc'),
      };

  // ---------------------------------------------------------- bag

  Future<void> _itemDialog(Item it) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ItemDialog(item: it, forge: widget.forge),
    );
    _changed();
  }
}

class ItemDialog extends StatefulWidget {
  const ItemDialog({super.key, required this.item, required this.forge});
  final Item item;
  final bool forge;

  @override
  State<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<ItemDialog> {
  String? _msg;
  Color _msgColor = cream;

  HeroData get h => SaveService.instance.hero;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final worn = h.equip[it.slot];
    final isWorn = worn == it;
    final rc = Color(it.color);
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
              // Scrolls: a high-level piece with every line, star and gem
              // is taller than a small landscape phone.
              Expanded(child: SingleChildScrollView(child: _statsBlock(it, rc, isWorn ? tr('Đang mặc') : tr('Trong hành trang')))),
              if (worn != null && !isWorn) ...[
                const VerticalDivider(color: gold),
                Expanded(child: SingleChildScrollView(child: _statsBlock(worn, Color(worn.color), tr('Đang mặc')))),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                // Fills the height (the Spacer pushes forging down) and
                // scrolls when a bag piece shows every button.
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isWorn)
                      LButton(
                        label: it.level > h.level ? tr('Cần cấp {level}', {'level': it.level}) : tr('Trang bị'),
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
                        label: tr('Tháo ra'),
                        small: true,
                        enabled: h.bag.length < bagSize,
                        onTap: () {
                          h.unequip(it.slot);
                          Navigator.pop(context);
                        },
                      ),
                    const SizedBox(height: 6),
                    // Khóa (1.15.0): a locked piece cannot be sold in any way.
                    Row(
                      children: [
                        Expanded(
                          child: isWorn
                              ? Text(it.locked ? tr('Đã khóa') : tr('Khóa để không bán nhầm'),
                                  style: small.copyWith(fontSize: 11))
                              : LButton(
                                  label: it.locked ? tr('Đã khóa') : tr('Bán {p0}', {'p0': fmt(it.sellPrice)}),
                                  small: true,
                                  color: const Color(0xFF5A4A3A),
                                  enabled: !it.locked,
                                  onTap: () {
                                    h.sell(it);
                                    Navigator.pop(context);
                                  },
                                ),
                        ),
                        IconButton(
                          tooltip: it.locked ? tr('Mở khóa') : tr('Khóa'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            it.locked = !it.locked;
                            SaveService.instance.save();
                          }),
                          icon: Icon(it.locked ? Icons.lock : Icons.lock_open, color: goldLight, size: 20),
                        ),
                      ],
                    ),
                    // 1.18.0: Tinh Hoa instead of lượng.
                    if (!isWorn && essenceOf(it) > 0) ...[
                      const SizedBox(height: 4),
                      LButton(
                        label: tr('Phân giải +{p0} Tinh Hoa', {'p0': essenceOf(it)}),
                        small: true,
                        color: const Color(0xFF3A6A8A),
                        enabled: !it.locked,
                        onTap: () {
                          if (h.salvage(it) > 0) {
                            Analytics.instance.log('salvage', {'n': 1, 'ess': essenceOf(it)});
                            SaveService.instance.save();
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                    const Spacer(),
                    if (it.golden && it.level < h.level) ...[
                      LButton(
                        label: tr('Đúc lại cấp {level} · {p0} mảnh', {'level': h.level, 'p0': goldReforgeCost(it.slot)}),
                        small: true,
                        color: const Color(0xFF8A6A1A),
                        enabled: h.canReforgeGold(it),
                        onTap: () {
                          if (h.reforgeGold(it) != null) {
                            SaveService.instance.save();
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (canEnhance) ...[
                      Text(tr('Cường hóa'), style: bold.copyWith(color: goldLight)),
                      Text(tr('+{plus} → +{p0} · tỉ lệ {p1}%', {'plus': it.plus, 'p0': it.plus + 1, 'p1': (enhanceChance(it.plus) * 100).round()}), style: small),
                      const SizedBox(height: 4),
                      LButton(
                        label: tr('Rèn {p0} lượng', {'p0': fmt(cost)}),
                        small: true,
                        color: widget.forge ? seal : const Color(0xFF7A3A1A),
                        enabled: h.gold >= cost,
                        onTap: _enhance,
                      ),
                    ] else
                      ..._starUp(it),
                    if (_msg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_msg!, style: bold.copyWith(color: _msgColor, fontSize: 13)),
                      ),
                  ],
                        ),
                      ),
                    ),
                  ),
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
      _msg = ok ? tr('Thành công! +{plus}', {'plus': it.plus}) : tr('Thất bại, mất {p0} lượng', {'p0': fmt(cost)});
      _msgColor = ok ? const Color(0xFF8CE07A) : const Color(0xFFFF8A7A);
    });
  }

  /// Chuyển sao: pick the piece [it] swaps its stars with; Đổi cả cường
  /// hóa swaps the + too, so the other piece need not be +10.
  Future<void> _moveStars(Item it) async {
    var withPlus = h.starMoveTargets(it).isEmpty;
    final picked = await showDialog<(Item, bool)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final targets = h.starMoveTargets(it, withPlus: withPlus)..sort((a, b) => b.star.compareTo(a.star));
          return AlertDialog(
            scrollable: true,
            backgroundColor: lacquer,
            title: Text(tr('Chuyển sao'), style: titleStyle(18)),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    tr('Đổi sao giữa {itName} (★{star}) và một món cùng loại đã +{maxPlus}. '
                        'Hung Thú Tinh Phách đi theo sao, không mất viên nào; phí {p0}% Tinh Thạch và lượng đã dùng cho món nhiều sao hơn.',
                        {'itName': tr(it.name), 'star': it.star, 'maxPlus': maxPlus, 'p0': (starMoveFeePct * 100).round()}),
                    style: small.copyWith(fontSize: 12)),
                CheckboxListTile(
                  value: withPlus,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: gold,
                  title: Text(tr('Đổi cả cường hóa'), style: bold.copyWith(fontSize: 13)),
                  subtitle: Text(tr('Món kia không cần +{maxPlus}; thêm phí lượng.', {'maxPlus': maxPlus}), style: small.copyWith(fontSize: 11)),
                  onChanged: (v) => setD(() => withPlus = v ?? false),
                ),
                if (targets.isEmpty)
                  Text(tr('Không có món cùng loại phù hợp trong túi.'), style: small.copyWith(color: creamDim)),
                for (final o in targets) _moveRow(ctx, it, o, withPlus),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Thôi')))],
          );
        },
      ),
    );
    if (picked == null) return;
    final (o, plus) = picked;
    final from = it.star, to = o.star;
    if (!h.moveStars(it, o, withPlus: plus)) return;
    h.bestPlus = math.max(h.bestPlus, math.max(it.plus, o.plus));
    Analytics.instance.log('star_move', {'a': from, 'b': to, 'slot': it.slot.name, 'plus': plus ? 1 : 0});
    SaveService.instance.save();
    setState(() {
      _msg = tr('Đã chuyển sao! Món này ★{p0}, món kia ★{p1}.', {'p0': it.star, 'p1': o.star});
      _msgColor = const Color(0xFFFFD34A);
    });
  }

  Widget _moveRow(BuildContext ctx, Item it, Item o, bool withPlus) {
    final block = h.starMoveBlock(it, o, withPlus: withPlus);
    final rc = Color(o.color);
    final where = identical(h.equip[o.slot], o) ? tr('Đang mặc') : tr('Trong hành trang');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rc.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(o.title), style: bold.copyWith(fontSize: 13, color: rc)),
                Text(
                    withPlus
                        ? tr('{where} · Cấp {level} · +{p0} ★{p1} thành +{p2} ★{p3}', {'where': where, 'level': o.level, 'p0': o.plus, 'p1': o.star, 'p2': it.plus, 'p3': it.star})
                        : tr('{where} · Cấp {level} · ★{p0} thành ★{p1}', {'where': where, 'level': o.level, 'p0': o.star, 'p1': it.star}),
                    style: small.copyWith(fontSize: 11)),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MatCount(Mat.stone, tr('{p0} (có {p1})', {'p0': starMoveStones(it, o), 'p1': fmt(h.starStones)}),
                        style: small.copyWith(fontSize: 11, color: block == StarMoveBlock.stones ? const Color(0xFFFF8A7A) : null), size: 16),
                    Text(tr('{p0} lượng', {'p0': fmt(h.starMoveGoldTotal(it, o, withPlus: withPlus))}),
                        style: small.copyWith(fontSize: 11, color: block == StarMoveBlock.gold ? const Color(0xFFFF8A7A) : null)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: LButton(
              label: tr('Chuyển'),
              small: true,
              color: const Color(0xFF5A3A8A),
              enabled: block == null,
              onTap: () => Navigator.pop(ctx, (o, withPlus)),
            ),
          ),
        ],
      ),
    );
  }

  /// Thăng Tinh (1.8.0) for a +10 item: the next star's cost and button.
  List<Widget> _starUp(Item it) {
    final maxed = it.star >= maxStar;
    final block = h.starBlock(it);
    return [
      // Two rows of five past ★5 (1.24.0), the second in Tinh Hồn red.
      Text.rich(
          TextSpan(children: [
            TextSpan(text: tr('Thăng Tinh {p0}{p1}', {'p0': '★' * math.min(it.star, starLowMax), 'p1': '☆' * (starLowMax - math.min(it.star, starLowMax))})),
            if (it.star >= starLowMax)
              TextSpan(
                  text: ' ${'★' * (it.star - starLowMax)}${'☆' * (maxStar - it.star)}',
                  style: const TextStyle(color: Color(starHighColor))),
          ]),
          style: bold.copyWith(color: goldLight)),
      if (maxed)
        Text(tr('Đã đạt ★{maxStar}', {'maxStar': maxStar}), style: small)
      else ...[
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MatCount(Mat.stone, tr('{p0} (có {p1})', {'p0': starStoneCost[it.star], 'p1': fmt(h.starStones)}), style: small.copyWith(fontSize: 11), size: 16),
            if (starSoulCost[it.star] > 0)
              MatCount(Mat.soul, tr('{p0} (có {beastSouls})', {'p0': starSoulCost[it.star], 'beastSouls': h.beastSouls}), style: small.copyWith(fontSize: 11), size: 16),
            Text(tr('{p0} lượng', {'p0': fmt(starGoldCost(it.star))}), style: small.copyWith(fontSize: 11)),
          ],
        ),
        Text(tr('+{p0}% chỉ số gốc, {p1} +{p2}%', {'p0': (nextStarPct(it.star) * 100).round(), 'p1': tr(starLines[it.slot]!.label).toLowerCase(), 'p2': (starLines[it.slot]!.per * (it.star < starLowMax ? 1 : 0.5) * 100).toStringAsFixed(1)}),
            style: small.copyWith(fontSize: 11, color: const Color(0xFFFFD34A))),
      ],
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: LButton(
              label: maxed ? tr('Tối đa') : tr('Thăng ★{p0}', {'p0': it.star + 1}),
              small: true,
              color: const Color(0xFF8A2A6A),
              enabled: block == null,
              onTap: () {
                if (!h.starUp(it)) return;
                SaveService.instance.save();
                setState(() {
                  _msg = tr('Thăng Tinh thành công! ★{star}'
                      '{p0}', {'star': it.star, 'p0': h.drillAllowed(it) > it.extraSockets ? tr(' Đã có thể đục thêm lỗ khảm.') : ''});
                  _msgColor = const Color(0xFFFFD34A);
                });
              },
            ),
          ),
          // Chuyển sao: swap stars with another +max piece of this slot.
          if (h.starMoveTargets(it).isNotEmpty || h.starMoveTargets(it, withPlus: true).isNotEmpty) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: tr('Chuyển sao'),
              child: Material(
                color: const Color(0xFF5A3A8A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: gold)),
                child: InkWell(
                  key: const ValueKey('starMove'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _moveStars(it),
                  child: const SizedBox(width: 38, height: 34, child: Icon(Icons.swap_horiz, color: goldLight, size: 22)),
                ),
              ),
            ),
          ],
        ],
      ),
      // Đục lỗ (1.8.0): a fourth socket at ★3, a fifth at ★5.
      if (h.drillAllowed(it) > it.extraSockets) ...[
        const SizedBox(height: 4),
        Text(tr('Đục lỗ thứ {p0}: {p1} ngọc Thần (có {drillGemsHeld}) · {p2} lượng', {'p0': it.gems.length + 1, 'p1': drillGems[it.extraSockets], 'drillGemsHeld': h.drillGemsHeld, 'p2': fmt(drillGold[it.extraSockets])}),
            style: small.copyWith(fontSize: 11, color: const Color(0xFF8AC8FF))),
        LButton(
          label: tr('Đục lỗ khảm'),
          small: true,
          color: const Color(0xFF3A6A8A),
          enabled: h.drillBlock(it) == null,
          onTap: () {
            if (!h.drillSocket(it)) return;
            SaveService.instance.save();
            setState(() {
              _msg = tr('Đã đục lỗ khảm thứ {gemsLength}!', {'gemsLength': it.gems.length});
              _msgColor = const Color(0xFF8AC8FF);
            });
          },
        ),
      ],
    ];
  }

  Widget _statsBlock(Item it, Color rc, String where) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(where, style: small),
        Text(tr(it.title), style: titleStyle(18, color: rc)),
        Text(tr('{rarityLabel} · {slotLabel} · Cấp {level}', {'rarityLabel': it.rarityLabel, 'slotLabel': tr(it.slot.label), 'level': it.level}), style: small.copyWith(color: rc)),
        if (goldSetById[it.set] case final s?)
          Text(tr('Bộ {sName} ({p0}/7)', {'sName': tr(s.name), 'p0': goldPieces(h.equip.values)[s.id] ?? 0}),
              style: small.copyWith(fontSize: 11.5, color: rc)),
        const SizedBox(height: 6),
        for (final e in it.base.entries)
          Text('${tr(e.key.label)} ${e.key.format(e.value * it.baseMul)}',
              style: bold.copyWith(fontSize: 13)),
        if (it.star > 0)
          Text('★ ${starLines[it.slot]!.at(it.star)}', style: bold.copyWith(fontSize: 13, color: const Color(0xFFFFD34A))),
        if (it.glow > 0)
          Text(tr('Khai Quang {glow}: chỉ số gốc +{p0}%', {'glow': it.glow, 'p0': (glowPct(it.glow) * 100).round()}),
              style: bold.copyWith(fontSize: 13, color: const Color(goldItemColor))),
        for (final e in it.bonus.entries)
          Text('${tr(e.key.label)} ${e.key.format(e.value)}',
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
                    g == null ? tr('Lỗ khảm trống') : '${g.name}: ${gemEffectText(g, banMenh: g.hanh == h.hanh)}',
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

class TabChip extends StatelessWidget {
  const TabChip({super.key, required this.label, required this.on, required this.onTap, this.badge = 0});
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

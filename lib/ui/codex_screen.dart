import 'package:flutter/material.dart';

import '../core/codex.dart';
import '../core/content.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../core/ky_ngo.dart';
import '../core/lore.dart' show loreBonusLabel;
import '../core/world_boss.dart' show vnDayKey;
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';

const _legendInk = Color(0xFFFF8A3D);
const _done = Color(0xFF8CE07A);

/// Đồ giám Truyền thuyết (1.19.0): Thần binh phổ and Vạn thú phổ.
class CodexScreen extends StatefulWidget {
  const CodexScreen({super.key, this.tab = 0});

  /// 0: Thần binh phổ, 1: Vạn thú phổ, 2: Kỳ ngộ phổ (1.20.0),
  /// 3: Truyền thuyết phổ (1.26.0).
  final int tab;

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> {
  HeroData get h => SaveService.instance.hero;
  late int _tab = widget.tab;

  @override
  void initState() {
    super.initState();
    h.codexScanOwned();
  }

  Future<void> _claim(String page) async {
    final lines = h.codexClaim(page);
    if (lines.isEmpty) return;
    await SaveService.instance.save();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(lines.join(' · ')), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final gearReady = [for (var t = 0; t < codexTiers; t++) codexGearPage(t)].where(h.codexClaimable).length;
    final landReady = [for (final m in codexLands) codexLandPage(m.id)].where(h.codexClaimable).length;
    final legendReady = [for (var i = 0; i < legendNames.length; i++) codexLegendPage(i)].where(h.codexClaimable).length;
    return SubScreen(
      title: tr('Đồ giám'),
      actions: [
        tabChip(gearReady > 0 ? tr('Thần binh phổ ({gearReady})', {'gearReady': gearReady}) : tr('Thần binh phổ'), _tab == 0, () => setState(() => _tab = 0)),
        tabChip(landReady > 0 ? tr('Vạn thú phổ ({landReady})', {'landReady': landReady}) : tr('Vạn thú phổ'), _tab == 1, () => setState(() => _tab = 1)),
        tabChip(legendReady > 0 ? tr('Truyền thuyết phổ ({n})', {'n': legendReady}) : tr('Truyền thuyết phổ'), _tab == 3,
            () => setState(() => _tab = 3)),
        tabChip(h.kyPagesReady > 0 ? tr('Kỳ ngộ phổ ({kyPagesReady})', {'kyPagesReady': h.kyPagesReady}) : tr('Kỳ ngộ phổ'), _tab == 2, () => setState(() => _tab = 2)),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: switch (_tab) { 0 => _gear(), 1 => _lands(), 3 => _legends(), _ => _ky() }),
          const SizedBox(width: 10),
          SizedBox(width: 220, child: _tab == 2 ? _kySide() : _side()),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ side panel

  Widget _side() {
    final b = h.codexBonuses();
    final gearCells = h.codexGear.where((k) => k.startsWith('g')).length;
    final legendPages = [for (var i = 0; i < legendNames.length; i++) codexLegendPage(i)].where(h.codexClaimed.contains).length;
    final gearPages = [for (var t = 0; t < codexTiers; t++) codexGearPage(t)].where(h.codexClaimed.contains).length;
    final landPages = [for (final m in codexLands) codexLandPage(m.id)].where(h.codexClaimed.contains).length;
    return Panel(
      border: _legendInk,
      padding: const EdgeInsets.all(10),
      child: ListView(
        children: [
          Text(tr('Đồ giám Truyền thuyết'), style: titleStyle(16, color: _legendInk)),
          const SizedBox(height: 4),
          Text(
            _tab == 3
                ? tr('Món Truyền thuyết mang một trong {n} danh hiệu (Bá Vương, Kinh Hồng…). Nhặt được món nào là ghi vào ô của danh hiệu và loại ấy, '
                    'bán hay phân giải rồi vẫn giữ. Đồ Hoàng Kim không tính. Đủ {slots} ô một danh hiệu thì nhận thưởng.',
                    {'n': legendNames.length, 'slots': Slot.values.length})
                : _tab == 0
                ? tr('Nhặt được món Truyền thuyết hoặc Hoàng Kim nào là ghi vào ô của bậc và loại ấy, bán hay phân giải rồi vẫn giữ. '
                    'Đủ {valuesLength} ô một bậc thì nhận thưởng.', {'valuesLength': Slot.values.length})
                : tr('Hạ mỗi loại quái {codexMobGoal} lần và boss {codexBossGoal} lần (đánh ở bản đồ, phó bản đều tính) để trọn một trang.', {'codexMobGoal': codexMobGoal, 'codexBossGoal': codexBossGoal}),
            style: small.copyWith(fontSize: 11),
          ),
          const Divider(color: gold),
          _kv(tr('Thần binh phổ'), tr('{gearCells}/{p0} ô · {gearPages}/{codexTiers} trang', {'gearCells': gearCells, 'p0': codexTiers * Slot.values.length, 'gearPages': gearPages, 'codexTiers': codexTiers})),
          _kv(tr('Vạn thú phổ'), tr('{landPages}/{codexLandsLength} trang', {'landPages': landPages, 'codexLandsLength': codexLands.length})),
          _kv(tr('Truyền thuyết phổ'), tr('{landPages}/{codexLandsLength} trang', {'landPages': legendPages, 'codexLandsLength': legendNames.length})),
          const SizedBox(height: 6),
          Text(tr('Đang được cộng'), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
          if (b.isEmpty)
            Text(tr('Chưa có. Nhận trang đầu tiên để được cộng chỉ số vĩnh viễn.'), style: small.copyWith(fontSize: 11))
          else
            for (final e in b.entries)
              Text('• ${loreBonusLabel(e.key, e.value)}', style: body.copyWith(fontSize: 12, color: _done)),
          const Divider(color: gold),
          Text(
            tr('Trọn Thần binh phổ: danh hiệu « {codexGearTitle} », '
            '{p0}', {'codexGearTitle': codexGearTitle, 'p0': codexGearAllBonus.entries.map((e) => loreBonusLabel(e.key, e.value)).join(', ')}),
            style: small.copyWith(fontSize: 11, color: h.codexGearAll ? _done : creamDim),
          ),
          const SizedBox(height: 4),
          Text(
            tr('Trọn Vạn thú phổ: danh hiệu « {codexLandTitle} », '
            '{p0}', {'codexLandTitle': codexLandTitle, 'p0': codexLandAllBonus.entries.map((e) => loreBonusLabel(e.key, e.value)).join(', ')}),
            style: small.copyWith(fontSize: 11, color: h.codexLandAll ? _done : creamDim),
          ),
          const SizedBox(height: 4),
          Text(
            tr('Trọn Truyền thuyết phổ: danh hiệu « {t} », {p0}', {
              't': tr(codexLegendTitle),
              'p0': codexLegendAllBonus.entries.map((e) => loreBonusLabel(e.key, e.value)).join(', '),
            }),
            style: small.copyWith(fontSize: 11, color: h.codexLegendAll ? _done : creamDim),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(child: Text(k, style: small.copyWith(fontSize: 11.5))),
            Text(v, style: bold.copyWith(fontSize: 11.5, color: cream)),
          ],
        ),
      );

  Widget _claimButton(String page, String progress) {
    if (h.codexClaimed.contains(page)) return const Icon(Icons.check_circle, color: _done, size: 22);
    final ready = h.codexClaimable(page);
    return LButton(label: ready ? tr('Nhận') : progress, small: true, color: jade, enabled: ready, onTap: () => _claim(page));
  }

  // ------------------------------------------------------- Truyền thuyết phổ

  Widget _legends() => ListView.builder(
        itemCount: legendNames.length,
        itemBuilder: (_, i) => _legendRow(i),
      );

  Widget _legendRow(int n) {
    final page = codexLegendPage(n);
    final (bonus, value) = codexLegendBonus[n];
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      border: h.codexClaimable(page) ? goldLight : (h.codexClaimed.contains(page) ? jade : gold),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(tr(legendNames[n]), style: bold.copyWith(color: _legendInk, fontSize: 13.5)),
          ),
          // The higher tiers' icons, a different one for each name.
          for (final s in Slot.values)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: _cell(codexTiers - legendNames.length + n, s,
                  got: h.codexGear.contains(codexLegendKey(n, s)), tip: '${tr(legendNames[n])} · ${tr(s.label)}'),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loreBonusLabel(bonus, value), style: bold.copyWith(fontSize: 11.5, color: cream), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(tr('+{p0} lượng{p1}', {'p0': fmt(codexLegendGold(n)), 'p1': tr(', +{ess} Tinh Hoa', {'ess': codexLegendEssence})}),
                    style: small.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _claimButton(page, '${h.codexLegendCount(n)}/${Slot.values.length}'),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Thần binh phổ

  Widget _gear() => ListView.builder(
        itemCount: codexTiers,
        itemBuilder: (_, t) => _tierRow(t),
      );

  Widget _tierRow(int t) {
    final page = codexGearPage(t);
    final (bonus, value) = codexGearBonus[t];
    final ess = codexGearEssence(t);
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      border: h.codexClaimable(page) ? goldLight : (h.codexClaimed.contains(page) ? jade : gold),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(codexTierName(t)), style: bold.copyWith(color: goldLight, fontSize: 13)),
                Text(codexTierRange(t), style: small.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          for (final s in Slot.values) Padding(padding: const EdgeInsets.only(right: 3), child: _cell(t, s)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loreBonusLabel(bonus, value), style: bold.copyWith(fontSize: 11.5, color: cream), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(tr('+{p0} lượng{p1}', {'p0': fmt(codexGearGold(t)), 'p1': ess > 0 ? tr(', +{ess} Tinh Hoa', {'ess': ess}) : ''}),
                    style: small.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _claimButton(page, '${h.codexGearCount(t)}/${Slot.values.length}'),
        ],
      ),
    );
  }

  Widget _cell(int t, Slot s, {bool? got, String? tip}) {
    final have = got ?? h.codexGear.contains(codexGearKey(t, s));
    final path = _iconPath(t, s);
    final glyph = Icon(Icons.shield_outlined, size: 18, color: have ? _legendInk : creamDim);
    Widget img = path == null
        ? glyph
        : Image.asset(path, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => glyph);
    if (!have) {
      img = Opacity(
        opacity: 0.3,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: img,
        ),
      );
    }
    return Tooltip(
      message: '${tip ?? '${tr(s.label)} ${tr(codexTierName(t))}'}${have ? tr(' · đã ghi') : ''}',
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: lacquerDeep,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: have ? _legendInk : gold.withValues(alpha: 0.35), width: have ? 1.6 : 1),
        ),
        child: img,
      ),
    );
  }

  /// The painted icon of slot [s] at tier [t] (the weapon of the hero's sect).
  String? _iconPath(int t, Slot s) {
    final tier = (t * 10 ~/ 20).clamp(0, 4) + 1;
    final kind = switch (s) {
      Slot.weapon => weaponIconOf(slotNoun(Slot.weapon, h.sect)),
      Slot.hat => 'hat',
      Slot.armor => 'armor',
      Slot.belt => 'belt',
      Slot.boots => 'boots',
      Slot.amulet => 'amulet',
      Slot.ring => 'ring',
    };
    return kind == null ? null : 'assets/art/icons/${kind}_$tier.webp';
  }

  // ------------------------------------------------------------ Vạn thú phổ

  Widget _lands() => ListView.builder(
        itemCount: codexLands.length,
        itemBuilder: (_, i) => _landRow(i, codexLands[i]),
      );

  Widget _landRow(int i, MapDef m) {
    final page = codexLandPage(m.id);
    final b = codexLandBonus[m.id];
    final (a, n) = h.codexLandProgress(m);
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      border: h.codexClaimable(page) ? goldLight : (h.codexClaimed.contains(page) ? jade : gold),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(m.name), style: bold.copyWith(color: goldLight, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(tr('Cấp {minLv}–{maxLv}', {'minLv': m.minLv, 'maxLv': m.maxLv}), style: small.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 3,
              children: [
                for (final id in m.mobs) _mobChip(mobById[id]!.name, h.codexMobCount(id), codexMobGoal),
                _mobChip(mobById[m.boss]!.name, h.codexBossCount(m.boss), codexBossGoal, boss: true),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (b != null)
                  Text(loreBonusLabel(b.$1, b.$2), style: bold.copyWith(fontSize: 11, color: cream), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(tr('+{p0} lượng', {'p0': fmt(codexLandGold(i))}), style: small.copyWith(fontSize: 10.5), maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _claimButton(page, '$a/$n'),
        ],
      ),
    );
  }

  Widget _mobChip(String name, int n, int goal, {bool boss = false}) {
    final full = n >= goal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: lacquerDeep,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: full ? _done : (boss ? const Color(0xFFFF9A5A) : gold.withValues(alpha: 0.4))),
      ),
      child: Text(
        '${boss ? '★ ' : ''}$name ${fmt(n)}/$goal',
        style: small.copyWith(fontSize: 10.5, color: full ? _done : cream),
      ),
    );
  }

  // ------------------------------------------------------------ Kỳ ngộ phổ

  Future<void> _claimKy(KyNgo k) async {
    final lines = h.kyClaimPage(k);
    if (lines.isEmpty) return;
    await SaveService.instance.save();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(lines.join(' · ')), duration: const Duration(seconds: 3)));
  }

  Widget _ky() => ListView.builder(
        itemCount: KyNgo.values.length,
        itemBuilder: (_, i) => _kyRow(KyNgo.values[i]),
      );

  Widget _kyRow(KyNgo k) {
    final n = h.kySeen(k);
    final done = h.kyClaimed.contains(k.name);
    final ready = h.kyPageReady(k);
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      border: ready ? goldLight : (done ? jade : gold),
      child: Row(
        children: [
          Icon(n > 0 ? Icons.auto_awesome : Icons.help_outline, size: 20, color: n > 0 ? _legendInk : creamDim),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n > 0 ? k.label : '???', style: bold.copyWith(color: goldLight, fontSize: 12.5)),
                Text(n > 0 ? k.desc : tr('Chưa gặp kỳ ngộ này.'),
                    style: small.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(tr('Đã gặp {p0}', {'p0': fmt(n)}), style: small.copyWith(fontSize: 10.5)),
          const SizedBox(width: 6),
          if (done)
            const Icon(Icons.check_circle, color: _done, size: 22)
          else
            LButton(
              label: ready ? tr('Nhận') : '${n.clamp(0, kyPageNeed)}/$kyPageNeed',
              small: true,
              color: jade,
              enabled: ready,
              onTap: () => _claimKy(k),
            ),
        ],
      ),
    );
  }

  Widget _kySide() {
    final day = vnDayKey();
    return Panel(
      border: _legendInk,
      padding: const EdgeInsets.all(10),
      child: ListView(
        children: [
          Text(tr('Kỳ ngộ phổ'), style: titleStyle(16, color: _legendInk)),
          const SizedBox(height: 4),
          Text(
            tr('Đánh quái ngoài bản đồ (từ cấp {kyMinLevel}) thỉnh thoảng gặp kỳ ngộ, tinh anh và boss dễ gặp hơn. '
            'Gặp mỗi loại {kyPageNeed} lần thì nhận thưởng trang: lượng, {kyPageGems} ngọc, {kyPageEssence} Tinh Hoa.', {'kyMinLevel': kyMinLevel, 'kyPageNeed': kyPageNeed, 'kyPageGems': kyPageGems, 'kyPageEssence': kyPageEssence}),
            style: small.copyWith(fontSize: 11),
          ),
          const Divider(color: gold),
          _kv(tr('Hôm nay'), '${kyDaily - h.kyLeft(day)}/$kyDaily'),
          _kv(tr('Tổng đã gặp'), fmt(h.kyTotal)),
          _kv(tr('Trang đã nhận'), '${h.kyClaimed.length}/${KyNgo.values.length}'),
          if (h.kyBless > 0) _kv(tr('Tiên nhân chỉ lộ'), tr('{p0} phút', {'p0': (h.kyBless / 60).ceil()})),
          const Divider(color: gold),
          Text(tr('Danh hiệu'), style: bold.copyWith(color: goldLight, fontSize: 12.5)),
          for (final e in kyTotalTitles.entries)
            Text(tr('« {eValue} »: gặp {key} kỳ ngộ', {'eValue': e.value, 'key': e.key}),
                style: small.copyWith(fontSize: 11, color: h.seasonTitles.contains(e.value) ? _done : creamDim)),
          Text(tr('« {kyAllTitle} »: nhận đủ {valuesLength} trang', {'kyAllTitle': kyAllTitle, 'valuesLength': KyNgo.values.length}),
              style: small.copyWith(fontSize: 11, color: h.seasonTitles.contains(kyAllTitle) ? _done : creamDim)),
        ],
      ),
    );
  }
}

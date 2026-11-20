import 'package:flutter/material.dart';

import '../core/codex.dart';
import '../core/content.dart';
import '../core/hero.dart';
import '../core/items.dart';
import '../core/lore.dart' show loreBonusLabel;
import '../services/save.dart';
import 'sub_screen.dart';
import 'theme.dart';

const _legendInk = Color(0xFFFF8A3D);
const _done = Color(0xFF8CE07A);

/// Đồ giám Truyền thuyết (1.19.0): Thần binh phổ and Vạn thú phổ.
class CodexScreen extends StatefulWidget {
  const CodexScreen({super.key, this.tab = 0});

  /// 0: Thần binh phổ, 1: Vạn thú phổ.
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
    return SubScreen(
      title: 'Đồ giám',
      actions: [
        tabChip(gearReady > 0 ? 'Thần binh phổ ($gearReady)' : 'Thần binh phổ', _tab == 0, () => setState(() => _tab = 0)),
        tabChip(landReady > 0 ? 'Vạn thú phổ ($landReady)' : 'Vạn thú phổ', _tab == 1, () => setState(() => _tab = 1)),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _tab == 0 ? _gear() : _lands()),
          const SizedBox(width: 10),
          SizedBox(width: 220, child: _side()),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ side panel

  Widget _side() {
    final b = h.codexBonuses();
    final gearCells = h.codexGear.length;
    final gearPages = [for (var t = 0; t < codexTiers; t++) codexGearPage(t)].where(h.codexClaimed.contains).length;
    final landPages = [for (final m in codexLands) codexLandPage(m.id)].where(h.codexClaimed.contains).length;
    return Panel(
      border: _legendInk,
      padding: const EdgeInsets.all(10),
      child: ListView(
        children: [
          Text('Đồ giám Truyền thuyết', style: titleStyle(16, color: _legendInk)),
          const SizedBox(height: 4),
          Text(
            _tab == 0
                ? 'Nhặt được món Truyền thuyết hoặc Hoàng Kim nào là ghi vào ô của bậc và loại ấy, bán hay phân giải rồi vẫn giữ. '
                    'Đủ ${Slot.values.length} ô một bậc thì nhận thưởng.'
                : 'Hạ mỗi loại quái $codexMobGoal lần và boss $codexBossGoal lần (đánh ở bản đồ, phó bản đều tính) để trọn một trang.',
            style: small.copyWith(fontSize: 11),
          ),
          const Divider(color: gold),
          _kv('Thần binh phổ', '$gearCells/${codexTiers * Slot.values.length} ô · $gearPages/$codexTiers trang'),
          _kv('Vạn thú phổ', '$landPages/${codexLands.length} trang'),
          const SizedBox(height: 6),
          Text('Đang được cộng', style: bold.copyWith(color: goldLight, fontSize: 12.5)),
          if (b.isEmpty)
            Text('Chưa có. Nhận trang đầu tiên để được cộng chỉ số vĩnh viễn.', style: small.copyWith(fontSize: 11))
          else
            for (final e in b.entries)
              Text('• ${loreBonusLabel(e.key, e.value)}', style: body.copyWith(fontSize: 12, color: _done)),
          const Divider(color: gold),
          Text(
            'Trọn Thần binh phổ: danh hiệu « $codexGearTitle », '
            '${codexGearAllBonus.entries.map((e) => loreBonusLabel(e.key, e.value)).join(', ')}',
            style: small.copyWith(fontSize: 11, color: h.codexGearAll ? _done : creamDim),
          ),
          const SizedBox(height: 4),
          Text(
            'Trọn Vạn thú phổ: danh hiệu « $codexLandTitle », '
            '${codexLandAllBonus.entries.map((e) => loreBonusLabel(e.key, e.value)).join(', ')}',
            style: small.copyWith(fontSize: 11, color: h.codexLandAll ? _done : creamDim),
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
    return LButton(label: ready ? 'Nhận' : progress, small: true, color: jade, enabled: ready, onTap: () => _claim(page));
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
                Text(codexTierName(t), style: bold.copyWith(color: goldLight, fontSize: 13)),
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
                Text('+${fmt(codexGearGold(t))} lượng${ess > 0 ? ', +$ess Tinh Hoa' : ''}',
                    style: small.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _claimButton(page, '${h.codexGearCount(t)}/${Slot.values.length}'),
        ],
      ),
    );
  }

  Widget _cell(int t, Slot s) {
    final got = h.codexGear.contains(codexGearKey(t, s));
    final path = _iconPath(t, s);
    final glyph = Icon(Icons.shield_outlined, size: 18, color: got ? _legendInk : creamDim);
    Widget img = path == null
        ? glyph
        : Image.asset(path, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => glyph);
    if (!got) {
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
      message: '${s.label} ${codexTierName(t)}${got ? ' · đã ghi' : ''}',
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: lacquerDeep,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: got ? _legendInk : gold.withValues(alpha: 0.35), width: got ? 1.6 : 1),
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
                Text(m.name, style: bold.copyWith(color: goldLight, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Cấp ${m.minLv}–${m.maxLv}', style: small.copyWith(fontSize: 10.5)),
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
                Text('+${fmt(codexLandGold(i))} lượng', style: small.copyWith(fontSize: 10.5), maxLines: 1),
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
}

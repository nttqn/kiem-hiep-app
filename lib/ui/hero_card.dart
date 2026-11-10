import 'package:flutter/material.dart';

import '../core/costumes.dart';
import '../core/divine.dart';
import '../core/gold_sets.dart';
import '../core/hanh.dart';
import '../core/items.dart';
import '../core/mounts.dart';
import '../core/ngo_dao.dart';
import '../core/pets.dart';
import '../core/sects.dart';
import '../core/hero_look.dart';
import '../core/arena.dart' show arenaOpenLevel;
import '../core/spar.dart';
import '../core/guild.dart' show Friends, maxFriends;
import '../core/world_boss.dart' show vnDayKey;
import '../render/art_figures.dart' show lookGear;
import '../services/save.dart';
import '../services/leaderboard.dart';
import 'backdrop.dart' show FigurePreview;
import 'play_screen.dart';
import 'theme.dart';

/// Rows reported this session, so the menu says so instead of asking again.
final Set<String> _reported = {};

/// What tapping a hero on a board offers (1.12.0): Xem thông tin, and
/// Báo cáo for anyone but this player.
Future<void> showLbHeroMenu(BuildContext context, LbEntry e, {bool mine = false}) async {
  final hn = Hanh.values[e.hanh];
  final pick = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      backgroundColor: lacquer,
      title: Text(e.name, style: titleStyle(18, color: cream)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${sectOf(hn).name} · Cấp ${e.level}${e.rebirths > 0 ? ' · Chuyển sinh ${e.rebirths}' : ''}',
              style: small.copyWith(color: hanhColor(hn))),
          const SizedBox(height: 12),
          LButton(label: 'Xem thông tin', icon: Icons.person_search, onTap: () => Navigator.pop(ctx, 'view')),
          if (!mine) ...[
            const SizedBox(height: 8),
            LButton(
              label: _reported.contains(e.id) ? 'Đã báo cáo' : 'Báo cáo gian lận',
              icon: Icons.flag,
              color: seal,
              enabled: !_reported.contains(e.id),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
    ),
  );
  if (!context.mounted) return;
  if (pick == 'view') {
    await showHeroCard(context, e, mine: mine);
  } else if (pick == 'report') {
    await _report(context, e);
  }
}

Future<void> _report(BuildContext context, LbEntry e) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      backgroundColor: lacquer,
      title: Text(e.name, style: titleStyle(18, color: cream)),
      content: Text(
        'Báo cáo nhân vật này gian lận (chỉ số vô lý, sửa dữ liệu…)? '
        'Nhà phát triển sẽ xem xét và gỡ khỏi bảng nếu đúng.',
        style: body,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Báo cáo gian lận')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final sent = await Leaderboard.instance.report(e);
  if (sent) _reported.add(e.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(sent ? 'Đã gửi báo cáo, cảm ơn bạn.' : 'Không gửi được (có thể bạn đã báo cáo rồi).'),
    duration: const Duration(seconds: 2),
  ));
}

/// The hero of row [e] as others see them: figure in their gear, rebirths,
/// level, lực chiến, stats and worn items. A row without looks (a boss
/// board's, or the main board's from an older app) is read fresh from the
/// main board first.
Future<void> showHeroCard(BuildContext context, LbEntry e, {bool mine = false}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: lacquer,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), side: BorderSide(color: gold.withValues(alpha: 0.7))),
      child: _HeroCard(entry: e, mine: mine),
    ),
  );
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.entry, required this.mine});
  final LbEntry entry;
  final bool mine;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  late LbEntry _e = widget.entry;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_e.look == null) _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final got = await Leaderboard.instance.profile(_e.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (got != null) _e = got;
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final hn = Hanh.values[e.hanh];
    final look = e.look;
    final items = lookItems(look);
    final female = look?['f'] as bool? ?? e.id.hashCode.isOdd;
    final divine = (look?['dv'] as num?)?.toInt() ?? 0;
    final gear = lookGear(look, e.level, e.rebirths);
    final costume = costumeById[look?['c'] as String? ?? ''];
    final screen = MediaQuery.sizeOf(context);
    return SizedBox(
      width: (screen.width - 24).clamp(300, 720),
      height: (screen.height - 24).clamp(260, 360),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The figure, on its element's colour.
            Container(
              width: 170,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  Color.lerp(lacquerLight, hanhColor(hn), 0.25)!,
                  lacquerDeep,
                ]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: hanhColor(hn).withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        child: FigurePreview(
                            hanh: hn, female: female, scale: 2.2, gear: gear, costume: costume, rebirths: e.rebirths),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(sectOf(hn).name, style: bold.copyWith(color: hanhColor(hn), fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _info(e)),
            const SizedBox(width: 10),
            SizedBox(width: 200, child: _gear(items, look, divine)),
          ],
        ),
      ),
    );
  }

  Widget _info(LbEntry e) {
    final st = e.st;
    String pct(int v) => '${(v / 10).toStringAsFixed(1)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(e.name, style: titleStyle(20, color: cream), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: creamDim, size: 22),
            ),
          ],
        ),
        if (e.title.isNotEmpty) Text('« ${e.title} »', style: small.copyWith(color: goldLight, fontSize: 12)),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            children: [
              _stat('Lực chiến', fmt(e.power), big: true),
              _stat('Cấp', '${e.level}'),
              _stat('Chuyển sinh', '${e.rebirths}'),
              if (e.dao > 0) _stat('Ngộ Đạo', daoName(e.dao)),
              _stat('Tháp Thử Luyện', 'Tầng ${e.tower}'),
              if (e.dhC > 0) _stat('Minh Chủ', '${e.dhC} lần'),
              if (st != null && st.length >= 8) ...[
                const Divider(color: Colors.white24, height: 10),
                _stat('Sinh lực', fmt(st[0])),
                _stat('Nội lực', fmt(st[1])),
                _stat('Công', fmt(st[2])),
                _stat('Thủ', fmt(st[3])),
                _stat('Bạo kích', pct(st[4])),
                _stat('Sát thương bạo', pct(st[5])),
                _stat('Né tránh', pct(st[6])),
                _stat('Tốc đánh', (st[7] / 1000).toStringAsFixed(2)),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Center(
                    child: SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(color: goldLight, strokeWidth: 2.5)),
                  ),
                )
              else if (e.look == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Người chơi này chưa cập nhật bản mới nên chưa có trang bị và chỉ số chi tiết.',
                      style: small.copyWith(fontSize: 11.5)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gear(List<Item> items, Map<String, dynamic>? look, int divine) {
    final bySlot = {for (final it in items) it.slot: it};
    final pet = petById[look?['pet'] as String? ?? ''];
    final petLv = (look?['pl'] as num?)?.toInt() ?? 1;
    final mount = mountById[_e.mount ?? ''];
    final sets = <String, int>{};
    for (final it in items) {
      if (it.golden) sets[it.set] = (sets[it.set] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Trang bị', style: bold.copyWith(color: goldLight)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in Slot.values)
              ItemTile(
                item: bySlot[s],
                slot: s,
                size: 44,
                onTap: bySlot[s] == null ? null : () => _showItem(bySlot[s]!),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            children: [
              if (divine > 0) _line('Thần binh', '${divineStage(divine)} · cấp $divine'),
              for (final s in sets.entries)
                if (goldSetById[s.key] != null) _line('Bộ Hoàng Kim', '${goldSetById[s.key]!.name} (${s.value})'),
              if (mount != null) _line('Thú cưỡi', '${mount.name} · cấp ${_e.mountLv}'),
              if (pet != null) _line('Linh thú', '${pet.name} · cấp $petLv'),
              if (look != null && items.isEmpty) Text('Không mặc trang bị.', style: small),
            ],
          ),
        ),
        if (!widget.mine && SaveService.instance.active >= 0) _actions(),
      ],
    );
  }

  /// Tỉ thí with this hero (and, 1.13.0, Kết bạn).
  Widget _actions() {
    final me = SaveService.instance.hero;
    final day = vnDayKey();
    final left = me.sparLeft(day);
    final friend = me.isFriend(_e.id);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: LButton(
              label: !me.sparOpen ? 'Tỉ thí: cấp $arenaOpenLevel' : 'Tỉ thí $left/$sparPerDay',
              small: true,
              color: seal,
              enabled: me.sparOpen && left > 0 && !_loading,
              onTap: _spar,
            ),
          ),
          const SizedBox(width: 4),
          // Hảo hữu (1.13.0).
          Expanded(
            child: LButton(
              label: friend ? 'Bỏ bạn' : 'Kết bạn',
              small: true,
              color: jade,
              enabled: friend || me.friends.length < maxFriends,
              onTap: () {
                friend ? me.removeFriend(_e.id) : me.addFriend(_e.id, _e.name, _e.hanh);
                SaveService.instance.save();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _spar() async {
    final me = SaveService.instance.hero;
    if (!me.sparStart(vnDayKey())) return;
    await SaveService.instance.save();
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    await nav.push(fadeRoute(PlayScreen.dungeon(sparDef(_e.toRival()))));
    await SaveService.instance.save();
  }

  void _showItem(Item it) {
    final gems = lookGems(_e.look, it.slot);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: lacquer,
        title: Text(it.title, style: titleStyle(17, color: Color(it.color))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${it.slot.label} · ${it.rarityLabel} · cấp ${it.level}', style: body),
            if (it.golden && goldSetById[it.set] != null)
              Text('Bộ ${goldSetById[it.set]!.name}${it.glow > 0 ? ' · Khai Quang ${it.glow}' : ''}',
                  style: small.copyWith(color: const Color(goldItemColor))),
            if (gems > 0) Text('Đã khảm $gems ngọc', style: small),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }

  Widget _stat(String k, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(child: Text(k, style: body.copyWith(fontSize: 13))),
            Text(v, style: big ? titleStyle(17, color: goldLight) : bold.copyWith(fontSize: 13.5, color: cream)),
          ],
        ),
      );

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$k: ', style: small.copyWith(fontSize: 12)),
            TextSpan(text: v, style: bold.copyWith(fontSize: 12, color: cream)),
          ]),
        ),
      );
}

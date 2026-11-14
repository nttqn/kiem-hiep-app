import 'package:flutter/material.dart';

import '../core/hanh.dart';
import '../core/helper.dart';
import '../core/hero.dart';
import '../core/guild.dart';
import '../core/sects.dart';
import '../core/world_boss.dart' show vnDayKey;
import '../services/guild.dart';
import '../services/leaderboard.dart';
import 'theme.dart';

/// A hero that may be called in, and why they are on the list.
class HelperPick {
  const HelperPick(this.entry, this.source);
  final LbEntry entry;
  final HelperSource source;
}

/// Friends, then bang members, then stronger players from the board, each
/// player's hero once, none of this account's own.
Future<List<HelperPick>> loadHelpers(HeroData h) async {
  final gs = GuildService.instance;
  final lb = Leaderboard.instance;
  final me = gs.uid;
  final seen = <String>{};
  final out = <HelperPick>[];
  void add(Iterable<LbEntry> rows, HelperSource src) {
    for (final e in rows) {
      if (me != null && e.id.startsWith('${me}_')) continue;
      if (seen.add(e.id)) out.add(HelperPick(e, src));
    }
  }

  if (gs.available) {
    try {
      add(await gs.rows([for (final f in h.friends) f.row]), HelperSource.friend);
    } catch (_) {}
    if (h.inGuild) {
      try {
        final members = await gs.members(h.guildId);
        final rows = [for (final m in members) m.row]..remove(gs.myRow);
        final got = await gs.rows(rows.take(20).toList());
        got.sort((a, b) => b.power.compareTo(a.power));
        add(got, HelperSource.guild);
      } catch (_) {}
    }
  }
  try {
    final pool = await lb.helperPool(h.power);
    // A few just above the hero and a few well above.
    final picks = pool.length <= 8 ? pool : [...pool.take(4), ...pool.skip(pool.length - 4)];
    add(picks, HelperSource.master);
  } catch (_) {}
  return out;
}

/// Lets the player pick who to call in; null when they close it.
Future<HelperPick?> showHelperPicker(BuildContext context, HeroData h) {
  return showDialog<HelperPick>(context: context, builder: (_) => _HelperDialog(hero: h));
}

class _HelperDialog extends StatefulWidget {
  const _HelperDialog({required this.hero});
  final HeroData hero;

  @override
  State<_HelperDialog> createState() => _HelperDialogState();
}

class _HelperDialogState extends State<_HelperDialog> {
  late final Future<List<HelperPick>> _list = loadHelpers(widget.hero);

  @override
  Widget build(BuildContext context) {
    final h = widget.hero;
    final day = vnDayKey();
    final left = h.helpsLeft(day);
    final signed = GuildService.instance.myRow != null;
    return AlertDialog(
      backgroundColor: lacquer,
      title: Text('Mời trợ chiến', style: titleStyle(20)),
      // Fits a short landscape phone (760x344): the list scrolls.
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: SizedBox(
        width: 460,
        height: (MediaQuery.sizeOf(context).height - 150).clamp(120.0, 300.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Còn $left/$helpCallsPerDay lượt hôm nay · người được mời nhận Hiệp nghĩa',
                style: small.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (!signed)
              Text('Đăng nhập để mời Hảo hữu, đồng môn bang',
                  style: small.copyWith(fontSize: 11.5, color: goldLight), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Expanded(
              child: FutureBuilder<List<HelperPick>>(
                future: _list,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: goldLight));
                  }
                  final list = snap.data ?? const <HelperPick>[];
                  if (list.isEmpty) {
                    return Center(
                      child: Text('Chưa tìm được ai. Kiểm tra mạng rồi thử lại.',
                          style: body, textAlign: TextAlign.center),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) => _row(list[i], h, day, left > 0),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đánh một mình'))],
    );
  }

  Widget _row(HelperPick p, HeroData h, String day, bool anyLeft) {
    final e = p.entry;
    final hanh = Hanh.values[e.hanh];
    final used = h.helpUsed.contains(e.id) && h.helpDay == day;
    final mul = helperMul(e.power, h.power);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: lacquerLight,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: Color(hanh.color), width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: bold.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
                Text(
                    '${helperSourceNames[p.source]} · ${sectOf(hanh).name} · Cấp ${e.level}'
                    '${e.rebirths > 0 ? ' · CS${e.rebirths}' : ''} · Lực chiến ${fmt(e.power)}',
                    style: small.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                Text('Sức trợ chiến ×${mul.toStringAsFixed(1)}',
                    style: small.copyWith(fontSize: 11, color: goldLight)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          LButton(
            label: used ? 'Đã mời' : 'Mời',
            small: true,
            color: jade,
            enabled: !used && anyLeft,
            onTap: () => Navigator.pop(context, p),
          ),
        ],
      ),
    );
  }
}

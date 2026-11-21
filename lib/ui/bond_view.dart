import 'package:flutter/material.dart';

import '../core/bond.dart';
import '../core/guild.dart';
import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/sects.dart';
import '../core/world_boss.dart' show vnDayKey;
import '../services/analytics.dart';
import '../services/guild.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'theme.dart';

const _kdTint = Color(0xFFFFA0C0);

/// Kết duyên (1.20.0), the fourth tab of Bang hội · Hảo hữu.
class BondView extends StatefulWidget {
  const BondView({super.key});

  @override
  State<BondView> createState() => _BondViewState();
}

class _BondViewState extends State<BondView> {
  HeroData get h => SaveService.instance.hero;
  GuildService get gs => GuildService.instance;
  String get _day => vnDayKey();

  bool _loading = true;
  List<BondMsg> _requests = const [];
  List<LbEntry> _candidates = const [];
  LbEntry? _partner;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 3)));
  }

  Future<void> _save() => SaveService.instance.save();

  static bool _levelOk(int level, int rebirths) => level >= bondMinLevel || rebirths > 0;

  Future<void> _load() async {
    setState(() => _loading = true);
    final day = _day;
    try {
      final inbox = await gs.bondInbox();
      final reqs = <BondMsg>[];
      final said = <String>[];
      for (final m in inbox) {
        switch (m.kind) {
          case 'req':
            if (m.from == h.kdPending && !h.bonded) {
              // Both asked each other: that is a yes.
              h.bondWith(m.from, m.name, m.hanh, day);
              await gs.bondSend(h, m.from, 'ok', day);
              await gs.bondDrop(m.from);
              said.add('Đã kết duyên cùng ${m.name}!');
            } else if (h.bonded) {
              if (m.from != h.kdPartner) await gs.bondSend(h, m.from, 'bye', day);
              await gs.bondDrop(m.from);
            } else {
              reqs.add(m);
            }
          case 'ok' || 'tt':
            if (m.from == h.kdPending && !h.bonded) {
              h.bondWith(m.from, m.name, m.hanh, day);
              h.addFriend(m.from, m.name, m.hanh);
              Analytics.instance.log('bond', {'k': 'made', 'level': h.level});
              said.add('${m.name} đã nhận lời kết duyên!');
            }
            if (m.from == h.kdPartner) {
              if (m.kind == 'tt' && !h.loveDone(LoveWay.got, day)) {
                final lines = h.addLove(LoveWay.got, day);
                said.add('${m.name} gửi Tương tư · ${lines.join(' · ')}');
                await gs.bondDrop(m.from);
              } else if (m.kind == 'ok') {
                await gs.bondDrop(m.from);
              }
            } else {
              // A yes that came too late: this hero is no longer free.
              if (m.kind == 'ok') await gs.bondSend(h, m.from, 'bye', day);
              await gs.bondDrop(m.from);
            }
          case 'bye':
            if (m.from == h.kdPartner) {
              h.part(day);
              said.add('${m.name} đã đoạn duyên.');
            } else if (m.from == h.kdPending) {
              h.cancelAsk();
              said.add('${m.name} chưa nhận lời kết duyên.');
            }
            await gs.bondDrop(m.from);
        }
      }
      _requests = reqs;
      _partner = null;
      if (h.bonded) {
        final rows = await gs.rows([h.kdPartner]);
        if (rows.isNotEmpty) {
          final e = rows.first;
          _partner = e;
          h.kdPartnerName = e.name;
          h.kdPartnerHanh = e.hanh;
        }
      } else if (h.kdPending.isEmpty) {
        await _findCandidates();
      }
      await _save();
      if (said.isNotEmpty) _toast(said.join('\n'));
    } catch (_) {
      _toast('Không tải được, thử lại sau.');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Friends of another account who could be asked.
  Future<void> _findCandidates() async {
    final mine = gs.uid;
    final rows = await gs.rows([for (final f in h.friends) f.row]);
    _candidates = [
      for (final e in rows)
        if (_levelOk(e.level, e.rebirths) && (mine == null || !e.id.startsWith('${mine}_'))) e,
    ]..sort((a, b) => b.power.compareTo(a.power));
  }

  Future<void> _run(String key, Future<void> Function() job) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _ask(LbEntry e) => _run('ask', () async {
        if (!h.canBond(_day)) return;
        final ok = await _confirm('Cầu duyên ${e.name}?',
            'Nếu người ấy nhận lời, hai bạn thành phu thê. Mỗi lúc chỉ cầu duyên được một người.');
        if (!ok) return;
        if (!await gs.bondSend(h, e.id, 'req', _day)) {
          _toast('Không gửi được, thử lại sau.');
          return;
        }
        h.askBond(e.id, e.name, e.hanh, _day);
        await _save();
        _toast('Đã gửi lời cầu duyên tới ${e.name}. Chờ người ấy trả lời.');
      });

  Future<void> _cancelAsk() => _run('ask', () async {
        final row = h.kdPending;
        if (row.isEmpty) return;
        await gs.bondSend(h, row, 'bye', _day);
        h.cancelAsk();
        await _save();
        await _findCandidates();
      });

  Future<void> _accept(BondMsg m) => _run('r${m.from}', () async {
        if (!h.bondLevelOk || h.bonded || h.bondWait(_day) > 0) return;
        if (!_levelOk(m.level, m.rebirths)) {
          _toast('Người ấy chưa đủ cấp $bondMinLevel.');
          return;
        }
        if (!await gs.bondSend(h, m.from, 'ok', _day)) {
          _toast('Không gửi được, thử lại sau.');
          return;
        }
        // An unanswered proposal of this hero's own is taken back.
        if (h.kdPending.isNotEmpty && h.kdPending != m.from) await gs.bondSend(h, h.kdPending, 'bye', _day);
        await gs.bondDrop(m.from);
        h.bondWith(m.from, m.name, m.hanh, _day);
        h.addFriend(m.from, m.name, m.hanh);
        Analytics.instance.log('bond', {'k': 'made', 'level': h.level});
        await _save();
        _toast('Đã kết duyên cùng ${m.name}!');
        await _load();
      });

  Future<void> _reject(BondMsg m) => _run('r${m.from}', () async {
        await gs.bondSend(h, m.from, 'bye', _day);
        await gs.bondDrop(m.from);
        _requests = [..._requests]..remove(m);
      });

  Future<void> _sendTt() => _run('tt', () async {
        if (!h.bonded || h.loveDone(LoveWay.sent, _day)) return;
        if (!await gs.bondSend(h, h.kdPartner, 'tt', _day)) {
          _toast('Không gửi được, thử lại sau.');
          return;
        }
        final lines = h.addLove(LoveWay.sent, _day);
        await _save();
        _toast('Đã gửi Tương tư tới ${h.kdPartnerName}. ${lines.join(' · ')}');
      });

  Future<void> _part() async {
    final ok = await _confirm('Đoạn duyên với ${h.kdPartnerName}?',
        'Tình ý (${h.kdLove}) và Nhẫn Đồng Tâm sẽ mất. Phải chờ $bondCooldownDays ngày mới kết duyên lại được.');
    if (!ok) return;
    await _run('part', () async {
      await gs.bondSend(h, h.kdPartner, 'bye', _day);
      h.part(_day);
      Analytics.instance.log('bond', {'k': 'part', 'level': h.level});
      await _save();
      await _findCandidates();
    });
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: lacquer,
          title: Text(title, style: titleStyle(18, color: cream)),
          content: Text(text, style: body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
          ],
        ),
      ) ??
      false;

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: goldLight));
    final day = _day;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(8),
            child: ListView(children: h.bonded ? _bondedPart(day) : _freePart(day)),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 230, child: _rules()),
      ],
    );
  }

  Widget _rules() => Panel(
        border: _kdTint,
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: [
            Text('Kết duyên', style: titleStyle(17, color: _kdTint)),
            const SizedBox(height: 4),
            Text(
              'Hai Hảo hữu khác tài khoản, cấp $bondMinLevel+ (hoặc đã chuyển sinh), kết thành phu thê.\n'
              '• Mỗi ngày +$bondLovePer Tình ý cho mỗi việc: gửi Tương tư, nhận Tương tư, mời phu thê trợ chiến, '
              'được phu thê mời trợ chiến\n'
              '• Tình ý nâng Nhẫn Đồng Tâm (tối đa cấp $bondRingMax): mỗi cấp +${_pct(bondHpPer)} HP, '
              '+${_pct(bondAtkPer)} công, +${_pct(bondDefPer)} phòng\n'
              '• +1 lượt Trợ chiến mỗi ngày; phu thê trợ chiến mạnh ×$bondHelperMul\n'
              '• Danh hiệu ở nhẫn cấp ${bondTitles.keys.join(', ')}',
              style: small.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text('Đoạn duyên thì mất Tình ý và nhẫn, chờ $bondCooldownDays ngày mới kết duyên lại.',
                style: small.copyWith(fontSize: 10.5, color: creamDim)),
          ],
        ),
      );

  static String _pct(double v) {
    final p = v * 100;
    return '${p == p.roundToDouble() ? p.round() : p.toStringAsFixed(1)}%';
  }

  static String _date(String d) =>
      d.length == 8 ? '${d.substring(6)}/${d.substring(4, 6)}/${d.substring(0, 4)}' : d;

  // ------------------------------------------------------------ bonded

  List<Widget> _bondedPart(String day) {
    final p = _partner;
    final ring = h.bondRing;
    final lo = ring == 0 ? 0 : bondRingNeeds[ring - 1];
    final hi = ring >= bondRingMax ? lo : bondRingNeeds[ring];
    final b = bondRingBonuses(ring);
    return [
      Text('Phu thê', style: titleStyle(16, color: _kdTint)),
      _personRow(
        h.kdPartnerName,
        h.kdPartnerHanh,
        p == null
            ? 'Từ ${_date(h.kdSince)}'
            : '${p.rebirths > 0 ? 'CS${p.rebirths} · ' : ''}Cấp ${p.level} · LC ${fmt(p.power)} · từ ${_date(h.kdSince)}',
        trailing: [
          LButton(label: 'Đoạn duyên', small: true, color: seal, enabled: !_busy.contains('part'), onTap: _part),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Text('Nhẫn Đồng Tâm · cấp $ring/$bondRingMax', style: bold.copyWith(color: goldLight, fontSize: 13)),
          ),
          Text('Tình ý ${h.kdLove}', style: small.copyWith(fontSize: 11.5)),
        ],
      ),
      const SizedBox(height: 3),
      Bar(
        value: hi == lo ? 1 : (h.kdLove - lo) / (hi - lo),
        color: _kdTint,
        height: 10,
      ),
      const SizedBox(height: 3),
      Text(
        ring == 0
            ? 'Chưa có chỉ số · cần thêm ${h.bondNextNeed} Tình ý cho cấp 1'
            : '+${_pct(b[Bonus.hpPct]!)} HP · +${_pct(b[Bonus.atkPct]!)} công · +${_pct(b[Bonus.defPct]!)} phòng'
                '${h.bondNextNeed > 0 ? ' · cấp sau cần thêm ${h.bondNextNeed} Tình ý' : ' · đã tối đa'}',
        style: small.copyWith(fontSize: 11),
      ),
      const SizedBox(height: 8),
      Text('Tình ý hôm nay', style: bold.copyWith(color: goldLight, fontSize: 12.5)),
      for (final w in LoveWay.values)
        SizedBox(
          height: 34,
          child: Row(
            children: [
              Icon(h.loveDone(w, day) ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 15, color: h.loveDone(w, day) ? jade : creamDim),
              const SizedBox(width: 6),
              Expanded(child: Text('${loveWayNames[w]} (+$bondLovePer)', style: small.copyWith(fontSize: 11.5))),
              if (w == LoveWay.sent)
                LButton(
                  label: h.loveDone(w, day) ? 'Đã gửi' : 'Gửi Tương tư',
                  small: true,
                  color: jade,
                  enabled: !h.loveDone(w, day) && !_busy.contains('tt'),
                  onTap: _sendTt,
                ),
              if (w == LoveWay.got)
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: goldLight, size: 18)),
            ],
          ),
        ),
    ];
  }

  // ------------------------------------------------------------ free

  List<Widget> _freePart(String day) {
    if (!h.bondLevelOk) {
      return [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Đạt cấp $bondMinLevel (hoặc chuyển sinh) để kết duyên.', style: body, textAlign: TextAlign.center),
        ),
      ];
    }
    final wait = h.bondWait(day);
    return [
      if (h.kdPending.isNotEmpty) ...[
        Text('Đang cầu duyên', style: titleStyle(16, color: _kdTint)),
        _personRow(h.kdPendingName, h.kdPendingHanh, 'Chờ người ấy trả lời',
            trailing: [LButton(label: 'Hủy', small: true, color: seal, enabled: !_busy.contains('ask'), onTap: _cancelAsk)]),
      ],
      if (_requests.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('Lời cầu duyên (${_requests.length})', style: bold.copyWith(color: goldLight, fontSize: 12.5)),
        for (final m in _requests)
          _personRow(m.name, m.hanh, '${m.rebirths > 0 ? 'CS${m.rebirths} · ' : ''}Cấp ${m.level}', trailing: [
            LButton(
                label: 'Nhận lời',
                small: true,
                color: jade,
                enabled: wait == 0 && !_busy.contains('r${m.from}'),
                onTap: () => _accept(m)),
            const SizedBox(width: 4),
            LButton(label: 'Từ chối', small: true, color: seal, enabled: !_busy.contains('r${m.from}'), onTap: () => _reject(m)),
          ]),
      ],
      if (h.kdPending.isEmpty) ...[
        Row(
          children: [
            Expanded(child: Text('Cầu duyên', style: titleStyle(16, color: _kdTint))),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: goldLight, size: 20)),
          ],
        ),
        if (wait > 0)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Vừa đoạn duyên: còn $wait ngày nữa mới kết duyên lại được.',
                style: body.copyWith(fontSize: 12.5), textAlign: TextAlign.center),
          )
        else if (_candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Chưa có Hảo hữu nào cấp $bondMinLevel+. Kết bạn trên Bảng xếp hạng hoặc trong bang rồi quay lại đây.',
              style: body.copyWith(fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final e in _candidates)
            _personRow(
              e.name,
              e.hanh,
              '${e.rebirths > 0 ? 'CS${e.rebirths} · ' : ''}Cấp ${e.level} · LC ${fmt(e.power)}',
              trailing: [
                LButton(label: 'Cầu duyên', small: true, color: jade, enabled: !_busy.contains('ask'), onTap: () => _ask(e)),
              ],
            ),
      ],
    ];
  }

  Widget _personRow(String name, int hanh, String line, {List<Widget> trailing = const []}) {
    final hn = Hanh.values[hanh.clamp(0, 4)];
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: lacquerDeep, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: hanhColor(hn), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: bold.copyWith(fontSize: 12.5, color: cream), overflow: TextOverflow.ellipsis),
                Text('${sectOf(hn).name} · $line',
                    style: small.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

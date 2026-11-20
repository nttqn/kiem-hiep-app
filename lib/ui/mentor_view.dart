import 'package:flutter/material.dart';

import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/mentor.dart';
import '../core/sects.dart';
import '../core/world_boss.dart' show vnDayKey;
import '../services/guild.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'theme.dart';

const _sdTint = Color(0xFFFFC88A);

/// Sư đồ (1.19.0), the third tab of Bang hội · Hảo hữu.
class MentorView extends StatefulWidget {
  const MentorView({super.key});

  @override
  State<MentorView> createState() => _MentorViewState();
}

/// A master the hero could ask: from the listing or a strong friend.
class _Candidate {
  const _Candidate(this.row, this.name, this.hanh, this.level, this.rebirths, this.power, this.seats, this.friend);
  final String row, name;
  final int hanh, level, rebirths, power, seats;
  final bool friend;
}

class _MentorViewState extends State<MentorView> {
  HeroData get h => SaveService.instance.hero;
  GuildService get gs => GuildService.instance;
  String get _day => vnDayKey();

  bool _loading = true;
  List<MentorMsg> _requests = const [];
  List<_Candidate> _candidates = const [];
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final day = _day;
    h.mentorRollDay(day);
    try {
      final inbox = await gs.mentorInbox();
      final reqs = <MentorMsg>[];
      for (final m in inbox) {
        switch (m.kind) {
          case 'req':
            if (h.canTeach && h.discipleOf(m.from) == null) {
              reqs.add(m);
            } else if (h.discipleOf(m.from) != null) {
              await gs.mentorDrop(m.from);
            }
          case 'ok' || 'tc':
            if (m.from == h.sdPending) {
              h.masterAccepted();
              _toast('${m.name} đã nhận bạn làm đệ tử!');
            }
            if (m.from == h.sdMaster) {
              if (m.kind == 'tc' && m.day == day && h.sdTcDay != day) h.sdTcReady = true;
              if (m.kind == 'ok') await gs.mentorDrop(m.from);
            } else {
              await gs.mentorDrop(m.from);
            }
          case 'bye':
            if (m.from == h.sdMaster) {
              h.leaveMaster();
              _toast('${m.name} đã cho bạn rời sư môn.');
            } else if (m.from == h.sdPending) {
              h.sdPending = '';
              h.sdPendingName = '';
              _toast('${m.name} chưa nhận đệ tử lúc này.');
            } else if (h.discipleOf(m.from) != null) {
              h.dropDisciple(m.from);
              _toast('Đệ tử ${m.name} đã rời sư môn.');
            }
            await gs.mentorDrop(m.from);
        }
      }
      _requests = reqs;
      // What the board says of each đệ tử.
      if (h.disciples.isNotEmpty) {
        final rows = await gs.rows([for (final d in h.disciples) d.row]);
        for (final e in rows) {
          h.seeDisciple(e.id, e.name, e.hanh, e.level, e.rebirths);
        }
      }
      if (h.sdListing) await gs.mentorList(h, h.canTeach, h.activeDisciples);
      if (h.sdListing && !h.canTeach) h.sdListing = false;
      if (h.canBaiSu && h.sdPending.isEmpty) await _findMasters();
      await _save();
    } catch (_) {
      _toast('Không tải được, thử lại sau.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _findMasters() async {
    final out = <String, _Candidate>{};
    try {
      for (final a in await gs.mentors()) {
        out[a.row] = _Candidate(a.row, a.name, a.hanh, a.level, a.rebirths, a.power, a.n, false);
      }
    } catch (_) {}
    final mine = gs.uid;
    final strong = await gs.rows([for (final f in h.friends) f.row]);
    for (final LbEntry e in strong) {
      if ((e.level >= mentorMinLevel || e.rebirths > 0) && (mine == null || !e.id.startsWith('${mine}_'))) {
        out[e.id] = _Candidate(e.id, e.name, e.hanh, e.level, e.rebirths, e.power, out[e.id]?.seats ?? 0, true);
      }
    }
    _candidates = out.values.toList()
      ..sort((a, b) => a.friend != b.friend ? (a.friend ? -1 : 1) : b.power.compareTo(a.power));
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

  Future<void> _ask(_Candidate c) => _run('ask', () async {
        if (!h.canBaiSu || h.sdPending.isNotEmpty) return;
        if (!await gs.mentorSend(h, c.row, 'req', _day)) {
          _toast('Không gửi được, thử lại sau.');
          return;
        }
        h.askMaster(c.row, c.name, c.hanh);
        await _save();
        _toast('Đã xin bái ${c.name} làm sư phụ. Chờ người ấy nhận lời.');
      });

  Future<void> _cancelAsk() => _run('ask', () async {
        final row = h.sdPending;
        if (row.isEmpty) return;
        await gs.mentorSend(h, row, 'bye', _day);
        h.sdPending = '';
        h.sdPendingName = '';
        await _save();
        await _findMasters();
      });

  Future<void> _accept(MentorMsg m) => _run('r${m.from}', () async {
        if (!h.acceptDisciple(m.from, m.name, m.hanh, m.level)) {
          _toast(h.seatFree ? 'Không nhận được đệ tử này (cấp quá $discipleMaxLevel?).' : 'Đã đủ $mentorMaxDisciples đệ tử.');
          return;
        }
        if (!await gs.mentorSend(h, m.from, 'ok', _day)) {
          h.dropDisciple(m.from);
          _toast('Không gửi được, thử lại sau.');
          return;
        }
        await gs.mentorDrop(m.from);
        _requests = [..._requests]..remove(m);
        if (h.sdListing) await gs.mentorList(h, true, h.activeDisciples);
        await _save();
        _toast('Đã nhận ${m.name} làm đệ tử.');
      });

  Future<void> _reject(MentorMsg m) => _run('r${m.from}', () async {
        await gs.mentorSend(h, m.from, 'bye', _day);
        await gs.mentorDrop(m.from);
        _requests = [..._requests]..remove(m);
      });

  Future<void> _truyenCong(Disciple d) => _run('t${d.row}', () async {
        if (!h.canTruyenCong(d.row, _day)) return;
        if (!await gs.mentorSend(h, d.row, 'tc', _day)) {
          _toast('Không gửi được, thử lại sau.');
          return;
        }
        h.sentTruyenCong(d.row, _day);
        await _save();
        _toast('Đã truyền công cho ${d.name}. +$truyenCongEssence Tinh Hoa');
      });

  Future<void> _truyenCongAll() => _run('tall', () async {
        var n = 0;
        for (final d in [...h.disciples]) {
          if (!h.canTruyenCong(d.row, _day)) continue;
          if (!await gs.mentorSend(h, d.row, 'tc', _day)) break;
          h.sentTruyenCong(d.row, _day);
          n++;
        }
        await _save();
        _toast(n > 0 ? 'Đã truyền công cho $n đệ tử. +${n * truyenCongEssence} Tinh Hoa' : 'Không gửi được, thử lại sau.');
      });

  Future<void> _pay(Disciple d) async {
    final lines = h.takeMentorPay(d);
    if (lines.isEmpty) return;
    await _save();
    _toast(lines.join(' · '));
    if (mounted) setState(() {});
  }

  Future<void> _release(Disciple d) async {
    final ok = await _confirm(d.graduated ? 'Xóa ${d.name} khỏi danh sách?' : 'Cho ${d.name} rời sư môn?',
        d.graduated ? 'Đệ tử đã xuất sư.' : 'Phần thưởng mốc chưa nhận sẽ mất.');
    if (!ok) return;
    await _run('x${d.row}', () async {
      if (!d.graduated) await gs.mentorSend(h, d.row, 'bye', _day);
      h.dropDisciple(d.row);
      if (h.sdListing) await gs.mentorList(h, true, h.activeDisciples);
      await _save();
    });
  }

  Future<void> _leave() async {
    final ok = await _confirm('Rời sư môn?', 'Bạn sẽ mất +${(discipleExpBonus * 100).round()}% EXP và quà các mốc sau.');
    if (!ok) return;
    await _run('leave', () async {
      await gs.mentorSend(h, h.sdMaster, 'bye', _day);
      h.leaveMaster();
      await _save();
      await _findMasters();
    });
  }

  Future<void> _takeGift() async {
    final lines = h.takeDiscipleGift();
    if (lines.isEmpty) return;
    await _save();
    _toast(lines.join(' · '));
    if (mounted) setState(() {});
  }

  Future<void> _takeTc() async {
    final xp = h.takeTruyenCong(_day);
    if (xp <= 0) return;
    await gs.mentorDrop(h.sdMaster);
    await _save();
    _toast('Sư phụ truyền công: +${fmt(xp)} kinh nghiệm');
    if (mounted) setState(() {});
  }

  Future<void> _toggleListing(bool on) => _run('list', () async {
        if (!await gs.mentorList(h, on, h.activeDisciples)) {
          _toast('Không cập nhật được, thử lại sau.');
          return;
        }
        h.sdListing = on;
        await _save();
      });

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
            child: ListView(
              children: [
                if (h.hasMaster || h.sdPending.isNotEmpty || h.canBaiSu) ..._learnerPart(day),
                if (h.canTeach) ...[
                  if (h.hasMaster || h.canBaiSu) const Divider(color: gold),
                  ..._masterPart(day),
                ],
                if (!h.canTeach && !h.canBaiSu && !h.hasMaster && h.sdPending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Bái sư: nhân vật chưa chuyển sinh, cấp $discipleMaxLevel trở xuống.\n'
                      'Nhận đệ tử: cấp $mentorMinLevel trở lên hoặc đã chuyển sinh.',
                      style: body,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 230, child: _rules()),
      ],
    );
  }

  Widget _rules() => Panel(
        border: _sdTint,
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: [
            Text('Sư đồ', style: titleStyle(17, color: _sdTint)),
            const SizedBox(height: 4),
            Text(
              'Đệ tử (chưa chuyển sinh, cấp ≤ $discipleMaxLevel khi bái sư):\n'
              '• +${(discipleExpBonus * 100).round()}% EXP quái đến khi xuất sư (chuyển sinh lần đầu)\n'
              '• Quà ở mỗi mốc ${mentorMilestones.first}, ${mentorMilestones[1]}… ${mentorMilestones.last} và xuất sư\n'
              '• Mỗi ngày nhận Truyền công: +${(truyenCongShare * 100).round()}% EXP cấp hiện tại',
              style: small.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              'Sư phụ (cấp $mentorMinLevel+ hoặc đã chuyển sinh), tối đa $mentorMaxDisciples đệ tử:\n'
              '• Tinh Hoa và Thần Thiết mỗi khi đệ tử qua một mốc, nhiều nhất lúc xuất sư\n'
              '• +$truyenCongEssence Tinh Hoa mỗi lần truyền công\n'
              '• Danh hiệu « $mentorTitle1 » (1 đệ tử xuất sư), « $mentorTitle3 » (3)',
              style: small.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text('Tiến độ của đệ tử đọc từ Bảng xếp hạng, nên đệ tử cần hiện trên bảng.',
                style: small.copyWith(fontSize: 10.5, color: creamDim)),
          ],
        ),
      );

  // ------------------------------------------------------------ as đệ tử

  List<Widget> _learnerPart(String day) {
    if (h.hasMaster) {
      final reached = h.discipleStepsReached;
      final next = h.sdGiftNext < mentorSteps ? h.sdGiftNext : -1;
      return [
        Text('Sư phụ', style: titleStyle(16, color: _sdTint)),
        _personRow(h.sdMasterName, h.sdMasterHanh, h.rebirths > 0 ? 'Đã xuất sư' : '+${(discipleExpBonus * 100).round()}% EXP quái',
            trailing: [
              if (h.rebirths == 0)
                LButton(label: 'Rời', small: true, color: seal, enabled: !_busy.contains('leave'), onTap: _leave),
            ]),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                h.sdTcReady && h.sdTcDay != day
                    ? 'Sư phụ đã truyền công hôm nay.'
                    : h.sdTcDay == day
                        ? 'Đã nhận Truyền công hôm nay.'
                        : 'Chưa có Truyền công hôm nay.',
                style: small.copyWith(fontSize: 11.5),
              ),
            ),
            LButton(
              label: 'Nhận Truyền công',
              small: true,
              color: jade,
              enabled: h.sdTcReady && h.sdTcDay != day && h.rebirths == 0,
              onTap: _takeTc,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                next < 0
                    ? 'Đã nhận hết quà sư môn.'
                    : h.discipleGiftReady
                        ? 'Quà mốc ${mentorStepName(next)} đã sẵn sàng.'
                        : 'Mốc tiếp: ${mentorStepName(next)} (đã qua $reached/$mentorSteps mốc)',
                style: small.copyWith(fontSize: 11.5),
              ),
            ),
            LButton(label: 'Nhận quà', small: true, color: jade, enabled: h.discipleGiftReady, onTap: _takeGift),
          ],
        ),
      ];
    }
    if (h.sdPending.isNotEmpty) {
      return [
        Text('Đang xin bái sư', style: titleStyle(16, color: _sdTint)),
        _personRow(h.sdPendingName, h.sdPendingHanh, 'Chờ người ấy nhận lời',
            trailing: [LButton(label: 'Hủy', small: true, color: seal, enabled: !_busy.contains('ask'), onTap: _cancelAsk)]),
      ];
    }
    return [
      Row(
        children: [
          Expanded(child: Text('Tìm sư phụ', style: titleStyle(16, color: _sdTint))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: goldLight, size: 20)),
        ],
      ),
      if (_candidates.isEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Chưa thấy ai đang nhận đệ tử. Kết bạn với người chơi cấp $mentorMinLevel+ trên Bảng xếp hạng rồi quay lại đây.',
            style: body.copyWith(fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        )
      else
        for (final c in _candidates)
          _personRow(
            c.name,
            c.hanh,
            '${c.rebirths > 0 ? 'CS${c.rebirths} · ' : ''}Cấp ${c.level} · LC ${fmt(c.power)}'
            '${c.friend ? ' · bạn bè' : ' · ${c.seats}/$mentorMaxDisciples đệ tử'}',
            trailing: [LButton(label: 'Bái sư', small: true, color: jade, enabled: !_busy.contains('ask'), onTap: () => _ask(c))],
          ),
    ];
  }

  // ------------------------------------------------------------ as sư phụ

  List<Widget> _masterPart(String day) {
    final canTc = h.disciples.any((d) => h.canTruyenCong(d.row, day));
    return [
      Row(
        children: [
          Expanded(child: Text('Đệ tử ${h.activeDisciples}/$mentorMaxDisciples', style: titleStyle(16, color: _sdTint))),
          Text('Nhận đệ tử', style: small.copyWith(fontSize: 11.5)),
          Switch(
            value: h.sdListing,
            activeThumbColor: jade,
            onChanged: _busy.contains('list') ? null : _toggleListing,
          ),
          LButton(label: 'Truyền công', small: true, color: jade, enabled: canTc && !_busy.contains('tall'), onTap: _truyenCongAll),
        ],
      ),
      if (h.disciples.isEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Chưa có đệ tử. Bật "Nhận đệ tử" để tân thủ tìm thấy bạn; bạn bè cấp thấp cũng có thể xin bái sư.',
            style: body.copyWith(fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ),
      for (final d in h.disciples) _discipleRow(d, day),
      if (_requests.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Xin bái sư (${_requests.length})', style: bold.copyWith(color: goldLight, fontSize: 12.5)),
        for (final m in _requests)
          _personRow(m.name, m.hanh, 'Cấp ${m.level}', trailing: [
            LButton(
                label: 'Nhận',
                small: true,
                color: jade,
                enabled: h.seatFree && !_busy.contains('r${m.from}'),
                onTap: () => _accept(m)),
            const SizedBox(width: 4),
            LButton(label: 'Từ chối', small: true, color: seal, enabled: !_busy.contains('r${m.from}'), onTap: () => _reject(m)),
          ]),
      ],
    ];
  }

  Widget _discipleRow(Disciple d, String day) {
    final due = h.mentorPayDue(d);
    final next = d.reached < mentorSteps ? mentorStepName(d.reached) : null;
    return _personRow(
      d.name,
      d.hanh,
      d.graduated
          ? 'Đã xuất sư'
          : 'Cấp ${d.level}${next != null ? ' · mốc tiếp: $next' : ''}',
      onTap: () => _release(d),
      trailing: [
        if (due > 0)
          LButton(label: 'Nhận thưởng', small: true, color: const Color(0xFF8A4A1A), onTap: () => _pay(d))
        else if (!d.graduated)
          LButton(
            label: h.canTruyenCong(d.row, day) ? 'Truyền công' : 'Đã truyền',
            small: true,
            color: jade,
            enabled: h.canTruyenCong(d.row, day) && !_busy.contains('t${d.row}'),
            onTap: () => _truyenCong(d),
          ),
      ],
    );
  }

  Widget _personRow(String name, int hanh, String line, {List<Widget> trailing = const [], VoidCallback? onTap}) {
    final hn = Hanh.values[hanh.clamp(0, 4)];
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

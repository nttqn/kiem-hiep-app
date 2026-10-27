import 'package:flutter/material.dart';

import '../core/hanh.dart';
import '../core/hero.dart';
import '../core/sects.dart';
import '../services/cloud.dart';
import '../services/leaderboard.dart';
import '../services/save.dart';
import 'cloud_panel.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Server-wide rankings: combat power, tower floor, level with rebirths.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LbBoard _board = LbBoard.power;
  List<LbEntry>? _rows;
  int? _place;
  String? _error;
  int _req = 0;

  HeroData get h => SaveService.instance.hero;
  Leaderboard get lb => Leaderboard.instance;

  @override
  void initState() {
    super.initState();
    CloudSave.instance.addListener(_onCloud);
    _load();
  }

  @override
  void dispose() {
    CloudSave.instance.removeListener(_onCloud);
    super.dispose();
  }

  void _onCloud() {
    if (mounted && lb.available && _rows == null && _error == null) _load();
  }

  int _mine(LbBoard b) => switch (b) {
        LbBoard.power => h.power,
        LbBoard.tower => h.towerBest,
        LbBoard.rank => h.rebirths * 100 + h.level,
        LbBoard.arena => arenaBoardValue(h),
      };

  Future<void> _load() async {
    if (!lb.available) {
      setState(() {});
      return;
    }
    final req = ++_req;
    setState(() {
      _rows = null;
      _place = null;
      _error = null;
    });
    // Push this hero's latest numbers first so the player sees themselves.
    final slot = SaveService.instance.active;
    if (slot >= 0) await lb.submit(slot, h);
    try {
      final rows = await lb.top(_board);
      final place = lb.hidden ? null : await lb.placeOf(_board, _mine(_board));
      if (!mounted || req != _req) return;
      setState(() {
        _rows = rows;
        _place = place;
      });
    } catch (e) {
      if (!mounted || req != _req) return;
      setState(() => _error = 'Không tải được bảng xếp hạng, thử lại sau.');
    }
  }

  @override
  Widget build(BuildContext context) {
    const names = {
      LbBoard.power: 'Lực chiến',
      LbBoard.tower: 'Tháp Thử Luyện',
      LbBoard.rank: 'Cấp độ',
      LbBoard.arena: 'Lôi đài',
    };
    return SubScreen(
      title: 'Xếp hạng',
      actions: [
        for (final b in LbBoard.values)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () {
                if (_board == b) return;
                setState(() => _board = b);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _board == b ? seal : lacquer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _board == b ? goldLight : gold.withValues(alpha: 0.5)),
                ),
                child: Text(names[b]!, style: bold.copyWith(fontSize: 13)),
              ),
            ),
          ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Panel(padding: const EdgeInsets.all(8), child: _list())),
          const SizedBox(width: 10),
          SizedBox(width: 240, child: _mePanel()),
        ],
      ),
    );
  }

  Widget _list() {
    if (!lb.available) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đăng nhập để xem và lên bảng xếp hạng', style: bold.copyWith(color: cream)),
            const SizedBox(height: 6),
            Text('Bảng xếp hạng dùng chung tài khoản với lưu trữ đám mây.', style: small),
            const SizedBox(height: 12),
            if (CloudSave.instance.available)
              LButton(label: 'Đăng nhập', color: jade, onTap: () => showCloudPanel(context)),
          ],
        ),
      );
    }
    if (_error != null) return Center(child: Text(_error!, style: body));
    final rows = _rows;
    if (rows == null) return const Center(child: CircularProgressIndicator(color: goldLight));
    if (rows.isEmpty) return Center(child: Text('Chưa có ai trên bảng. Hãy là người đầu tiên!', style: body));
    final me = lb.myUid;
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) => _row(i + 1, rows[i], me != null && rows[i].id.startsWith('${me}_')),
    );
  }

  Widget _row(int place, LbEntry e, bool mine) {
    final hn = Hanh.values[e.hanh];
    final medal = place <= 3 ? const [Color(0xFFFFD34A), Color(0xFFD8DEE4), Color(0xFFD08A4A)][place - 1] : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: mine ? Color.lerp(lacquer, seal, 0.35) : lacquerDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: mine ? goldLight : (medal ?? gold.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('$place',
                textAlign: TextAlign.center, style: titleStyle(place <= 3 ? 20 : 16, color: medal ?? cream)),
          ),
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: hanhColor(hn), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: bold.copyWith(fontSize: 14, color: cream), overflow: TextOverflow.ellipsis),
                Text(
                  '${sectOf(hn).name} · Cấp ${e.level}${e.rebirths > 0 ? ' · Chuyển sinh ${e.rebirths}' : ''}'
                  '${e.title.isNotEmpty ? ' · « ${e.title} »' : ''}',
                  style: small.copyWith(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(_value(e), style: titleStyle(17, color: goldLight)),
        ],
      ),
    );
  }

  String _value(LbEntry e) => switch (_board) {
        LbBoard.power => fmt(e.power),
        LbBoard.tower => 'Tầng ${e.tower}',
        LbBoard.rank => e.rebirths > 0 ? 'CS${e.rebirths} · ${e.level}' : 'Cấp ${e.level}',
        LbBoard.arena => '${e.arenaS % 100000} điểm',
      };

  Widget _mePanel() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(h.name, style: titleStyle(18, color: cream), overflow: TextOverflow.ellipsis),
          Text('${h.sect.name} · Cấp ${h.level}', style: small.copyWith(color: hanhColor(h.hanh))),
          const SizedBox(height: 8),
          _stat('Lực chiến', fmt(h.power)),
          _stat('Tháp Thử Luyện', 'Tầng ${h.towerBest}'),
          _stat('Chuyển sinh', '${h.rebirths}'),
          _stat('Lôi đài', '${h.arenaPoints} điểm'),
          const SizedBox(height: 8),
          if (lb.available && !lb.hidden)
            Text(
                _board == LbBoard.arena && arenaBoardValue(h) == 0
                    ? 'Đấu một trận Lôi đài mùa này để lên bảng'
                    : (_place == null ? 'Đang tính hạng…' : 'Hạng của bạn: #$_place'),
                style: titleStyle(_board == LbBoard.arena && arenaBoardValue(h) == 0 ? 14 : 17, color: goldLight)),
          const Spacer(),
          if (lb.available)
            Row(
              children: [
                Expanded(child: Text('Ẩn tôi khỏi bảng', style: small.copyWith(color: cream))),
                Switch(
                  value: lb.hidden,
                  activeThumbColor: goldLight,
                  onChanged: (v) async {
                    await lb.setHidden(v);
                    _load();
                  },
                ),
              ],
            ),
          Text('Bảng hiện tên nhân vật, môn phái, cấp, lực chiến, tầng tháp và điểm Lôi đài.',
              style: small.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _stat(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Expanded(child: Text(k, style: body.copyWith(fontSize: 13))),
            Text(v, style: bold.copyWith(fontSize: 14, color: cream)),
          ],
        ),
      );
}

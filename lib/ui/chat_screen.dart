import 'dart:async';

import 'package:flutter/material.dart';

import '../core/chat.dart';
import '../core/hanh.dart';
import '../core/sects.dart';
import '../services/chat.dart';
import '../services/cloud.dart';
import '../services/save.dart';
import 'cloud_panel.dart';
import 'sub_screen.dart';
import 'theme.dart';
import '../core/i18n.dart';
import '../core/quick_chat.dart';
import 'quick_chat_button.dart';

/// Kênh Thế Giới: the last hundred messages of every player, one message
/// per ten minutes each.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.embedded = false, this.onClose});

  /// 1.13.3: a side panel over the battle (PlayScreen), so players can chat
  /// while the fight goes on; [onClose] hides it.
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  Timer? _tick;
  bool _sending = false;

  ChatService get chat => ChatService.instance;

  @override
  void initState() {
    super.initState();
    chat.addListener(_changed);
    CloudSave.instance.addListener(_changed);
    chat.open();
    // The countdown on the send button.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && chat.wait > Duration.zero) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    chat.removeListener(_changed);
    CloudSave.instance.removeListener(_changed);
    chat.close();
    _input.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _toast(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  /// Sends what is typed, or a quick line ([text]) leaving the draft alone.
  Future<void> _send({String? text}) async {
    if (_sending) return;
    if (!chat.rulesAccepted && !await _showRules(ask: true)) return;
    setState(() => _sending = true);
    final err = await chat.send(SaveService.instance.hero, text ?? _input.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      _toast(err);
    } else {
      if (text == null) _input.clear();
      FocusScope.of(context).unfocus();
    }
  }

  /// The channel's rules; with [ask], true once the player agrees.
  Future<bool> _showRules({bool ask = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text(tr('Quy tắc Kênh Thế Giới'), style: titleStyle(18)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Text(
              tr('• Mọi người chơi đều đọc được tin của bạn, kèm tên nhân vật, môn phái và cấp.\n'
              '• Mỗi người gửi một tin mỗi {inMinutes} phút, tối đa {chatMaxLen} chữ.\n'
              '• Không chửi bới, xúc phạm, quấy rối, phân biệt, nội dung người lớn, lừa đảo, '
              'quảng cáo hay để lộ thông tin cá nhân. Từ tục bị tự động che.\n'
              '• Chạm vào tin của người khác để Báo cáo hoặc Chặn. Tài khoản vi phạm sẽ bị cấm chat '
              'và tin bị xoá.\n'
              '• Tin cũ tự xoá sau {inDays} ngày.', {'inMinutes': chatCooldown.inMinutes, 'chatMaxLen': chatMaxLen, 'inDays': chatKeep.inDays}),
              style: body.copyWith(fontSize: 13),
            ),
          ),
        ),
        actions: [
          if (ask) TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Để sau'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ask ? tr('Đồng ý') : tr('Đóng'))),
        ],
      ),
    );
    if (ask && ok == true) await chat.acceptRules();
    return ok == true;
  }

  Future<void> _actions(ChatMsg m) async {
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: lacquer,
        title: Text(m.name, style: titleStyle(18, color: cream)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'report'),
            child: Row(children: [
              const Icon(Icons.flag, color: Color(0xFFF07A6A)),
              const SizedBox(width: 10),
              Text(tr('Báo cáo tin này'), style: body),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'block'),
            child: Row(children: [
              const Icon(Icons.block, color: creamDim),
              const SizedBox(width: 10),
              Text(tr('Chặn người này (ẩn mọi tin của họ)'), style: body),
            ]),
          ),
        ],
      ),
    );
    if (pick == 'report') {
      await chat.report(m);
      _toast(tr('Đã báo cáo, cảm ơn bạn. Tin đã được ẩn.'));
    } else if (pick == 'block') {
      await chat.block(m.uid);
      _toast(tr('Đã chặn {mName}', {'mName': m.name}));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Panel(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.forum, color: goldLight, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(tr('Kênh Thế Giới'), style: titleStyle(16, color: cream))),
                if (chat.wait > Duration.zero)
                  Text(tr('Gửi sau {p0}', {'p0': chatWaitLabel(chat.wait)}), style: small.copyWith(fontSize: 11, color: goldLight)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('Đóng'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: cream),
                ),
              ],
            ),
            Expanded(child: _list()),
            const SizedBox(height: 6),
            _inputRow(),
          ],
        ),
      );
    }
    return SubScreen(
      title: tr('Kênh Thế Giới'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Panel(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _list()),
                  const SizedBox(height: 6),
                  _inputRow(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 220, child: _side()),
        ],
      ),
    );
  }

  Widget _list() {
    if (!chat.available) {
      return Center(child: Text(tr('Kênh chat cần kết nối mạng.'), style: body));
    }
    if (chat.error != null) return Center(child: Text(chat.error!, style: body));
    final rows = chat.visible;
    if (chat.loading && rows.isEmpty) return const Center(child: CircularProgressIndicator(color: goldLight));
    if (rows.isEmpty) return Center(child: Text(tr('Chưa có tin nào. Chào giang hồ một câu!'), style: body));
    final me = chat.myUid;
    // Reversed so it opens at the newest and new lines push up from below.
    return ListView.builder(
      reverse: true,
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final m = rows[rows.length - 1 - i];
        return _row(m, m.uid == me);
      },
    );
  }

  String _time(int at) {
    final t = DateTime.fromMillisecondsSinceEpoch(at);
    final n = DateTime.now();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == n.year && t.month == n.month && t.day == n.day) return hm;
    return '${t.day}/${t.month} $hm';
  }

  Widget _row(ChatMsg m, bool mine) {
    final hn = Hanh.values[m.hanh];
    return GestureDetector(
      onTap: mine ? null : () => _actions(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: mine ? Color.lerp(lacquer, seal, 0.3) : lacquerDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: mine ? goldLight.withValues(alpha: 0.6) : gold.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: m.name, style: bold.copyWith(fontSize: 13, color: hanhColor(hn))),
                      TextSpan(
                        text: tr('  {p0} · {p1}Cấp {level}', {'p0': tr(sectOf(hn).name), 'p1': m.rebirths > 0 ? tr('CS{rebirths} · ', {'rebirths': m.rebirths}) : '', 'level': m.level}),
                        style: small.copyWith(fontSize: 10.5),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(_time(m.at), style: small.copyWith(fontSize: 10.5)),
              ],
            ),
            Text(chatShow(m.text), style: body.copyWith(fontSize: 13.5)),
          ],
        ),
      ),
    );
  }

  Widget _inputRow() {
    if (!chat.canSend) {
      return Row(
        children: [
          Expanded(child: Text(tr('Đăng nhập để gửi tin (dùng chung tài khoản lưu đám mây).'), style: small)),
          if (CloudSave.instance.available)
            LButton(label: tr('Đăng nhập'), small: true, color: jade, onTap: () => showCloudPanel(context)),
        ],
      );
    }
    if (chat.banned) {
      return Text(tr('Tài khoản của bạn đã bị cấm chat.'), style: small.copyWith(color: const Color(0xFFF07A6A)));
    }
    final w = chat.wait;
    return Row(
      children: [
        QuickChatButton(
          input: _input,
          onPhrase: (p) => _send(text: p),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _input,
            maxLength: chatMaxLen,
            style: body,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: w > Duration.zero ? tr('Soạn sẵn, gửi được sau {p0}', {'p0': chatWaitLabel(w)}) : tr('Nói gì đó với giang hồ…'),
              hintStyle: small,
              filled: true,
              fillColor: lacquerDeep,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: gold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        LButton(
          label: w > Duration.zero ? chatWaitLabel(w) : tr('Gửi'),
          icon: w > Duration.zero ? Icons.hourglass_bottom : Icons.send,
          small: true,
          width: 96,
          color: jade,
          enabled: !_sending && w == Duration.zero,
          onTap: _send,
        ),
      ],
    );
  }

  Widget _side() {
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.forum, color: goldLight, size: 22),
              const SizedBox(width: 8),
              Text(tr('Kênh chung'), style: titleStyle(17, color: cream)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr('Mỗi người {inMinutes} phút một tin. Hiện {chatShown} tin gần nhất. '
            'Chạm vào tin của người khác để báo cáo hoặc chặn.', {'inMinutes': chatCooldown.inMinutes, 'chatShown': chatShown}),
            style: small.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          if (chat.wait > Duration.zero)
            Text(tr('Gửi tiếp sau {p0}', {'p0': chatWaitLabel(chat.wait)}), style: titleStyle(15, color: goldLight)),
          const Spacer(),
          if (chat.blocked.isNotEmpty)
            TextButton(
              onPressed: chat.unblockAll,
              child: Text(tr('Bỏ chặn {blockedLength} người', {'blockedLength': chat.blocked.length}), style: small.copyWith(color: goldLight)),
            ),
          TextButton(
            onPressed: _showRules,
            child: Text(tr('Quy tắc kênh chat'), style: small.copyWith(color: goldLight)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/quick_chat.dart';
import 'theme.dart';

/// The smiley next to a chat box (1.24.0): emotes go into [input], a quick
/// line is sent at once through [onPhrase] (as its Vietnamese text, shown to
/// each reader in their language).
class QuickChatButton extends StatelessWidget {
  const QuickChatButton({super.key, required this.input, required this.onPhrase, this.size = 40});
  final TextEditingController input;
  final void Function(String phrase) onPhrase;
  final double size;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: lacquerDeep,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('Chat nhanh'), style: titleStyle(17)),
                const SizedBox(height: 2),
                Text(tr('Câu chat nhanh hiện bằng ngôn ngữ của người đọc.'), style: small),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final e in quickEmotes)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(ctx, '\u0000$e'),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in quickPhrases)
                      ActionChip(
                        label: Text(tr(p), style: body.copyWith(fontSize: 13)),
                        backgroundColor: lacquer,
                        side: const BorderSide(color: gold),
                        onPressed: () => Navigator.pop(ctx, p),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;
    if (picked.startsWith('\u0000')) {
      // An emote: added where the caret is.
      final e = picked.substring(1);
      final v = input.value;
      final at = v.selection.isValid ? v.selection.baseOffset : v.text.length;
      final text = v.text.replaceRange(at, at, e);
      input.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at + e.length));
    } else {
      onPhrase(picked);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Material(
          color: lacquerDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: gold)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _open(context),
            child: Icon(Icons.emoji_emotions_outlined, color: goldLight, size: size * 0.6),
          ),
        ),
      );
}

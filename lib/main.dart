import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/newbie.dart';

import 'services/ads.dart';
import 'services/chat.dart';
import 'services/cloud.dart';
import 'services/leaderboard.dart';
import 'services/notify.dart';
import 'services/perf.dart';
import 'services/presence.dart';
import 'services/purchase.dart';
import 'services/save.dart';
import 'services/sound.dart';
import 'ui/theme.dart';
import 'ui/title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The joystick and skill pad are laid out for a wide screen.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Not awaited: a slow or broken audio asset must never delay the first frame.
  SoundService.instance.init();
  await LiteMode.instance.load();
  await ViewRange.instance.load();
  await SaveService.instance.load();
  await Leaderboard.instance.load();
  await ChatService.instance.load();
  // Not awaited: reminders are a nicety.
  NotifyService.instance.init();
  // Not awaited either: the game starts offline and syncs when it can.
  CloudSave.instance.init();
  // App Open ads skip new players, as interstitials do.
  AdsService.instance.appOpenAllowed = () {
    final s = SaveService.instance;
    final h = s.active >= 0 ? s.slots[s.active] : null;
    return h != null && !newbieAdFree(h.level, h.rebirths);
  };
  AdsService.instance.init();
  PurchaseService.instance.init();
  await Presence.instance.init();
  Presence.instance.lostSlot.addListener(_onHeroTakenOver);
  runApp(const KiemHiepApp());
}

/// Another phone opened the hero played here (1.8.1): tell the player, who
/// goes back to the hero list; nothing more is uploaded from this phone.
void _onHeroTakenOver() {
  final slot = Presence.instance.lostSlot.value;
  if (slot == null) return;
  // This phone's copy now counts as the older one: the next sync asks
  // before it could replace the other phone's progress.
  final h = SaveService.instance.slots[slot];
  if (h != null) {
    h.savedAt = 1;
    SaveService.instance.writeSlot(slot);
  }
  final ctx = AdsService.navigatorKey.currentContext;
  if (ctx == null) return;
  showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      backgroundColor: lacquer,
      title: Text('Đang chơi trên máy khác', style: titleStyle(20)),
      content: Text(
        'Nhân vật này vừa được mở trên một điện thoại khác cùng tài khoản. '
        'Để hai máy không ghi đè tiến trình của nhau, máy này sẽ ngừng lưu lên mây và quay về màn hình chọn nhân vật.',
        style: body,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(d).pop();
            AdsService.navigatorKey.currentState
                ?.pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const TitleScreen()), (_) => false);
          },
          child: const Text('Về chọn nhân vật'),
        ),
      ],
    ),
  );
}

class KiemHiepApp extends StatelessWidget {
  const KiemHiepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AdsService.navigatorKey,
      title: gameTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Every screen is laid out for a landscape phone at the normal text
      // size; a large system font size overflows the town grid, the HUD and
      // the dialogs, so it is capped a little above normal.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.1)),
          child: child!,
        );
      },
      home: const TitleScreen(),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/reminders.dart';
import 'save.dart';

/// Reminders on the phone itself (no server): set when the game goes to
/// the background, cleared when it comes back, so none ever shows while
/// playing. The player can turn them off in town.
class NotifyService extends ChangeNotifier {
  NotifyService._();
  static final NotifyService instance = NotifyService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = true;
  bool _asked = false;
  AppLifecycleListener? _life;

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool('notify_on') ?? true;
      _asked = prefs.getBool('notify_asked') ?? false;
    } catch (_) {}
    if (!_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
          // Asked for later, at a better moment than the first launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
      await _plugin.cancelAll();
      _life ??= AppLifecycleListener(onPause: _schedule, onHide: _schedule, onResume: _clear);
    } catch (e) {
      debugPrint('notifications off: $e');
    }
  }

  /// Asks the system once (Android 13+, iOS), when the player has played a
  /// little and is back in town.
  Future<void> askOnce() async {
    if (!_ready || _asked || !enabled) return;
    _asked = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notify_asked', true);
    } catch (_) {}
    await _requestPermission();
  }

  Future<bool> _requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('notification permission: $e');
    }
    return false;
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notify_on', v);
    } catch (_) {}
    if (v) {
      await _requestPermission();
    } else {
      await _clear();
    }
  }

  Future<void> _clear() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Nhắc nhở',
      channelDescription: 'Bế quan đầy, quà mới và lời nhắc trở lại giang hồ',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _schedule() async {
    if (!_ready || !enabled) return;
    final save = SaveService.instance;
    if (save.active < 0 || save.slots[save.active] == null) return;
    final h = save.hero;
    final now = DateTime.now().toUtc();
    try {
      await _plugin.cancelAll();
      for (final r in reminderPlan(h, now, newbieWaiting: h.newbieOpen)) {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
        );
      }
    } catch (e) {
      debugPrint('reminders not set: $e');
    }
  }
}

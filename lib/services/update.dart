import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../core/version.dart';
import '../core/world_boss.dart' show vnDayKey;
import '../ui/theme.dart';
import 'analytics.dart';
import 'cloud.dart';
import 'save.dart';
import '../core/i18n.dart';

/// Cập nhật trong game (Android): asks Google Play whether a newer build
/// is out and offers it, downloading in the background. The oldest version
/// still allowed to play is `min` in the Firestore document `config/app`
/// (written by hand in the console); below it the update is required.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  bool _checked = false;

  Future<void> check(BuildContext context) async {
    if (_checked || kIsWeb || !Platform.isAndroid) return;
    _checked = true;
    // Read first and on its own (1.16.2): before, `min` was only read once
    // Play said a newer build was out, which lags a day or more, and the
    // Play sheet could be closed to keep playing.
    final min = await _minVersion();
    AppUpdateInfo? info;
    try {
      info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 8));
    } catch (e) {
      // Not installed from Play (a sideloaded or debug build), or offline.
      debugPrint('update check: $e');
    }
    if (mustUpdate(appVersion, min)) {
      if (context.mounted) await _block(context, info);
      return;
    }
    if (info == null) return;
    final available = info.updateAvailability == UpdateAvailability.updateAvailable;
    if (!available) return;
    final prefs = await SharedPreferences.getInstance();
    final today = vnDayKey();
    final plan = updatePlan(
      available: true,
      current: appVersion,
      min: min,
      snoozedToday: prefs.getString('update_snooze') == today,
    );
    if (plan == UpdatePlan.none || !context.mounted) return;
    Analytics.instance.log('update_prompt', {'force': plan == UpdatePlan.force ? 1 : 0});
    if (plan == UpdatePlan.force && info.immediateUpdateAllowed) {
      await SaveService.instance.save();
      try {
        await InAppUpdate.performImmediateUpdate();
      } catch (e) {
        debugPrint('immediate update: $e');
      }
      return;
    }
    if (!info.flexibleUpdateAllowed && !info.immediateUpdateAllowed) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: lacquer,
        title: Text(tr('Có bản cập nhật mới'), style: titleStyle(20)),
        content: Text(
          tr('Bản mới có thêm tính năng và sửa lỗi (bảng xếp hạng, lưu trữ đám mây). '
          'Tải ngầm, vẫn chơi được trong lúc tải; xong sẽ khởi động lại game, nhân vật được giữ nguyên.'),
          style: body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Để mai'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Cập nhật'))),
        ],
      ),
    );
    if (yes != true) {
      await prefs.setString('update_snooze', today);
      return;
    }
    try {
      if (info.flexibleUpdateAllowed) {
        final r = await InAppUpdate.startFlexibleUpdate();
        if (r != AppUpdateResult.success) return;
        // Downloaded: save, then let Play install and restart the game.
        await SaveService.instance.save();
        await InAppUpdate.completeFlexibleUpdate();
      } else {
        await SaveService.instance.save();
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint('update: $e');
    }
  }

  static const _store = MethodChannel('kh/screen');

  /// Bắt buộc cập nhật (1.16.2): this version is below `min`, so the title
  /// screen is covered by a dialog that Back and taps outside cannot close.
  /// "Cập nhật" runs Play's update when Play already knows of it, otherwise
  /// opens the game's Play page; coming back without updating stays here.
  Future<void> _block(BuildContext context, AppUpdateInfo? info) async {
    Analytics.instance.log('update_prompt', {'force': 1, 'hard': 1});
    await SaveService.instance.save();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: lacquer,
          title: Text(tr('Cần cập nhật'), style: titleStyle(20)),
          content: Text(
            tr('Phiên bản {appVersion} đã cũ. Hãy cập nhật bản mới trên Google Play để tiếp tục chơi. '
            'Nhân vật và đồ đạc được giữ nguyên.', {'appVersion': appVersion}),
            style: body,
          ),
          actions: [
            TextButton(onPressed: () => _updateNow(info), child: Text(tr('Cập nhật'))),
          ],
        ),
      ),
    );
  }

  Future<void> _updateNow(AppUpdateInfo? first) async {
    var info = first;
    try {
      // Play may have learned of the build since the game started.
      info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (info != null &&
        info.updateAvailability == UpdateAvailability.updateAvailable &&
        info.immediateUpdateAllowed) {
      try {
        // Restarts the game when done; closing Play's sheet returns here.
        await InAppUpdate.performImmediateUpdate();
        return;
      } catch (e) {
        debugPrint('immediate update: $e');
      }
    }
    try {
      await _store.invokeMethod<bool>('openStore');
    } catch (e) {
      debugPrint('open store: $e');
    }
  }

  Future<String?> _minVersion() async {
    if (!CloudSave.instance.available) return null;
    try {
      final doc = await FirebaseFirestore.instance.doc('config/app').get().timeout(const Duration(seconds: 6));
      final v = doc.data()?['min'];
      return v is String ? v : null;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../core/festival.dart';
import '../core/premium.dart';
import '../core/pass_extras.dart';
import '../core/world_boss.dart';
import 'ads.dart';
import 'analytics.dart';
import 'cloud.dart';
import 'play_verify.dart';
import 'save.dart';
import '../core/i18n.dart';

/// One line of the purchase history.
class PurchaseLog {
  const PurchaseLog(this.sku, this.order, this.hero, this.at);
  final String sku, order, hero;
  final DateTime at;

  String get product => switch (sku) {
        skuMonthCard => tr('Nguyệt thẻ'),
        skuStarter => tr('Gói tân thủ'),
        skuNoAds => tr('Bỏ quảng cáo'),
        skuStarPack => tr('Gói Thăng Tinh'),
        skuPass => tr('Lệnh Bài Hào Kiệt'),
        skuFest => tr('Gói lễ hội'),
        skuGoldPack => tr('Hòm Ngân Lượng'),
        _ => sku,
      };

  static PurchaseLog? parse(String s) {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return PurchaseLog(m['sku'] as String, m['order'] as String? ?? '', m['hero'] as String? ?? '',
          DateTime.fromMillisecondsSinceEpoch(m['at'] as int));
    } catch (_) {
      return null;
    }
  }
}

/// Google Play / App Store purchases (1.7.0): Nguyệt thẻ and Gói tân thủ
/// are consumables for the hero playing when bought; Gói bỏ quảng cáo is
/// a non-consumable for the store account, restored on every start.
///
/// No server checks the receipts, but since 1.16.1 every Android purchase's
/// Play signature is checked on the phone ([PlayVerifier]): faked ones are
/// refused. Every delivery is remembered by purchase id so a replayed one
/// is never granted twice.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  final Map<String, ProductDetails> products = {};
  bool available = false;

  /// Bumped on every change, for the shop to rebuild.
  final ValueNotifier<int> changed = ValueNotifier(0);

  /// The last thing to tell the player ("Đã nhận Nguyệt thẻ"…), or an error.
  final ValueNotifier<String?> message = ValueNotifier(null);

  /// A purchase is in flight (the store sheet is open or pending).
  final ValueNotifier<bool> busy = ValueNotifier(false);

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Set<String> _done = {};

  /// Consumables bought with no hero open yet (on the title screen), given
  /// to the next hero that reaches town.
  final List<String> _queue = [];

  static const _doneKey = 'iap_done';
  static const _queueKey = 'iap_queue';

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _done.addAll(p.getStringList(_doneKey) ?? const []);
      _queue.addAll(p.getStringList(_queueKey) ?? const []);
    } catch (_) {}
    if (!_supported) return;
    try {
      final iap = InAppPurchase.instance;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (Object e) => debugPrint('iap stream: $e'));
      available = await iap.isAvailable();
      if (!available) return;
      final r = await iap.queryProductDetails(allSkus);
      for (final d in r.productDetails) {
        products[d.id] = d;
      }
      changed.value++;
      // Brings back Gói bỏ quảng cáo after a reinstall or on a new phone.
      await iap.restorePurchases();
      await _recheckAdFree();
    } catch (e) {
      debugPrint('iap off: $e');
    }
  }

  /// Play's signing key, or null when none is compiled in (then nothing is
  /// rejected, as before 1.16.1).
  static final PlayVerifier? _verifier = PlayVerifier.fromBase64(playLicenseKey);

  /// False for an Android purchase whose signature is not Google's: a
  /// faked one. iOS purchases come from StoreKit and pass.
  static bool genuine(PurchaseDetails p) => rejectReason(p) == null;

  /// Why [p] is refused (1.16.2, sent with `iap_bad`): 'nosig' (no
  /// signature at all), 'sku' (signed data names another product), 'sig'
  /// (signature is not Google's); null when it is fine.
  static String? rejectReason(PurchaseDetails p) {
    if (p is! GooglePlayPurchaseDetails) return null;
    final v = _verifier;
    if (v == null) return null;
    final w = p.billingClientPurchase;
    if (w.signature.trim().isEmpty) return 'nosig';
    if (!w.products.contains(p.productID)) return 'sku';
    return v.verify(w.originalJson, w.signature) ? null : 'sig';
  }

  /// Settings → Khôi phục giao dịch (1.16.2): asks the store again, gives
  /// back Gói bỏ quảng cáo when this Play account genuinely owns it, and
  /// re-delivers any purchase left unfinished. The line to show.
  Future<String> restoreNow() async {
    if (!_supported) return tr('Chỉ khôi phục được trên điện thoại.');
    if (!available) return tr('Không kết nối được cửa hàng. Kiểm tra mạng và tài khoản cửa hàng rồi thử lại.');
    try {
      // Unfinished consumables come back through the stream; ids already
      // given are skipped there.
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('restore: $e');
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return tr('Đã gửi yêu cầu khôi phục tới App Store.');
    }
    try {
      final add = InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final r = await add.queryPastPurchases();
      if (r.error != null) return tr('Google Play chưa trả lời. Thử lại sau ít phút.');
      final owns = r.pastPurchases.any((p) =>
          p.productID == skuNoAds &&
          p.billingClientPurchase.purchaseState == PurchaseStateWrapper.purchased &&
          genuine(p));
      Analytics.instance.log('iap_restore', {'noads': owns ? 1 : 0, 'v': appVersion});
      if (owns) {
        AdsService.instance.setAdFree(true);
        changed.value++;
        return tr('Đã khôi phục Gói bỏ quảng cáo.');
      }
      return tr('Tài khoản Google Play đang dùng trên máy này chưa mua Gói bỏ quảng cáo. '
          'Nếu bạn mua bằng tài khoản khác, hãy chuyển sang tài khoản đó trong Play Store rồi thử lại. '
          'Các gói khác đã vào nhân vật ngay lúc mua (xem Lịch sử nạp).');
    } catch (e) {
      return tr('Không khôi phục được: {e}', {'e': e});
    }
  }

  /// Turns Gói bỏ quảng cáo off on a phone whose Play account does not own
  /// a genuinely signed one (1.16.1): it was unlocked by a fake purchase,
  /// or refunded. Only on a clean answer from Play — any error keeps it.
  Future<void> _recheckAdFree() async {
    if (_verifier == null || defaultTargetPlatform != TargetPlatform.android) return;
    if (!AdsService.instance.adFree.value) return;
    try {
      final add = InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final r = await add.queryPastPurchases();
      if (r.error != null) return;
      final owns = r.pastPurchases.any((p) =>
          p.productID == skuNoAds &&
          p.billingClientPurchase.purchaseState == PurchaseStateWrapper.purchased &&
          genuine(p));
      if (!owns) {
        AdsService.instance.setAdFree(false);
        Analytics.instance.log('ad_free_revoked');
        changed.value++;
      }
    } catch (e) {
      debugPrint('iap recheck: $e');
    }
  }

  void dispose() => _sub?.cancel();

  String? priceOf(String sku) => products[sku]?.price;

  Future<void> buy(String sku) async {
    final d = products[sku];
    if (d == null || busy.value) return;
    busy.value = true;
    Analytics.instance.log('iap_start', {'sku': sku});
    try {
      final param = PurchaseParam(productDetails: d);
      final ok = sku == skuNoAds
          ? await InAppPurchase.instance.buyNonConsumable(purchaseParam: param)
          : await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      if (!ok) busy.value = false;
    } catch (e) {
      busy.value = false;
      message.value = tr('Không mở được cửa hàng: {e}', {'e': e});
    }
  }

  Future<void> restore() async {
    if (!available) return;
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          busy.value = true;
          message.value = tr('Giao dịch đang chờ xác nhận…');
        case PurchaseStatus.error:
          busy.value = false;
          message.value = tr('Giao dịch lỗi: {p0}', {'p0': p.error?.message ?? tr('không rõ')});
        case PurchaseStatus.canceled:
          busy.value = false;
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          busy.value = false;
          final why = rejectReason(p);
          if (why == null) {
            await _deliver(p);
          } else {
            Analytics.instance.log('iap_bad', {'sku': p.productID, 'why': why, 'v': appVersion});
            message.value = tr('Giao dịch không hợp lệ: Google Play không xác nhận giao dịch này.');
          }
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (e) {
          debugPrint('iap complete: $e');
        }
      }
    }
    changed.value++;
  }

  Future<void> _deliver(PurchaseDetails p) async {
    if (p.productID == skuNoAds) {
      // Restored every start; granting again is harmless.
      AdsService.instance.setAdFree(true);
      if (p.status == PurchaseStatus.purchased) {
        message.value = tr('Đã bỏ quảng cáo! Phần thưởng quảng cáo nay nhận ngay, không cần xem.');
        Analytics.instance.log('iap_done', {'sku': p.productID, 'v': appVersion});
        await _addLog(p.productID, p.purchaseID ?? '', tr('Cả tài khoản'));
      }
      return;
    }
    final id = p.purchaseID ?? base64Encode(utf8.encode(p.verificationData.serverVerificationData)).substring(0, 40);
    if (_done.contains(id)) return;
    _done.add(id);
    Analytics.instance.log('iap_done', {'sku': p.productID, 'v': appVersion});
    final save = SaveService.instance;
    if (save.active >= 0 && save.slots[save.active] != null) {
      message.value = grant(p.productID, id: id);
      await _addLog(p.productID, p.purchaseID ?? '', save.hero.name);
    } else {
      _queue.add(p.productID);
      message.value = tr('Đã mua! Quà sẽ vào nhân vật bạn chọn tiếp theo.');
      await _addLog(p.productID, p.purchaseID ?? '', tr('Nhân vật vào thành tiếp theo'));
    }
    await _persist();
  }

  // ------------------------------------------------------------ nhật ký

  static const _logKey = 'iap_log';

  /// Purchases made on this phone, newest first (1.8.1): what, when, which
  /// hero got it and the store's order id, to settle a "my purchase is
  /// gone" with the order list in Play Console.
  Future<List<PurchaseLog>> history() async {
    try {
      final p = await SharedPreferences.getInstance();
      return [
        for (final s in (p.getStringList(_logKey) ?? const <String>[]).reversed) ?PurchaseLog.parse(s),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _addLog(String sku, String order, String hero) async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_logKey) ?? <String>[];
      list.add(jsonEncode({'sku': sku, 'order': order, 'hero': hero, 'at': DateTime.now().millisecondsSinceEpoch}));
      // The last hundred are plenty.
      await p.setStringList(_logKey, list.length > 100 ? list.sublist(list.length - 100) : list);
    } catch (e) {
      debugPrint('iap log: $e');
    }
  }

  /// Gives [sku] to the open hero; the line to show.
  String grant(String sku, {String? id}) {
    final h = SaveService.instance.hero;
    final String text;
    switch (sku) {
      case skuMonthCard:
        h.addMonthCard(vnDayKey());
        text = tr('Đã kích hoạt Nguyệt thẻ cho {hName}: {p0} ngày.', {'hName': h.name, 'p0': h.cardDaysLeft(vnDayKey())});
      case skuStarter:
        text = tr('Gói tân thủ cho {hName}: {p0}', {'hName': h.name, 'p0': h.grantStarter().join(', ')});
      case skuStarPack:
        text = tr('Gói Thăng Tinh cho {hName}: {p0}', {'hName': h.name, 'p0': h.grantStarPack().join(', ')});
      case skuGoldPack:
        text = tr('Hòm Ngân Lượng cho {hName}: {p0}', {'hName': h.name, 'p0': h.grantGoldPack().join(', ')});
      case skuFest:
        text = tr('Gói lễ hội cho {hName}: {p0}', {'hName': h.name, 'p0': h.grantFestPack().join(', ')});
      case skuPass:
        h.grantPass(vnDayKey());
        text = tr('Đã mở Lệnh Bài Hào Kiệt mùa {passSeason} cho {hName}. Nhận thưởng trong Lệnh Bài.', {'passSeason': h.passSeason, 'hName': h.name});
      default:
        return '';
    }
    h.paidFlag = true;
    SaveService.instance.save();
    // Remembered in the cloud, so another phone's older save cannot lose it.
    CloudSave.instance.recordGrant(
      id ?? 'q${DateTime.now().millisecondsSinceEpoch}',
      PaidGrant(sku: sku, seed: h.seed, slot: SaveService.instance.active, until: switch (sku) {
        skuMonthCard => h.cardUntil,
        skuPass => '${h.passSeason}',
        _ => '',
      }),
    );
    changed.value++;
    return text;
  }

  /// Hands anything bought on the title screen to the hero now in town.
  String? applyQueued() {
    if (_queue.isEmpty) return null;
    final lines = [for (final s in _queue) grant(s)];
    _queue.clear();
    _persist();
    return lines.where((l) => l.isNotEmpty).join('\n');
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_doneKey, _done.toList());
      await p.setStringList(_queueKey, _queue);
    } catch (_) {}
  }
}

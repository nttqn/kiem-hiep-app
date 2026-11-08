import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/festival.dart';
import '../core/premium.dart';
import '../core/pass_extras.dart';
import '../core/world_boss.dart';
import 'ads.dart';
import 'analytics.dart';
import 'cloud.dart';
import 'save.dart';

/// One line of the purchase history.
class PurchaseLog {
  const PurchaseLog(this.sku, this.order, this.hero, this.at);
  final String sku, order, hero;
  final DateTime at;

  String get product => switch (sku) {
        skuMonthCard => 'Nguyệt thẻ',
        skuStarter => 'Gói tân thủ',
        skuNoAds => 'Bỏ quảng cáo',
        skuStarPack => 'Gói Thăng Tinh',
        skuPass => 'Lệnh Bài Hào Kiệt',
        skuFest => 'Gói lễ hội',
        skuGoldPack => 'Hòm Ngân Lượng',
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
/// No server checks the receipts: the game is offline and a cheater can
/// already edit their own save. Every delivery is remembered by purchase
/// id so a replayed one is never granted twice.
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
    } catch (e) {
      debugPrint('iap off: $e');
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
      message.value = 'Không mở được cửa hàng: $e';
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
          message.value = 'Giao dịch đang chờ xác nhận…';
        case PurchaseStatus.error:
          busy.value = false;
          message.value = 'Giao dịch lỗi: ${p.error?.message ?? 'không rõ'}';
        case PurchaseStatus.canceled:
          busy.value = false;
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          busy.value = false;
          await _deliver(p);
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
        message.value = 'Đã bỏ quảng cáo! Phần thưởng quảng cáo nay nhận ngay, không cần xem.';
        Analytics.instance.log('iap_done', {'sku': p.productID});
        await _addLog(p.productID, p.purchaseID ?? '', 'Cả tài khoản');
      }
      return;
    }
    final id = p.purchaseID ?? base64Encode(utf8.encode(p.verificationData.serverVerificationData)).substring(0, 40);
    if (_done.contains(id)) return;
    _done.add(id);
    Analytics.instance.log('iap_done', {'sku': p.productID});
    final save = SaveService.instance;
    if (save.active >= 0 && save.slots[save.active] != null) {
      message.value = grant(p.productID, id: id);
      await _addLog(p.productID, p.purchaseID ?? '', save.hero.name);
    } else {
      _queue.add(p.productID);
      message.value = 'Đã mua! Quà sẽ vào nhân vật bạn chọn tiếp theo.';
      await _addLog(p.productID, p.purchaseID ?? '', 'Nhân vật vào thành tiếp theo');
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
        text = 'Đã kích hoạt Nguyệt thẻ cho ${h.name}: ${h.cardDaysLeft(vnDayKey())} ngày.';
      case skuStarter:
        text = 'Gói tân thủ cho ${h.name}: ${h.grantStarter().join(', ')}';
      case skuStarPack:
        text = 'Gói Thăng Tinh cho ${h.name}: ${h.grantStarPack().join(', ')}';
      case skuGoldPack:
        text = 'Hòm Ngân Lượng cho ${h.name}: ${h.grantGoldPack().join(', ')}';
      case skuFest:
        text = 'Gói lễ hội cho ${h.name}: ${h.grantFestPack().join(', ')}';
      case skuPass:
        h.grantPass(vnDayKey());
        text = 'Đã mở Lệnh Bài Hào Kiệt mùa ${h.passSeason} cho ${h.name}. Nhận thưởng trong Lệnh Bài.';
      default:
        return '';
    }
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

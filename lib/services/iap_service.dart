import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/game_config.dart';

/// Google Play Billing wrapper. Listens to the purchase stream, verifies and
/// completes purchases, then routes the grant to a callback the app provides
/// (which credits gems / removes ads / unlocks the battle pass).
///
/// SECURITY: For real money products you should verify purchases server-side
/// (Play Developer API / Firebase Functions) before granting. The hook is
/// [serverVerify]; by default it returns true (client-trust) for demo purposes.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> products = <ProductDetails>[];

  /// Called with the productId of a successfully purchased item.
  void Function(String productId)? onPurchaseGranted;

  Future<bool> Function(PurchaseDetails details) serverVerify =
      (PurchaseDetails _) async => true;

  Future<void> init() async {
    if (!GameConfig.enableIap) return;
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('IAP not available on this device/build.');
      return;
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) => debugPrint('IAP stream error: $e'),
    );
    final ProductDetailsResponse resp =
        await _iap.queryProductDetails(GameConfig.iapProductIds.toSet());
    products = resp.productDetails;
  }

  ProductDetails? product(String id) {
    for (final ProductDetails p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(String productId) async {
    final ProductDetails? p = product(productId);
    if (p == null) return;
    final PurchaseParam param = PurchaseParam(productDetails: p);
    // remove_ads & battle_pass are non-consumable; gems are consumable.
    final bool consumable = productId.startsWith('gems_') || productId == GameConfig.iapStarterPack;
    if (consumable) {
      await _iap.buyConsumable(purchaseParam: param);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> restorePurchases() async => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final bool valid = await serverVerify(purchase);
        if (valid) onPurchaseGranted?.call(purchase.productID);
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() => _sub?.cancel();
}

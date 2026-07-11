import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// in_app_purchase is not supported on web; all methods guard on kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_data_provider.dart';
import 'user_data_manager.dart' show authenticatedPost;

const String _subscriptionId = 'level_up_premium';
// queryProductDetails takes the subscription ID, not the base plan IDs
const Set<String> _productIds = {_subscriptionId};

class PremiumService {
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // Cached after the first query so the sheet never calls queryProductDetails on open
  List<ProductDetails> _cachedProducts = [];
  bool _productsLoaded = false;

  PremiumService(this._ref);

  // Called once at app start: starts the purchase stream and pre-fetches products in the background
  void initialize() {
    if (kIsWeb) return;
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        if (kDebugMode) debugPrint('PremiumService purchase stream error: $e');
      },
    );
    // Pre-fetch off the critical path so the binder call happens in the background, not when the sheet opens
    unawaited(_fetchProducts());
  }

  void dispose() {
    _purchaseSubscription?.cancel();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await InAppPurchase.instance.queryProductDetails(
        _productIds,
      );
      debugPrint(
        'PremiumService: ${response.productDetails.length} products loaded, '
        'notFound=${response.notFoundIDs}, error=${response.error}',
      );
      _cachedProducts = response.productDetails;
      _productsLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('PremiumService _fetchProducts error: $e');
    }
  }

  // Returns cached products immediately; re-fetches only if the initial fetch never completed
  Future<List<ProductDetails>> loadProducts() async {
    if (kIsWeb) return [];
    if (!_productsLoaded) await _fetchProducts();
    return _cachedProducts;
  }

  // Launches the Play Store payment sheet for the given product
  Future<void> subscribe(ProductDetails product) async {
    if (kIsWeb) return;
    final param = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyAndGrant(purchase);
      }

      if (purchase.status != PurchaseStatus.pending) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndGrant(PurchaseDetails purchase) async {
    try {
      final token = purchase.verificationData.serverVerificationData;
      final productId = purchase.productID;
      // Strip the base plan suffix to get the subscription ID
      final subscriptionId = productId.contains(':')
          ? productId.split(':').first
          : productId;

      final response = await authenticatedPost(
        'verify_purchase',
        body: {
          'purchase_token': token,
          'product_id': productId,
          'subscription_id': subscriptionId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final expiresAt = data['premium_expires_at'] != null
            ? DateTime.tryParse(data['premium_expires_at'] as String)?.toLocal()
            : null;
        _ref
            .read(userDataProvider.notifier)
            .patch(
              (u) => u.copyWith(
                isPremium: true,
                premiumExpiresAt: expiresAt,
                shieldCount: 3,
              ),
            );
      } else {
        if (kDebugMode) {
          debugPrint(
            'verify_purchase failed: ${response.statusCode} ${response.body}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PremiumService _verifyAndGrant error: $e');
    }
  }
}

final premiumServiceProvider = Provider<PremiumService>((ref) {
  final service = PremiumService(ref);
  service.initialize();
  ref.onDispose(service.dispose);
  return service;
});

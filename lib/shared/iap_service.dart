import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  /// 상품 ID → 지급할 다이아 수량
  static const Map<String, int> productDiamonds = {
    'diamonds_1200': 1200,
    'diamonds_3500': 3500,
    'diamonds_8000': 8000,
    'diamonds_18000': 18000,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _productDetails = {};
  bool _storeAvailable = false;
  bool _initialized = false;

  /// 다이아가 지급됐을 때 지급량을 emit하는 broadcast 스트림
  final StreamController<int> _diamondsController =
      StreamController<int>.broadcast();
  Stream<int> get onDiamondsGranted => _diamondsController.stream;

  Map<String, ProductDetails> get productDetails =>
      Map.unmodifiable(_productDetails);
  bool get storeAvailable => _storeAvailable;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      debugPrint('[IapService] 스토어 사용 불가');
      return;
    }

    // 구매 업데이트 스트림 구독 (앱 전체 수명 동안 유지)
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) =>
          debugPrint('[IapService] purchaseStream error: $error'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ids = productDiamonds.keys.toSet();
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      debugPrint('[IapService] queryProductDetails error: ${response.error}');
    }
    for (final p in response.productDetails) {
      _productDetails[p.id] = p;
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IapService] 스토어에서 찾지 못한 상품: ${response.notFoundIDs}');
    }
  }

  /// [productId]에 해당하는 상품 구매 플로우 시작
  Future<void> buyProduct(String productId) async {
    if (!_storeAvailable) {
      debugPrint('[IapService] 스토어 사용 불가 - 구매 중단');
      return;
    }
    final product = _productDetails[productId];
    if (product == null) {
      debugPrint('[IapService] 상품 정보 없음: $productId');
      return;
    }
    final param = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> details) async {
    for (final detail in details) {
      switch (detail.status) {
        case PurchaseStatus.pending:
          debugPrint('[IapService] 결제 대기 중: ${detail.productID}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliverProduct(detail);
          break;
        case PurchaseStatus.error:
          debugPrint('[IapService] 결제 오류: ${detail.error}');
          await _iap.completePurchase(detail);
          break;
        case PurchaseStatus.canceled:
          debugPrint('[IapService] 결제 취소: ${detail.productID}');
          await _iap.completePurchase(detail);
          break;
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails detail) async {
    final diamonds = productDiamonds[detail.productID];
    if (diamonds == null) {
      debugPrint('[IapService] 알 수 없는 상품 ID: ${detail.productID}');
      await _iap.completePurchase(detail);
      return;
    }

    AccountProgressRepository? repo;
    try {
      repo = AccountProgressRepository();
      final progress = await repo.load(); // 정적 캐시 hit → 거의 즉시 반환
      progress.diamonds += diamonds;

      // UI 즉시 갱신 (Firestore 저장 완료를 기다리지 않음)
      _diamondsController.add(diamonds);

      // Firestore 저장은 백그라운드에서 처리
      unawaited(repo.save(progress));

      debugPrint('[IapService] 다이아 $diamonds 지급 (${detail.productID})');
    } catch (e, st) {
      // 지급 실패 시 completePurchase 를 호출하지 않아 다음 앱 시작 시 재시도
      debugPrint('[IapService] 다이아 지급 실패: $e\n$st');
      return;
    }

    await _iap.completePurchase(detail);
  }

  void dispose() {
    _purchaseSub?.cancel();
    _diamondsController.close();
  }
}

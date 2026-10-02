import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// notepad.exe PRO: 한 번 결제(비소모성)로 메모 잠금(Face ID)과 아이폰 위젯을 연다.
///
/// App Store Connect / Google Play Console 에 [productId] 로 비소모성 상품을 만들어야 한다.
class ProController extends ChangeNotifier {
  ProController({InAppPurchase? iap}) : _iapOverride = iap;

  static const productId = 'notepad_exe_pro';
  static const _prefsKey = 'notepad_exe_pro_v1';

  final InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  SharedPreferences? _prefs;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Timer? _restoreTimeout;

  bool _unlocked = false;
  bool _devOverride = false;

  /// 스토어에 연결됐는지.
  bool available = false;

  /// 스토어에서 받아온 상품 (가격 표시용). 등록 전이면 null.
  ProductDetails? product;

  /// 결제/복원 진행 중.
  bool busy = false;

  /// 상품을 못 불러온 이유 (구매 화면에 보여준다).
  String? productProblem;

  /// 화면 아래에 보여줄 최근 메시지.
  String? message;
  bool messageIsError = false;

  bool get isPro => _unlocked || _devOverride;

  /// 가격 문자열. 상품을 못 불러왔으면 null.
  String? get price => product?.price;

  /// PRO 는 위젯 · Face ID 잠금이라 지금은 아이폰에서만 판다. (안드로이드에는 PRO 메뉴를 보이지 않는다)
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _unlocked = _prefs!.getBool(_prefsKey) ?? false;
    notifyListeners();
    if (!supported) return;
    // 스토어 연결은 느릴 수 있으니 앱 시작을 막지 않는다.
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => _setMessage('결제 정보를 받지 못했어요. ($e)', error: true),
      );
      available = await _iap.isAvailable();
      if (available) await loadProduct();
    } catch (e) {
      debugPrint('notepad.exe pro: 초기화 실패 ($e)');
      available = false;
    }
    notifyListeners();
  }

  Future<void> loadProduct() async {
    try {
      final res = await _iap.queryProductDetails({productId});
      product = res.productDetails.isEmpty ? null : res.productDetails.first;
      if (product != null) {
        productProblem = null;
      } else if (res.error != null) {
        productProblem = 'App Store 오류: ${res.error!.message} (${res.error!.code})';
      } else {
        productProblem = "App Store 에 '$productId' 상품이 아직 없어요. "
            'App Store Connect 의 앱 내 구입에서 제품 ID 와 상태(제출 준비 완료)를 확인해 주세요.';
      }
      if (product == null) debugPrint('notepad.exe pro: 상품을 찾지 못함 ${res.notFoundIDs} ${res.error}');
    } catch (e) {
      productProblem = '상품 조회 실패: $e';
      debugPrint('notepad.exe pro: 상품 조회 실패 ($e)');
    }
    notifyListeners();
  }

  Future<void> buy() async {
    if (isPro || busy) return;
    if (!available) {
      _setMessage('스토어에 연결할 수 없어요. 인터넷 연결을 확인해 주세요.', error: true);
      return;
    }
    if (product == null) {
      await loadProduct();
      if (product == null) {
        _setMessage('상품 정보를 불러오지 못했어요. ${productProblem ?? '잠시 후 다시 시도해 주세요.'}', error: true);
        return;
      }
    }
    busy = true;
    _setMessage('결제 창을 여는 중...');
    try {
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product!));
    } catch (e) {
      busy = false;
      _setMessage('결제를 시작하지 못했어요. ($e)', error: true);
    }
  }

  Future<void> restore() async {
    if (busy) return;
    if (!available) {
      _setMessage('스토어에 연결할 수 없어요. 인터넷 연결을 확인해 주세요.', error: true);
      return;
    }
    busy = true;
    _setMessage('구매 내역을 확인하는 중...');
    try {
      await _iap.restorePurchases();
    } catch (e) {
      busy = false;
      _setMessage('복원하지 못했어요. ($e)', error: true);
      return;
    }
    // 복원할 내역이 없으면 스트림에 아무것도 오지 않는다.
    _restoreTimeout?.cancel();
    _restoreTimeout = Timer(const Duration(seconds: 8), () {
      if (busy && !isPro) {
        busy = false;
        _setMessage('복원할 구매 내역을 찾지 못했어요.');
      }
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == productId) {
        switch (p.status) {
          case PurchaseStatus.pending:
            busy = true;
            _setMessage('결제 승인을 기다리는 중...');
          case PurchaseStatus.purchased || PurchaseStatus.restored:
            busy = false;
            await _unlock();
            _setMessage(p.status == PurchaseStatus.restored ? '구매를 복원했어요. PRO 활성화!' : '결제 완료. PRO 활성화!');
          case PurchaseStatus.error:
            busy = false;
            _setMessage('결제에 실패했어요. ${p.error?.message ?? ''}'.trim(), error: true);
          case PurchaseStatus.canceled:
            busy = false;
            _setMessage('결제를 취소했어요.');
        }
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('notepad.exe pro: completePurchase 실패 ($e)');
        }
      }
    }
  }

  Future<void> _unlock() async {
    _unlocked = true;
    _restoreTimeout?.cancel();
    await _prefs?.setBool(_prefsKey, true);
    notifyListeners();
  }

  /// 디버그 빌드 전용: 결제 없이 PRO 화면·위젯 잠금을 확인할 때 쓴다 (`pro --dev`).
  void debugToggle() {
    if (!kDebugMode) return;
    _devOverride = !_devOverride;
    notifyListeners();
  }

  void _setMessage(String text, {bool error = false}) {
    message = text;
    messageIsError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _restoreTimeout?.cancel();
    super.dispose();
  }
}

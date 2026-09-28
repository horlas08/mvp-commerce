import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:image_picker/image_picker.dart';
import '../app/utils/app_snackbar.dart';
import '../services/address_service.dart';
import '../services/checkout_service.dart';
import '../services/coupon_service.dart';
import 'cart_controller.dart';

class CheckoutController extends GetxController {
  final AddressService _addressService = AddressService();
  final CheckoutService _checkoutService = CheckoutService();
  final CouponService _couponService = CouponService();

  // ── Step navigation ──────────────────────────────────────────────────────
  final RxInt currentStep = 0.obs; // 0=Address, 1=Shipping, 2=Review, 3=Payment

  // ── Coupon & Tax ───────────────────────────────────────────────────────────
  final RxString couponCode = ''.obs;
  final Rx<Map<String, dynamic>?> appliedCoupon = Rx<Map<String, dynamic>?>(null);
  final RxDouble discountAmount = 0.0.obs;
  final RxBool isApplyingCoupon = false.obs;
  final RxString couponError = ''.obs;
  final RxDouble taxPercentage = 0.0.obs;
  final RxDouble taxAmount = 0.0.obs;

  double get discount => discountAmount.value;
  double get tax => taxAmount.value;

  // ── Step 1: Address ───────────────────────────────────────────────────────
  final RxList<Map<String, dynamic>> addresses = <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> selectedAddress =
      Rx<Map<String, dynamic>?>(null);
  final RxBool isLoadingAddresses = false.obs;

  // ── Step 2: Shipping ──────────────────────────────────────────────────────
  final RxString shippingType = 'home'.obs; // 'home' | 'pickup'
  final RxList<Map<String, dynamic>> pickupStations =
      <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> selectedPickupStation =
      Rx<Map<String, dynamic>?>(null);
  final RxBool allowTeamReview = false.obs;
  final RxString additionalNote = ''.obs;
  final RxBool isLoadingShipping = false.obs;

  // ── Step 4: Payment ───────────────────────────────────────────────────────
  final RxList<Map<String, dynamic>> paymentMethods =
      <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> selectedPaymentMethod =
      Rx<Map<String, dynamic>?>(null);
  final RxDouble walletBalance = 0.0.obs;
  final RxMap<String, String> paymentFormData = <String, String>{}.obs;
  Rx<XFile?> paymentProofImage = Rx<XFile?>(null);
  final RxBool isLoadingPayment = false.obs;

  // ── Order placement ────────────────────────────────────────────────────────
  final RxBool isPlacingOrder = false.obs;
  final RxBool orderPlaced = false.obs;
  final Rx<Map<String, dynamic>?> placedOrder = Rx<Map<String, dynamic>?>(null);

  // Passed from cart screen
  String cartType = 'internal';
  List<Map<String, dynamic>> cartItems = [];
  double subtotal = 0.0;

  @override
  void onInit() {
    super.onInit();
    loadAddresses();
    loadShippingOptions();
    loadPaymentOptions();
    
    // Register dynamic fee listeners
    ever(selectedAddress, (_) => _updateDynamicFees());
    ever(allowTeamReview, (_) => _updateDynamicFees());
    ever(shippingType, (_) => _updateDynamicFees());
    _updateDynamicFees();
  }

  // ── Address ────────────────────────────────────────────────────────────────
  Future<void> loadAddresses() async {
    isLoadingAddresses.value = true;
    addresses.value = await _addressService.getAddresses();
    // Auto-select the default or first address
    if (selectedAddress.value == null && addresses.isNotEmpty) {
      final def = addresses.firstWhereOrNull((a) => a['is_default'] == true || a['is_default'] == 1);
      selectedAddress.value = def ?? addresses.first;
    }
    isLoadingAddresses.value = false;
  }

  bool canSelectAddress(Map<String, dynamic> address) {
    return true;
  }

  // ── Shipping ────────────────────────────────────────────────────────────────
  Future<void> loadShippingOptions() async {
    isLoadingShipping.value = true;
    pickupStations.value = await _checkoutService.getPickupStations();
    isLoadingShipping.value = false;
  }

  // ── Payment ─────────────────────────────────────────────────────────────────
  Future<void> loadPaymentOptions() async {
    isLoadingPayment.value = true;
    final methods = await _checkoutService.getPaymentMethods(lang: 'ar');

    // Filter out Cash on Delivery completely
    final filtered = methods.where((m) {
      final id = m['id']?.toString().toLowerCase() ?? '';
      final title = (m['title']?.toString() ?? '').toLowerCase();
      final titleEn = (m['title_en']?.toString() ?? '').toLowerCase();
      final titleAr = (m['title_ar']?.toString() ?? '');
      return !id.contains('cod') &&
          !title.contains('cash') &&
          !titleEn.contains('cash') &&
          !titleAr.contains('نقداً');
    }).toList();

    paymentMethods.value = filtered;
    walletBalance.value = await _checkoutService.getWalletBalance();

    // Auto-select Bank Transfer as the active default payment method
    if (selectedPaymentMethod.value == null ||
        selectedPaymentMethod.value?['id'] == 'payment-cod' ||
        selectedPaymentMethod.value?['title']?.toString().toLowerCase().contains('cash') == true) {
      final bankMethod = filtered.firstWhereOrNull((m) =>
          m['id'] == 'payment-bank' ||
          (m['bank_accounts'] is List && (m['bank_accounts'] as List).isNotEmpty)) ??
          (filtered.isNotEmpty ? filtered.first : null);

      selectedPaymentMethod.value = bankMethod ?? {
        'id': 'payment-bank',
        'title': 'حوالة بنكية 💳',
        'title_ar': 'حوالة بنكية 💳',
        'title_en': 'Bank Transfer 💳',
        'fields': [
          {'key': 'receipt_proof', 'label': 'Transfer Receipt Photo', 'type': 'file'}
        ]
      };
    }
    isLoadingPayment.value = false;
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  void goToStep(int step) {
    if (step >= 0 && step <= 2) currentStep.value = step;
  }

  void nextStep() {
    if (currentStep.value < 2) currentStep.value++;
  }

  void prevStep() {
    if (currentStep.value > 0) currentStep.value--;
  }

  bool get canProceedStep1 => selectedAddress.value != null;

  bool get canProceedStep2 {
    if (cartType == 'internal') {
      if (shippingType.value == 'pickup') {
        return selectedPickupStation.value != null;
      }
      return true;
    }
    return true; // external cart: team review toggle is optional
  }

  // ── Place order ──────────────────────────────────────────────────────────────
  Future<void> placeOrder() async {
    if (isPlacingOrder.value) return;
    isPlacingOrder.value = true;

    final address = selectedAddress.value;
    final payment = selectedPaymentMethod.value;
    if (address == null || payment == null) {
      isPlacingOrder.value = false;
      return;
    }

    // Validate wallet balance if paying with wallet
    if (payment['id'] == 'wallet') {
      if (walletBalance.value < orderTotal) {
        isPlacingOrder.value = false;
        AppSnackbar.error(null, 'insufficient_balance_desc'.tr());
        return;
      }
    }

    final result = await _checkoutService.placeOrder(
      addressId: address['id'].toString(),
      cartType: cartType,
      shippingType: shippingType.value,
      pickupStationId: selectedPickupStation.value?['id']?.toString(),
      additionalNote: additionalNote.value,
      allowTeamReview: allowTeamReview.value,
      couponCode: couponCode.value.isNotEmpty ? couponCode.value : null,
      paymentMethodId: payment['id']?.toString() ?? 'wallet',
      paymentFormData: Map<String, String>.from(paymentFormData),
      paymentProofImage: paymentProofImage.value,
      paymentFields: payment['fields'],
    );

    isPlacingOrder.value = false;
    if (result != null) {
      placedOrder.value = result;
      orderPlaced.value = true;

      // Reload cart upon success (backend already removed checked-out items)
      try {
        final cartCtrl = Get.find<CartController>();
        await cartCtrl.loadCart(autoRefresh: false);
      } catch (_) {}
    } else {
      AppSnackbar.error(null, 'error_occurred'.tr());
    }
  }

  // ── Coupon Application ─────────────────────────────────────────────────────
  Future<bool> applyCoupon(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return false;
    isApplyingCoupon.value = true;
    couponError.value = '';
    try {
      final res = await _couponService.validateCoupon(trimmed, subtotal);
      if (res != null && res['valid'] == true) {
        couponCode.value = trimmed;
        appliedCoupon.value = res['coupon'] != null ? Map<String, dynamic>.from(res['coupon']) : null;
        discountAmount.value = (res['discount'] as num?)?.toDouble() ?? 0.0;
        AppSnackbar.success(null, 'coupon_applied'.tr());
        await _updateDynamicFees();
        return true;
      } else {
        couponError.value = 'invalid_coupon'.tr();
        AppSnackbar.error(null, 'invalid_coupon'.tr());
        return false;
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      couponError.value = msg;
      AppSnackbar.error(null, msg);
      return false;
    } finally {
      isApplyingCoupon.value = false;
    }
  }

  void removeCoupon() {
    couponCode.value = '';
    appliedCoupon.value = null;
    discountAmount.value = 0.0;
    couponError.value = '';
    _updateDynamicFees();
  }

  final RxDouble dynamicShippingFee = 0.0.obs;
  final RxDouble dynamicCommissionFee = 0.0.obs;
  final RxDouble configuredTeamReviewFee = 5.0.obs;

  double get shippingFee => dynamicShippingFee.value;
  double get commissionFee => dynamicCommissionFee.value;
  double get teamReviewPrice => configuredTeamReviewFee.value;
  double get teamReviewFee => allowTeamReview.value ? configuredTeamReviewFee.value : 0.0;
  double get orderTotal =>
      double.parse((((subtotal - discount).clamp(0.0, double.infinity)) +
              shippingFee +
              commissionFee +
              teamReviewFee +
              tax)
          .toStringAsFixed(2));

  Future<void> _updateDynamicFees() async {
    Map<String, dynamic> policy = {};

    // 1. Fetch configured fees & pricing policy from settings
    try {
      final settingsMap = await _checkoutService.getAppSettings();
      if (settingsMap.containsKey('team_review_fee')) {
        final val = settingsMap['team_review_fee']?['value_en'] ?? settingsMap['team_review_fee']?['value_ar'];
        final parsed = double.tryParse(val?.toString() ?? '');
        if (parsed != null && parsed >= 0) {
          configuredTeamReviewFee.value = parsed;
        }
      }

      if (settingsMap.containsKey('pricing_policy')) {
        final raw = settingsMap['pricing_policy']?['value_en'] ?? settingsMap['pricing_policy']?['value_ar'];
        if (raw is String && raw.isNotEmpty) {
          try {
            policy = Map<String, dynamic>.from(jsonDecode(raw));
          } catch (_) {}
        } else if (raw is Map) {
          policy = Map<String, dynamic>.from(raw);
        }
      }
    } catch (_) {}

    // Determine effective per-site policy with global fallback
    Map<String, dynamic> effectivePolicy = Map<String, dynamic>.from(policy);
    final sitesMap = policy['sites'];
    if (sitesMap is Map && sitesMap.containsKey(cartType.toLowerCase())) {
      final siteOverride = sitesMap[cartType.toLowerCase()];
      if (siteOverride is Map) {
        siteOverride.forEach((k, v) {
          if (v != null) effectivePolicy[k.toString()] = v;
        });
      }
    }

    // Tax percentage from effective policy (default 0.0)
    final rawTax = effectivePolicy['tax_percentage'];
    taxPercentage.value = (rawTax is num)
        ? rawTax.toDouble()
        : (double.tryParse(rawTax?.toString() ?? '0') ?? 0.0);

    final addr = selectedAddress.value;
    double sFee = 0.0;
    double cFee = 0.0;
    bool hasCustomStateOrCityShip = false;
    bool hasCustomStateOrCityComm = false;

    if (addr != null) {
      final stateName = addr['state']?.toString().trim();
      final cityName = addr['city']?.toString().trim();

      // Load states first if not loaded
      List<Map<String, dynamic>> statesList = [];
      try {
        statesList = await _addressService.getStates();
      } catch (_) {}

      final matchedState = statesList.firstWhereOrNull((s) {
        final nEn = s['name_en']?.toString().trim();
        final nAr = s['name_ar']?.toString().trim();
        final n = s['name']?.toString().trim();
        return nEn == stateName || nAr == stateName || n == stateName;
      });

      if (matchedState != null) {
        final bool stateFree = matchedState['free_shipping'] == true || matchedState['free_shipping'] == 1;
        final bool stateNoComm = matchedState['no_commission'] == true || matchedState['no_commission'] == 1;
        final double stateShipFee = double.tryParse(matchedState['shipping_fee']?.toString() ?? '0') ?? 0.0;
        final double stateComm = double.tryParse(matchedState['commission']?.toString() ?? '0') ?? 0.0;

        if (stateFree) {
          sFee = 0.0;
          hasCustomStateOrCityShip = true;
        } else if (stateShipFee > 0) {
          sFee = stateShipFee;
          hasCustomStateOrCityShip = true;
        }

        if (stateNoComm) {
          cFee = 0.0;
          hasCustomStateOrCityComm = true;
        } else if (stateComm > 0) {
          cFee = stateComm;
          hasCustomStateOrCityComm = true;
        }

        // Check city overrides
        try {
          final citiesList = await _addressService.getCities(matchedState['id'].toString());
          final matchedCity = citiesList.firstWhereOrNull((c) {
            final nEn = c['name_en']?.toString().trim();
            final nAr = c['name_ar']?.toString().trim();
            final n = c['name']?.toString().trim();
            return nEn == cityName || nAr == cityName || n == cityName;
          });

          if (matchedCity != null) {
            final bool cityFree = matchedCity['free_shipping'] == true || matchedCity['free_shipping'] == 1;
            final bool cityNoComm = matchedCity['no_commission'] == true || matchedCity['no_commission'] == 1;
            final double cityShipFee = double.tryParse(matchedCity['shipping_fee']?.toString() ?? '0') ?? 0.0;
            final double cityComm = double.tryParse(matchedCity['commission']?.toString() ?? '0') ?? 0.0;

            if (cityFree) {
              sFee = 0.0;
              hasCustomStateOrCityShip = true;
            } else if (cityShipFee > 0) {
              sFee = cityShipFee;
              hasCustomStateOrCityShip = true;
            }

            if (cityNoComm) {
              cFee = 0.0;
              hasCustomStateOrCityComm = true;
            } else if (cityComm > 0) {
              cFee = cityComm;
              hasCustomStateOrCityComm = true;
            }
          }
        } catch (_) {}
      }
    }

    // If no state/city shipping fee and home delivery, apply pricing policy fallback
    if (shippingType.value == 'home' && !hasCustomStateOrCityShip && effectivePolicy.isNotEmpty) {
      final mode = effectivePolicy['shipping_mode']?.toString() ?? 'fixed';
      final val = (effectivePolicy['shipping_value'] is num)
          ? (effectivePolicy['shipping_value'] as num).toDouble()
          : (double.tryParse(effectivePolicy['shipping_value']?.toString() ?? '0') ?? 0.0);
      if (mode == 'fixed') {
        sFee = val;
      } else if (mode == 'formula') {
        sFee = double.parse((subtotal * val).toStringAsFixed(2));
      }
    }

    // If no state/city commission fee, apply pricing policy fallback
    if (!hasCustomStateOrCityComm && effectivePolicy.isNotEmpty) {
      final mode = effectivePolicy['commission_mode']?.toString() ?? 'fixed';
      final val = (effectivePolicy['commission_value'] is num)
          ? (effectivePolicy['commission_value'] as num).toDouble()
          : (double.tryParse(effectivePolicy['commission_value']?.toString() ?? '0') ?? 0.0);
      if (mode == 'fixed') {
        cFee = val;
      } else if (mode == 'formula') {
        cFee = double.parse((subtotal * val).toStringAsFixed(2));
      }
    }

    if (shippingType.value != 'home') {
      sFee = 0.0;
    }

    dynamicShippingFee.value = sFee;
    dynamicCommissionFee.value = cFee;

    // Calculate tax amount on taxable subtotal (subtotal - discount)
    final taxableSubtotal = (subtotal - discountAmount.value).clamp(0.0, double.infinity);
    if (taxPercentage.value > 0) {
      taxAmount.value = double.parse((taxableSubtotal * (taxPercentage.value / 100.0)).toStringAsFixed(2));
    } else {
      taxAmount.value = 0.0;
    }
  }
}

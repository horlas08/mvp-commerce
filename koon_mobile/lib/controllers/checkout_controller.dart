import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:image_picker/image_picker.dart';
import '../app/theme/app_colors.dart';
import '../app/utils/app_snackbar.dart';
import '../services/address_service.dart';
import '../services/checkout_service.dart';
import 'cart_controller.dart';
import 'package:flutter/material.dart';
class CheckoutController extends GetxController {
  final AddressService _addressService = AddressService();
  final CheckoutService _checkoutService = CheckoutService();

  // ── Step navigation ──────────────────────────────────────────────────────
  final RxInt currentStep = 0.obs; // 0=Address, 1=Shipping, 2=Review, 3=Payment

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
    paymentMethods.value = await _checkoutService.getPaymentMethods();
    walletBalance.value = await _checkoutService.getWalletBalance();
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
      paymentMethodId: payment['id']?.toString() ?? 'wallet',
      paymentFormData: Map<String, String>.from(paymentFormData),
      paymentProofImage: paymentProofImage.value,
      paymentFields: payment['fields'],
    );

    isPlacingOrder.value = false;
    if (result != null) {
      placedOrder.value = result;
      orderPlaced.value = true;

      // Clear the cart upon success
      try {
        final cartCtrl = Get.find<CartController>();
        await cartCtrl.clearCurrentCart();
      } catch (_) {}
    } else {
      AppSnackbar.error(null, 'error_occurred'.tr());
    }
  }

  final RxDouble dynamicShippingFee = 0.0.obs;
  final RxDouble dynamicCommissionFee = 0.0.obs;

  double get shippingFee => dynamicShippingFee.value;
  double get teamReviewFee => dynamicCommissionFee.value;
  double get orderTotal => subtotal + shippingFee + teamReviewFee;

  Future<void> _updateDynamicFees() async {
    final addr = selectedAddress.value;
    if (addr == null) {
      dynamicShippingFee.value = 0.0;
      dynamicCommissionFee.value = (allowTeamReview.value && cartType != 'internal') ? 5.0 : 0.0;
      return;
    }

    final stateName = addr['state']?.toString();
    final cityName = addr['city']?.toString();

    double sFee = 0.0;
    double cFee = (allowTeamReview.value && cartType != 'internal') ? 5.0 : 0.0;

    // Load states first if not loaded
    List<Map<String, dynamic>> statesList = [];
    try {
      statesList = await _addressService.getStates();
    } catch (_) {}

    final matchedState = statesList.firstWhereOrNull((s) =>
        s['name_en'] == stateName || s['name_ar'] == stateName || s['name'] == stateName);

    if (matchedState != null) {
      final bool stateFree = matchedState['free_shipping'] == true || matchedState['free_shipping'] == 1;
      final bool stateNoComm = matchedState['no_commission'] == true || matchedState['no_commission'] == 1;
      final double stateShipFee = double.tryParse(matchedState['shipping_fee']?.toString() ?? '0') ?? 0.0;
      final double stateComm = double.tryParse(matchedState['commission']?.toString() ?? '5.0') ?? 5.0;

      sFee = stateFree ? 0.0 : stateShipFee;
      if (allowTeamReview.value && cartType != 'internal') {
        cFee = stateNoComm ? 0.0 : stateComm;
      }

      // Check city overrides
      try {
        final citiesList = await _addressService.getCities(matchedState['id'].toString());
        final matchedCity = citiesList.firstWhereOrNull((c) =>
            c['name_en'] == cityName || c['name_ar'] == cityName || c['name'] == cityName);

        if (matchedCity != null) {
          final bool cityFree = matchedCity['free_shipping'] == true || matchedCity['free_shipping'] == 1;
          final bool cityNoComm = matchedCity['no_commission'] == true || matchedCity['no_commission'] == 1;
          final double cityShipFee = double.tryParse(matchedCity['shipping_fee']?.toString() ?? '0') ?? 0.0;
          final double cityComm = double.tryParse(matchedCity['commission']?.toString() ?? '5.0') ?? 5.0;

          if (cityFree) {
            sFee = 0.0;
          } else if (cityShipFee > 0) {
            sFee = cityShipFee;
          }

          if (allowTeamReview.value && cartType != 'internal') {
            if (cityNoComm) {
              cFee = 0.0;
            } else if (cityComm > 0) {
              cFee = cityComm;
            }
          }
        }
      } catch (_) {}
    }

    if (shippingType.value != 'home') {
      sFee = 0.0;
    }

    dynamicShippingFee.value = sFee;
    dynamicCommissionFee.value = cFee;
  }
}

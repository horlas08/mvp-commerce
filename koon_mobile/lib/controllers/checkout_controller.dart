import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:image_picker/image_picker.dart';
import '../app/theme/app_colors.dart';
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
  }

  // ── Address ────────────────────────────────────────────────────────────────
  Future<void> loadAddresses() async {
    isLoadingAddresses.value = true;
    addresses.value = await _addressService.getAddresses();
    // Auto-select the first address that has a location linked
    if (selectedAddress.value == null) {
      final linked = addresses.firstWhereOrNull(
        (a) => a['lat'] != null && a['lng'] != null,
      );
      selectedAddress.value = linked;
    }
    isLoadingAddresses.value = false;
  }

  bool canSelectAddress(Map<String, dynamic> address) {
    return address['lat'] != null && address['lng'] != null;
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
    if (step >= 0 && step <= 3) currentStep.value = step;
  }

  void nextStep() {
    if (currentStep.value < 3) currentStep.value++;
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
        Get.snackbar(
          'insufficient_balance'.tr(),
          'insufficient_balance_desc'.tr(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
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
      Get.snackbar(
        'error'.tr(),
        'error_occurred'.tr(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ── Shipping fee helper ───────────────────────────────────────────────────────
  double get shippingFee => 0.0; // Set from API response when available
  double get teamReviewFee => (allowTeamReview.value && cartType != 'internal') ? 5.0 : 0.0;
  double get orderTotal => subtotal + shippingFee + teamReviewFee;
}

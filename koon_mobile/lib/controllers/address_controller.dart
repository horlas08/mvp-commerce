import 'package:get/get.dart';
import '../services/address_service.dart';

class AddressController extends GetxController {
  final AddressService _service = AddressService();

  final RxList<Map<String, dynamic>> addresses = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Form state
  final RxList<Map<String, dynamic>> states = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> cities = <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> selectedState = Rx<Map<String, dynamic>?>(null);
  final Rx<Map<String, dynamic>?> selectedCity = Rx<Map<String, dynamic>?>(null);
  final RxBool isLoadingStates = false.obs;
  final RxBool isLoadingCities = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadAddresses();
    loadStates();
  }

  Future<void> loadAddresses() async {
    isLoading.value = true;
    addresses.value = await _service.getAddresses();
    isLoading.value = false;
  }

  Future<void> loadStates() async {
    isLoadingStates.value = true;
    states.value = await _service.getStates();
    isLoadingStates.value = false;
  }

  Future<void> onStateChanged(Map<String, dynamic>? state) async {
    selectedState.value = state;
    selectedCity.value = null;
    cities.clear();
    if (state == null) return;
    isLoadingCities.value = true;
    cities.value = await _service.getCities(state['id'].toString());
    isLoadingCities.value = false;
  }

  Future<bool> addAddress({
    required String label,
    required String street,
    required String phone,
  }) async {
    if (selectedState.value == null || selectedCity.value == null) return false;
    isSaving.value = true;
    final result = await _service.addAddress(
      label: label,
      fullName: label,
      phone: phone,
      street: street,
      city: selectedCity.value!['name'] ?? '',
      state: selectedState.value!['name'],
    );
    isSaving.value = false;
    if (result != null) {
      await loadAddresses();
      return true;
    }
    return false;
  }

  Future<bool> updateAddress({
    required String addressId,
    required String label,
    required String street,
    required String phone,
  }) async {
    if (selectedState.value == null || selectedCity.value == null) return false;
    isSaving.value = true;
    final result = await _service.updateAddress(
      addressId,
      label: label,
      fullName: label,
      phone: phone,
      street: street,
      city: selectedCity.value!['name'] ?? '',
      state: selectedState.value!['name'],
    );
    isSaving.value = false;
    if (result != null) {
      await loadAddresses();
      return true;
    }
    return false;
  }

  Future<bool> deleteAddress(String addressId) async {
    final success = await _service.deleteAddress(addressId);
    if (success) await loadAddresses();
    return success;
  }

  Future<bool> linkLocation(String addressId, double lat, double lng) async {
    final success = await _service.linkLocation(addressId, lat, lng);
    if (success) await loadAddresses();
    return success;
  }

  /// Pre-fill form for editing an existing address
  void prefillForEdit(Map<String, dynamic> address) {
    // Match state by name
    final stateName = address['state'];
    if (stateName != null) {
      final matchedState = states.firstWhereOrNull(
        (s) => s['name'] == stateName,
      );
      if (matchedState != null) {
        selectedState.value = matchedState;
        // Load cities for this state, then match city
        onStateChanged(matchedState).then((_) {
          final cityName = address['city'];
          if (cityName != null) {
            final matchedCity = cities.firstWhereOrNull(
              (c) => c['name'] == cityName,
            );
            selectedCity.value = matchedCity;
          }
        });
      }
    }
  }

  void resetForm() {
    selectedState.value = null;
    selectedCity.value = null;
    cities.clear();
  }
}

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class CheckoutService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getPickupStations() async {
    try {
      final response = await _dio.get(ApiConstants.pickupStations);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await _dio.get(ApiConstants.paymentMethods);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<double> getWalletBalance() async {
    try {
      final response = await _dio.get(ApiConstants.walletBalance);
      if (response.statusCode == 200) {
        final data = response.data;
        return (data['balance'] ?? 0.0).toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  Future<Map<String, dynamic>?> placeOrder({
    required String addressId,
    required String cartType,
    required String shippingType, // 'home' | 'pickup'
    String? pickupStationId,
    String? additionalNote,
    bool allowTeamReview = false,
    required String paymentMethodId, // 'wallet' or admin method id
    Map<String, String>? paymentFormData,
    XFile? paymentProofImage,
    List<dynamic>? paymentFields,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'address_id': addressId,
        'cart_type': cartType,
        'shipping_type': shippingType,
        if (pickupStationId != null) 'pickup_station_id': pickupStationId,
        if (additionalNote != null && additionalNote.isNotEmpty)
          'additional_note': additionalNote,
        'allow_team_review': allowTeamReview,
        'payment_method_id': paymentMethodId,
      });

      if (paymentFormData != null) {
        for (var entry in paymentFormData.entries) {
          final key = entry.key;
          final value = entry.value;

          final isFileField = paymentFields?.any((f) => f['key'] == key && f['type'] == 'file') ?? false;
          if (isFileField && value.isNotEmpty) {
            formData.files.add(MapEntry(
              key,
              await MultipartFile.fromFile(
                value,
                filename: value.split('/').last,
              ),
            ));
          } else {
            formData.fields.add(MapEntry(key, value));
          }
        }
      }

      if (paymentProofImage != null) {
        formData.files.add(MapEntry(
          'payment_proof',
          await MultipartFile.fromFile(
            paymentProofImage.path,
            filename: paymentProofImage.name,
          ),
        ));
      }

      final response = await _dio.post(
        ApiConstants.placeOrder,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }
}

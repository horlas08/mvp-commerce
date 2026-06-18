import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class AddressService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      final response = await _dio.get(ApiConstants.addresses);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> addAddress({
    required String label,
    required String fullName,
    required String phone,
    required String street,
    required String city,
    String? state,
    String country = "Saudi Arabia",
    String? postalCode,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.addresses,
        data: {
          'label': label,
          'full_name': fullName,
          'phone': phone,
          'street': street,
          'city': city,
          if (state != null) 'state': state,
          'country': country,
          if (postalCode != null) 'postal_code': postalCode,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'is_default': isDefault,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> updateAddress(
    String addressId, {
    required String label,
    required String fullName,
    required String phone,
    required String street,
    required String city,
    String? state,
    String country = "Saudi Arabia",
    String? postalCode,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.addresses}/$addressId',
        data: {
          'label': label,
          'full_name': fullName,
          'phone': phone,
          'street': street,
          'city': city,
          if (state != null) 'state': state,
          'country': country,
          if (postalCode != null) 'postal_code': postalCode,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          'is_default': isDefault,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteAddress(String addressId) async {
    try {
      final response = await _dio.delete('${ApiConstants.addresses}/$addressId');
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }
}

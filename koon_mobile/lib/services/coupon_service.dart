import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class CouponService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getCoupons({String lang = "en"}) async {
    try {
      final response = await _dio.get(ApiConstants.coupons, queryParameters: {'lang': lang});
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> validateCoupon(String code, double orderTotal) async {
    try {
      final response = await _dio.post(
        ApiConstants.validateCoupon,
        data: {'code': code, 'order_total': orderTotal},
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }
}

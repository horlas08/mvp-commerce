import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class RefundService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getRefunds() async {
    try {
      final response = await _dio.get(ApiConstants.refunds);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> requestRefund({
    required String orderId,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.refunds,
        data: {
          'order_id': orderId,
          'reason': reason,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }
}

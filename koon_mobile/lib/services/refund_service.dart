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

  Future<bool> requestRefund({
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
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {}
    return false;
  }

  Future<bool> cancelRefund(String refundId) async {
    try {
      final response = await _dio.delete('${ApiConstants.refunds}/$refundId');
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }
}

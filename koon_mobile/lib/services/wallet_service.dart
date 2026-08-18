import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class WalletService {
  final Dio _dio = ApiService().dio;

  Future<double?> getBalance() async {
    try {
      final response = await _dio.get(ApiConstants.walletBalance);
      if (response.statusCode == 200 && response.data != null) {
        return (response.data['balance'] as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final response = await _dio.get(ApiConstants.walletTransactions);
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> topUpWithCoupon(String code) async {
    try {
      final response = await _dio.post(
        ApiConstants.walletTopupCoupon,
        data: {'code': code},
      );
      if (response.statusCode == 200 && response.data != null) {
        return {
          'success': true,
          'amount_added': (response.data['amount_added'] as num?)?.toDouble() ?? 0.0,
          'new_balance': (response.data['new_balance'] as num?)?.toDouble() ?? 0.0,
          'message': response.data['message']?.toString() ?? 'Top up successful',
        };
      }
      return {
        'success': false,
        'message': 'Failed to top up balance',
      };
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      return {
        'success': false,
        'message': detail?.toString() ?? e.message ?? 'An error occurred',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}

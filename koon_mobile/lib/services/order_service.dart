import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class OrderService {
  final Dio _dio = ApiService().dio;

  Future<Map<String, dynamic>?> createOrder({
    Map<String, dynamic>? shippingAddress,
    String? couponCode,
    String? notes,
    String? cartType,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.orders, data: {
        if (shippingAddress != null) 'shipping_address': shippingAddress,
        if (couponCode != null) 'coupon_code': couponCode,
        if (notes != null) 'notes': notes,
        if (cartType != null) 'cart_type': cartType,
      });
      return response.data;
    } catch (_) { return null; }
  }

  Future<List<Map<String, dynamic>>> getOrders({String? status, int page = 1}) async {
    try {
      final response = await _dio.get(ApiConstants.orders, queryParameters: {
        if (status != null) 'status': status,
        'page': page,
      });
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final response = await _dio.get('${ApiConstants.orders}/$orderId');
      return response.data;
    } catch (_) { return null; }
  }
}

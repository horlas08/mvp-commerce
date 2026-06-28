import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class CartService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getCart({String? cartType, String lang = 'en'}) async {
    try {
      final response = await _dio.get(ApiConstants.cart, queryParameters: {
        if (cartType != null) 'cart_type': cartType,
        'lang': lang,
      });
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> addToCart({
    required String cartType,
    String? productId,
    String? title,
    String? price,
    String? imageUrl,
    String? externalUrl,
    String? siteName,
    int quantity = 1,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.cart, data: {
        'cart_type': cartType,
        if (productId != null) 'product_id': productId,
        if (title != null) 'title': title,
        if (price != null) 'price': price,
        if (imageUrl != null) 'image_url': imageUrl,
        if (externalUrl != null) 'external_url': externalUrl,
        if (siteName != null) 'site_name': siteName,
        'quantity': quantity,
      });
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        rethrow;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCartItem(String itemId, {int? quantity, bool? isSelected}) async {
    try {
      await _dio.put('${ApiConstants.cart}/$itemId', data: {
        if (quantity != null) 'quantity': quantity,
        if (isSelected != null) 'is_selected': isSelected,
      });
      return true;
    } catch (_) { return false; }
  }

  Future<bool> removeFromCart(String itemId) async {
    try {
      await _dio.delete('${ApiConstants.cart}/$itemId');
      return true;
    } catch (_) { return false; }
  }

  Future<bool> clearCart({String? cartType}) async {
    try {
      await _dio.delete(ApiConstants.cart, queryParameters: {
        if (cartType != null) 'cart_type': cartType,
      });
      return true;
    } catch (_) { return false; }
  }
}

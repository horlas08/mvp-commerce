import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class WishlistService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getWishlist() async {
    try {
      final response = await _dio.get(ApiConstants.wishlist);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> addToWishlist({
    String? productId,
    String? externalUrl,
    String? title,
    String? price,
    String? imageUrl,
    String source = "internal",
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.wishlist,
        data: {
          if (productId != null) 'product_id': productId,
          if (externalUrl != null) 'external_url': externalUrl,
          if (title != null) 'title': title,
          if (price != null) 'price': price,
          if (imageUrl != null) 'image_url': imageUrl,
          'source': source,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> removeFromWishlist(String itemId) async {
    try {
      final response = await _dio.delete('${ApiConstants.wishlist}/$itemId');
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }
}

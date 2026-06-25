import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';
import 'currency_service.dart';

class WishlistService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getWishlist({String lang = 'en'}) async {
    try {
      final response = await _dio.get(ApiConstants.wishlist, queryParameters: {'lang': lang});
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
      String? convertedPrice = price;
      if (price != null) {
        convertedPrice = await KoonCurrencyService.convertToSar(price);
      }
      final response = await _dio.post(
        ApiConstants.wishlist,
        data: {
          if (productId != null) 'product_id': productId,
          if (externalUrl != null) 'external_url': externalUrl,
          if (title != null) 'title': title,
          if (convertedPrice != null) 'price': convertedPrice,
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

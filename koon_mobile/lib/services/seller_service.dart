import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class SellerService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getSellers({String lang = "en"}) async {
    try {
      final response = await _dio.get(ApiConstants.sellers, queryParameters: {'lang': lang});
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> applyAsSeller({
    required String storeNameEn,
    required String storeNameAr,
    String? descriptionEn,
    String? descriptionAr,
    String? logoUrl,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.applySeller,
        data: {
          'store_name_en': storeNameEn,
          'store_name_ar': storeNameAr,
          if (descriptionEn != null) 'description_en': descriptionEn,
          if (descriptionAr != null) 'description_ar': descriptionAr,
          if (logoUrl != null) 'logo_url': logoUrl,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getMyProducts({String lang = "en"}) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/sellers/me/products',
        queryParameters: {'lang': lang},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> createProduct(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/sellers/me/products',
        data: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.baseUrl}/sellers/me/products/$productId',
        data: data,
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.baseUrl}/sellers/me/products/$productId',
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // Get current seller's profile
  Future<Map<String, dynamic>?> getMySellerProfile() async {
    try {
      final response = await _dio.get(ApiConstants.sellerMe);
      if (response.statusCode == 200) return Map<String, dynamic>.from(response.data);
    } catch (_) {}
    return null;
  }

  // Get internal products (for marketplace tab)
  Future<List<Map<String, dynamic>>> getInternalProducts({String lang = "en", int limit = 40}) async {
    try {
      final response = await _dio.get(ApiConstants.products, queryParameters: {'lang': lang, 'limit': limit});
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(response.data);
    } catch (_) {}
    return [];
  }
}

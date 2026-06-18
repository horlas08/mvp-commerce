import 'package:dio/dio.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class ProductService {
  final Dio _dio = ApiService().dio;

  Future<List<Map<String, dynamic>>> getProducts({String lang = 'en', int page = 1, String? categoryId}) async {
    try {
      final response = await _dio.get(ApiConstants.products, queryParameters: {
        'lang': lang, 'page': page,
        if (categoryId != null) 'category_id': categoryId,
      });
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> getTopSelling({String lang = 'en', int limit = 10}) async {
    try {
      final response = await _dio.get(ApiConstants.topSelling, queryParameters: {'lang': lang, 'limit': limit});
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query, {String lang = 'en'}) async {
    try {
      final response = await _dio.get(ApiConstants.searchProducts, queryParameters: {'q': query, 'lang': lang});
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> getBanners({String lang = 'en'}) async {
    try {
      final response = await _dio.get(ApiConstants.banners, queryParameters: {'lang': lang});
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> getProduct(String id, {String lang = 'en'}) async {
    try {
      final response = await _dio.get('${ApiConstants.products}/$id', queryParameters: {'lang': lang});
      return response.data;
    } catch (_) { return null; }
  }

  Future<List<Map<String, dynamic>>> getCategories({String lang = 'en'}) async {
    try {
      final response = await _dio.get(ApiConstants.categories, queryParameters: {'lang': lang});
      return List<Map<String, dynamic>>.from(response.data);
    } catch (_) { return []; }
  }
}

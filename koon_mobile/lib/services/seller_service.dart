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
}

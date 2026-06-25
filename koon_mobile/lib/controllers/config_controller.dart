import 'package:get/get.dart';
import '../services/api_service.dart';
import '../app/constants/api_constants.dart';

class ConfigController extends GetxController {
  final RxMap<String, Map<String, dynamic>> configs = <String, Map<String, dynamic>>{}.obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoaded = false.obs;

  Future<void> fetchConfigs() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await ApiService().dio.get(ApiConstants.scraperConfigAll);
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data);
        configs.value = data.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
        isLoaded.value = true;
      }
    } catch (e) {
      Get.log('Error fetching scraper configurations: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, dynamic>? getConfigForUrl(String url) {
    final urlLower = url.toLowerCase();
    for (final entry in configs.entries) {
      final config = entry.value;
      final domain = config['domain'] as String?;
      final name = entry.key.toLowerCase();
      if ((domain != null && urlLower.contains(domain.toLowerCase())) || urlLower.contains(name)) {
        return config;
      }
    }
    return null;
  }
}

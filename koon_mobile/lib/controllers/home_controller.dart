import 'package:get/get.dart';
import '../services/product_service.dart';

class HomeController extends GetxController {
  final ProductService _productService = ProductService();

  final RxList<Map<String, dynamic>> banners = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> categories = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> topSelling = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadHomeData();
  }

  Future<void> loadHomeData({String lang = 'en'}) async {
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _productService.getBanners(lang: lang),
        _productService.getCategories(lang: lang),
        _productService.getTopSelling(lang: lang),
      ]);
      banners.value = results[0];
      categories.value = results[1];
      topSelling.value = results[2];
    } catch (_) {}
    isLoading.value = false;
  }

  Future<void> refresh({String lang = 'en'}) async {
    await loadHomeData(lang: lang);
  }
}

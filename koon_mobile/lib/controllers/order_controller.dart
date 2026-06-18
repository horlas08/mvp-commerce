import 'package:get/get.dart';
import '../services/order_service.dart';

class OrderController extends GetxController {
  final OrderService _orderService = OrderService();

  final RxList<Map<String, dynamic>> orders = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  Future<void> loadOrders() async {
    isLoading.value = true;
    orders.value = await _orderService.getOrders();
    isLoading.value = false;
  }

  Future<bool> createOrder({String? cartType}) async {
    final result = await _orderService.createOrder(cartType: cartType);
    if (result != null) {
      await loadOrders();
      return true;
    }
    return false;
  }
}

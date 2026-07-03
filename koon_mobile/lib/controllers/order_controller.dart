import 'package:get/get.dart';
import '../services/order_service.dart';
import '../services/refund_service.dart';

class OrderController extends GetxController {
  final OrderService _orderService = OrderService();
  final RefundService _refundService = RefundService();

  final RxList<Map<String, dynamic>> orders = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  Future<void> loadOrders({String? status}) async {
    isLoading.value = true;
    orders.value = await _orderService.getOrders(status: status);
    isLoading.value = false;
  }

  Future<Map<String, dynamic>?> fetchOrderById(String orderId) async {
    return await _orderService.getOrderById(orderId);
  }

  Future<bool> createOrder({String? cartType}) async {
    final result = await _orderService.createOrder(cartType: cartType);
    if (result != null) {
      await loadOrders();
      return true;
    }
    return false;
  }

  Future<bool> submitRefund({required String orderId, required String reason}) async {
    final result = await _refundService.requestRefund(orderId: orderId, reason: reason);
    return result;
  }

  Future<bool> cancelRefund(String refundId) async {
    return await _refundService.cancelRefund(refundId);
  }
}

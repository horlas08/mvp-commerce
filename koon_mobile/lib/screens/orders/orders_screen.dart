import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/auth_controller.dart';
import '../auth/login_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderController = Get.find<OrderController>();
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('orders'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (!authController.isLoggedIn.value) {
          return _buildLoginPrompt(context);
        }

        if (orderController.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (orderController.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 80, color: AppColors.textHint)
                    .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                Text('no_orders'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('start_exploring'.tr(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint), textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => orderController.loadOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orderController.orders.length,
            itemBuilder: (context, index) {
              final order = orderController.orders[index];
              return _buildOrderCard(order, index);
            },
          ),
        );
      }),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final status = order['status'] ?? 'pending';
    final total = order['total'] ?? 0;
    final items = order['items'] as List? ?? [];
    final createdAt = order['created_at'] ?? '';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_outlined, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('#${(order['id'] ?? '').toString().substring(0, 8)}',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'order_status_$status'.tr(),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('${items.length} item${items.length != 1 ? 's' : ''}',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(createdAt.toString().split('T').first,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                Text('$total SAR',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 300.ms).slideX(begin: 0.05);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'confirmed': return AppColors.info;
      case 'processing': return AppColors.secondary;
      case 'shipped': return AppColors.secondaryLight;
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textHint;
    }
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 80, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('login_to_continue'.tr(), style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Text('login'.tr()),
          ),
        ],
      ),
    );
  }
}

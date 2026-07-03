import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/auth_controller.dart';
import '../auth/login_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final OrderController _orderController = Get.find<OrderController>();
  final AuthController _authController = Get.find<AuthController>();

  late TabController _tabController;
  final List<String?> _statusFilters = [null, 'pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];
  final List<String> _tabLabels = ['all', 'pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _orderController.loadOrders(status: _statusFilters[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('orders'.tr()),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Obx(() {
            if (!_authController.isLoggedIn.value) return const SizedBox.shrink();
            return TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textHint,
              labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
              tabs: _tabLabels.map((l) => Tab(text: 'order_tab_$l'.tr())).toList(),
            );
          }),
        ),
      ),
      body: Obx(() {
        if (!_authController.isLoggedIn.value) {
          return _buildLoginPrompt(context);
        }

        if (_orderController.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (_orderController.orders.isEmpty) {
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
          onRefresh: () => _orderController.loadOrders(status: _statusFilters[_tabController.index]),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _orderController.orders.length,
            itemBuilder: (context, index) {
              final order = _orderController.orders[index];
              return _buildOrderCard(context, order, index);
            },
          ),
        );
      }),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, int index) {
    final status = order['status'] ?? 'pending';
    final paymentStatus = order['payment_status'] ?? 'not_required';
    final total = order['total'] ?? 0;
    final items = order['items'] as List? ?? [];
    final createdAt = order['created_at'] ?? '';
    final cartType = order['cart_type'] ?? 'internal';
    final statusColor = _getStatusColor(status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => OrderDetailScreen(order: order),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        );
      },
      child: Card(
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
                    child: Text('#${(order['id'] ?? '').toString().length >= 8 ? (order['id'] ?? '').toString().substring(0, 8).toUpperCase() : (order['id'] ?? '').toString().toUpperCase()}',
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

              // Payment pending badge
              if (paymentStatus == 'pending_approval') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('payment_pending_approval'.tr(),
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(cartType.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    items.length == 1 ? 'one_item'.tr() : 'items_count'.tr(args: [items.length.toString()]),
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(createdAt.toString().split('T').first,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                  Text('$total ' + 'SAR'.tr(),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),

              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('view_details'.tr(), style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 300.ms).slideX(begin: 0.05),
    );
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

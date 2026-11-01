import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../services/seller_service.dart';
import 'add_product_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final SellerService _sellerService = SellerService();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProducts());
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final lang = context.locale.languageCode;
    final products = await _sellerService.getMyProducts(lang: lang);
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_product'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('delete_product_confirm'.tr(), style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('delete'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _sellerService.deleteProduct(productId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('product_deleted'.tr(), style: GoogleFonts.inter()),
          backgroundColor: AppColors.success,
        ),
      );
      _loadProducts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_occurred'.tr(), style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _products.where((p) => p['is_active'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'seller_dashboard'.tr(),
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadProducts,
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (result == true && mounted) _loadProducts();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('add_product'.tr(), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadProducts,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // Stats Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _buildStatCard(
                            icon: Icons.inventory_2_outlined,
                            label: 'total_products'.tr(),
                            value: _products.length.toString(),
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            icon: Icons.check_circle_outline,
                            label: 'active_listings'.tr(),
                            value: activeCount.toString(),
                            color: AppColors.success,
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                  ),

                  // Products section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        '📦 ${'my_products'.tr()}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  // Products list
                  if (_products.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 72, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            Text(
                              'no_products_yet'.tr(),
                              style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'tap_add_product'.tr(),
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = _products[index];
                            return _buildProductCard(product, index)
                                .animate()
                                .fadeIn(duration: 350.ms, delay: (index * 50).ms)
                                .slideY(begin: 0.05);
                          },
                          childCount: _products.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final images = product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] as String? : null;
    final isActive = product['is_active'] == true;
    final price = (product['price'] ?? 0.0).toDouble();
    final currency = product['currency'] ?? 'SAR';
    final stock = product['stock_quantity'] ?? 0;
    final productId = product['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 100,
              height: 100,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surfaceVariant),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.image, color: AppColors.textHint),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.image, size: 32, color: AppColors.textHint),
                    ),
            ),
          ),

          // Product info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product['title'] ?? product['title_en'] ?? 'Untitled',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                      // Active badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.textHint.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'active'.tr() : 'draft'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : AppColors.textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency ${price.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'stock'.tr()}: $stock',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Edit button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddProductScreen(product: product),
                              ),
                            );
                            if (result == true && mounted) _loadProducts();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: Text('edit'.tr(), style: GoogleFonts.inter(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteProduct(productId),
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: Text('delete'.tr(), style: GoogleFonts.inter(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


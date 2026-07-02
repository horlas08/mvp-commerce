import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/settings_controller.dart';
import '../search/search_screen.dart';
import '../webview/webview_screen.dart';
import '../product/product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _homeController = Get.find<HomeController>();
  final SettingsController _settingsController = Get.find<SettingsController>();
  int _bannerIndex = 0;

  final List<Map<String, dynamic>> _externalStores = [
    {'name': 'Alibaba', 'logo': '🏭', 'color': Color(0xFFFF6B00), 'url': 'https://www.alibaba.com', 'subtitle': 'Wholesale', 'enabled': true},
    {'name': 'AliExpress', 'logo': '🛒', 'color': Color(0xFFE53935), 'url': 'https://ar.aliexpress.com', 'subtitle': '', 'enabled': true},
    {'name': 'SHEIN', 'logo': '👗', 'color': Color(0xFF1A1A2E), 'url': 'https://ar.shein.com', 'subtitle': '', 'enabled': true},
    {'name': 'iHerb', 'logo': '🌿', 'color': Color(0xFF007943), 'url': 'https://www.iherb.com', 'subtitle': '', 'enabled': true},
    {'name': 'Amazon', 'logo': '📦', 'color': Color(0xFFFFA726), 'url': 'https://www.amazon.sa', 'subtitle': '', 'enabled': true},
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _homeController.refresh(lang: lang),
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('🛍️', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Koon', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const Spacer(),
                      _buildHeaderIcon(Icons.headset_mic_outlined),
                      const SizedBox(width: 4),
                      _buildHeaderIcon(Icons.chat_bubble_outline),
                      const SizedBox(width: 4),
                      _buildHeaderIcon(Icons.notifications_none_outlined),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Text('search_hint'.tr(), style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                          const Spacer(),
                          Container(
                            width: 40, height: 40, margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.search, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05),
              ),

              // Banner Carousel
              SliverToBoxAdapter(
                child: Obx(() {
                  if (_homeController.banners.isEmpty) {
                    return const SizedBox(height: 180);
                  }
                  return Column(
                    children: [
                      CarouselSlider.builder(
                        itemCount: _homeController.banners.length,
                        itemBuilder: (context, index, _) {
                          final banner = _homeController.banners[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: banner['image_url'] ?? '',
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: AppColors.surfaceVariant),
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppColors.primarySurface,
                                      child: const Center(child: Icon(Icons.image, size: 40, color: AppColors.primary)),
                                    ),
                                  ),
                                  // Gradient overlay
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (banner['title'] != null)
                                    Positioned(
                                      bottom: 12, left: 16, right: 16,
                                      child: Text(
                                        banner['title'],
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        options: CarouselOptions(
                          height: 180,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 4),
                          enlargeCenterPage: true,
                          viewportFraction: 0.88,
                          onPageChanged: (index, _) => setState(() => _bannerIndex = index),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSmoothIndicator(
                        activeIndex: _bannerIndex,
                        count: _homeController.banners.length,
                        effect: WormEffect(
                          dotWidth: 8, dotHeight: 8,
                          activeDotColor: AppColors.primary,
                          dotColor: AppColors.divider,
                        ),
                      ),
                    ],
                  );
                }).animate(delay: 200.ms).fadeIn(duration: 500.ms),
              ),

              // External Stores Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text('order_from_global'.tr(),
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _externalStores.length,
                    itemBuilder: (context, index) {
                      final store = _externalStores[index];
                      return GestureDetector(
                        onTap: store['enabled']
                            ? () async {
                                await WebViewScreen.setupCurrencyCookies(store['url']);
                                if (!context.mounted) return;
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => WebViewScreen(initialUrl: store['url'], siteName: store['name'])));
                              }
                            : null,

                        child: Container(
                          width: 155,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [store['color'], (store['color'] as Color).withOpacity(0.7)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: (store['color'] as Color).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (store['subtitle'] != '')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(store['subtitle'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ),
                                    const Spacer(),
                                    Text(store['logo'], style: const TextStyle(fontSize: 28)),
                                    const SizedBox(height: 4),
                                    Text(store['name'], style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              if (!store['enabled'])
                                Positioned(
                                  top: 10, right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('soon'.tr(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ).animate(delay: Duration(milliseconds: 350 + (index * 80))).fadeIn(duration: 400.ms).slideX(begin: 0.1);
                    },
                  ),
                ),
              ),

              // Featured Categories
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      Text('featured_categories'.tr(),
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: Text('see_all'.tr(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ).animate(delay: 500.ms).fadeIn(duration: 400.ms),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: Obx(() => ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _homeController.categories.length,
                        itemBuilder: (context, index) {
                          final cat = _homeController.categories[index];
                          return Container(
                            width: 90,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              children: [
                                Container(
                                  width: 68, height: 68,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.divider, width: 0.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: cat['image_url'] != null
                                        ? CachedNetworkImage(imageUrl: cat['image_url'], fit: BoxFit.cover)
                                        : Center(child: Text(cat['icon'] ?? '📦', style: const TextStyle(fontSize: 28))),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(cat['name'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ).animate(delay: Duration(milliseconds: 550 + (index * 60))).fadeIn(duration: 300.ms).slideY(begin: 0.1);
                        },
                      )),
                ),
              ),

              // Top Selling Products
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Text('top_selling'.tr(),
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: Text('see_all'.tr(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ).animate(delay: 650.ms).fadeIn(duration: 400.ms),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: Obx(() => SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = _homeController.topSelling[index];
                          return _buildProductCard(product);
                        },
                        childCount: _homeController.topSelling.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                    )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: AppColors.textSecondary),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final images = product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;
    final hasDiscount = product['discount_price'] != null;
    final double price = (product['price'] ?? 0.0).toDouble();
    final double discount = hasDiscount ? (product['discount_price'] ?? 0.0).toDouble() : 0.0;
    final currency = product['currency'] ?? 'SAR';

    return Obx(() => GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: imageUrl != null
                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, width: double.infinity)
                        : Container(
                            color: AppColors.surfaceVariant,
                            child: const Center(child: Icon(Icons.image, size: 40, color: AppColors.textHint)),
                          ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              _settingsController.formatPrice(hasDiscount ? discount : price, currency),
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                        if (hasDiscount)
                          Text(
                            _settingsController.formatPrice(price, currency),
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint, decoration: TextDecoration.lineThrough),
                          ),
                        const SizedBox(height: 4),
                        if (product['rating'] != null && product['rating'] > 0)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: AppColors.warning),
                              const SizedBox(width: 2),
                              Text('${product['rating']}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

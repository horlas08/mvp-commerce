import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/home_controller.dart';

import 'category_products_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeController = Get.find<HomeController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('categories'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (homeController.categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.category_outlined, size: 64, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text('No categories available', style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: homeController.categories.length,
          itemBuilder: (context, index) {
            final cat = homeController.categories[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryProductsScreen(
                      categoryId: cat['id'],
                      categoryName: cat['name'] ?? '',
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: cat['image_url'] != null
                            ? CachedNetworkImage(imageUrl: cat['image_url'], fit: BoxFit.cover)
                            : Center(child: Text(cat['icon'] ?? '📦', style: const TextStyle(fontSize: 32))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        cat['name'] ?? '',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
            );
          },
        );
      }),
    );
  }
}

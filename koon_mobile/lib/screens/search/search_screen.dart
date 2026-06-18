import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../services/product_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _productService.searchProducts(query, lang: context.locale.languageCode);
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'search_hint'.tr(),
            border: InputBorder.none,
            filled: false,
          ),
          onSubmitted: _search,
          onChanged: (v) {
            if (v.length > 2) _search(v);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () => _search(_searchController.text),
          ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text('search_for_products'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final product = _results[index];
                    final images = product['images'] as List? ?? [];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: images.isNotEmpty
                            ? Image.network(images[0], width: 50, height: 50, fit: BoxFit.cover)
                            : Container(width: 50, height: 50, color: AppColors.surfaceVariant, child: const Icon(Icons.image)),
                      ),
                      title: Text(product['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text('${product['discount_price'] ?? product['price']} SAR',
                          style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      onTap: () {},
                    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn(duration: 300.ms);
                  },
                ),
    );
  }
}

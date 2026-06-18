import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class BackendService {
  // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for iOS simulator and other platforms.
  static String get baseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
    } catch (_) {
      // Fallback for web or desktop environments where Platform.isAndroid might throw
    }
    return 'http://127.0.0.1:8000/api';
  }

  /// Fetches scraping configuration selectors for the target URL.
  Future<Map<String, dynamic>?> fetchScraperConfig(String url) async {
    try {
      final uri = Uri.parse('$baseUrl/config').replace(
        queryParameters: {'url': url},
      );
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Backend config fetch failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching scraper config: $e');
      return null;
    }
  }

  /// Adds a scraped product to the backend cart.
  Future<Product?> addToCart({
    required String title,
    required String price,
    required String imageUrl,
    required String url,
    required String site,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/cart');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'price': price,
          'image_url': imageUrl,
          'url': url,
          'site': site,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return Product.fromJson(jsonDecode(response.body));
      } else {
        print('Failed to add item to cart: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error adding to cart: $e');
      return null;
    }
  }

  /// Fetches all items currently in the cart.
  Future<List<Product>> fetchCart() async {
    try {
      final uri = Uri.parse('$baseUrl/cart');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        print('Failed to fetch cart: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching cart: $e');
      return [];
    }
  }

  /// Removes an item from the cart.
  Future<bool> removeFromCart(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/cart/$id');
      final response = await http.delete(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Error removing item from cart: $e');
      return false;
    }
  }
}

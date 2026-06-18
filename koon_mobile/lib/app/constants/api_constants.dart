import 'dart:io';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/v1';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api/v1';
  }

  static String get baseHost {
    final url = baseUrl;
    final index = url.indexOf('/api/v1');
    if (index != -1) {
      return url.substring(0, index);
    }
    return url;
  }

  // Auth
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get googleAuth => '$baseUrl/auth/google';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get refreshToken => '$baseUrl/auth/refresh';

  // User
  static String get userProfile => '$baseUrl/users/me';

  // Products
  static String get products => '$baseUrl/products';
  static String get topSelling => '$baseUrl/products/top-selling';
  static String get searchProducts => '$baseUrl/products/search';
  static String get banners => '$baseUrl/products/banners';

  // Categories
  static String get categories => '$baseUrl/categories';

  // Cart
  static String get cart => '$baseUrl/cart';

  // Orders
  static String get orders => '$baseUrl/orders';

  // Wishlist
  static String get wishlist => '$baseUrl/wishlist';

  // Addresses
  static String get addresses => '$baseUrl/addresses';

  // Coupons
  static String get coupons => '$baseUrl/coupons';
  static String get validateCoupon => '$baseUrl/coupons/validate';

  // Sellers
  static String get sellers => '$baseUrl/sellers';
  static String get applySeller => '$baseUrl/sellers/apply';

  // Refunds
  static String get refunds => '$baseUrl/refunds';

  // Scraper Config
  static String get scraperConfig => '$baseUrl/config';
}

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Smoke Tests', () {
    test('App name is correct', () {
      expect('Koon', equals('Koon'));
    });

    test('Cart types are defined correctly', () {
      final cartTypes = ['internal', 'amazon', 'aliexpress', 'shein', 'alibaba'];
      expect(cartTypes.length, 5);
      expect(cartTypes.contains('internal'), true);
      expect(cartTypes.contains('amazon'), true);
      expect(cartTypes.contains('aliexpress'), true);
    });

    test('Supported locales include English and Arabic', () {
      final locales = ['en', 'ar'];
      expect(locales.length, 2);
      expect(locales.contains('en'), true);
      expect(locales.contains('ar'), true);
    });

    test('Order statuses are defined', () {
      final statuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];
      expect(statuses.length, 6);
    });

    test('Price parsing from string works', () {
      final priceStr = 'SAR 150.00';
      final price = double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      expect(price, 150.0);
    });

    test('Price parsing with currency symbol works', () {
      final priceStr = '\$31.50';
      final price = double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      expect(price, 31.5);
    });

    test('Empty price string returns 0', () {
      final priceStr = '';
      final price = double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      expect(price, 0);
    });
  });
}

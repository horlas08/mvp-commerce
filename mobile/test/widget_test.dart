import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('fromJson creates a valid Product object', () {
      final json = {
        'id': 'test-123',
        'title': 'Test Headset',
        'price': 'SAR 299',
        'image_url': 'https://example.com/img.png',
        'url': 'https://amazon.sa/dp/123',
        'site': 'Amazon SA'
      };

      final product = Product.fromJson(json);

      expect(product.id, 'test-123');
      expect(product.title, 'Test Headset');
      expect(product.price, 'SAR 299');
      expect(product.imageUrl, 'https://example.com/img.png');
      expect(product.url, 'https://amazon.sa/dp/123');
      expect(product.site, 'Amazon SA');
    });

    test('toJson generates matching JSON map', () {
      final product = Product(
        id: 'test-456',
        title: 'Test Dress',
        price: 'SAR 99',
        imageUrl: 'https://example.com/dress.png',
        url: 'https://shein.com/dress',
        site: 'Shein',
      );

      final json = product.toJson();

      expect(json['id'], 'test-456');
      expect(json['title'], 'Test Dress');
      expect(json['price'], 'SAR 99');
      expect(json['image_url'], 'https://example.com/dress.png');
      expect(json['url'], 'https://shein.com/dress');
      expect(json['site'], 'Shein');
    });

    test('copyWith updates fields correctly', () {
      final product = Product(
        id: 'test-1',
        title: 'Original Title',
        price: 'Original Price',
        imageUrl: 'Original Image',
        url: 'Original URL',
        site: 'Original Site',
      );

      final updated = product.copyWith(
        title: 'New Title',
        price: 'New Price',
      );

      expect(updated.id, 'test-1');
      expect(updated.title, 'New Title');
      expect(updated.price, 'New Price');
      expect(updated.imageUrl, 'Original Image');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:koon_mobile/controllers/cart_controller.dart';

void main() {
  group('CartController effective pricing', () {
    test('uses discount_price for internal products', () {
      final item = <String, dynamic>{
        'quantity': 2,
        'is_selected': true,
        'product': <String, dynamic>{
          'price': 299.0,
          'discount_price': 249.0,
        },
      };

      expect(CartController.effectiveUnitPrice(item), 249.0);
      expect(CartController.effectiveUnitPriceRaw(item), 249.0);
    });

    test('falls back to product price when discount_price is absent or zero', () {
      expect(
        CartController.effectiveUnitPrice(<String, dynamic>{
          'product': <String, dynamic>{'price': 599.0},
        }),
        599.0,
      );
      expect(
        CartController.effectiveUnitPrice(<String, dynamic>{
          'product': <String, dynamic>{
            'price': 599.0,
            'discount_price': 0,
          },
        }),
        599.0,
      );
    });

    test('uses scraped price for external items', () {
      expect(
        CartController.effectiveUnitPrice(<String, dynamic>{
          'price': 'SAR 45.87',
        }),
        closeTo(45.87, 0.001),
      );
    });

    test('totalAmount uses the effective (discounted) unit price', () {
      final controller = CartController();
      controller.cartItems.value = <Map<String, dynamic>>[
        <String, dynamic>{
          'quantity': 2,
          'is_selected': true,
          'product': <String, dynamic>{
            'price': 299.0,
            'discount_price': 249.0,
          },
        },
        <String, dynamic>{
          'quantity': 1,
          'is_selected': true,
          'price': 'SAR 45.87',
        },
      ];

      expect(controller.totalAmount, closeTo(543.87, 0.001));
    });
  });
}

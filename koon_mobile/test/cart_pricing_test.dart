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

  group('CartController coupon discount recalculation on item removal', () {
    test('recalculates percentage discount when an internal product is removed', () {
      final controller = CartController();
      controller.selectedCartType.value = 'internal';
      controller.cartItems.value = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'item-1',
          'quantity': 2,
          'is_selected': true,
          'product': <String, dynamic>{
            'price': 200.0,
            'discount_price': 100.0, // 2 * 100 = 200
          },
        },
        <String, dynamic>{
          'id': 'item-2',
          'quantity': 1,
          'is_selected': true,
          'product': <String, dynamic>{
            'price': 100.0, // 1 * 100 = 100
          },
        },
      ];

      // Total = 200 + 100 = 300 SAR
      expect(controller.totalAmount, 300.0);

      // Apply 10% coupon
      controller.couponCode.value = 'SAVE10';
      controller.appliedCoupon.value = <String, dynamic>{
        'code': 'SAVE10',
        'type': 'percentage',
        'value': 10.0,
        'min_order_amount': 50.0,
      };
      controller.recalculateCouponDiscount();

      // Discount = 10% of 300 = 30 SAR
      expect(controller.discount, 30.0);
      expect(controller.finalTotal, 270.0);

      // Now remove item-2 (subtotal drops from 300 to 200)
      controller.cartItems.removeWhere((i) => i['id'] == 'item-2');
      controller.recalculateCouponDiscount();

      // Total is now 200 SAR
      expect(controller.totalAmount, 200.0);
      // Discount is dynamically recalculated to 10% of 200 = 20 SAR
      expect(controller.discount, 20.0);
      expect(controller.finalTotal, 180.0);
    });

    test('recalculates percentage discount when an external item is removed', () {
      final controller = CartController();
      controller.selectedCartType.value = 'shein';
      controller.cartItems.value = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'shein-1',
          'quantity': 1,
          'is_selected': true,
          'price': 'SAR 150.00',
        },
        <String, dynamic>{
          'id': 'shein-2',
          'quantity': 1,
          'is_selected': true,
          'price': 'SAR 50.00',
        },
      ];

      expect(controller.totalAmount, 200.0);

      // Apply Shein-restricted 15% coupon
      controller.couponCode.value = 'SHEIN15';
      controller.appliedCoupon.value = <String, dynamic>{
        'code': 'SHEIN15',
        'type': 'percentage',
        'value': 15.0,
        'store': 'shein',
        'min_order_amount': 100.0,
      };
      controller.recalculateCouponDiscount();

      // 15% of 200 = 30 SAR
      expect(controller.discount, 30.0);
      expect(controller.finalTotal, 170.0);

      // Remove shein-2 (drops subtotal from 200 to 150)
      controller.cartItems.removeWhere((i) => i['id'] == 'shein-2');
      controller.recalculateCouponDiscount();

      expect(controller.totalAmount, 150.0);
      // 15% of 150 = 22.50 SAR
      expect(controller.discount, 22.50);
      expect(controller.finalTotal, 127.50);
    });

    test('invalidates coupon when deleting an item drops total below min_order_amount', () {
      final controller = CartController();
      controller.selectedCartType.value = 'internal';
      controller.cartItems.value = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'item-1',
          'quantity': 1,
          'is_selected': true,
          'product': <String, dynamic>{
            'price': 100.0,
          },
        },
        <String, dynamic>{
          'id': 'item-2',
          'quantity': 1,
          'is_selected': true,
          'product': <String, dynamic>{
            'price': 40.0,
          },
        },
      ];

      // Total = 140 SAR
      expect(controller.totalAmount, 140.0);

      // Coupon requires minimum 120 SAR
      controller.couponCode.value = 'BIGORDER';
      controller.appliedCoupon.value = <String, dynamic>{
        'code': 'BIGORDER',
        'type': 'fixed',
        'value': 25.0,
        'min_order_amount': 120.0,
      };
      controller.recalculateCouponDiscount();

      expect(controller.discount, 25.0);
      expect(controller.finalTotal, 115.0);

      // Remove item-2 (40 SAR), total becomes 100 SAR, which is below 120 SAR
      controller.cartItems.removeWhere((i) => i['id'] == 'item-2');
      controller.recalculateCouponDiscount();

      expect(controller.totalAmount, 100.0);
      // Coupon must be invalidated
      expect(controller.discount, 0.0);
      expect(controller.appliedCoupon.value, isNull);
      expect(controller.couponCode.value, isEmpty);
      expect(controller.couponError.value.isNotEmpty, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pos/features/orders/data/create_order_request.dart';
import 'package:pos/features/orders/domain/order_entity.dart';

void main() {
  group('CreateOrderRequest', () {
    test('serializes to the POST /orders contract', () {
      const request = CreateOrderRequest(
        branchId: 'branch-central',
        orderType: OrderType.dineIn,
        tableNumber: 'Стол 3',
        comment: 'Без лука',
        items: [
          OrderItemRequest(
            menuItemId: 'item-philadelphia',
            quantity: 2,
            selectedModifiers: [
              SelectedModifierRequest(modifierItemId: 'mi-spicy'),
            ],
          ),
        ],
      );

      expect(request.toJson(), {
        'branchId': 'branch-central',
        'orderType': 'DINE_IN',
        'tableNumber': 'Стол 3',
        'comment': 'Без лука',
        'items': [
          {
            'menuItemId': 'item-philadelphia',
            'quantity': 2,
            'selectedModifiers': [
              {'modifierItemId': 'mi-spicy', 'quantity': 1},
            ],
          },
        ],
      });
    });

    test('omits optional fields for takeaway orders', () {
      const request = CreateOrderRequest(
        branchId: 'branch-central',
        orderType: OrderType.takeaway,
        items: [OrderItemRequest(menuItemId: 'item-1', quantity: 1)],
      );

      final json = request.toJson();
      expect(json['orderType'], 'TAKEAWAY');
      expect(json.containsKey('tableNumber'), isFalse);
      expect(json.containsKey('comment'), isFalse);
    });
  });

  group('OrderEntity', () {
    test('parses the 201 Created response', () {
      final order = OrderEntity.fromJson(const {
        'id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        'orderNumber': 1005,
        'status': 'CONFIRMED',
        'totalAmount': 470.0,
      });

      expect(order.orderNumber, '1005');
      expect(order.status, 'CONFIRMED');
      expect(order.totalAmount.minorUnits, 47000);
    });
  });
}

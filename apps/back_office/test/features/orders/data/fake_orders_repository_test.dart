import 'package:back_office/features/orders/data/fake_orders_repository.dart';
import 'package:back_office/features/orders/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeOrdersRepository repository;

  setUp(() {
    repository = FakeOrdersRepository(latency: Duration.zero);
  });

  test('fetchOrders returns all demo orders newest first', () async {
    final page = await repository.fetchOrders(branchId: 'branch-center');

    expect(page.total, 7);
    expect(page.orders.length, 7);
    for (var i = 0; i + 1 < page.orders.length; i++) {
      expect(
        page.orders[i].createdAt.isBefore(page.orders[i + 1].createdAt),
        isFalse,
        reason: 'orders must be sorted by createdAt desc',
      );
    }
  });

  test('fetchOrders filters by status', () async {
    final page = await repository.fetchOrders(
      branchId: 'branch-center',
      status: OrderStatus.completed,
    );

    expect(page.total, greaterThan(0));
    expect(
      page.orders.every((o) => o.status == OrderStatus.completed),
      isTrue,
    );
  });

  test('fetchOrders paginates with contract PageMeta', () async {
    final first = await repository.fetchOrders(
      branchId: 'branch-center',
      limit: 3,
    );
    final second = await repository.fetchOrders(
      branchId: 'branch-center',
      page: 2,
      limit: 3,
    );

    expect(first.page, 1);
    expect(first.totalPages, 3);
    expect(first.hasMore, isTrue);
    expect(first.orders.length, 3);
    expect(second.page, 2);
    expect(second.orders.length, 3);
    expect(
      first.orders.map((o) => o.id).toSet().intersection(
        second.orders.map((o) => o.id).toSet(),
      ),
      isEmpty,
    );
  });

  test('fetchOrderPayment returns null when no payment exists', () async {
    expect(await repository.fetchOrderPayment(orderId: 'ord-1'), isNull);
    expect(await repository.fetchOrderPayment(orderId: 'unknown'), isNull);
  });

  test('fetchOrderPayment returns the registered payment', () async {
    final payment = await repository.fetchOrderPayment(orderId: 'ord-2');

    expect(payment, isNotNull);
    expect(payment!.orderId, 'ord-2');
    expect(payment.idempotenceKey, isNotEmpty);
  });
}

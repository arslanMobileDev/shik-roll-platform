import '../../../core/utils/money.dart';
import 'models/order.dart';
import 'models/order_payment.dart';
import 'orders_repository.dart';

/// In-memory demo repository used while the backend is offline.
///
/// Order timestamps are derived from [DateTime.now] so the journal's
/// date filters ("Сегодня", "Вчера", "7 дней") always have demo data.
final class FakeOrdersRepository implements OrdersRepository {
  FakeOrdersRepository({this.latency = const Duration(milliseconds: 200)});

  final Duration latency;

  static const int pageSize = 50;

  List<Order> _seed() {
    final now = DateTime.now();
    // Calendar-day anchored timestamps so the journal's period filters
    // ("Сегодня", "Вчера", "7 дней") have demo data at any run time.
    DateTime daysAgo(int days, int hour) =>
        DateTime(now.year, now.month, now.day - days, hour);
    Order order(
      String id,
      String number,
      OrderStatus status,
      OrderType type,
      int totalMinor,
      DateTime createdAt,
      List<OrderItem> items, {
      String? tableNumber,
      String? deliveryAddress,
      String? comment,
    }) => Order(
      id: id,
      orderNumber: number,
      status: status,
      type: type,
      brandId: 'shik-roll',
      branchId: 'branch-center',
      subtotalAmount: Money(totalMinor),
      totalAmount: Money(totalMinor),
      currency: 'RUB',
      createdAt: createdAt,
      tableNumber: tableNumber,
      deliveryAddress: deliveryAddress,
      comment: comment,
      items: items,
    );

    OrderItem item(
      String id,
      String name,
      int qty,
      int unitMinor, {
      List<OrderItemModifier> modifiers = const [],
    }) => OrderItem(
      id: id,
      menuItemId: 'menu-$id',
      name: name,
      quantity: qty,
      unitPrice: Money(unitMinor),
      totalAmount: Money(unitMinor * qty),
      modifiers: modifiers,
    );

    return [
      order('ord-1', 'A-1042', OrderStatus.newOrder, OrderType.dineIn, 84800,
          now.subtract(const Duration(minutes: 12)), [
        item('oi-1', 'Филадельфия классик', 1, 44900),
        item('oi-2', 'Калифорния с креветкой', 1, 39900),
      ], tableNumber: '12'),
      order('ord-2', 'A-1041', OrderStatus.cooking, OrderType.takeaway, 57800,
          now.subtract(const Duration(minutes: 35)), [
        item('oi-3', 'ШИК бургер', 1, 34900, modifiers: const [
          OrderItemModifier(
            id: 'm-1',
            name: 'Доп. сыр чеддер',
            priceDelta: Money(6000),
            quantity: 1,
          ),
        ]),
        item('oi-4', 'Морс облепиховый 0,4 л', 1, 12900),
        item('oi-5', 'Картофель фри', 1, 14900),
      ]),
      order('ord-3', 'A-1040', OrderStatus.ready, OrderType.delivery, 129900,
          now.subtract(const Duration(hours: 1, minutes: 20)), [
        item('oi-6', 'Сет «Халяль Микс»', 1, 129900),
      ], deliveryAddress: 'ул. Баумана, 42, кв. 15', comment: 'Позвонить за 10 минут'),
      order('ord-4', 'A-1039', OrderStatus.completed, OrderType.dineIn, 79800,
          now.subtract(const Duration(hours: 3)), [
        item('oi-7', 'Калифорния с креветкой', 2, 39900),
      ], tableNumber: '4'),
      order('ord-5', 'A-1036', OrderStatus.completed, OrderType.takeaway, 24900,
          daysAgo(1, 18), [
        item('oi-8', 'Чикен стрипсы', 1, 24900),
      ]),
      order('ord-6', 'A-1031', OrderStatus.cancelled, OrderType.delivery, 44900,
          daysAgo(2, 12), [
        item('oi-9', 'Филадельфия классик', 1, 44900),
      ], deliveryAddress: 'пр. Победы, 8', comment: 'Клиент отменил по телефону'),
      order('ord-7', 'A-1024', OrderStatus.completed, OrderType.dineIn, 159600,
          daysAgo(5, 13), [
        item('oi-10', 'Сет «Халяль Микс»', 1, 129900),
        item('oi-11', 'Спайси ролл с цыплёнком', 1, 32900),
      ], tableNumber: '7'),
    ];
  }

  late final List<Order> _orders = _seed();

  late final Map<String, OrderPayment?> _payments = {
    'ord-1': null,
    'ord-2': OrderPayment(
      id: 'pay-2',
      orderId: 'ord-2',
      provider: PaymentProvider.yookassa,
      status: PaymentStatus.succeeded,
      amount: const Money(57800),
      currency: 'RUB',
      idempotenceKey: 'ord-2-payment',
      externalPaymentId: '2f9a1c00-0015-5000-9000-1d3f5a7b9c01',
      createdAt: DateTime.now().subtract(const Duration(minutes: 34)),
    ),
    'ord-4': OrderPayment(
      id: 'pay-4',
      orderId: 'ord-4',
      provider: PaymentProvider.cash,
      status: PaymentStatus.succeeded,
      amount: const Money(79800),
      currency: 'RUB',
      idempotenceKey: 'ord-4-payment',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    'ord-5': OrderPayment(
      id: 'pay-5',
      orderId: 'ord-5',
      provider: PaymentProvider.terminal,
      status: PaymentStatus.succeeded,
      amount: const Money(24900),
      currency: 'RUB',
      idempotenceKey: 'ord-5-payment',
      externalPaymentId: 'T-88213',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
    'ord-6': OrderPayment(
      id: 'pay-6',
      orderId: 'ord-6',
      provider: PaymentProvider.yookassa,
      status: PaymentStatus.canceled,
      amount: const Money(44900),
      currency: 'RUB',
      idempotenceKey: 'ord-6-payment',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  };

  @override
  Future<OrdersPage> fetchOrders({
    required String branchId,
    OrderStatus? status,
    int page = 1,
    int limit = pageSize,
  }) async {
    await Future<void>.delayed(latency);
    final filtered = [
      for (final order in _orders)
        if (status == null || order.status == status) order,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = (page - 1) * limit;
    final slice = start >= filtered.length
        ? <Order>[]
        : filtered.sublist(
            start,
            start + limit > filtered.length ? filtered.length : start + limit,
          );
    final totalPages = filtered.isEmpty ? 1 : (filtered.length / limit).ceil();
    return OrdersPage(
      orders: slice,
      page: page,
      totalPages: totalPages,
      total: filtered.length,
    );
  }

  @override
  Future<OrderPayment?> fetchOrderPayment({required String orderId}) async {
    await Future<void>.delayed(latency);
    return _payments[orderId];
  }
}

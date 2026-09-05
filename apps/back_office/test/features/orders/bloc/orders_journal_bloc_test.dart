import 'package:back_office/core/utils/money.dart';
import 'package:back_office/features/orders/bloc/orders_journal_bloc.dart';
import 'package:back_office/features/orders/bloc/orders_journal_event.dart';
import 'package:back_office/features/orders/bloc/orders_journal_state.dart';
import 'package:back_office/features/orders/data/models/order.dart';
import 'package:back_office/features/orders/data/models/order_payment.dart';
import 'package:back_office/features/orders/data/orders_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements OrdersRepository {}

Order _order(
  String id,
  OrderStatus status,
  DateTime createdAt, {
  int totalMinor = 10000,
}) => Order(
  id: id,
  orderNumber: 'N-$id',
  status: status,
  type: OrderType.takeaway,
  brandId: 'brand',
  branchId: 'b1',
  subtotalAmount: Money(totalMinor),
  totalAmount: Money(totalMinor),
  currency: 'RUB',
  createdAt: createdAt,
);

OrdersPage _page(
  List<Order> orders, {
  int page = 1,
  int totalPages = 1,
  int? total,
}) => OrdersPage(
  orders: orders,
  page: page,
  totalPages: totalPages,
  total: total ?? orders.length,
);

void main() {
  late _MockRepository repository;

  final now = DateTime.now();
  // Calendar-day anchored fixtures: stable period-filter assertions at any
  // run time (a raw `now - 24h` crosses two days around midnight).
  final todayOrder = _order('o1', OrderStatus.newOrder, now);
  final yesterdayOrder = _order(
    'o2',
    OrderStatus.completed,
    DateTime(now.year, now.month, now.day - 1, 12),
  );
  final oldOrder = _order(
    'o3',
    OrderStatus.cancelled,
    DateTime(now.year, now.month, now.day - 10, 12),
  );

  final payment = OrderPayment(
    id: 'p1',
    orderId: 'o1',
    provider: PaymentProvider.yookassa,
    status: PaymentStatus.succeeded,
    amount: const Money(10000),
    currency: 'RUB',
    idempotenceKey: 'o1-payment',
    createdAt: now,
  );

  setUp(() {
    repository = _MockRepository();
  });

  OrdersJournalBloc buildBloc() => OrdersJournalBloc(repository: repository);

  group('OrdersJournalRequested', () {
    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'emits loading then ready with first page',
      setUp: () {
        when(() => repository.fetchOrders(branchId: 'b1'))
            .thenAnswer((_) async => _page([todayOrder, yesterdayOrder]));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const OrdersJournalRequested(branchId: 'b1')),
      expect: () => [
        isA<OrdersJournalState>()
            .having((s) => s.status, 'status', OrdersJournalStatus.loading)
            .having((s) => s.branchId, 'branchId', 'b1'),
        isA<OrdersJournalState>()
            .having((s) => s.status, 'status', OrdersJournalStatus.ready)
            .having((s) => s.orders.length, 'orders', 2),
      ],
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'emits loading then failure on repository error',
      setUp: () {
        when(() => repository.fetchOrders(branchId: 'b1'))
            .thenThrow(const OrdersApiException('boom'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const OrdersJournalRequested(branchId: 'b1')),
      expect: () => [
        isA<OrdersJournalState>()
            .having((s) => s.status, 'status', OrdersJournalStatus.loading),
        isA<OrdersJournalState>()
            .having((s) => s.status, 'status', OrdersJournalStatus.failure)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('OrdersStatusFilterChanged', () {
    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'refetches with the status query param',
      setUp: () {
        when(
          () => repository.fetchOrders(
            branchId: 'b1',
            status: OrderStatus.cooking,
          ),
        ).thenAnswer((_) async => _page([todayOrder]));
      },
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder, yesterdayOrder],
        total: 2,
      ),
      act: (bloc) =>
          bloc.add(const OrdersStatusFilterChanged(OrderStatus.cooking)),
      expect: () => [
        isA<OrdersJournalState>()
            .having((s) => s.status, 'status', OrdersJournalStatus.loading)
            .having(
              (s) => s.statusFilter,
              'statusFilter',
              OrderStatus.cooking,
            ),
        isA<OrdersJournalState>()
            .having((s) => s.status, 'status', OrdersJournalStatus.ready)
            .having((s) => s.orders, 'orders', [todayOrder]),
      ],
      verify: (_) {
        verify(
          () => repository.fetchOrders(
            branchId: 'b1',
            status: OrderStatus.cooking,
          ),
        ).called(1);
      },
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'is a no-op when the status is unchanged',
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        statusFilter: OrderStatus.cooking,
      ),
      act: (bloc) =>
          bloc.add(const OrdersStatusFilterChanged(OrderStatus.cooking)),
      expect: () => <OrdersJournalState>[],
      verify: (_) {
        verifyNever(() => repository.fetchOrders(branchId: 'b1'));
      },
    );
  });

  group('OrdersDateFilterChanged', () {
    final seeded = OrdersJournalState(
      status: OrdersJournalStatus.ready,
      branchId: 'b1',
      orders: [todayOrder, yesterdayOrder, oldOrder],
      total: 3,
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'today keeps only orders created since midnight',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) =>
          bloc.add(const OrdersDateFilterChanged(OrdersDateFilter.today)),
      expect: () => [
        isA<OrdersJournalState>().having(
          (s) => s.visibleOrders,
          'visible',
          [todayOrder],
        ),
      ],
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'last7Days hides orders older than a week',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) =>
          bloc.add(const OrdersDateFilterChanged(OrdersDateFilter.last7Days)),
      expect: () => [
        isA<OrdersJournalState>().having(
          (s) => s.visibleOrders,
          'visible',
          [todayOrder, yesterdayOrder],
        ),
      ],
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'customDay keeps only the picked day',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        OrdersDateFilterChanged(
          OrdersDateFilter.customDay,
          customDay: now.subtract(const Duration(days: 1)),
        ),
      ),
      expect: () => [
        isA<OrdersJournalState>().having(
          (s) => s.visibleOrders,
          'visible',
          [yesterdayOrder],
        ),
      ],
    );
  });

  group('OrdersJournalNextPageRequested', () {
    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'appends the next page and updates pagination meta',
      setUp: () {
        when(() => repository.fetchOrders(branchId: 'b1', page: 2))
            .thenAnswer((_) async => _page([oldOrder], page: 2, totalPages: 2, total: 3));
      },
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder, yesterdayOrder],
        page: 1,
        totalPages: 2,
        total: 3,
      ),
      act: (bloc) => bloc.add(const OrdersJournalNextPageRequested()),
      expect: () => [
        isA<OrdersJournalState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<OrdersJournalState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', false)
            .having((s) => s.orders, 'orders', [
              todayOrder,
              yesterdayOrder,
              oldOrder,
            ])
            .having((s) => s.page, 'page', 2)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'is a no-op when all pages are loaded',
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder],
        page: 1,
        totalPages: 1,
        total: 1,
      ),
      act: (bloc) => bloc.add(const OrdersJournalNextPageRequested()),
      expect: () => <OrdersJournalState>[],
      verify: (_) {
        verifyNever(() => repository.fetchOrders(branchId: 'b1', page: 2));
      },
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'surfaces a notice when the next page fails',
      setUp: () {
        when(() => repository.fetchOrders(branchId: 'b1', page: 2))
            .thenThrow(const OrdersApiException('network'));
      },
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder],
        page: 1,
        totalPages: 2,
        total: 2,
      ),
      act: (bloc) => bloc.add(const OrdersJournalNextPageRequested()),
      expect: () => [
        isA<OrdersJournalState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<OrdersJournalState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', false)
            .having((s) => s.notice, 'notice', contains('Не удалось')),
      ],
    );
  });

  group('OrderDetailsOpened/Closed', () {
    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'loads the payment of the opened order',
      setUp: () {
        when(() => repository.fetchOrderPayment(orderId: 'o1'))
            .thenAnswer((_) async => payment);
      },
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder],
      ),
      act: (bloc) => bloc.add(const OrderDetailsOpened('o1')),
      expect: () => [
        isA<OrdersJournalState>()
            .having((s) => s.selectedOrderId, 'selectedOrderId', 'o1')
            .having(
              (s) => s.paymentStatus,
              'paymentStatus',
              OrderPaymentStatus.loading,
            ),
        isA<OrdersJournalState>()
            .having(
              (s) => s.paymentStatus,
              'paymentStatus',
              OrderPaymentStatus.ready,
            )
            .having((s) => s.payment, 'payment', payment),
      ],
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'keeps payment null when none is registered',
      setUp: () {
        when(() => repository.fetchOrderPayment(orderId: 'o1'))
            .thenAnswer((_) async => null);
      },
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder],
      ),
      act: (bloc) => bloc.add(const OrderDetailsOpened('o1')),
      expect: () => [
        isA<OrdersJournalState>().having(
          (s) => s.paymentStatus,
          'paymentStatus',
          OrderPaymentStatus.loading,
        ),
        isA<OrdersJournalState>()
            .having(
              (s) => s.paymentStatus,
              'paymentStatus',
              OrderPaymentStatus.ready,
            )
            .having((s) => s.payment, 'payment', isNull),
      ],
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'emits failure state when the payment request fails',
      setUp: () {
        when(() => repository.fetchOrderPayment(orderId: 'o1'))
            .thenThrow(const OrdersApiException('network'));
      },
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder],
      ),
      act: (bloc) => bloc.add(const OrderDetailsOpened('o1')),
      expect: () => [
        isA<OrdersJournalState>().having(
          (s) => s.paymentStatus,
          'paymentStatus',
          OrderPaymentStatus.loading,
        ),
        isA<OrdersJournalState>().having(
          (s) => s.paymentStatus,
          'paymentStatus',
          OrderPaymentStatus.failure,
        ),
      ],
    );

    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'closed clears selection and payment',
      build: buildBloc,
      seed: () => OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        orders: [todayOrder],
        selectedOrderId: 'o1',
        paymentStatus: OrderPaymentStatus.ready,
        payment: payment,
      ),
      act: (bloc) => bloc.add(const OrderDetailsClosed()),
      expect: () => [
        isA<OrdersJournalState>()
            .having((s) => s.selectedOrderId, 'selectedOrderId', isNull)
            .having((s) => s.payment, 'payment', isNull)
            .having(
              (s) => s.paymentStatus,
              'paymentStatus',
              OrderPaymentStatus.idle,
            ),
      ],
    );
  });

  group('OrdersJournalNoticeConsumed', () {
    blocTest<OrdersJournalBloc, OrdersJournalState>(
      'clears the notice',
      build: buildBloc,
      seed: () => const OrdersJournalState(
        status: OrdersJournalStatus.ready,
        branchId: 'b1',
        notice: 'hi',
      ),
      act: (bloc) => bloc.add(const OrdersJournalNoticeConsumed()),
      expect: () => [
        isA<OrdersJournalState>().having((s) => s.notice, 'notice', isNull),
      ],
    );
  });
}

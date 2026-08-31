import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/utils/money.dart';
import 'package:pos/features/cart/bloc/cart_bloc.dart';
import 'package:pos/features/cart/bloc/cart_event.dart';
import 'package:pos/features/cart/bloc/cart_state.dart';
import 'package:pos/features/cart/domain/cart_line.dart';
import 'package:pos/features/orders/data/create_order_request.dart';
import 'package:pos/features/orders/data/fake_orders_repository.dart';
import 'package:pos/features/orders/data/orders_repository.dart';
import 'package:pos/features/orders/domain/order_entity.dart';

import '../../../helpers/test_fixtures.dart';

/// Captures the checkout payload and always succeeds with order #1005.
final class _RecordingOrdersRepository implements OrdersRepository {
  CreateOrderRequest? lastRequest;
  int calls = 0;

  @override
  Future<OrderEntity> createOrder(CreateOrderRequest request) async {
    calls++;
    lastRequest = request;
    await Future<void>.delayed(Duration.zero);
    return const OrderEntity(
      id: 'order-1',
      orderNumber: '1005',
      status: 'NEW',
      totalAmount: Money.kopecks(39000),
    );
  }
}

final class _FailingOrdersRepository implements OrdersRepository {
  @override
  Future<OrderEntity> createOrder(CreateOrderRequest request) =>
      throw const OrdersException('Сервер недоступен');
}

void main() {
  final spicy = SelectedModifier(
    groupId: 'mg-sauce',
    groupName: 'Соус',
    optionId: 'mi-spicy',
    optionName: 'Спайси',
    price: const Money.kopecks(4000),
  );
  final unagi = SelectedModifier(
    groupId: 'mg-sauce',
    groupName: 'Соус',
    optionId: 'mi-unagi',
    optionName: 'Унаги',
    price: const Money.kopecks(4000),
  );

  CartBloc buildBloc() =>
      CartBloc(ordersRepository: FakeOrdersRepository(latency: Duration.zero));

  group('CartBloc', () {
    blocTest<CartBloc, CartState>(
      'adds an item with its effective price',
      build: buildBloc,
      act: (bloc) => bloc.add(CartItemAdded(item: testMenuItem())),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.itemCount, 1);
        expect(bloc.state.total, const Money.kopecks(39000));
      },
    );

    blocTest<CartBloc, CartState>(
      'merges repeated adds of the same configuration into one line',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(CartItemAdded(item: testMenuItem())),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.quantity, 3);
        expect(bloc.state.total, const Money.kopecks(39000 * 3));
      },
    );

    blocTest<CartBloc, CartState>(
      'keeps different modifier configurations on separate lines',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [spicy])),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(2));
      },
    );

    blocTest<CartBloc, CartState>(
      'includes modifier surcharges in the total (exact decimal math)',
      build: buildBloc,
      act: (bloc) => bloc.add(
        CartItemAdded(item: testMenuItem(), modifiers: [spicy, unagi]),
      ),
      verify: (bloc) {
        final line = bloc.state.lines.single;
        // 390,00 + 40,00 + 40,00 = 470,00 ₽
        expect(line.unitPrice, const Money.kopecks(47000));
        expect(bloc.state.total, const Money.kopecks(47000));
      },
    );

    blocTest<CartBloc, CartState>(
      'modifier order does not affect line identity',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [spicy, unagi]))
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [unagi, spicy])),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.quantity, 2);
      },
    );

    blocTest<CartBloc, CartState>(
      'quantity changes recalculate the line and cart totals',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(CartItemAdded(item: testMenuItem()));
        await Future<void>.delayed(Duration.zero);
        final key = bloc.state.lines.single.key;
        bloc.add(CartLineQuantityChanged(key, 4));
      },
      verify: (bloc) {
        expect(bloc.state.itemCount, 4);
        expect(bloc.state.total, const Money.kopecks(39000 * 4));
      },
    );

    blocTest<CartBloc, CartState>(
      'quantity of zero removes the line',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(CartItemAdded(item: testMenuItem()));
        await Future<void>.delayed(Duration.zero);
        final key = bloc.state.lines.single.key;
        bloc.add(CartLineQuantityChanged(key, 0));
      },
      verify: (bloc) => expect(bloc.state.isEmpty, isTrue),
    );

    blocTest<CartBloc, CartState>(
      'refuses to add unavailable or stop-listed items',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem(isAvailable: false)))
        ..add(CartItemAdded(item: testMenuItem(stopListed: true))),
      verify: (bloc) => expect(bloc.state.isEmpty, isTrue),
    );

    blocTest<CartBloc, CartState>(
      'clear empties the cart',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(const CartCleared()),
      verify: (bloc) {
        expect(bloc.state.isEmpty, isTrue);
        expect(bloc.state.total, Money.zero);
      },
    );
  });

  group('CartBloc checkout', () {
    blocTest<CartBloc, CartState>(
      'emits inProgress then success, clears the cart and keeps the order',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(
          const CheckoutSubmitted(
            branchId: 'branch-central',
            orderType: OrderType.takeaway,
          ),
        ),
      skip: 1, // CartItemAdded emission
      expect: () => [
        isA<CartState>().having(
          (s) => s.checkoutStatus,
          'checkoutStatus',
          CheckoutStatus.inProgress,
        ),
        isA<CartState>()
            .having(
              (s) => s.checkoutStatus,
              'checkoutStatus',
              CheckoutStatus.success,
            )
            .having((s) => s.isEmpty, 'cart cleared', true)
            .having((s) => s.completedOrder?.orderNumber, 'orderNumber', '1005')
            .having((s) => s.completedOrder?.status, 'order status', 'NEW'),
      ],
    );

    blocTest<CartBloc, CartState>(
      'failure keeps the cart and exposes the error message',
      build: () => CartBloc(ordersRepository: _FailingOrdersRepository()),
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(
          const CheckoutSubmitted(
            branchId: 'branch-central',
            orderType: OrderType.takeaway,
          ),
        ),
      skip: 1,
      expect: () => [
        isA<CartState>().having(
          (s) => s.checkoutStatus,
          'checkoutStatus',
          CheckoutStatus.inProgress,
        ),
        isA<CartState>()
            .having(
              (s) => s.checkoutStatus,
              'checkoutStatus',
              CheckoutStatus.failure,
            )
            .having((s) => s.lines, 'lines preserved', isNotEmpty)
            .having((s) => s.checkoutError, 'error', 'Сервер недоступен'),
      ],
    );

    test('maps cart lines and modifiers to the POST /orders payload', () async {
      final repository = _RecordingOrdersRepository();
      final bloc = CartBloc(ordersRepository: repository)
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [spicy]))
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [spicy]));
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.lines.isNotEmpty);

      bloc.add(
        const CheckoutSubmitted(
          branchId: 'branch-central',
          orderType: OrderType.dineIn,
          tableNumber: 'Стол 3',
        ),
      );
      await bloc.stream.firstWhere(
        (s) => s.checkoutStatus == CheckoutStatus.success,
      );

      final request = repository.lastRequest!;
      expect(request.branchId, 'branch-central');
      expect(request.orderType, OrderType.dineIn);
      expect(request.tableNumber, 'Стол 3');
      expect(request.items.single.menuItemId, 'item-philadelphia');
      expect(request.items.single.quantity, 2);
      expect(
        request.items.single.selectedModifiers.single.modifierItemId,
        'mi-spicy',
      );
    });

    test('ignores checkout when the cart is empty', () async {
      final repository = _RecordingOrdersRepository();
      final bloc = CartBloc(ordersRepository: repository);
      addTearDown(bloc.close);

      bloc.add(
        const CheckoutSubmitted(
          branchId: 'branch-central',
          orderType: OrderType.takeaway,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.calls, 0);
      expect(bloc.state.checkoutStatus, CheckoutStatus.idle);
    });

    test('ignores a second checkout while one is in progress', () async {
      final repository = _RecordingOrdersRepository();
      final bloc = CartBloc(ordersRepository: repository)
        ..add(CartItemAdded(item: testMenuItem()));
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.lines.isNotEmpty);

      bloc.add(
        const CheckoutSubmitted(
          branchId: 'branch-central',
          orderType: OrderType.takeaway,
        ),
      );
      bloc.add(
        const CheckoutSubmitted(
          branchId: 'branch-central',
          orderType: OrderType.takeaway,
        ),
      );
      await bloc.stream.firstWhere(
        (s) => s.checkoutStatus == CheckoutStatus.success,
      );

      expect(repository.calls, 1);
    });

    test('CheckoutFeedbackConsumed returns checkout to idle', () async {
      final bloc = buildBloc()..add(CartItemAdded(item: testMenuItem()));
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.lines.isNotEmpty);

      bloc.add(
        const CheckoutSubmitted(
          branchId: 'branch-central',
          orderType: OrderType.takeaway,
        ),
      );
      await bloc.stream.firstWhere(
        (s) => s.checkoutStatus == CheckoutStatus.success,
      );

      bloc.add(const CheckoutFeedbackConsumed());
      await bloc.stream.firstWhere(
        (s) => s.checkoutStatus == CheckoutStatus.idle,
      );

      expect(bloc.state.completedOrder, isNull);
      expect(bloc.state.checkoutError, isNull);
      expect(bloc.state.isEmpty, isTrue);
    });
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/data/repositories/courier_repository.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/orders/bloc/orders_cubit.dart';
import 'package:courier_mobile/features/orders/bloc/orders_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_fakes.dart';

class _MockCourierRepository extends Mock implements CourierRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(OrderStatus.ready);
  });

  group('OrdersCubit', () {
    blocTest<OrdersCubit, OrdersState>(
      'load emits OrdersLoaded with branch orders',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(),
        session: testSession,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const OrdersLoading(),
        isA<OrdersLoaded>()
            .having((s) => s.pickupOrders.length, 'ready orders', 2)
            .having((s) => s.myOrders.length, 'my delivering orders', 1),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'load failure emits OrdersFailure',
      build: () {
        final repo = _MockCourierRepository();
        when(
          () => repo.fetchActiveOrders(branchId: any(named: 'branchId')),
        ).thenThrow(Exception('network'));
        return OrdersCubit(repository: repo, session: testSession);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const OrdersLoading(),
        isA<OrdersFailure>(),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'pickupOrder moves READY order to «Мои текущие»',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(),
        session: testSession,
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.pickupOrder('order-1001');
      },
      skip: 1, // OrdersLoading
      expect: () => [
        isA<OrdersLoaded>().having((s) => s.pickupOrders.length, 'ready', 2),
        isA<OrdersLoaded>()
            .having((s) => s.pickupOrders.length, 'ready', 1)
            .having((s) => s.myOrders.length, 'mine', 2)
            .having((s) => s.updatingOrderId, 'updating', 'order-1001'),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'mine', 2)
            .having((s) => s.updatingOrderId, 'updating', isNull),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'completeOrder removes DELIVERING order from active list',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(),
        session: testSession,
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.completeOrder('order-1004');
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>().having((s) => s.myOrders.length, 'mine', 1),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'mine', 0)
            .having((s) => s.updatingOrderId, 'updating', 'order-1004'),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'mine', 0)
            .having((s) => s.updatingOrderId, 'updating', isNull),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'selectTab switches between pickup and mine',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(),
        session: testSession,
      ),
      act: (cubit) async {
        await cubit.load();
        cubit
          ..selectTab(OrdersTab.mine)
          ..selectTab(OrdersTab.pickup);
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>().having((s) => s.tab, 'tab', OrdersTab.pickup),
        isA<OrdersLoaded>().having((s) => s.tab, 'tab', OrdersTab.mine),
        isA<OrdersLoaded>().having((s) => s.tab, 'tab', OrdersTab.pickup),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'failed status update rolls back and emits failure',
      build: () {
        final repo = _MockCourierRepository();
        when(
          () => repo.fetchActiveOrders(branchId: any(named: 'branchId')),
        ).thenAnswer((_) async => [makeOrder(id: '1')]);
        when(
          () => repo.updateOrderStatus(
            orderId: any(named: 'orderId'),
            status: any(named: 'status'),
            courierId: any(named: 'courierId'),
          ),
        ).thenThrow(Exception('network'));
        return OrdersCubit(repository: repo, session: testSession);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.pickupOrder('1');
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>().having((s) => s.orders.length, 'orders', 1),
        isA<OrdersLoaded>().having(
          (s) => s.orders.first.status,
          'optimistic',
          OrderStatus.delivering,
        ),
        isA<OrdersLoaded>()
            .having((s) => s.orders.first.status, 'rollback', OrderStatus.ready)
            .having((s) => s.updatingOrderId, 'updating', isNull),
        isA<OrdersFailure>(),
        isA<OrdersLoaded>().having(
          (s) => s.orders.first.status,
          'final',
          OrderStatus.ready,
        ),
      ],
    );
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/data/models/courier_order_event.dart';
import 'package:courier_mobile/data/repositories/courier_repository.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/orders/bloc/orders_cubit.dart';
import 'package:courier_mobile/features/orders/bloc/orders_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_fakes.dart';

class _MockCourierRepository extends Mock implements CourierRepository {}

/// SSE feed controlled by hand; fetchActiveOrders is counted.
class _ManualSseRepository implements CourierRepository {
  _ManualSseRepository(this.orders);

  List<CourierOrder> orders;
  final events = StreamController<CourierOrderEvent>.broadcast();
  var fetchCount = 0;

  @override
  Future<List<CourierOrder>> fetchActiveOrders() async {
    fetchCount++;
    return orders;
  }

  @override
  Stream<CourierOrderEvent> watchOrders() => events.stream;

  @override
  Future<void> claimOrder(String orderId) async {}

  @override
  Future<void> startDelivery(String orderId) async {}

  @override
  Future<void> completeDelivery(String orderId) async {}

  // loginWithPin is never used here.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<void> dispose() => events.close();
}

CourierOrderEvent event({
  required String orderId,
  String status = 'READY',
  String timestamp = '2026-09-06T12:30:00.000Z',
}) => CourierOrderEvent(
  orderId: orderId,
  orderNumber: 'A-$orderId',
  status: status,
  branchId: 'branch-center',
  timestamp: timestamp,
);

void main() {
  group('OrdersCubit (snapshot)', () {
    blocTest<OrdersCubit, OrdersState>(
      'refresh emits OrdersLoaded with branch orders',
      build: () =>
          OrdersCubit(repository: FakeCourierRepository(), session: testSession),
      act: (cubit) => cubit.refresh(),
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>()
            .having((s) => s.availableOrders.length, 'available', 2)
            .having((s) => s.myOrders.length, 'mine', 1),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'refresh failure emits OrdersFailure',
      build: () {
        final repo = _MockCourierRepository();
        when(() => repo.fetchActiveOrders()).thenThrow(Exception('network'));
        return OrdersCubit(repository: repo, session: testSession);
      },
      act: (cubit) => cubit.refresh(),
      skip: 1,
      expect: () => [isA<OrdersFailure>()],
    );

    blocTest<OrdersCubit, OrdersState>(
      'claim moves an unassigned READY order to «Мой активный заказ»',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(
          seedOrders: [
            makeOrder(id: 'order-1'),
            makeOrder(id: 'order-2', status: OrderStatus.cooking),
          ],
        ),
        session: testSession,
      ),
      act: (cubit) async {
        await cubit.refresh();
        await cubit.claim('order-1');
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>()
            .having((s) => s.availableOrders.length, 'available', 2)
            .having((s) => s.myOrders.length, 'mine', 0),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'optimistic mine', 1)
            .having((s) => s.mutatingOrderId, 'mutating', 'order-1'),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'mine', 1)
            .having((s) => s.mutatingOrderId, 'mutating', isNull),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'claim conflict rolls back and emits failure',
      build: () {
        final repo = _MockCourierRepository();
        when(
          () => repo.fetchActiveOrders(),
        ).thenAnswer((_) async => [makeOrder(id: 'order-1')]);
        when(
          () => repo.claimOrder(any()),
        ).thenThrow(const CourierOrderConflictException());
        return OrdersCubit(repository: repo, session: testSession);
      },
      act: (cubit) async {
        await cubit.refresh();
        await cubit.claim('order-1');
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>().having((s) => s.orders.length, 'orders', 1),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'optimistic mine', 1)
            .having((s) => s.mutatingOrderId, 'mutating', 'order-1'),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'rolled back', 0)
            .having((s) => s.mutatingOrderId, 'mutating', isNull),
        isA<OrdersFailure>(),
        isA<OrdersLoaded>().having((s) => s.myOrders.length, 'final', 0),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'startDelivery moves the own READY order to ON_WAY',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(
          seedOrders: [makeOrder(id: 'order-1', courierId: testCourier.id)],
        ),
        session: testSession,
      ),
      act: (cubit) async {
        await cubit.refresh();
        await cubit.startDelivery('order-1');
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>().having(
          (s) => s.myOnWayOrder,
          'onWay before',
          isNull,
        ),
        isA<OrdersLoaded>()
            .having((s) => s.myOnWayOrder?.id, 'optimistic onWay', 'order-1')
            .having((s) => s.mutatingOrderId, 'mutating', 'order-1'),
        isA<OrdersLoaded>()
            .having((s) => s.myOnWayOrder?.id, 'onWay', 'order-1')
            .having((s) => s.mutatingOrderId, 'mutating', isNull),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'completeDelivery removes the ON_WAY order from the active list',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(
          seedOrders: [
            makeOrder(
              id: 'order-1',
              status: OrderStatus.onWay,
              courierId: testCourier.id,
            ),
          ],
        ),
        session: testSession,
      ),
      act: (cubit) async {
        await cubit.refresh();
        await cubit.completeDelivery('order-1');
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>().having((s) => s.myOrders.length, 'mine', 1),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'optimistic gone', 0)
            .having((s) => s.mutatingOrderId, 'mutating', 'order-1'),
        isA<OrdersLoaded>()
            .having((s) => s.myOrders.length, 'gone', 0)
            .having((s) => s.mutatingOrderId, 'mutating', isNull),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'selectTab switches between available and mine',
      build: () =>
          OrdersCubit(repository: FakeCourierRepository(), session: testSession),
      act: (cubit) async {
        await cubit.refresh();
        cubit
          ..selectTab(OrdersTab.mine)
          ..selectTab(OrdersTab.available);
      },
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>().having((s) => s.tab, 'tab', OrdersTab.available),
        isA<OrdersLoaded>().having((s) => s.tab, 'tab', OrdersTab.mine),
        isA<OrdersLoaded>().having((s) => s.tab, 'tab', OrdersTab.available),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'available excludes takeaway and assigned orders',
      build: () => OrdersCubit(
        repository: FakeCourierRepository(
          seedOrders: [
            makeOrder(id: '1', status: OrderStatus.ready),
            makeOrder(id: '2', status: OrderStatus.cooking),
            makeOrder(id: '3', type: OrderType.takeaway),
            makeOrder(id: '4', courierId: 'courier-other'),
          ],
        ),
        session: testSession,
      ),
      act: (cubit) => cubit.refresh(),
      skip: 1,
      expect: () => [
        isA<OrdersLoaded>()
            .having(
              (s) => s.availableOrders.map((o) => o.id).toList(),
              'available',
              ['1', '2'],
            )
            .having((s) => s.myOrders.length, 'mine', 0),
      ],
    );
  });

  group('OrdersCubit (realtime)', () {
    test('start connects SSE and flips the indicator to live on first event',
        () async {
      final repo = FakeCourierRepository(
        seedOrders: [makeOrder(id: 'order-1')],
      );
      addTearDown(repo.dispose);
      final cubit = OrdersCubit(repository: repo, session: testSession);
      addTearDown(cubit.close);

      await cubit.start();
      expect(
        (cubit.state as OrdersLoaded).realtime,
        RealtimeConnectionState.connecting,
      );

      await cubit.claim('order-1'); // the fake emits an SSE event
      await Future<void>.delayed(Duration.zero);
      expect(
        (cubit.state as OrdersLoaded).realtime,
        RealtimeConnectionState.live,
      );
    });

    test('unknown-order event triggers one debounced refresh; dupes dropped',
        () async {
      final repo = _ManualSseRepository([makeOrder(id: 'order-1')]);
      addTearDown(repo.dispose);
      final cubit = OrdersCubit(repository: repo, session: testSession);
      addTearDown(cubit.close);

      await cubit.start();
      expect(repo.fetchCount, 1);

      final evt = event(orderId: 'unknown-9');
      repo.events.add(evt);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(repo.fetchCount, 2); // one debounced resync

      // Same dedupKey — applied at most once (ADR-1617).
      repo.events.add(evt);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(repo.fetchCount, 2);
    });

    test('SSE event removes a completed order from the active list', () async {
      final repo = _ManualSseRepository([
        makeOrder(
          id: 'order-1',
          status: OrderStatus.onWay,
          courierId: testCourier.id,
        ),
      ]);
      addTearDown(repo.dispose);
      final cubit = OrdersCubit(repository: repo, session: testSession);
      addTearDown(cubit.close);

      await cubit.start();
      expect((cubit.state as OrdersLoaded).orders, hasLength(1));

      repo.events.add(event(orderId: 'order-1', status: 'COMPLETED'));
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as OrdersLoaded).orders, isEmpty);
    });

    test('three failed SSE attempts switch to the polling fallback', () async {
      final repo = _MockCourierRepository();
      when(() => repo.fetchActiveOrders()).thenAnswer((_) async => const []);
      when(
        () => repo.watchOrders(),
      ).thenAnswer((_) => Stream<CourierOrderEvent>.error(StateError('down')));
      final cubit = OrdersCubit(repository: repo, session: testSession);
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.stream
          .firstWhere(
            (s) =>
                s is OrdersLoaded &&
                s.realtime == RealtimeConnectionState.polling,
          )
          .timeout(const Duration(seconds: 15));
    });

    test('resume from background forces an immediate refresh', () async {
      final repo = _ManualSseRepository(const []);
      addTearDown(repo.dispose);
      final cubit = OrdersCubit(repository: repo, session: testSession);
      addTearDown(cubit.close);

      await cubit.start();
      expect(repo.fetchCount, 1);

      cubit.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCount, 2);
    });
  });
}

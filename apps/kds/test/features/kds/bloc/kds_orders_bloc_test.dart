import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/kds/bloc/kds_orders_bloc.dart';
import 'package:kds/features/kds/bloc/kds_orders_event.dart';
import 'package:kds/features/kds/bloc/kds_orders_state.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/data/kds_orders_repository.dart';
import 'package:kds/features/kds/data/kitchen_events_client.dart';

import '../../../helpers/test_fixtures.dart';

Future<void> settle([int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late TestKdsOrdersRepository repository;
  late TestKitchenEventsClient eventsClient;

  KdsOrdersBloc buildBloc({
    Duration? pollInterval,
    List<Duration> reconnectDelays = const [
      Duration(milliseconds: 20),
      Duration(milliseconds: 40),
      Duration(milliseconds: 80),
      Duration(milliseconds: 200),
    ],
    int maxConsecutiveFailures = 3,
  }) {
    return KdsOrdersBloc(
      repository: repository,
      eventsClient: eventsClient,
      pollInterval: pollInterval,
      reconnectDelays: reconnectDelays,
      maxConsecutiveFailures: maxConsecutiveFailures,
      now: () => kNow,
    );
  }

  KitchenOrderUpserted upsert(KdsOrder order, {int? version}) =>
      KitchenOrderUpserted(
        order: order,
        orderVersion: version ?? order.version,
        eventId: 'evt-${order.id}-${version ?? order.version}',
      );

  setUp(() {
    repository = TestKdsOrdersRepository();
    eventsClient = TestKitchenEventsClient();
  });

  group('initial snapshot', () {
    test('loads the board FIFO by status-entry time and hides non-kitchen '
        'statuses', () async {
      repository.orders = [
        buildOrder(
          id: 'newer',
          orderNumber: '102',
          confirmedAt: kNow.subtract(const Duration(minutes: 1)),
        ),
        buildOrder(
          id: 'older',
          orderNumber: '101',
          confirmedAt: kNow.subtract(const Duration(minutes: 6)),
        ),
        buildOrder(
          id: 'cooking',
          orderNumber: '103',
          status: KdsOrderStatus.cooking,
          confirmedAt: kNow.subtract(const Duration(minutes: 30)),
          cookingStartedAt: kNow.subtract(const Duration(minutes: 12)),
        ),
        buildOrder(
          id: 'done',
          orderNumber: '104',
          status: KdsOrderStatus.completed,
        ),
        buildOrder(
          id: 'new-order',
          orderNumber: '105',
          status: KdsOrderStatus.newOrder,
        ),
      ];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      final state = bloc.state;
      expect(state, isA<KdsOrdersLoaded>());
      // NEW/CONFIRMED and COOKING are sorted by their status-entry time;
      // terminal COMPLETED orders never reach the board.
      expect(state.orders!.map((o) => o.id), [
        'cooking',
        'older',
        'new-order',
        'newer',
      ]);
      expect(state.freshOrderIds, isEmpty, reason: 'no alerts on initial load');
      expect(eventsClient.connectCount, 1);
    });

    test('derives the server clock offset from serverTime', () async {
      repository
        ..orders = [buildOrder()]
        ..serverTime = kNow.add(const Duration(seconds: 45));
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      expect(bloc.state.serverClockOffset, const Duration(seconds: 45));
    });

    test('initial load error surfaces the Error state', () async {
      repository.fetchError = Exception('offline');
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      expect(bloc.state, isA<KdsOrdersError>());
    });
  });

  group('SSE stream', () {
    test('connected signal flips the board to live', () async {
      repository.orders = [buildOrder()];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();
      expect(bloc.state.connection, KdsConnectionStatus.connecting);

      eventsClient.emitSignal(const KitchenStreamConnected());
      await settle();
      expect(bloc.state.connection, KdsConnectionStatus.live);
    });

    test('upsert of a new CONFIRMED order marks it fresh', () async {
      repository.orders = [buildOrder(id: 'a')];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      eventsClient.emitSignal(
        upsert(buildOrder(id: 'fresh', orderNumber: '777', version: 2)),
      );
      await settle();

      expect(bloc.state.orders!.map((o) => o.id), contains('fresh'));
      expect(bloc.state.freshOrderIds, {'fresh'});
    });

    test('upsert of a non-CONFIRMED newcomer is silent', () async {
      repository.orders = [buildOrder(id: 'a')];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      eventsClient.emitSignal(
        upsert(
          buildOrder(
            id: 'b',
            status: KdsOrderStatus.cooking,
            version: 3,
            cookingStartedAt: kNow,
          ),
        ),
      );
      await settle();

      expect(bloc.state.orders!.map((o) => o.id), contains('b'));
      expect(bloc.state.freshOrderIds, isEmpty);
    });

    test('stale versions are dropped (version dedupe)', () async {
      repository.orders = [buildOrder(id: 'a', version: 5)];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      eventsClient.emitSignal(
        upsert(
          buildOrder(id: 'a', version: 4, status: KdsOrderStatus.cooking),
          version: 4,
        ),
      );
      await settle();

      expect(bloc.state.orders!.single.status, KdsOrderStatus.confirmed);
      expect(bloc.state.orders!.single.version, 5);
    });

    test('upsert with a newer version replaces the local order', () async {
      repository.orders = [buildOrder(id: 'a', version: 5)];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      eventsClient.emitSignal(
        upsert(
          buildOrder(
            id: 'a',
            version: 6,
            status: KdsOrderStatus.cooking,
            cookingStartedAt: kNow,
          ),
          version: 6,
        ),
      );
      await settle();

      expect(bloc.state.orders!.single.status, KdsOrderStatus.cooking);
      expect(bloc.state.orders!.single.version, 6);
      expect(bloc.state.freshOrderIds, isEmpty);
    });

    test('removed event takes the order off the board', () async {
      repository.orders = [buildOrder(id: 'a'), buildOrder(id: 'b')];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      eventsClient.emitSignal(
        const KitchenOrderRemoved(
          orderId: 'a',
          orderVersion: 7,
          eventId: 'evt-a-7',
        ),
      );
      await settle();

      expect(bloc.state.orders!.map((o) => o.id), ['b']);
    });
  });

  group('recovery contract (ADR-1618)', () {
    test(
      'a dropped stream reconnects and refreshes the snapshot silently',
      () async {
        repository.orders = [buildOrder(id: 'a')];
        final bloc = buildBloc()..add(const KdsOrdersStarted());
        addTearDown(bloc.close);
        await settle();
        eventsClient.emitSignal(const KitchenStreamConnected());
        await settle();
        expect(repository.fetchCount, 1);

        eventsClient.dropStream();
        await settle();
        expect(bloc.state.connection, KdsConnectionStatus.connecting);

        // Backoff fires → a fresh connection is dialled.
        await Future<void>.delayed(const Duration(milliseconds: 90));
        expect(eventsClient.connectCount, 2);

        // A brand-new CONFIRMED order is present in the re-sync snapshot.
        repository.orders = [
          ...repository.orders,
          buildOrder(id: 'during-drop', orderNumber: '999'),
        ];
        eventsClient.emitSignal(const KitchenStreamConnected());
        await settle();

        expect(bloc.state.connection, KdsConnectionStatus.live);
        expect(repository.fetchCount, 2, reason: 'snapshot after reconnect');
        expect(bloc.state.orders!.map((o) => o.id), contains('during-drop'));
        expect(
          bloc.state.freshOrderIds,
          isEmpty,
          reason: 'no new-order alerts on a reconnect snapshot',
        );
      },
    );

    test(
      'three failed reconnects fall back to polling; recovery stops it',
      () async {
        repository.orders = [buildOrder(id: 'a')];
        final bloc = buildBloc(
          pollInterval: const Duration(milliseconds: 30),
          maxConsecutiveFailures: 3,
        )..add(const KdsOrdersStarted());
        addTearDown(bloc.close);
        await settle();
        eventsClient.emitSignal(const KitchenStreamConnected());
        await settle();
        final fetchesAfterStart = repository.fetchCount;

        // Three consecutive drops, each followed by a failed dial (the
        // stream closes before any Connected signal).
        for (var i = 0; i < 3; i++) {
          eventsClient.dropStream();
          await settle();
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }

        expect(eventsClient.connectCount, greaterThanOrEqualTo(4));
        expect(bloc.state.connection, KdsConnectionStatus.polling);

        // Fallback polling refreshes the snapshot on its own.
        await Future<void>.delayed(const Duration(milliseconds: 90));
        expect(repository.fetchCount, greaterThan(fetchesAfterStart));

        // SSE recovers: snapshot is refreshed once and polling stops.
        final fetchesBeforeRecovery = repository.fetchCount;
        eventsClient.emitSignal(const KitchenStreamConnected());
        await settle();
        expect(bloc.state.connection, KdsConnectionStatus.live);
        expect(repository.fetchCount, fetchesBeforeRecovery + 1);
        final fetchesAtRecovery = repository.fetchCount;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          repository.fetchCount,
          fetchesAtRecovery,
          reason: 'polling must stop once SSE is live again',
        );
      },
    );

    test('polling marks newly CONFIRMED orders as fresh', () async {
      repository.orders = [buildOrder(id: 'a')];
      final bloc = buildBloc(
        pollInterval: const Duration(milliseconds: 30),
        maxConsecutiveFailures: 1,
      )..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();
      eventsClient.emitSignal(const KitchenStreamConnected());
      await settle();

      // One failure is enough here → polling starts.
      eventsClient.dropStream();
      await settle();
      expect(bloc.state.connection, KdsConnectionStatus.polling);

      repository.orders = [
        ...repository.orders,
        buildOrder(id: 'polled', orderNumber: '555'),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(bloc.state.orders!.map((o) => o.id), contains('polled'));
      expect(bloc.state.freshOrderIds, contains('polled'));
    });
  });

  group('status transitions (kitchen-owned)', () {
    test('«Начать готовить» moves the card optimistically and passes '
        'expectedVersion from the local order', () async {
      repository.orders = [
        buildOrder(
          id: 'a',
          version: 4,
          confirmedAt: kNow.subtract(const Duration(minutes: 3)),
        ),
      ];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      final pending = Completer<KdsOrder>();
      repository.updateCompleter = pending;
      bloc.add(
        const KdsOrderStatusChangeRequested(
          orderId: 'a',
          status: KdsOrderStatus.cooking,
          cookId: 'cook-1',
          shiftId: 'shift-1',
        ),
      );
      await settle();

      // Optimistic: the card already sits in COOKING and is blocked.
      expect(bloc.state.orders!.single.status, KdsOrderStatus.cooking);
      expect(bloc.state.mutatingOrderIds, {'a'});
      expect(repository.statusCalls, [('a', KdsOrderStatus.cooking, 4)]);
      expect(repository.attributionCalls, [('a', 'cook-1', 'shift-1')]);

      pending.complete(
        repository.applyServerUpdate('a', KdsOrderStatus.cooking),
      );
      await settle();
      // Server response is authoritative: version bumped, unblocked.
      expect(bloc.state.orders!.single.version, 5);
      expect(bloc.state.orders!.single.status, KdsOrderStatus.cooking);
      expect(bloc.state.mutatingOrderIds, isEmpty);
    });

    test('«Готово» moves COOKING → READY', () async {
      repository.orders = [
        buildOrder(
          id: 'a',
          version: 2,
          status: KdsOrderStatus.cooking,
          cookingStartedAt: kNow.subtract(const Duration(minutes: 7)),
        ),
      ];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      bloc.add(
        const KdsOrderStatusChangeRequested(
          orderId: 'a',
          status: KdsOrderStatus.ready,
        ),
      );
      await settle();

      expect(repository.statusCalls, [('a', KdsOrderStatus.ready, 2)]);
      expect(bloc.state.orders!.single.status, KdsOrderStatus.ready);
    });

    test('a version conflict rolls back, reports the error code and forces a '
        'snapshot refresh', () async {
      repository.orders = [buildOrder(id: 'a', version: 3)];
      repository.updateError = const KitchenOrderUpdateException(
        'ORDER_VERSION_CONFLICT',
        'Заказ уже изменён другой станцией (ORDER_VERSION_CONFLICT)',
      );
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();
      final fetchesBefore = repository.fetchCount;

      bloc.add(
        const KdsOrderStatusChangeRequested(
          orderId: 'a',
          status: KdsOrderStatus.cooking,
        ),
      );
      await settle();

      final state = bloc.state as KdsOrdersLoaded;
      expect(state.orders.single.status, KdsOrderStatus.confirmed);
      expect(state.mutatingOrderIds, isEmpty);
      expect(state.actionError, contains('ORDER_VERSION_CONFLICT'));
      expect(
        repository.fetchCount,
        greaterThan(fetchesBefore),
        reason: 'conflict forces a snapshot refresh',
      );
    });

    test('a second tap on a mutating order is ignored', () async {
      repository.orders = [buildOrder(id: 'a')];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      final pending = Completer<KdsOrder>();
      repository.updateCompleter = pending;
      bloc.add(
        const KdsOrderStatusChangeRequested(
          orderId: 'a',
          status: KdsOrderStatus.cooking,
        ),
      );
      await settle();
      expect(bloc.state.mutatingOrderIds, {'a'});

      bloc.add(
        const KdsOrderStatusChangeRequested(
          orderId: 'a',
          status: KdsOrderStatus.cooking,
        ),
      );
      await settle();
      expect(repository.statusCalls, hasLength(1));

      pending.complete(
        repository.applyServerUpdate('a', KdsOrderStatus.cooking),
      );
      await settle();
      expect(bloc.state.mutatingOrderIds, isEmpty);
    });
  });

  group('fresh-order acknowledgement', () {
    test('acknowledgement clears the highlight set', () async {
      repository.orders = [buildOrder(id: 'a')];
      final bloc = buildBloc()..add(const KdsOrdersStarted());
      addTearDown(bloc.close);
      await settle();

      eventsClient.emitSignal(
        upsert(buildOrder(id: 'fresh', orderNumber: '778', version: 1)),
      );
      await settle();
      expect(bloc.state.freshOrderIds, {'fresh'});

      bloc.add(const KdsOrdersNewOrdersAcknowledged());
      await settle();
      expect(bloc.state.freshOrderIds, isEmpty);
    });
  });
}

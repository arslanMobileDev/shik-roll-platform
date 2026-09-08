import 'dart:async';

import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/orders/bloc/order_tracking_bloc.dart';
import 'package:customer_mobile/features/orders/data/order_tracking_repository.dart';
import 'package:customer_mobile/features/orders/domain/order_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// Управляемый репозиторий: snapshot-ответы по очереди, SSE-стрим —
/// свежий StreamController на каждое подключение, ошибки по флагу.
final class _ControllableTrackingRepository implements OrderTrackingRepository {
  final snapshots = <OrderTrackingUpdate>[];
  final streamControllers = <StreamController<OrderTrackingUpdate>>[];
  var snapshotError = false;
  var streamError = false;

  StreamController<OrderTrackingUpdate> get stream => streamControllers.last;

  OrderTrackingUpdate _snapshot(String orderId) {
    if (snapshots.isEmpty) {
      return OrderTrackingUpdate(
        orderId: orderId,
        status: 'NEW',
        version: 1,
        timestamp: DateTime.utc(2026, 9, 8, 19),
      );
    }
    return snapshots.removeAt(0);
  }

  @override
  Future<OrderTrackingUpdate> getOrderSnapshot(String orderId) async {
    if (snapshotError) {
      throw const OrdersException('Сервер не отвечает.', statusCode: 503);
    }
    return _snapshot(orderId);
  }

  @override
  Stream<OrderTrackingUpdate> openTrackingStream(String orderId) {
    if (streamError) {
      return Stream.error(const OrdersException('Сеть недоступна.'));
    }
    final controller = StreamController<OrderTrackingUpdate>();
    streamControllers.add(controller);
    return controller.stream;
  }

  Future<void> dispose() async {
    for (final controller in streamControllers) {
      await controller.close();
    }
  }
}

OrderTrackingUpdate _event(
  String status, {
  required int version,
  String? courierId,
}) => OrderTrackingUpdate(
  orderId: 'order-1',
  status: status,
  courierId: courierId,
  version: version,
  timestamp: DateTime.utc(2026, 9, 8, 19, version),
);

OrderTrackingBloc _bloc(
  OrderTrackingRepository repository, {
  Duration pollingInterval = const Duration(milliseconds: 40),
  Duration retryBaseDelay = const Duration(milliseconds: 30),
}) => OrderTrackingBloc(
  repository: repository,
  pollingInterval: pollingInterval,
  retryBaseDelay: retryBaseDelay,
  maxRetryDelay: const Duration(milliseconds: 200),
  maxRetryJitter: Duration.zero,
);

/// Пропускает микрозадачи/таймеры нулевой длительности.
Future<void> _tick([int times = 3]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _ControllableTrackingRepository repository;

  setUp(() => repository = _ControllableTrackingRepository());
  tearDown(() => repository.dispose());

  group('OrderTrackingBloc', () {
    test('snapshot применяется первым, затем live-события из стрима', () async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();

      expect(bloc.state.status, OrderTimelineStatus.pending);
      expect(bloc.state.progressPercent, 5);
      expect(bloc.state.orderVersion, 1);
      expect(bloc.state.isConnected, isFalse);

      repository.stream.add(_event('CONFIRMED', version: 2));
      await _tick();

      expect(bloc.state.status, OrderTimelineStatus.accepted);
      expect(bloc.state.progressPercent, 15);
      expect(bloc.state.orderVersion, 2);
      expect(bloc.state.isConnected, isTrue);
    });

    test('события с версией <= текущей игнорируются', () async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();

      repository.stream.add(_event('COOKING', version: 3));
      await _tick();
      expect(bloc.state.status, OrderTimelineStatus.cooking);
      expect(bloc.state.orderVersion, 3);

      // Повтор той же версии и «отставшее» событие не откатывают состояние.
      repository.stream.add(_event('COOKING', version: 3));
      repository.stream.add(_event('CONFIRMED', version: 2));
      await _tick();

      expect(bloc.state.status, OrderTimelineStatus.cooking);
      expect(bloc.state.orderVersion, 3);
    });

    test('READY с курьером → COURIER_ASSIGNED, без курьера — COOKING', () async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();

      repository.stream.add(_event('READY', version: 2));
      await _tick();
      expect(bloc.state.status, OrderTimelineStatus.cooking);
      expect(bloc.state.progressPercent, 40);

      repository.stream.add(_event('READY', version: 3, courierId: 'c-1'));
      await _tick();
      expect(bloc.state.status, OrderTimelineStatus.courierAssigned);
      expect(bloc.state.progressPercent, 55);
    });

    test('CANCELLED — терминальное состояние без процента', () async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();

      repository.stream.add(_event('CANCELLED', version: 2));
      await _tick();

      expect(bloc.state.isCancelled, isTrue);
      expect(bloc.state.status, isNull);
      expect(bloc.state.progressPercent, 0);
    });

    test('ошибка snapshot → loadFailed, повторный Started восстанавливает', () async {
      repository.snapshotError = true;
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();
      expect(bloc.state.loadFailed, isTrue);
      expect(bloc.state.errorMessage, isNotEmpty);

      repository.snapshotError = false;
      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();
      expect(bloc.state.status, OrderTimelineStatus.pending);
      expect(bloc.state.errorMessage, isNull);
    });

    test('обрыв SSE → isConnected=false, fallback-поллинг двигает статус', () async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();

      repository.stream.add(_event('CONFIRMED', version: 2));
      await _tick();
      expect(bloc.state.isConnected, isTrue);

      // SSE умирает; следующий poll вернёт COOKING (поллинг без версии
      // применяется по изменению проекции).
      repository.snapshots.add(
        OrderTrackingUpdate(orderId: 'order-1', status: 'COOKING'),
      );
      await repository.stream.close();
      await _tick();
      expect(bloc.state.isConnected, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 90));
      await _tick();
      expect(bloc.state.status, OrderTimelineStatus.cooking);
      expect(bloc.state.progressPercent, 40);
      // Поллинг не «воскрешает» connected — только SSE.
      expect(bloc.state.isConnected, isFalse);
    });

    test('после backoff стрим переподключается, поллинг останавливается', () async {
      repository.streamError = true;
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _tick();
      expect(bloc.state.isConnected, isFalse);
      final attemptsBeforeReconnect = repository.streamControllers.length;

      // Сеть «восстановилась» — следующий retry поднимет живой стрим.
      repository.streamError = false;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _tick();
      expect(
        repository.streamControllers.length,
        greaterThan(attemptsBeforeReconnect),
      );

      repository.stream.add(_event('COOKING', version: 2));
      await _tick();
      expect(bloc.state.isConnected, isTrue);
      expect(bloc.state.status, OrderTimelineStatus.cooking);
    });

    test('OrderTrackingRefreshed подтягивает свежий snapshot', () async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();

      repository.snapshots.add(
        OrderTrackingUpdate(orderId: 'order-1', status: 'READY'),
      );
      bloc.add(const OrderTrackingRefreshed());
      await _tick();

      expect(bloc.state.status, OrderTimelineStatus.cooking);
      expect(bloc.state.progressPercent, 40);
    });

    test('close() останавливает таймеры и подписку без падений', () async {
      repository.streamError = true;
      final bloc = _bloc(repository);
      bloc.add(const OrderTrackingStarted('order-1'));
      await _tick();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await bloc.close();
      // Таймеры отменены: задержки после close не бросают.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
  });
}

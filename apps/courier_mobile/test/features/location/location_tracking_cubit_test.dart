import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/features/location/bloc/location_tracking_cubit.dart';
import 'package:courier_mobile/features/location/bloc/location_tracking_state.dart';
import 'package:courier_mobile/features/location/data/courier_location_repository.dart';
import 'package:courier_mobile/features/location/data/courier_location_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_fakes.dart';

final onWayOrder = makeOrder(
  id: 'order-1',
  status: OrderStatus.onWay,
  courierId: testCourier.id,
);

LocationTrackingCubit buildCubit(FakeLocationSource source) =>
    LocationTrackingCubit(
      source: source,
      repository: FakeCourierLocationRepository(),
      timeGate: const Duration(milliseconds: 100),
      hardMinInterval: const Duration(milliseconds: 10),
    );

Future<void> pump([int ms = 5]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('LocationTrackingCubit (permissions)', () {
    test('disabled location service blocks tracking', () async {
      final source = FakeLocationSource(serviceEnabled: false);
      final cubit = buildCubit(source);
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);

      expect(cubit.state.status, CourierTrackingStatus.serviceDisabled);
      expect(source.streamSubscriptions, 0);
    });

    test('denied permission blocks tracking without re-prompting', () async {
      final source = FakeLocationSource(
        permission: CourierLocationPermission.denied,
      );
      final cubit = buildCubit(source);
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);

      expect(cubit.state.status, CourierTrackingStatus.permissionDenied);
      expect(source.streamSubscriptions, 0);
    });

    test('whileInUse permission tracks in foreground-only mode', () async {
      final source = FakeLocationSource();
      final cubit = buildCubit(source);
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);

      expect(
        cubit.state.status,
        CourierTrackingStatus.trackingForegroundOnly,
      );
      expect(cubit.state.activeOrderId, 'order-1');
      expect(source.streamSubscriptions, 1);
    });

    test('«always» permission tracks with background capability', () async {
      final source = FakeLocationSource(
        permission: CourierLocationPermission.always,
      );
      final cubit = buildCubit(source);
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);

      expect(cubit.state.status, CourierTrackingStatus.tracking);
    });
  });

  group('LocationTrackingCubit (send gate)', () {
    test('first fix is sent immediately; repeats inside the gate are held',
        () async {
      final source = FakeLocationSource();
      final repo = FakeCourierLocationRepository();
      final cubit = LocationTrackingCubit(
        source: source,
        repository: repo,
        timeGate: const Duration(milliseconds: 100),
        hardMinInterval: const Duration(milliseconds: 10),
      );
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);
      source.positionController.add(source.fix());
      await pump();
      expect(repo.reports, hasLength(1));

      // Same spot, inside the 100 ms gate — not sent.
      source.positionController.add(source.fix());
      await pump();
      expect(repo.reports, hasLength(1));

      // After the time gate — sent even without movement.
      await pump(120);
      source.positionController.add(source.fix());
      await pump();
      expect(repo.reports, hasLength(2));
    });

    test('displacement >= 30 m after the hard minimum sends early', () async {
      final source = FakeLocationSource();
      final repo = FakeCourierLocationRepository();
      final cubit = LocationTrackingCubit(
        source: source,
        repository: repo,
        timeGate: const Duration(seconds: 15),
        hardMinInterval: const Duration(milliseconds: 10),
      );
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);
      source.positionController.add(source.fix());
      await pump();
      expect(repo.reports, hasLength(1));

      // ~111 m north, well inside the 15 s time gate but past 30 m.
      await pump(20);
      source.positionController.add(source.fix(lat: 55.7903));
      await pump();
      expect(repo.reports, hasLength(2));
    });

    test('invalid fixes are dropped (accuracy > 100 m, null island)', () async {
      final source = FakeLocationSource();
      final repo = FakeCourierLocationRepository();
      final cubit = LocationTrackingCubit(
        source: source,
        repository: repo,
        timeGate: const Duration(milliseconds: 100),
        hardMinInterval: const Duration(milliseconds: 10),
      );
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);
      source.positionController.add(source.fix(accuracy: 150));
      source.positionController.add(source.fix(lat: 0, lon: 0));
      await pump();
      expect(repo.reports, isEmpty);
    });

    test('completing the delivery stops tracking and sending', () async {
      final source = FakeLocationSource();
      final repo = FakeCourierLocationRepository();
      final cubit = LocationTrackingCubit(
        source: source,
        repository: repo,
        timeGate: const Duration(milliseconds: 100),
        hardMinInterval: const Duration(milliseconds: 10),
      );
      addTearDown(cubit.close);

      await cubit.syncActiveOrder(onWayOrder);
      source.positionController.add(source.fix());
      await pump();
      expect(repo.reports, hasLength(1));

      await cubit.syncActiveOrder(null);
      expect(cubit.state.status, CourierTrackingStatus.off);
      expect(cubit.state.activeOrderId, isNull);

      source.positionController.add(source.fix());
      await pump();
      expect(repo.reports, hasLength(1));
    });
  });
}

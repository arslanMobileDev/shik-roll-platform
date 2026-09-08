import 'dart:async';
import 'dart:convert';

import 'package:courier_mobile/data/models/branch.dart';
import 'package:courier_mobile/data/models/courier.dart';
import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/data/models/courier_session.dart';
import 'package:courier_mobile/features/location/data/courier_location_source.dart';

const testBranch = Branch(id: 'branch-center', name: 'SHIK ROLL — Центр');

const testCourier = Courier(id: 'courier-muhammad', name: 'Мухаммад');

const testSession = CourierSession(
  token: 'test-jwt',
  courier: testCourier,
  branch: testBranch,
  phone: '+79170000000',
);

/// Builds a structurally valid unsigned JWT (same claim shape as the backend)
/// so client-side expiry/branch parsing works in tests.
String makeTestJwt({
  String courierId = 'courier-muhammad',
  String branchId = 'branch-center',
  int? exp,
}) {
  String b64(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = b64({'alg': 'none', 'typ': 'JWT'});
  final payload = b64({
    'sub': courierId,
    'phone': '+79170000000',
    'branchId': branchId,
    'role': 'COURIER',
    'type': 'access',
    'exp': exp ?? 4102444800, // 2100-01-01
  });
  return '$header.$payload.test';
}

/// A JWT that is already expired (exp = 2001-01-01).
final expiredTestJwt = makeTestJwt(exp: 978307200);

CourierOrder makeOrder({
  required String id,
  OrderStatus status = OrderStatus.ready,
  OrderType type = OrderType.delivery,
  PaymentMethod paymentMethod = PaymentMethod.cash,
  String? courierId,
  String branchId = 'branch-center',
  DateTime? createdAt,
}) {
  return CourierOrder(
    id: id,
    number: 'A-$id',
    status: status,
    type: type,
    totalRubles: 1250,
    paymentMethod: paymentMethod,
    address: const DeliveryAddress(
      street: 'ул. Баумана, 58',
      apartment: '12',
      entrance: '3',
      floor: '5',
      intercom: '127',
    ),
    clientPhone: '+79171234567',
    clientComment: 'Позвонить за 5 минут, спит ребенок',
    branchId: branchId,
    courierId: courierId,
    createdAt: createdAt ?? DateTime(2026, 9, 6, 12, 5),
  );
}

/// Location source stub: no platform channels, controllable position feed.
class FakeLocationSource implements CourierLocationSource {
  FakeLocationSource({
    this.serviceEnabled = true,
    this.permission = CourierLocationPermission.whileInUse,
  });

  bool serviceEnabled;
  CourierLocationPermission permission;

  final positionController = StreamController<CourierPosition>.broadcast();
  var streamSubscriptions = 0;
  var appSettingsOpened = 0;
  var locationSettingsOpened = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<CourierLocationPermission> checkPermission() async => permission;

  @override
  Future<CourierLocationPermission> requestPermission() async => permission;

  @override
  Stream<CourierPosition> positionStream() {
    streamSubscriptions++;
    return positionController.stream;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }

  CourierPosition fix({
    double lat = 55.7893,
    double lon = 49.1221,
    double accuracy = 10,
  }) => CourierPosition(
    latitude: lat,
    longitude: lon,
    accuracyMeters: accuracy,
    timestamp: DateTime.now(),
  );

  Future<void> dispose() => positionController.close();
}

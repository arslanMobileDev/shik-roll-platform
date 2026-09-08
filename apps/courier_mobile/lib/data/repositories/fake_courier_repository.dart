import 'dart:async';
import 'dart:convert';

import '../models/courier.dart';
import '../models/courier_order.dart';
import '../models/courier_order_event.dart';
import 'courier_repository.dart';

/// Offline demo repository with mock SHIK ROLL delivery orders.
///
/// Any 4-digit PIN is accepted; the courier is always «Мухаммад» attached to
/// 'branch-center'. Mutations mirror the backend transition rules and emit
/// SSE-like events on [watchOrders].
class FakeCourierRepository implements CourierRepository {
  FakeCourierRepository({List<CourierOrder>? seedOrders})
    : _orders = List.of(seedOrders ?? _defaultOrders);

  static const _demoCourier = Courier(id: 'courier-muhammad', name: 'Мухаммад');
  static const _demoBranchId = 'branch-center';

  final List<CourierOrder> _orders;
  final _events = StreamController<CourierOrderEvent>.broadcast();

  static final List<CourierOrder> _defaultOrders = [
    CourierOrder(
      id: 'order-1001',
      number: 'A-1024',
      status: OrderStatus.ready,
      totalRubles: 1250,
      paymentMethod: PaymentMethod.cash,
      address: const DeliveryAddress(
        street: 'ул. Баумана, 58',
        apartment: '12',
        entrance: '3',
        floor: '5',
        intercom: '127',
        lat: 55.7893,
        lon: 49.1221,
      ),
      clientPhone: '+79171234567',
      clientComment: 'Позвонить за 5 минут, спит ребенок',
      branchId: _demoBranchId,
      createdAt: DateTime(2026, 9, 6, 12, 5),
    ),
    CourierOrder(
      id: 'order-1002',
      number: 'A-1025',
      status: OrderStatus.cooking,
      totalRubles: 890,
      paymentMethod: PaymentMethod.onlinePaid,
      address: const DeliveryAddress(
        street: 'пр. Победы, 141',
        apartment: '77',
        floor: '9',
      ),
      clientPhone: '+79177654321',
      branchId: _demoBranchId,
      createdAt: DateTime(2026, 9, 6, 12, 20),
    ),
    CourierOrder(
      id: 'order-1004',
      number: 'A-1027',
      status: OrderStatus.onWay,
      totalRubles: 1670,
      paymentMethod: PaymentMethod.onlinePaid,
      address: const DeliveryAddress(
        street: 'ул. Габдуллы Тукая, 33',
        apartment: '45',
        floor: '2',
      ),
      clientPhone: '+79870001122',
      branchId: _demoBranchId,
      courierId: _demoCourier.id,
      createdAt: DateTime(2026, 9, 6, 11, 40),
    ),
  ];

  @override
  Future<({String token, Courier courier})> loginWithPin({
    required String pin,
    required String phone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (pin.length != 4 || int.tryParse(pin) == null) {
      throw const CourierAuthException('PIN должен состоять из 4 цифр');
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      throw const CourierAuthException('Введите корректный номер телефона');
    }
    return (token: _fakeJwt(), courier: _demoCourier);
  }

  /// Demo token with the real claim shape (far-future exp) so session
  /// restore and branch resolution work exactly as against the backend.
  static String _fakeJwt() {
    String b64(Map<String, dynamic> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final header = b64({'alg': 'none', 'typ': 'JWT'});
    final payload = b64({
      'sub': _demoCourier.id,
      'phone': '+79170000000',
      'branchId': _demoBranchId,
      'role': 'COURIER',
      'type': 'access',
      'exp': 4102444800, // 2100-01-01 — the demo token never expires
    });
    return '$header.$payload.demo';
  }

  @override
  Future<List<CourierOrder>> fetchActiveOrders() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _orders
        .where(
          (o) =>
              o.branchId == _demoBranchId &&
              o.type == OrderType.delivery &&
              (o.status == OrderStatus.cooking ||
                  o.status == OrderStatus.ready ||
                  o.status == OrderStatus.onWay),
        )
        .toList();
  }

  @override
  Future<void> claimOrder(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    if (order.courierId != null) {
      throw const CourierOrderConflictException('Заказ уже занят');
    }
    if (order.status != OrderStatus.ready) {
      throw const CourierOrderConflictException();
    }
    final hasActive = _orders.any(
      (o) =>
          o.courierId == _demoCourier.id &&
          (o.status == OrderStatus.ready || o.status == OrderStatus.onWay),
    );
    if (hasActive) {
      throw const CourierOrderConflictException(
        'Сначала завершите текущую доставку',
      );
    }
    _orders[index] = order.copyWith(courierId: () => _demoCourier.id);
    _emit(_orders[index]);
  }

  @override
  Future<void> startDelivery(String orderId) =>
      _transition(orderId, OrderStatus.ready, OrderStatus.onWay);

  @override
  Future<void> completeDelivery(String orderId) =>
      _transition(orderId, OrderStatus.onWay, OrderStatus.completed);

  Future<void> _transition(
    String orderId,
    OrderStatus from,
    OrderStatus to,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    if (order.courierId != _demoCourier.id || order.status != from) {
      throw const CourierOrderConflictException();
    }
    _orders[index] = order.copyWith(status: to);
    _emit(_orders[index]);
  }

  void _emit(CourierOrder order) {
    if (_events.isClosed) return;
    _events.add(
      CourierOrderEvent(
        orderId: order.id,
        orderNumber: order.number,
        status: order.status.wireName,
        branchId: order.branchId,
        courierId: order.courierId,
        deliveryAddress: order.address.street,
        totalRubles: order.totalRubles,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Stream<CourierOrderEvent> watchOrders() => _events.stream;

  Future<void> dispose() => _events.close();
}

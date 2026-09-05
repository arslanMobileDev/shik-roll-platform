import '../models/courier.dart';
import '../models/courier_order.dart';
import 'courier_repository.dart';

/// Offline demo repository with mock SHIK ROLL delivery orders.
///
/// Any 4-digit PIN is accepted; the courier is always «Мухаммад».
class FakeCourierRepository implements CourierRepository {
  FakeCourierRepository({List<CourierOrder>? seedOrders})
      : _orders = List.of(seedOrders ?? _defaultOrders);

  static const _demoCourier = Courier(
    id: 'courier-muhammad',
    name: 'Мухаммад',
  );

  final List<CourierOrder> _orders;

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
      branchId: 'branch-center',
    ),
    CourierOrder(
      id: 'order-1002',
      number: 'A-1025',
      status: OrderStatus.ready,
      totalRubles: 890,
      paymentMethod: PaymentMethod.onlinePaid,
      address: const DeliveryAddress(
        street: 'пр. Победы, 141',
        apartment: '77',
        floor: '9',
      ),
      clientPhone: '+79177654321',
      branchId: 'branch-center',
    ),
    CourierOrder(
      id: 'order-1003',
      number: 'A-1026',
      status: OrderStatus.ready,
      totalRubles: 2340,
      paymentMethod: PaymentMethod.cash,
      address: const DeliveryAddress(
        street: 'ул. Декабристов, 81',
        apartment: '203',
        entrance: '1',
        intercom: '203',
      ),
      clientPhone: '+79061112233',
      clientComment: 'Оставить у двери, без звонка',
      branchId: 'branch-yug',
    ),
    CourierOrder(
      id: 'order-1004',
      number: 'A-1027',
      status: OrderStatus.delivering,
      totalRubles: 1670,
      paymentMethod: PaymentMethod.onlinePaid,
      address: const DeliveryAddress(
        street: 'ул. Габдуллы Тукая, 33',
        apartment: '45',
        floor: '2',
      ),
      clientPhone: '+79870001122',
      branchId: 'branch-center',
      courierId: _demoCourier.id,
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
    return (token: 'fake-jwt-token', courier: _demoCourier);
  }

  @override
  Future<List<CourierOrder>> fetchActiveOrders({
    required String branchId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _orders
        .where(
          (o) =>
              o.branchId == branchId &&
              (o.status == OrderStatus.ready ||
                  o.status == OrderStatus.delivering),
        )
        .toList();
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    required String courierId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(
      status: status,
      courierId: status == OrderStatus.ready ? null : courierId,
    );
  }
}

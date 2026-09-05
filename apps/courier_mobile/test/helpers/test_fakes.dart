import 'package:courier_mobile/data/models/branch.dart';
import 'package:courier_mobile/data/models/courier.dart';
import 'package:courier_mobile/data/models/courier_order.dart';
import 'package:courier_mobile/data/models/courier_session.dart';

const testBranch = Branch(id: 'branch-center', name: 'SHIK ROLL — Центр');

const testCourier = Courier(id: 'courier-muhammad', name: 'Мухаммад');

const testSession = CourierSession(
  token: 'test-jwt',
  courier: testCourier,
  branch: testBranch,
);

CourierOrder makeOrder({
  required String id,
  OrderStatus status = OrderStatus.ready,
  String? courierId,
  String branchId = 'branch-center',
}) {
  return CourierOrder(
    id: id,
    number: 'A-$id',
    status: status,
    totalRubles: 1250,
    paymentMethod: PaymentMethod.cash,
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
  );
}

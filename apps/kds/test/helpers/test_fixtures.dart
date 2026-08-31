import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/data/kds_orders_repository.dart';

/// Fixed reference clock for deterministic timer assertions.
final DateTime kNow = DateTime(2026, 8, 31, 12, 0);

KdsOrderItemModifier buildModifier({
  String id = 'mod-1',
  String name = 'Соус унаги',
  int quantity = 1,
}) => KdsOrderItemModifier(id: id, name: name, quantity: quantity);

KdsOrderItem buildItem({
  String id = 'item-1',
  String name = 'Филадельфия классик',
  int quantity = 1,
  String? comment,
  List<KdsOrderItemModifier> modifiers = const [],
}) => KdsOrderItem(
  id: id,
  name: name,
  quantity: quantity,
  comment: comment,
  modifiers: modifiers,
);

KdsOrder buildOrder({
  String id = 'order-1',
  String orderNumber = '1001',
  KdsOrderStatus status = KdsOrderStatus.confirmed,
  KdsOrderType type = KdsOrderType.dineIn,
  String branchId = 'branch-central',
  DateTime? createdAt,
  String? tableNumber,
  String? comment,
  List<KdsOrderItem> items = const [],
}) => KdsOrder(
  id: id,
  orderNumber: orderNumber,
  status: status,
  type: type,
  branchId: branchId,
  createdAt: createdAt ?? kNow.subtract(const Duration(minutes: 5)),
  tableNumber: tableNumber,
  comment: comment,
  items: items,
);

/// Mutable in-memory repository for widget/bloc tests.
final class TestKdsOrdersRepository implements KdsOrdersRepository {
  TestKdsOrdersRepository({List<KdsOrder> orders = const []}) {
    this.orders = List.of(orders);
  }

  List<KdsOrder> orders = [];
  final List<(String orderId, KdsOrderStatus status)> statusCalls = [];
  Object? fetchError;
  Object? updateError;

  @override
  Future<List<KdsOrder>> fetchOrders({
    required String branchId,
    int page = 1,
    int limit = 50,
  }) async {
    if (fetchError != null) throw fetchError!;
    return List.unmodifiable(orders.where((o) => o.branchId == branchId));
  }

  @override
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
  }) async {
    if (updateError != null) throw updateError!;
    statusCalls.add((orderId, status));
    final index = orders.indexWhere((o) => o.id == orderId);
    final updated = orders[index].copyWith(status: status);
    orders = [...orders]..[index] = updated;
    return updated;
  }
}

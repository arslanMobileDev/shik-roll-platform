import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/data/kds_orders_repository.dart';
import 'package:kds/features/shift/data/cook_shift_models.dart';
import 'package:kds/features/shift/data/cook_shift_repository.dart';

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

  /// Cook/shift attribution captured from update calls.
  final List<(String orderId, String? cookId, String? shiftId)>
  attributionCalls = [];
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
    String? cookId,
    String? shiftId,
  }) async {
    if (updateError != null) throw updateError!;
    statusCalls.add((orderId, status));
    attributionCalls.add((orderId, cookId, shiftId));
    final index = orders.indexWhere((o) => o.id == orderId);
    final updated = orders[index].copyWith(status: status);
    orders = [...orders]..[index] = updated;
    return updated;
  }
}

ActiveCook buildCook({
  String id = 'cook-1',
  String name = 'Ахмед',
  CookRole role = CookRole.sushiChef,
  int completedOrders = 0,
  int? avgPrepSeconds,
}) => ActiveCook(
  id: id,
  name: name,
  role: role,
  clockInAt: kNow.subtract(const Duration(hours: 2)),
  completedOrders: completedOrders,
  avgPrepSeconds: avgPrepSeconds,
);

/// Mutable in-memory shift repository for widget/bloc tests.
final class TestCookShiftRepository implements CookShiftRepository {
  TestCookShiftRepository({
    List<ActiveCook> cooks = const [],
    this.shiftId = 'shift-1',
  }) : cooks = List.of(cooks);

  final String shiftId;
  List<ActiveCook> cooks;
  Object? fetchError;
  Object? clockInError;
  Object? clockOutError;
  final List<(String pin, String name, CookRole role)> clockInCalls = [];
  final List<(String cookId, String shiftId)> clockOutCalls = [];

  @override
  Future<ActiveShift> fetchActiveShift({required String branchId}) async {
    if (fetchError != null) throw fetchError!;
    return ActiveShift(
      shiftId: shiftId,
      branchId: branchId,
      cooks: List.unmodifiable(cooks),
    );
  }

  @override
  Future<ClockInResult> clockIn({
    required String branchId,
    required String pin,
    required String name,
    required CookRole role,
  }) async {
    if (clockInError != null) throw clockInError!;
    clockInCalls.add((pin, name, role));
    final cook = ActiveCook(
      id: 'cook-$pin',
      name: name,
      role: role,
      clockInAt: kNow,
    );
    cooks.add(cook);
    return (shiftId: shiftId, cook: cook);
  }

  @override
  Future<void> clockOut({required String cookId, required String shiftId}) async {
    if (clockOutError != null) throw clockOutError!;
    clockOutCalls.add((cookId, shiftId));
    cooks.removeWhere((c) => c.id == cookId);
  }
}

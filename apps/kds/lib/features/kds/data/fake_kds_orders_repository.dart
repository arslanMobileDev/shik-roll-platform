import 'kds_order_models.dart';
import 'kds_orders_repository.dart';

/// In-memory demo order stream.
///
/// Keeps the kitchen board usable without a backend (API_BASE_URL unset) and
/// seeds orders at varied ages so the delay-timer color bands are visible.
final class FakeKdsOrdersRepository implements KdsOrdersRepository {
  FakeKdsOrdersRepository() {
    final now = DateTime.now();
    _orders = [
      KdsOrder(
        id: 'demo-1001',
        orderNumber: '1001',
        status: KdsOrderStatus.confirmed,
        type: KdsOrderType.dineIn,
        branchId: 'branch-central',
        createdAt: now.subtract(const Duration(minutes: 4)),
        tableNumber: '7',
        items: const [
          KdsOrderItem(
            id: 'di-1',
            name: 'Филадельфия классик',
            quantity: 2,
            modifiers: [
              KdsOrderItemModifier(id: 'dm-1', name: 'Соус унаги', quantity: 1),
            ],
          ),
          KdsOrderItem(id: 'di-2', name: 'Мисо-суп', quantity: 1),
        ],
      ),
      KdsOrder(
        id: 'demo-1002',
        orderNumber: '1002',
        status: KdsOrderStatus.newOrder,
        type: KdsOrderType.takeaway,
        branchId: 'branch-central',
        createdAt: now.subtract(const Duration(minutes: 12)),
        comment: 'Без васаби, пожалуйста',
        items: const [
          KdsOrderItem(
            id: 'di-3',
            name: 'Сет «SHIK ROLL»',
            quantity: 1,
            modifiers: [
              KdsOrderItemModifier(
                id: 'dm-2',
                name: 'Икра тобико',
                quantity: 2,
              ),
              KdsOrderItemModifier(
                id: 'dm-3',
                name: 'Соевый соус',
                quantity: 3,
              ),
            ],
          ),
        ],
      ),
      KdsOrder(
        id: 'demo-1003',
        orderNumber: '1003',
        status: KdsOrderStatus.cooking,
        type: KdsOrderType.delivery,
        branchId: 'branch-central',
        createdAt: now.subtract(const Duration(minutes: 25)),
        items: const [
          KdsOrderItem(id: 'di-4', name: 'Ролл «Дракон»', quantity: 3),
          KdsOrderItem(
            id: 'di-5',
            name: 'Гунканы с лососем',
            quantity: 4,
            comment: 'Лосось посолить слегка',
          ),
        ],
      ),
      KdsOrder(
        id: 'demo-1004',
        orderNumber: '1004',
        status: KdsOrderStatus.ready,
        type: KdsOrderType.dineIn,
        branchId: 'branch-central',
        createdAt: now.subtract(const Duration(minutes: 8)),
        tableNumber: '3',
        items: const [
          KdsOrderItem(id: 'di-6', name: 'Чизкейк матча', quantity: 2),
        ],
      ),
    ];
  }

  late List<KdsOrder> _orders;

  @override
  Future<List<KdsOrder>> fetchOrders({
    required String branchId,
    int page = 1,
    int limit = 50,
  }) async {
    return List.unmodifiable(_orders.where((o) => o.branchId == branchId));
  }

  @override
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw StateError('Order $orderId not found');
    }
    final updated = _orders[index].copyWith(status: status);
    _orders = [..._orders]..[index] = updated;
    return updated;
  }
}

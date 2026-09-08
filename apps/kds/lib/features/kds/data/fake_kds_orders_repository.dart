import 'kds_order_models.dart';
import 'kds_orders_repository.dart';

/// In-memory demo order stream (API_BASE_URL unset).
///
/// Keeps the kitchen board usable without a backend and seeds orders at
/// varied ages so the delay-timer color bands are visible. Status transitions
/// mirror the kitchen state machine (CONFIRMED → COOKING → READY) and enforce
/// the same optimistic-locking contract as the live API.
final class FakeKdsOrdersRepository implements KdsOrdersRepository {
  FakeKdsOrdersRepository() {
    final now = DateTime.now();
    _orders = [
      KdsOrder(
        id: 'demo-1001',
        orderNumber: '1001',
        version: 2,
        status: KdsOrderStatus.confirmed,
        type: KdsOrderType.dineIn,
        confirmedAt: now.subtract(const Duration(minutes: 4)),
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
        version: 2,
        status: KdsOrderStatus.confirmed,
        type: KdsOrderType.takeaway,
        confirmedAt: now.subtract(const Duration(minutes: 12)),
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
        version: 3,
        status: KdsOrderStatus.cooking,
        type: KdsOrderType.delivery,
        confirmedAt: now.subtract(const Duration(minutes: 28)),
        cookingStartedAt: now.subtract(const Duration(minutes: 25)),
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
        version: 4,
        status: KdsOrderStatus.ready,
        type: KdsOrderType.dineIn,
        confirmedAt: now.subtract(const Duration(minutes: 20)),
        cookingStartedAt: now.subtract(const Duration(minutes: 17)),
        readyAt: now.subtract(const Duration(minutes: 8)),
        tableNumber: '3',
        items: const [
          KdsOrderItem(id: 'di-6', name: 'Чизкейк матча', quantity: 2),
        ],
      ),
    ];
  }

  late List<KdsOrder> _orders;

  @override
  Future<KitchenBoardSnapshot> fetchSnapshot() async => KitchenBoardSnapshot(
    serverTime: DateTime.now(),
    orders: List.unmodifiable(_orders),
  );

  @override
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
    required int expectedVersion,
    String? cookId,
    String? shiftId,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw const KitchenOrderUpdateException(
        'ORDER_NOT_FOUND',
        'Заказ не найден (ORDER_NOT_FOUND)',
      );
    }
    final order = _orders[index];
    final validSource =
        (status == KdsOrderStatus.cooking &&
            order.status == KdsOrderStatus.confirmed) ||
        (status == KdsOrderStatus.ready &&
            order.status == KdsOrderStatus.cooking);
    if (!validSource) {
      throw const KitchenOrderUpdateException(
        'INVALID_ORDER_STATUS_TRANSITION',
        'Статус заказа уже изменился (INVALID_ORDER_STATUS_TRANSITION)',
      );
    }
    if (order.version != expectedVersion) {
      throw const KitchenOrderUpdateException(
        'ORDER_VERSION_CONFLICT',
        'Заказ уже изменён другой станцией (ORDER_VERSION_CONFLICT)',
      );
    }
    final now = DateTime.now();
    final updated = order.copyWith(
      status: status,
      version: order.version + 1,
      cookingStartedAt: status == KdsOrderStatus.cooking
          ? () => now
          : null,
      readyAt: status == KdsOrderStatus.ready ? () => now : null,
    );
    _orders = [..._orders]..[index] = updated;
    return updated;
  }
}

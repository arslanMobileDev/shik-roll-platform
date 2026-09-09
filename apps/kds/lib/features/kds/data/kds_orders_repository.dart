import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/network/api_client.dart';
import 'kds_order_models.dart';

/// Board snapshot (API-709 `GET /kitchen/orders/active`).
///
/// [serverTime] lets the client derive its clock offset so delay timers stay
/// accurate even when the terminal clock drifts.
final class KitchenBoardSnapshot extends Equatable {
  const KitchenBoardSnapshot({required this.serverTime, required this.orders});

  final DateTime serverTime;
  final List<KdsOrder> orders;

  @override
  List<Object?> get props => [serverTime, orders];
}

/// Status-transition failure with the backend error code (API-709): the bloc
/// surfaces the code in a snackbar and force-refreshes the snapshot.
final class KitchenOrderUpdateException implements Exception {
  const KitchenOrderUpdateException(this.code, this.message);

  /// `ORDER_NOT_FOUND` | `ORDER_BRANCH_FORBIDDEN` |
  /// `ORDER_VERSION_CONFLICT` | `INVALID_ORDER_STATUS_TRANSITION` |
  /// `NETWORK`.
  final String code;
  final String message;

  @override
  String toString() => 'KitchenOrderUpdateException($code): $message';
}

/// Source of kitchen orders (API-709 `KitchenController`).
///
/// Branch identity is **never** supplied by the client — the backend scopes
/// every response to the branch of the terminal's JWT.
abstract interface class KdsOrdersRepository {
  /// `GET /kitchen/orders/active` — full board snapshot (NEW/CONFIRMED, COOKING,
  /// READY, FIFO by status-entry time).
  Future<KitchenBoardSnapshot> fetchSnapshot();

  /// `PATCH /kitchen/orders/{id}/status` — kitchen-owned transition
  /// (NEW/CONFIRMED → COOKING or COOKING → READY) with optimistic locking via
  /// [expectedVersion].
  ///
  /// [cookId]/[shiftId] are audit metadata only, not authorization.
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
    required int expectedVersion,
    String? cookId,
    String? shiftId,
  });
}

/// Remote implementation against the live Kitchen API.
final class HttpKdsOrdersRepository implements KdsOrdersRepository {
  HttpKdsOrdersRepository(ApiClient client) : _client = client;

  final ApiClient _client;

  @override
  Future<KitchenBoardSnapshot> fetchSnapshot() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/kitchen/orders/active',
    );
    final body = response.data ?? const <String, dynamic>{};
    return KitchenBoardSnapshot(
      serverTime:
          DateTime.tryParse(body['serverTime'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      orders: [
        for (final o in (body['orders'] as List?) ?? const [])
          KdsOrder.fromJson(o as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
    required int expectedVersion,
    String? cookId,
    String? shiftId,
  }) async {
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/kitchen/orders/$orderId/status',
        data: {
          'status': status.wireName,
          'expectedVersion': expectedVersion,
          'cookId': ?cookId,
          'shiftId': ?shiftId,
        },
      );
      final body = response.data;
      if (body == null) {
        throw const KitchenOrderUpdateException(
          'NETWORK',
          'Пустой ответ сервера',
        );
      }
      return KdsOrder.fromJson(body);
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map<String, dynamic>
          ? data['code'] as String?
          : null;
      throw KitchenOrderUpdateException(code ?? 'NETWORK', switch (code) {
        'ORDER_VERSION_CONFLICT' =>
          'Заказ уже изменён другой станцией (ORDER_VERSION_CONFLICT)',
        'INVALID_ORDER_STATUS_TRANSITION' =>
          'Статус заказа уже изменился (INVALID_ORDER_STATUS_TRANSITION)',
        'ORDER_NOT_FOUND' => 'Заказ не найден (ORDER_NOT_FOUND)',
        'ORDER_BRANCH_FORBIDDEN' =>
          'Заказ другого филиала (ORDER_BRANCH_FORBIDDEN)',
        _ => 'Нет связи с сервером. Попробуйте снова.',
      });
    }
  }
}

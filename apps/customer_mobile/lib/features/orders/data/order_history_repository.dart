import 'package:dio/dio.dart';

import '../../../core/auth/auth_token_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/money.dart';
import '../../cart/data/orders_repository.dart';
import 'order_history_models.dart';

/// Guest order history (`GET /orders` with the guest Bearer token; the
/// backend restricts the list to the authenticated customer).
abstract interface class OrderHistoryRepository {
  Future<List<OrderHistoryEntry>> getOrders();
}

/// Remote implementation over the Orders API contract.
final class RemoteOrderHistoryRepository implements OrderHistoryRepository {
  RemoteOrderHistoryRepository(this._client, this._tokenProvider);

  final ApiClient _client;
  final AuthTokenProvider _tokenProvider;

  @override
  Future<List<OrderHistoryEntry>> getOrders() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/orders',
        options: Options(
          headers: {
            if (_tokenProvider.authorizationHeader != null)
              'Authorization': _tokenProvider.authorizationHeader,
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        throw OrdersException(
          'Пустой ответ сервера. Попробуйте ещё раз.',
          statusCode: response.statusCode,
        );
      }
      return [
        for (final item in (data['data'] as List<dynamic>?) ?? const [])
          OrderHistoryEntry.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const OrdersException(
        'Некорректный ответ сервера. Попробуйте ещё раз.',
      );
    }
  }

  /// Translates transport failures into a message the guest can act on.
  static OrdersException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => OrdersException(
        'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        statusCode: statusCode,
      ),
      DioExceptionType.connectionError => OrdersException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when statusCode == 401 => OrdersException(
        'Сессия истекла. Войдите ещё раз, чтобы увидеть заказы.',
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse when (statusCode ?? 0) >= 500 =>
        OrdersException(
          'Сервер временно недоступен. Попробуйте позже.',
          statusCode: statusCode,
        ),
      DioExceptionType.badResponse => OrdersException(
        'Не удалось загрузить заказы. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
      DioExceptionType.cancel => OrdersException(
        'Загрузка отменена.',
        statusCode: statusCode,
      ),
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => OrdersException(
        'Ошибка сети при загрузке заказов. Попробуйте ещё раз.',
        statusCode: statusCode,
      ),
    };
  }
}

/// In-memory history for development and widget tests.
final class FakeOrderHistoryRepository implements OrderHistoryRepository {
  FakeOrderHistoryRepository({
    this.latency = const Duration(milliseconds: 400),
    List<OrderHistoryEntry>? orders,
  }) : _orders = orders ?? _demoOrders;

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  final List<OrderHistoryEntry> _orders;

  static final _demoOrders = <OrderHistoryEntry>[
    OrderHistoryEntry(
      id: 'demo-order-1042',
      orderNumber: '1042',
      status: 'COOKING',
      type: 'DELIVERY',
      totalAmount: const Money.kopecks(78000),
      createdAt: DateTime(2026, 9, 4, 12, 30),
      items: const [
        OrderHistoryItem(
          menuItemId: 'item-philadelphia',
          name: 'Филадельфия',
          quantity: 2,
          unitPrice: Money.kopecks(39000),
          modifiers: [
            OrderHistoryModifier(
              modifierItemId: 'mi-s-spicy',
              name: 'Спайси',
              priceDelta: Money.kopecks(4000),
            ),
          ],
        ),
      ],
    ),
    OrderHistoryEntry(
      id: 'demo-order-1035',
      orderNumber: '1035',
      status: 'COMPLETED',
      type: 'DELIVERY',
      totalAmount: const Money.kopecks(54000),
      createdAt: DateTime(2026, 9, 1, 19, 5),
      items: const [
        OrderHistoryItem(
          menuItemId: 'item-california',
          name: 'Калифорния',
          quantity: 1,
          unitPrice: Money.kopecks(39000),
          modifiers: [],
        ),
        OrderHistoryItem(
          menuItemId: 'item-mors',
          name: 'Морс',
          quantity: 1,
          unitPrice: Money.kopecks(15000),
          modifiers: [],
        ),
      ],
    ),
  ];

  @override
  Future<List<OrderHistoryEntry>> getOrders() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _orders;
  }
}

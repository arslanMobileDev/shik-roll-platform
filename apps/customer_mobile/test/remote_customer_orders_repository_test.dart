import 'package:customer_mobile/core/network/api_client.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/data/create_order_request.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

const _request = CreateOrderRequest(
  branchId: 'branch-1',
  orderType: OrderType.delivery,
  deliveryAddress: 'ул. Пушкина, 10',
  comment: 'Позвонить за час',
  items: [
    OrderItemRequest(
      menuItemId: 'item-1',
      quantity: 2,
      selectedModifiers: [
        SelectedModifierRequest(modifierItemId: 'mod-1'),
      ],
    ),
  ],
);

Response<Map<String, dynamic>> _okResponse(Map<String, dynamic> body) =>
    Response<Map<String, dynamic>>(
      data: body,
      statusCode: 201,
      requestOptions: RequestOptions(path: '/orders'),
    );

DioException _transportError({required DioExceptionType type}) => DioException(
  requestOptions: RequestOptions(path: '/orders'),
  type: type,
  message: 'connection failed',
);

DioException _badResponse(int statusCode, {Object? body}) => DioException(
  requestOptions: RequestOptions(path: '/orders'),
  type: DioExceptionType.badResponse,
  response: Response<Object>(
    data: body,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/orders'),
  ),
);

void main() {
  late _MockDio dio;
  late RemoteCustomerOrdersRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = RemoteCustomerOrdersRepository(ApiClient(baseUrl: '', dio: dio));
  });

  group('RemoteCustomerOrdersRepository', () {
    test('успешный чекаут: POST /orders → заказ с реальным номером', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(const {
          'id': 'order-uuid-1',
          'orderNumber': '5551',
          'status': 'NEW',
          'totalAmount': 780.0,
        }),
      );

      final order = await repository.createOrder(_request);

      expect(order.id, 'order-uuid-1');
      expect(order.orderNumber, '5551');
      expect(order.status, 'NEW');
      expect(order.totalAmount, const Money.kopecks(78000));
    });

    test('тело запроса отправляется по контракту POST /orders', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(const {
          'id': 'order-uuid-1',
          'orderNumber': '5551',
          'status': 'NEW',
          'totalAmount': 0,
        }),
      );

      await repository.createOrder(_request);

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.single, _request.toJson());
    });

    test('числовой orderNumber приводится к строке', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(const {
          'id': 'order-uuid-1',
          'orderNumber': 5552,
          'status': 'CONFIRMED',
          'totalAmount': 100,
        }),
      );

      final order = await repository.createOrder(_request);

      expect(order.orderNumber, '5552');
    });

    test('пустое тело ответа → OrdersException', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          statusCode: 201,
          requestOptions: RequestOptions(path: '/orders'),
        ),
      );

      expect(
        repository.createOrder(_request),
        throwsA(isA<OrdersException>()),
      );
    });

    test('ответ без номера заказа → OrdersException о некорректном ответе',
        () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _okResponse(const {'id': 'order-uuid-1'}),
      );

      expect(
        repository.createOrder(_request),
        throwsA(
          isA<OrdersException>().having(
            (e) => e.message,
            'message',
            contains('Некорректный ответ'),
          ),
        ),
      );
    });

    test('нет соединения → понятное сообщение про интернет', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenThrow(_transportError(type: DioExceptionType.connectionError));

      expect(
        repository.createOrder(_request),
        throwsA(
          isA<OrdersException>().having(
            (e) => e.message,
            'message',
            'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
          ),
        ),
      );
    });

    test('таймаут ответа → сообщение о неотвечающем сервере', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenThrow(_transportError(type: DioExceptionType.receiveTimeout));

      expect(
        repository.createOrder(_request),
        throwsA(
          isA<OrdersException>().having(
            (e) => e.message,
            'message',
            'Сервер не отвечает. Проверьте интернет и повторите попытку.',
          ),
        ),
      );
    });

    test('5xx → сервер недоступен, статус сохраняется', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenThrow(_badResponse(503));

      expect(
        repository.createOrder(_request),
        throwsA(
          isA<OrdersException>()
              .having(
                (e) => e.message,
                'message',
                'Сервер временно недоступен. Попробуйте оформить заказ позже.',
              )
              .having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('4xx с сообщением бэкенда → показываем сообщение бэкенда', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _badResponse(400, body: {'message': 'deliveryAddress must be filled'}),
      );

      expect(
        repository.createOrder(_request),
        throwsA(
          isA<OrdersException>()
              .having(
                (e) => e.message,
                'message',
                'deliveryAddress must be filled',
              )
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('4xx без сообщения → общая фраза о проверке данных', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenThrow(_badResponse(422));

      expect(
        repository.createOrder(_request),
        throwsA(
          isA<OrdersException>().having(
            (e) => e.message,
            'message',
            contains('Проверьте данные'),
          ),
        ),
      );
    });
  });
}

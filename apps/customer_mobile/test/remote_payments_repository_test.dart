import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/network/api_client.dart';
import 'package:customer_mobile/features/payments/data/payment.dart';
import 'package:customer_mobile/features/payments/data/payments_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _createdResponse(Map<String, dynamic> body) =>
    Response<Map<String, dynamic>>(
      data: body,
      statusCode: 201,
      requestOptions: RequestOptions(path: '/payments/create'),
    );

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  late _MockDio dio;
  late RemoteCustomerPaymentsRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = RemoteCustomerPaymentsRepository(
      ApiClient(baseUrl: '', dio: dio),
    );
  });

  group('RemoteCustomerPaymentsRepository', () {
    test('POST /payments/create: тело {orderId}, ответ с paymentUrl', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/payments/create',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _createdResponse(const {
          'paymentId': 'payment-uuid-1',
          'paymentUrl':
              'https://yoomoney.ru/checkout/payments/v2/contract?orderId=order-uuid-1',
          'status': 'PENDING',
        }),
      );

      final payment = await repository.createPayment('order-uuid-1');

      final captured =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/payments/create',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured, {'orderId': 'order-uuid-1'});
      expect(payment.id, 'payment-uuid-1');
      expect(
        payment.paymentUrl,
        'https://yoomoney.ru/checkout/payments/v2/contract?orderId=order-uuid-1',
      );
      expect(payment.status, PaymentStatus.pending);
      expect(payment.isSucceeded, isFalse);
    });

    test('статус SUCCEEDED парсится как оплаченный платёж', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/payments/create',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _createdResponse(const {
          'paymentId': 'payment-uuid-2',
          'paymentUrl': 'https://yoomoney.ru/checkout/payments/v2/contract',
          'status': 'SUCCEEDED',
        }),
      );

      final payment = await repository.createPayment('order-uuid-2');

      expect(payment.status, PaymentStatus.succeeded);
      expect(payment.isSucceeded, isTrue);
    });

    test('прокидывает Bearer-токен гостевой сессии', () async {
      final tokenProvider = AuthTokenProvider()..accessToken = 'access-123';
      final authedRepository = RemoteCustomerPaymentsRepository(
        ApiClient(baseUrl: '', dio: dio),
        tokenProvider,
      );
      when(
        () => dio.post<Map<String, dynamic>>(
          '/payments/create',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _createdResponse(const {
          'paymentId': 'payment-uuid-3',
          'paymentUrl': 'https://yoomoney.ru/checkout/payments/v2/contract',
          'status': 'PENDING',
        }),
      );

      await authedRepository.createPayment('order-uuid-3');

      final options =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/payments/create',
                  data: any(named: 'data'),
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.headers?['Authorization'], 'Bearer access-123');
    });

    test('ошибка 4xx: сообщение бэкенда пробрасывается гостю', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/payments/create',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/payments/create'),
          type: DioExceptionType.badResponse,
          response: Response<Object>(
            data: const {'message': 'Order already paid'},
            statusCode: 409,
            requestOptions: RequestOptions(path: '/payments/create'),
          ),
        ),
      );

      await expectLater(
        () => repository.createPayment('order-uuid-4'),
        throwsA(
          isA<PaymentsException>()
              .having((e) => e.message, 'message', 'Order already paid')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('нет соединения: понятное сообщение об ошибке сети', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/payments/create',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/payments/create'),
          type: DioExceptionType.connectionError,
          message: 'connection failed',
        ),
      );

      await expectLater(
        () => repository.createPayment('order-uuid-5'),
        throwsA(
          isA<PaymentsException>().having(
            (e) => e.message,
            'message',
            'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
          ),
        ),
      );
    });

    test('пустой ответ сервера → PaymentsException', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/payments/create',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: null,
          statusCode: 201,
          requestOptions: RequestOptions(path: '/payments/create'),
        ),
      );

      await expectLater(
        () => repository.createPayment('order-uuid-6'),
        throwsA(isA<PaymentsException>()),
      );
    });
  });
}

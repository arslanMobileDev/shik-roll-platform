import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/network/api_client.dart';
import 'package:kds/features/auth/data/cook_auth_repository.dart';
import 'package:kds/features/kds/data/kds_orders_repository.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import '../../core/network/api_client_test.dart' show FakeHttpClientAdapter;

void main() {
  test(
    'PATCH keeps terminal Authorization and adds a separate cook bearer',
    () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 200,
        body: {'id': 'order', 'status': 'COOKING'},
      );
      final client = ApiClient(
        baseUrl: 'http://test',
        tokenProvider: () => 'terminal',
      )..dio.httpClientAdapter = adapter;
      await HttpKdsOrdersRepository(
        client,
        cookToken: () => 'cook',
      ).updateOrderStatus(
        orderId: 'order',
        status: KdsOrderStatus.cooking,
        expectedVersion: 1,
      );
      expect(adapter.requestHeaders.single['Authorization'], 'Bearer terminal');
      expect(
        adapter.requestHeaders.single['X-Cook-Authorization'],
        'Bearer cook',
      );
    },
  );
  test(
    'personal login uses terminal bearer without the terminal logout interceptor',
    () async {
      final adapter = FakeHttpClientAdapter(statusCode: 401);
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final repo = HttpCookAuthRepository(
        baseUrl: 'http://test',
        terminalToken: () => 'terminal',
        dio: dio,
      );
      await expectLater(
        repo.login('89280000000', '1234'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requestHeaders.single['Authorization'], 'Bearer terminal');
      expect(dio.interceptors.whereType<InterceptorsWrapper>(), isEmpty);
    },
  );
}

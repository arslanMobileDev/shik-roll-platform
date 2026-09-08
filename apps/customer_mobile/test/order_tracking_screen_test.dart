import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/orders/data/order_tracking_repository.dart';
import 'package:customer_mobile/features/orders/domain/order_timeline.dart';
import 'package:customer_mobile/features/orders/presentation/screens/order_tracking_screen.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_settings_repository.dart';

/// Snapshot падает: проверяем error-стейт экрана.
final class _FailingTrackingRepository implements OrderTrackingRepository {
  @override
  Future<OrderTrackingUpdate> getOrderSnapshot(String orderId) =>
      throw const OrdersException('Сервер не отвечает.', statusCode: 503);

  @override
  Stream<OrderTrackingUpdate> openTrackingStream(String orderId) =>
      const Stream.empty();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  OrderTrackingRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<UserSettingsCubit>(
        create: (_) => UserSettingsCubit(FakeUserSettingsRepository()),
        child: OrderTrackingScreen(
          orderId: 'demo-order',
          orderNumber: '1042',
          trackingRepository: repository,
          deliveryAddress: 'ул. Ленина, д. 42, кв. 15',
          items: const [
            {'name': 'Филадельфия Классик', 'count': 2, 'price': 980},
          ],
          totalPrice: 1550,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('экран подключается к стриму и показывает статус из событий', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      FakeOrderTrackingRepository(
        latency: Duration.zero,
        stepDelay: Duration.zero,
        script: const ['NEW', 'CONFIRMED'],
      ),
    );
    await tester.pump();
    // В fake-стриме между событиями Future.delayed(Duration.zero) — это
    // zero-таймер, который срабатывает только при elapse fake-часов.
    await tester.pump(Duration.zero);
    await tester.pump();
    await tester.pump();

    // Live-событие CONFIRMED (v2) доехало до трекера.
    expect(find.text('#1042'), findsOneWidget);
    expect(find.text('Подтверждён'), findsWidgets);
    expect(find.text('15%'), findsOneWidget);

    // Адрес, состав и итог.
    expect(find.text('ул. Ленина, д. 42, кв. 15'), findsOneWidget);
    expect(find.text('Филадельфия Классик'), findsOneWidget);
    expect(find.text('1550 ₽'), findsOneWidget);
  });

  testWidgets('отменённый заказ показывает состояние отмены', (tester) async {
    await _pumpScreen(
      tester,
      FakeOrderTrackingRepository(
        latency: Duration.zero,
        stepDelay: Duration.zero,
        script: const ['CANCELLED'],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Отменён'), findsOneWidget);
    expect(find.textContaining('Заказ отменён'), findsOneWidget);
  });

  testWidgets('ошибка загрузки snapshot → сообщение и кнопка повтора', (
    tester,
  ) async {
    await _pumpScreen(tester, _FailingTrackingRepository());
    await tester.pump();
    await tester.pump();

    expect(find.text('Сервер не отвечает.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracking-retry-button')), findsOneWidget);
  });
}

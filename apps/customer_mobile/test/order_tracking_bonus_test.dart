import 'package:customer_mobile/features/loyalty/bloc/loyalty_cubit.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_repository.dart';
import 'package:customer_mobile/features/orders/data/order_tracking_repository.dart';
import 'package:customer_mobile/features/orders/presentation/screens/order_tracking_screen.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_settings_repository.dart';

Future<void> _pumpScreen(WidgetTester tester, LoyaltyCubit loyaltyCubit) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<UserSettingsCubit>(
        create: (_) => UserSettingsCubit(FakeUserSettingsRepository()),
        child: OrderTrackingScreen(
          orderId: 'demo-order',
          orderNumber: '1042',
          trackingRepository: FakeOrderTrackingRepository(
            latency: Duration.zero,
            stepDelay: Duration.zero,
            script: const ['NEW', 'CONFIRMED'],
          ),
          loyaltyCubit: loyaltyCubit,
          items: const [
            {'name': 'Филадельфия Классик', 'count': 2, 'price': 980},
          ],
          totalPrice: 1550,
        ),
      ),
    ),
  );
  // Snapshot + live-события fake-стрима (zero-таймеры).
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('EARN-запись леджера: блок «Бонусы начислены» с суммой', (
    tester,
  ) async {
    final loyaltyCubit = LoyaltyCubit(
      repository: FakeLoyaltyRepository(
        latency: Duration.zero,
        balance: 298,
        cashbackRate: 5,
        transactions: [
          BonusTransaction(
            id: 'tx-earn-1',
            type: BonusTransactionType.earn,
            points: 48,
            balanceAfter: 298,
            orderId: 'demo-order',
            createdAt: DateTime(2026, 9, 5, 12, 30),
          ),
        ],
      ),
    );
    await loyaltyCubit.loadBalance();
    await _pumpScreen(tester, loyaltyCubit);

    expect(find.byKey(const ValueKey('bonus-earn-card')), findsOneWidget);
    expect(find.text('Бонусы начислены'), findsOneWidget);
    expect(find.text('+48 бонусов зачислено на баланс'), findsOneWidget);
  });

  testWidgets('до начисления: превью ожидаемого кешбэка от итога заказа', (
    tester,
  ) async {
    final loyaltyCubit = LoyaltyCubit(
      repository: FakeLoyaltyRepository(
        latency: Duration.zero,
        balance: 250,
        cashbackRate: 5,
        transactions: const [],
      ),
    );
    await loyaltyCubit.loadBalance();
    await _pumpScreen(tester, loyaltyCubit);

    // floor(1550 * 5 / 100) = 77 бонусов после доставки.
    expect(find.byKey(const ValueKey('bonus-earn-card')), findsOneWidget);
    expect(find.text('Бонусы за заказ'), findsOneWidget);
    expect(find.text('Начислим ~77 бонусов после доставки'), findsOneWidget);
  });

  testWidgets('без ставки кешбэка и записей блок скрыт', (tester) async {
    final loyaltyCubit = LoyaltyCubit(
      repository: FakeLoyaltyRepository(
        latency: Duration.zero,
        balance: 0,
        cashbackRate: 0,
        transactions: const [],
      ),
    );
    await loyaltyCubit.loadBalance();
    await _pumpScreen(tester, loyaltyCubit);

    expect(find.byKey(const ValueKey('bonus-earn-card')), findsNothing);
  });
}

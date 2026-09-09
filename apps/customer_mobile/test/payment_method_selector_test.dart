import 'package:customer_mobile/features/cart/bloc/checkout_cubit.dart';
import 'package:customer_mobile/features/cart/data/fake_orders_repository.dart';
import 'package:customer_mobile/features/payments/data/fake_payments_repository.dart';
import 'package:customer_mobile/features/payments/data/payment_method.dart';
import 'package:customer_mobile/features/payments/view/widgets/payment_method_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CheckoutCubit cubit;

  setUp(() {
    cubit = CheckoutCubit(
      repository: FakeCustomerOrdersRepository(latency: Duration.zero),
      paymentsRepository: FakeCustomerPaymentsRepository(
        latency: Duration.zero,
      ),
    );
  });

  Future<void> pumpSelector(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<CheckoutCubit>.value(
            value: cubit,
            child: const PaymentMethodSelector(),
          ),
        ),
      ),
    );
  }

  testWidgets('два способа оплаты с подписями из контракта', (tester) async {
    await pumpSelector(tester);

    expect(find.text('Онлайн-оплата (СБП, Карты)'), findsOneWidget);
    expect(
      find.text('При получении (Картой курьеру / Наличными)'),
      findsOneWidget,
    );
  });

  testWidgets('по умолчанию выбрана онлайн-оплата ЮKassa', (tester) async {
    await pumpSelector(tester);

    expect(cubit.state.paymentMethod, PaymentMethod.online);
    // Ровно одна карточка отмечена.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
  });

  testWidgets('тап по карточке переключает выбор в CheckoutCubit', (
    tester,
  ) async {
    await pumpSelector(tester);

    await tester.tap(find.byKey(const ValueKey('payment-method-onDelivery')));
    await tester.pump();
    expect(cubit.state.paymentMethod, PaymentMethod.onDelivery);
    expect(
      find.byKey(const ValueKey('payment-method-check-onDelivery')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('payment-method-online')));
    await tester.pump();
    expect(cubit.state.paymentMethod, PaymentMethod.online);
  });
}

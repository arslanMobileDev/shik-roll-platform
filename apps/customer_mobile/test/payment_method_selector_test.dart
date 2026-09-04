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

  testWidgets('три способа оплаты с подписями из контракта', (tester) async {
    await pumpSelector(tester);

    expect(find.text('Онлайн (СБП, Картой через ЮKassa)'), findsOneWidget);
    expect(find.text('Наличными при получении'), findsOneWidget);
    expect(find.text('Картой курьеру / на стойке'), findsOneWidget);
  });

  testWidgets('по умолчанию выбрана онлайн-оплата ЮKassa', (tester) async {
    await pumpSelector(tester);

    expect(cubit.state.paymentMethod, PaymentMethod.yookassa);
    // Ровно одна карточка отмечена.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));
  });

  testWidgets('тап по карточке переключает выбор в CheckoutCubit', (
    tester,
  ) async {
    await pumpSelector(tester);

    await tester.tap(find.byKey(const ValueKey('payment-method-cash')));
    await tester.pump();
    expect(cubit.state.paymentMethod, PaymentMethod.cash);
    expect(
      find.byKey(const ValueKey('payment-method-check-cash')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('payment-method-terminal')));
    await tester.pump();
    expect(cubit.state.paymentMethod, PaymentMethod.terminal);

    await tester.tap(find.byKey(const ValueKey('payment-method-yookassa')));
    await tester.pump();
    expect(cubit.state.paymentMethod, PaymentMethod.yookassa);
  });
}

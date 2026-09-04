import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/auth/auth_session.dart';
import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/cart/bloc/cart_event.dart';
import 'package:customer_mobile/features/cart/bloc/checkout_cubit.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/cart/data/cart_line.dart';
import 'package:customer_mobile/features/cart/data/create_order_request.dart';
import 'package:customer_mobile/features/cart/data/fake_orders_repository.dart';
import 'package:customer_mobile/features/cart/data/guest_order.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/cart/view/cart_screen.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/payments/data/fake_payments_repository.dart';
import 'package:customer_mobile/features/payments/data/payment.dart';
import 'package:customer_mobile/features/payments/data/payment_method.dart';
import 'package:customer_mobile/features/payments/data/payments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrdersRepository extends Mock implements CustomerOrdersRepository {}

class _MockPaymentsRepository extends Mock
    implements CustomerPaymentsRepository {}

const _drink = MenuItem(
  id: 'item-lemonade',
  sku: 'D-001',
  name: 'Лимонад',
  category: MenuItemCategoryRef(id: 'cat-drinks', name: 'Напитки'),
  price: Money.kopecks(15000),
  sortOrder: 0,
  isPopular: false,
  isNew: false,
  isHalal: true,
  available: true,
  modifierGroups: [],
);

final _line = CartLine.fromSelection(item: _drink);

const _successOrder = GuestOrder(
  id: 'order-uuid-1',
  orderNumber: '5551',
  status: 'NEW',
  totalAmount: Money.kopecks(15000),
);

const _pendingPayment = Payment(
  id: 'payment-uuid-1',
  paymentUrl: 'https://yoomoney.ru/checkout/payments/v2/demo?orderId=order-uuid-1',
  status: PaymentStatus.pending,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateOrderRequest(
        branchId: '',
        orderType: OrderType.delivery,
        items: [],
      ),
    );
  });

  late _MockOrdersRepository ordersRepository;
  late _MockPaymentsRepository paymentsRepository;

  setUp(() {
    ordersRepository = _MockOrdersRepository();
    paymentsRepository = _MockPaymentsRepository();
  });

  CheckoutCubit buildCubit() => CheckoutCubit(
    repository: ordersRepository,
    paymentsRepository: paymentsRepository,
  );

  group('CheckoutCubit + платежи', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'ЮKassa: после создания заказа создаётся платёж с orderId заказа',
      build: buildCubit,
      seed: () => const CheckoutState(offerAccepted: true),
      act: (cubit) async {
        when(
          () => ordersRepository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        when(
          () => paymentsRepository.createPayment(any()),
        ).thenAnswer((_) async => _pendingPayment);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      expect: () => [
        predicate<CheckoutState>((s) => s.status == CheckoutStatus.submitting),
        predicate<CheckoutState>(
          (s) =>
              s.status == CheckoutStatus.success &&
              s.placedOrder?.id == 'order-uuid-1' &&
              s.payment?.paymentUrl == _pendingPayment.paymentUrl &&
              s.payment?.status == PaymentStatus.pending,
        ),
      ],
      verify: (_) {
        verify(
          () => paymentsRepository.createPayment('order-uuid-1'),
        ).called(1);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'наличными: платёж не создаётся, заказ сразу успешен',
      build: buildCubit,
      seed: () => const CheckoutState(
        offerAccepted: true,
        paymentMethod: PaymentMethod.cash,
      ),
      act: (cubit) async {
        when(
          () => ordersRepository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      expect: () => [
        predicate<CheckoutState>((s) => s.status == CheckoutStatus.submitting),
        predicate<CheckoutState>(
          (s) =>
              s.status == CheckoutStatus.success &&
              s.placedOrder?.id == 'order-uuid-1' &&
              s.payment == null,
        ),
      ],
      verify: (_) {
        verifyNever(() => paymentsRepository.createPayment(any()));
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'картой курьеру: платёж не создаётся, заказ сразу успешен',
      build: buildCubit,
      seed: () => const CheckoutState(
        offerAccepted: true,
        paymentMethod: PaymentMethod.terminal,
      ),
      act: (cubit) async {
        when(
          () => ordersRepository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      verify: (_) {
        verifyNever(() => paymentsRepository.createPayment(any()));
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'ошибка создания платежа: failure с сообщением, заказ остаётся',
      build: buildCubit,
      seed: () => const CheckoutState(offerAccepted: true),
      act: (cubit) async {
        when(
          () => ordersRepository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        when(() => paymentsRepository.createPayment(any())).thenThrow(
          const PaymentsException(
            'Сервер временно недоступен. Попробуйте оплатить позже.',
          ),
        );
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      expect: () => [
        predicate<CheckoutState>((s) => s.status == CheckoutStatus.submitting),
        predicate<CheckoutState>(
          (s) =>
              s.status == CheckoutStatus.failure &&
              s.errorMessage ==
                  'Сервер временно недоступен. Попробуйте оплатить позже.' &&
              s.payment == null,
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'выбор способа оплаты обновляет состояние',
      build: buildCubit,
      act: (cubit) => cubit.paymentMethodSelected(PaymentMethod.cash),
      expect: () => [
        predicate<CheckoutState>(
          (s) => s.paymentMethod == PaymentMethod.cash,
        ),
      ],
    );
  });

  group('Виджет-флоу онлайн-оплаты', () {
    Future<CustomerCartBloc> pumpCart(
      WidgetTester tester, {
      CustomerPaymentsRepository? payments,
    }) async {
      final cartBloc = CustomerCartBloc();
      final storage = InMemoryAuthTokenStorage();
      await storage.save(
        const StoredAuthSession(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          customerId: 'customer-1',
          phone: '+79991234567',
          name: 'Тест',
        ),
      );
      final authBloc = AuthBloc(
        repository: FakeAuthRepository(latency: Duration.zero),
        tokenStorage: storage,
        tokenProvider: AuthTokenProvider(),
      )..add(const AuthStarted());
      await authBloc.stream.firstWhere((s) => s.isAuthenticated);
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<CustomerCartBloc>.value(value: cartBloc),
              BlocProvider<CheckoutCubit>(
                create: (_) => CheckoutCubit(
                  repository: FakeCustomerOrdersRepository(
                    latency: Duration.zero,
                  ),
                  paymentsRepository:
                      payments ??
                      FakeCustomerPaymentsRepository(latency: Duration.zero),
                ),
              ),
              BlocProvider<OrderTypeCubit>(create: (_) => OrderTypeCubit()),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: Scaffold(body: CartScreen(onGoToMenu: () {})),
          ),
        ),
      );
      return cartBloc;
    }

    Future<void> prepareCheckout(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Самовывоз (стойка)'));
      await tester.tap(find.text('Самовывоз (стойка)'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('offer-checkbox')));
      await tester.tap(find.byKey(const ValueKey('offer-checkbox')));
      await tester.pump();
    }

    Future<void> closeSuccessScreen(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('back-to-menu-button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }

    testWidgets(
      'ЮKassa: экран оплаты с mock-ссылкой → демо-оплата → «Оплачено онлайн»',
      (tester) async {
        final cart = await pumpCart(tester);
        cart.add(const CartItemAdded(item: _drink));
        await tester.pump();
        await prepareCheckout(tester);

        await tester.tap(find.byKey(const ValueKey('checkout-submit-button')));
        await tester.pump();
        await tester.pump();

        // Экран статуса оплаты с confirmation URL из POST /payments/create.
        expect(find.text('Счёт на оплату выставлен'), findsOneWidget);
        final urlWidget = tester.widget<SelectableText>(
          find.byKey(const ValueKey('payment-url')),
        );
        expect(urlWidget.data, contains('yoomoney.ru'));
        expect(urlWidget.data, contains('demo-order-1042'));

        // Мок-оплата → экран успеха с бейджем «Оплачено онлайн (ЮKassa)».
        await tester.tap(find.byKey(const ValueKey('mock-pay-button')));
        await tester.pump();
        await tester.pump();

        expect(find.text('Заказ #1042 принят!'), findsOneWidget);
        expect(find.byKey(const ValueKey('paid-online-badge')), findsOneWidget);
        expect(find.text('Оплачено онлайн (ЮKassa)'), findsOneWidget);
        expect(cart.state.isEmpty, isTrue);

        await closeSuccessScreen(tester);
      },
    );

    testWidgets(
      'наличными: сразу экран успеха без бейджа, платёж не создаётся',
      (tester) async {
        final payments = _MockPaymentsRepository();
        final cart = await pumpCart(tester, payments: payments);
        cart.add(const CartItemAdded(item: _drink));
        await tester.pump();
        await prepareCheckout(tester);

        await tester.ensureVisible(
          find.byKey(const ValueKey('payment-method-cash')),
        );
        await tester.tap(find.byKey(const ValueKey('payment-method-cash')));
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('checkout-submit-button')));
        await tester.pump();
        await tester.pump();

        expect(find.text('Заказ #1042 принят!'), findsOneWidget);
        expect(find.byKey(const ValueKey('paid-online-badge')), findsNothing);
        verifyNever(() => payments.createPayment(any()));

        await closeSuccessScreen(tester);
      },
    );
  });
}

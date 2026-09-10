import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/core/auth/auth_session.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/cart/bloc/cart_event.dart';
import 'package:customer_mobile/features/cart/bloc/checkout_cubit.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/cart/data/cart_line.dart';
import 'package:customer_mobile/features/cart/data/create_order_request.dart';
import 'package:customer_mobile/features/cart/data/guest_order.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/cart/view/cart_screen.dart';
import 'package:customer_mobile/features/loyalty/bloc/loyalty_cubit.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_repository.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/orders/data/order_tracking_repository.dart';
import 'package:customer_mobile/features/payments/data/payment.dart';
import 'package:customer_mobile/features/payments/data/payment_method.dart';
import 'package:customer_mobile/features/payments/data/payments_repository.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_user_settings_repository.dart';

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

const _onlineOrder = GuestOrder(
  id: 'order-uuid-1',
  orderNumber: '5551',
  status: 'PENDING_PAYMENT',
  totalAmount: Money.kopecks(15000),
  paymentId: 'payment-uuid-1',
  paymentUrl: 'https://yoomoney.ru/checkout/order-uuid-1',
);
const _deliveryOrder = GuestOrder(
  id: 'order-uuid-2',
  orderNumber: '5552',
  status: 'NEW',
  totalAmount: Money.kopecks(15000),
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

  group('CheckoutCubit payment contract', () {
    late _MockOrdersRepository orders;
    late _MockPaymentsRepository legacyPayments;

    setUp(() {
      orders = _MockOrdersRepository();
      legacyPayments = _MockPaymentsRepository();
    });

    CheckoutCubit buildCubit() =>
        CheckoutCubit(repository: orders, paymentsRepository: legacyPayments);

    blocTest<CheckoutCubit, CheckoutState>(
      'ONLINE uses paymentUrl from POST /orders and does not call /payments/create',
      build: buildCubit,
      seed: () =>
          const CheckoutEditing(form: CheckoutForm(offerAccepted: true)),
      act: (cubit) async {
        when(
          () => orders.createOrder(any()),
        ).thenAnswer((_) async => _onlineOrder);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      expect: () => [
        isA<CheckoutSubmitting>(),
        isA<CheckoutSuccess>()
            .having(
              (s) => s.payment?.paymentUrl,
              'payment.paymentUrl',
              _onlineOrder.paymentUrl,
            )
            .having(
              (s) => s.payment?.status,
              'payment.status',
              PaymentStatus.pending,
            ),
      ],
      verify: (_) {
        verifyNever(() => legacyPayments.createPayment(any()));
        final request =
            verify(() => orders.createOrder(captureAny())).captured.single
                as CreateOrderRequest;
        expect(request.paymentMethod, PaymentMethod.online);
        expect(request.toJson()['paymentMethod'], 'ONLINE');
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'ON_DELIVERY completes without a payment redirect',
      build: buildCubit,
      seed: () => const CheckoutEditing(
        form: CheckoutForm(
          offerAccepted: true,
          paymentMethod: PaymentMethod.onDelivery,
        ),
      ),
      act: (cubit) async {
        when(
          () => orders.createOrder(any()),
        ).thenAnswer((_) async => _deliveryOrder);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      expect: () => [
        isA<CheckoutSubmitting>(),
        isA<CheckoutSuccess>().having((s) => s.payment, 'payment', isNull),
      ],
      verify: (_) {
        final request =
            verify(() => orders.createOrder(captureAny())).captured.single
                as CreateOrderRequest;
        expect(request.toJson()['paymentMethod'], 'ON_DELIVERY');
        verifyNever(() => legacyPayments.createPayment(any()));
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'ONLINE without paymentUrl reports a checkout error',
      build: buildCubit,
      seed: () =>
          const CheckoutEditing(form: CheckoutForm(offerAccepted: true)),
      act: (cubit) async {
        when(() => orders.createOrder(any())).thenAnswer(
          (_) async => const GuestOrder(
            id: 'order-without-url',
            orderNumber: '5553',
            status: 'PENDING_PAYMENT',
            totalAmount: Money.kopecks(15000),
          ),
        );
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      expect: () => [
        isA<CheckoutSubmitting>(),
        isA<CheckoutFailure>().having(
          (s) => s.errorMessage,
          'errorMessage',
          contains('не вернул ссылку'),
        ),
      ],
    );
  });

  group('checkout widget flow', () {
    Future<({CustomerCartBloc cart, List<Uri> launched})> pumpCart(
      WidgetTester tester,
    ) async {
      final cart = CustomerCartBloc();
      final orders = _MockOrdersRepository();
      final payments = _MockPaymentsRepository();
      final launched = <Uri>[];
      when(() => orders.createOrder(any())).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.single as CreateOrderRequest;
        return request.paymentMethod == PaymentMethod.online
            ? _onlineOrder
            : _deliveryOrder;
      });
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
      final auth = AuthBloc(
        repository: FakeAuthRepository(latency: Duration.zero),
        tokenStorage: storage,
        tokenProvider: AuthTokenProvider(),
      )..add(const AuthStarted());
      await auth.stream.firstWhere((state) => state.isAuthenticated);
      await tester.pumpWidget(
        BlocProvider<UserSettingsCubit>(
          create: (_) => UserSettingsCubit(FakeUserSettingsRepository()),
          child: MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<CustomerCartBloc>.value(value: cart),
                BlocProvider<CheckoutCubit>(
                  create: (_) => CheckoutCubit(
                    repository: orders,
                    paymentsRepository: payments,
                  ),
                ),
                BlocProvider<OrderTypeCubit>(create: (_) => OrderTypeCubit()),
                BlocProvider<AuthBloc>.value(value: auth),
                BlocProvider<LoyaltyCubit>(
                  create: (_) => LoyaltyCubit(
                    repository: FakeLoyaltyRepository(
                      latency: Duration.zero,
                      balance: 0,
                    ),
                  ),
                ),
              ],
              child: Scaffold(
                body: CartScreen(
                  onGoToMenu: () {},
                orderTrackingRepository: FakeOrderTrackingRepository(
                  latency: Duration.zero,
                  script: const ['NEW'],
                ),
                  paymentUrlLauncher: (uri) async {
                    launched.add(uri);
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      return (cart: cart, launched: launched);
    }

    Future<void> prepareCheckout(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Самовывоз (стойка)'));
      await tester.tap(find.text('Самовывоз (стойка)'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('offer-checkbox')));
      await tester.tap(find.byKey(const ValueKey('offer-checkbox')));
      await tester.pump();
    }

    testWidgets('ONLINE launches YooKassa and opens order tracking', (
      tester,
    ) async {
      final flow = await pumpCart(tester);
      flow.cart.add(const CartItemAdded(item: _drink));
      await tester.pump();
      await prepareCheckout(tester);
      await tester.tap(find.byKey(const ValueKey('checkout-submit-button')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(flow.launched.single.toString(), _onlineOrder.paymentUrl);
      expect(find.text('Отслеживание заказа'), findsOneWidget);
      expect(flow.cart.state.isEmpty, isTrue);
    });

    testWidgets('ON_DELIVERY skips the browser and opens order tracking', (
      tester,
    ) async {
      final flow = await pumpCart(tester);
      flow.cart.add(const CartItemAdded(item: _drink));
      await tester.pump();
      await prepareCheckout(tester);
      await tester.tap(find.byKey(const ValueKey('payment-method-onDelivery')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('checkout-submit-button')));
      await tester.pump();
      await tester.pump();

      expect(flow.launched, isEmpty);
      expect(find.text('Отслеживание заказа'), findsOneWidget);
      expect(flow.cart.state.isEmpty, isTrue);
    });
  });
}

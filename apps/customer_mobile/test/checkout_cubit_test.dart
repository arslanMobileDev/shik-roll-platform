import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/checkout_cubit.dart';
import 'package:customer_mobile/features/cart/data/cart_line.dart';
import 'package:customer_mobile/features/cart/data/create_order_request.dart';
import 'package:customer_mobile/features/cart/data/guest_order.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:customer_mobile/features/payments/data/fake_payments_repository.dart';
import 'package:customer_mobile/features/payments/data/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrdersRepository extends Mock implements CustomerOrdersRepository {}

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
  status: 'PENDING_PAYMENT',
  totalAmount: Money.kopecks(15000),
  paymentId: 'payment-uuid-1',
  paymentUrl: 'https://yoomoney.ru/checkout/order-uuid-1',
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateOrderRequest(
        brandId: '',
        branchId: '',
        orderType: OrderType.delivery,
        items: [],
      ),
    );
  });

  late _MockOrdersRepository repository;

  setUp(() => repository = _MockOrdersRepository());

  group('CheckoutCubit', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'успешный submit: submitting → success с реальным номером заказа',
      build: () => CheckoutCubit(
        repository: repository,
        brandId: 'brand-test',
        branchId: 'branch-test',
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () => const CheckoutEditing(
        form: CheckoutForm(
          street: 'ул. Пушкина',
          house: '10',
          offerAccepted: true,
        ),
      ),
      act: (cubit) async {
        when(
          () => repository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.delivery, lines: [_line]);
      },
      expect: () => [
        isA<CheckoutSubmitting>(),
        isA<CheckoutSuccess>().having(
          (s) => s.placedOrder.orderNumber,
          'placedOrder.orderNumber',
          '5551',
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'submit отправляет запрос по контракту: филиал, тип, адрес, позиции',
      build: () => CheckoutCubit(
        repository: repository,
        brandId: 'brand-test',
        branchId: 'branch-test',
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () => const CheckoutEditing(
        form: CheckoutForm(
          street: 'ул. Пушкина',
          house: '10',
          comment: 'Без лука',
          offerAccepted: true,
        ),
      ),
      act: (cubit) async {
        when(
          () => repository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.delivery, lines: [_line]);
      },
      verify: (cubit) {
        expect(cubit.state, isA<CheckoutSuccess>());
        final captured =
            verify(() => repository.createOrder(captureAny())).captured.single
                as CreateOrderRequest;
        expect(captured.orderType, OrderType.delivery);
        expect(captured.deliveryAddress, 'ул. Пушкина, д. 10');
        expect(captured.scheduledFor, isNull);
        expect(captured.brandId, 'brand-test');
        expect(captured.branchId, 'branch-test');
        expect(captured.comment, 'Без лука');
        expect(captured.items.single.menuItemId, 'item-lemonade');
        expect(captured.items.single.quantity, 1);
        expect(captured.paymentMethod.wireName, 'ONLINE');
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'ошибка сети: failure, корзина и форма не сброшены, сообщение видно',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () => const CheckoutEditing(
        form: CheckoutForm(
          street: 'ул. Пушкина',
          house: '10',
          offerAccepted: true,
        ),
      ),
      act: (cubit) async {
        when(() => repository.createOrder(any())).thenThrow(
          const OrdersException(
            'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
          ),
        );
        await cubit.submit(orderType: OrderType.delivery, lines: [_line]);
      },
      expect: () => [
        isA<CheckoutSubmitting>(),
        isA<CheckoutFailure>()
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
            )
            .having(
              (s) => s.composedAddress,
              'composedAddress',
              'ул. Пушкина, д. 10',
            )
            .having((s) => s.offerAccepted, 'offerAccepted', isTrue),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'без пункта «оферта принята» submit не уходит в сеть',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () => const CheckoutEditing(
        form: CheckoutForm(street: 'ул. Пушкина', house: '10'),
      ),
      act: (cubit) =>
          cubit.submit(orderType: OrderType.delivery, lines: [_line]),
      expect: () => <CheckoutState>[],
      verify: (_) => verifyNever(() => repository.createOrder(any())),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'доставка без адреса не отправляет заказ',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () =>
          const CheckoutEditing(form: CheckoutForm(offerAccepted: true)),
      act: (cubit) =>
          cubit.submit(orderType: OrderType.delivery, lines: [_line]),
      expect: () => <CheckoutState>[],
      verify: (_) => verifyNever(() => repository.createOrder(any())),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'самовывоз: адрес не нужен, заказ уходит без deliveryAddress',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () =>
          const CheckoutEditing(form: CheckoutForm(offerAccepted: true)),
      act: (cubit) async {
        when(
          () => repository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      verify: (cubit) {
        expect(cubit.state, isA<CheckoutSuccess>());
        final captured =
            verify(() => repository.createOrder(captureAny())).captured.single
                as CreateOrderRequest;
        expect(captured.deliveryAddress, isNull);
        expect(captured.orderType, OrderType.pickup);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'double-tap: повторный submit во время отправки игнорируется, '
      'заказ создаётся один раз (ADR-001)',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () =>
          const CheckoutEditing(form: CheckoutForm(offerAccepted: true)),
      act: (cubit) async {
        when(() => repository.createOrder(any())).thenAnswer((_) async {
          // Медленная сеть: второй тап прилетает, пока первый заказ в полёте.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _successOrder;
        });
        await Future.wait([
          cubit.submit(orderType: OrderType.pickup, lines: [_line]),
          cubit.submit(orderType: OrderType.pickup, lines: [_line]),
        ]);
      },
      expect: () => [isA<CheckoutSubmitting>(), isA<CheckoutSuccess>()],
      verify: (_) => verify(() => repository.createOrder(any())).called(1),
    );
  });

  group('CheckoutForm: структурированный адрес', () {
    test('composedAddress собирает все заполненные поля по шаблону', () {
      const form = CheckoutForm(
        street: ' ул. Пушкина ',
        house: '10',
        apartment: '5',
        entrance: '2',
        floor: '3',
        intercom: '45',
      );
      expect(
        form.composedAddress,
        'ул. Пушкина, д. 10, кв. 5, подъезд 2, этаж 3, домофон 45',
      );
    });

    test('composedAddress пропускает пустые опциональные поля', () {
      const form = CheckoutForm(street: 'ул. Пушкина', house: '10');
      expect(form.composedAddress, 'ул. Пушкина, д. 10');
    });

    test('hasDeliveryAddress: улица без дома недостаточна', () {
      expect(const CheckoutForm(street: 'ул. Пушкина').hasDeliveryAddress, isFalse);
      expect(const CheckoutForm(house: '10').hasDeliveryAddress, isFalse);
      expect(
        const CheckoutForm(street: 'ул. Пушкина', house: '10')
            .hasDeliveryAddress,
        isTrue,
      );
    });

    blocTest<CheckoutCubit, CheckoutState>(
      'доставка: улица без дома блокирует submit',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () => const CheckoutEditing(
        form: CheckoutForm(street: 'ул. Пушкина', offerAccepted: true),
      ),
      act: (cubit) =>
          cubit.submit(orderType: OrderType.delivery, lines: [_line]),
      expect: () => <CheckoutState>[],
      verify: (_) => verifyNever(() => repository.createOrder(any())),
    );
  });

  group('CheckoutForm: время получения (scheduledAt)', () {
    final slot = DateTime(2026, 9, 11, 19, 30);

    test('copyWith: scheduledAt: null сохраняет прежнее значение', () {
      final form = CheckoutForm(scheduledAt: slot);
      expect(form.copyWith(scheduledAt: null).scheduledAt, slot);
    });

    test('copyWith: clearScheduledAt сбрасывает время в null (ASAP)', () {
      final form = CheckoutForm(scheduledAt: slot);
      expect(form.copyWith(clearScheduledAt: true).scheduledAt, isNull);
      expect(
        form.copyWith(scheduledAt: slot, clearScheduledAt: true).scheduledAt,
        isNull,
      );
    });

    blocTest<CheckoutCubit, CheckoutState>(
      'scheduledSelected фиксирует слот, asapSelected сбрасывает',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      act: (cubit) {
        cubit.scheduledSelected(slot);
        cubit.asapSelected();
      },
      expect: () => [
        isA<CheckoutEditing>().having((s) => s.scheduledAt, 'scheduledAt', slot),
        isA<CheckoutEditing>().having(
          (s) => s.scheduledAt,
          'scheduledAt',
          isNull,
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'submit со слотом: scheduledFor уходит в запросе как ISO-8601 UTC',
      build: () => CheckoutCubit(
        repository: repository,
        paymentsRepository: FakeCustomerPaymentsRepository(
          latency: Duration.zero,
        ),
      ),
      seed: () => CheckoutEditing(
        form: CheckoutForm(offerAccepted: true, scheduledAt: slot),
      ),
      act: (cubit) async {
        when(
          () => repository.createOrder(any()),
        ).thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      verify: (_) {
        final captured =
            verify(() => repository.createOrder(captureAny())).captured.single
                as CreateOrderRequest;
        expect(captured.scheduledFor, slot);
        expect(
          captured.toJson()['scheduledFor'],
          slot.toUtc().toIso8601String(),
        );
      },
    );
  });
}

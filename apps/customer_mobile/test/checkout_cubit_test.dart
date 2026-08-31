import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/checkout_cubit.dart';
import 'package:customer_mobile/features/cart/data/cart_line.dart';
import 'package:customer_mobile/features/cart/data/create_order_request.dart';
import 'package:customer_mobile/features/cart/data/guest_order.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/menu/bloc/order_type.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
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

  late _MockOrdersRepository repository;

  setUp(() => repository = _MockOrdersRepository());

  group('CheckoutCubit', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'успешный submit: submitting → success с реальным номером заказа',
      build: () => CheckoutCubit(repository: repository),
      seed: () => const CheckoutState(
        address: 'ул. Пушкина, 10',
        offerAccepted: true,
      ),
      act: (cubit) async {
        when(() => repository.createOrder(any()))
            .thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.delivery, lines: [_line]);
      },
      expect: () => [
        predicate<CheckoutState>((s) => s.status == CheckoutStatus.submitting),
        predicate<CheckoutState>(
          (s) =>
              s.status == CheckoutStatus.success &&
              s.placedOrder?.orderNumber == '5551',
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'submit отправляет запрос по контракту: филиал, тип, адрес, позиции',
      build: () => CheckoutCubit(repository: repository),
      seed: () => const CheckoutState(
        address: 'ул. Пушкина, 10',
        comment: 'Без лука',
        offerAccepted: true,
      ),
      act: (cubit) async {
        when(() => repository.createOrder(any()))
            .thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.delivery, lines: [_line]);
      },
      verify: (cubit) {
        expect(cubit.state.status, CheckoutStatus.success);
        final captured = verify(
          () => repository.createOrder(captureAny()),
        ).captured.single as CreateOrderRequest;
        expect(captured.orderType, OrderType.delivery);
        expect(captured.deliveryAddress, 'ул. Пушкина, 10');
        expect(captured.branchId, isNotEmpty);
        expect(captured.comment, 'Без лука');
        expect(captured.items.single.menuItemId, 'item-lemonade');
        expect(captured.items.single.quantity, 1);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'ошибка сети: failure, корзина и форма не сброшены, сообщение видно',
      build: () => CheckoutCubit(repository: repository),
      seed: () => const CheckoutState(
        address: 'ул. Пушкина, 10',
        offerAccepted: true,
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
        predicate<CheckoutState>((s) => s.status == CheckoutStatus.submitting),
        predicate<CheckoutState>(
          (s) =>
              s.status == CheckoutStatus.failure &&
              s.errorMessage ==
                  'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.' &&
              s.address == 'ул. Пушкина, 10' &&
              s.offerAccepted,
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'без пункта «оферта принята» submit не уходит в сеть',
      build: () => CheckoutCubit(repository: repository),
      seed: () => const CheckoutState(address: 'ул. Пушкина, 10'),
      act: (cubit) =>
          cubit.submit(orderType: OrderType.delivery, lines: [_line]),
      expect: () => <CheckoutState>[],
      verify: (_) => verifyNever(() => repository.createOrder(any())),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'доставка без адреса не отправляет заказ',
      build: () => CheckoutCubit(repository: repository),
      seed: () => const CheckoutState(offerAccepted: true),
      act: (cubit) =>
          cubit.submit(orderType: OrderType.delivery, lines: [_line]),
      expect: () => <CheckoutState>[],
      verify: (_) => verifyNever(() => repository.createOrder(any())),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'самовывоз: адрес не нужен, заказ уходит без deliveryAddress',
      build: () => CheckoutCubit(repository: repository),
      seed: () => const CheckoutState(offerAccepted: true),
      act: (cubit) async {
        when(() => repository.createOrder(any()))
            .thenAnswer((_) async => _successOrder);
        await cubit.submit(orderType: OrderType.pickup, lines: [_line]);
      },
      verify: (cubit) {
        expect(cubit.state.status, CheckoutStatus.success);
        final captured = verify(
          () => repository.createOrder(captureAny()),
        ).captured.single as CreateOrderRequest;
        expect(captured.deliveryAddress, isNull);
        expect(captured.orderType, OrderType.pickup);
      },
    );
  });
}

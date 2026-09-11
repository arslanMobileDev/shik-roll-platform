import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/cart_event.dart';
import 'package:customer_mobile/features/cart/bloc/cart_state.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/cart/data/cart_line.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Потоки самого блока (добавление/мердж позиций, шаг количества, удаление
/// при нуле, очистка) покрыты в customer_cart_bloc_test.dart. Здесь —
/// расширенная поверхность состояния: deliveryFee/finalAmount и семантика
/// nullable errorMessage с явным флагом clearError.
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

void main() {
  group('CartState: итоги', () {
    test('finalAmount = total + deliveryFee', () {
      final state = CartState(
        lines: [CartLine.fromSelection(item: _drink, quantity: 2)],
        deliveryFee: const Money.kopecks(19900),
      );

      expect(state.total, const Money.kopecks(30000));
      expect(state.finalAmount, const Money.kopecks(49900));
    });

    test('пустая корзина: finalAmount — только стоимость доставки', () {
      const state = CartState(deliveryFee: Money.kopecks(19900));

      expect(state.total, Money.zero);
      expect(state.finalAmount, const Money.kopecks(19900));
    });
  });

  group('CartState.copyWith: nullable errorMessage', () {
    const withError = CartState(errorMessage: 'промокод не найден');

    test('по умолчанию сохраняет прежнюю ошибку', () {
      expect(withError.copyWith().errorMessage, 'промокод не найден');
    });

    test('переданное значение заменяет ошибку', () {
      expect(
        withError.copyWith(errorMessage: 'позиция недоступна').errorMessage,
        'позиция недоступна',
      );
    });

    test('errorMessage: null сохраняет прежнее значение', () {
      expect(
        withError.copyWith(errorMessage: null).errorMessage,
        'промокод не найден',
      );
    });

    test('clearError: true сбрасывает ошибку в null', () {
      expect(withError.copyWith(clearError: true).errorMessage, isNull);
    });

    test('clearError побеждает одновременно переданное значение', () {
      expect(
        withError.copyWith(errorMessage: 'x', clearError: true).errorMessage,
        isNull,
      );
    });
  });

  group('CustomerCartBloc: расширенное состояние', () {
    blocTest<CustomerCartBloc, CartState>(
      'успешная мутация сбрасывает устаревшую ошибку',
      build: CustomerCartBloc.new,
      seed: () => const CartState(errorMessage: 'промокод не найден'),
      act: (bloc) => bloc.add(const CartItemAdded(item: _drink)),
      expect: () => [
        predicate<CartState>(
          (s) => s.lines.length == 1 && s.errorMessage == null,
        ),
      ],
    );

    blocTest<CustomerCartBloc, CartState>(
      'deliveryFee переживает мутации позиций, finalAmount пересчитывается',
      build: CustomerCartBloc.new,
      seed: () => const CartState(deliveryFee: Money.kopecks(19900)),
      act: (bloc) => bloc
        ..add(const CartItemAdded(item: _drink))
        ..add(
          const CartLineQuantityChanged(lineId: 'item-lemonade|', delta: 1),
        ),
      expect: () => [
        predicate<CartState>(
          (s) =>
              s.deliveryFee == const Money.kopecks(19900) &&
              s.finalAmount == const Money.kopecks(19900 + 15000),
        ),
        predicate<CartState>(
          (s) =>
              s.deliveryFee == const Money.kopecks(19900) &&
              s.finalAmount == const Money.kopecks(19900 + 30000),
        ),
      ],
    );

    blocTest<CustomerCartBloc, CartState>(
      'очистка корзины сбрасывает и ошибку, и стоимость доставки',
      build: CustomerCartBloc.new,
      seed: () => const CartState(
        deliveryFee: Money.kopecks(19900),
        errorMessage: 'промокод не найден',
      ),
      act: (bloc) => bloc
        ..add(const CartItemAdded(item: _drink))
        ..add(const CartCleared()),
      expect: () => [
        predicate<CartState>((s) => s.lines.length == 1),
        predicate<CartState>(
          (s) =>
              s.isEmpty &&
              s.errorMessage == null &&
              s.deliveryFee == Money.zero &&
              s.finalAmount == Money.zero,
        ),
      ],
    );
  });
}

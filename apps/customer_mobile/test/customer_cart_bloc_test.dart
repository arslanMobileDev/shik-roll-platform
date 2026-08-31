import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/bloc/cart_event.dart';
import 'package:customer_mobile/features/cart/bloc/cart_state.dart';
import 'package:customer_mobile/features/cart/bloc/customer_cart_bloc.dart';
import 'package:customer_mobile/features/menu/data/menu_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Roll with a required single-choice portion group and an optional
/// multiple-choice sauce group.
final _roll = () {
  const portionGroup = ModifierGroup(
    id: 'mg-portion',
    name: 'Порция',
    selectionType: ModifierSelectionType.single,
    minSelected: 1,
    maxSelected: 1,
    isRequired: true,
    sortOrder: 0,
    items: [
      ModifierItem(
        id: 'mi-p-std',
        name: 'Стандарт',
        price: Money.zero,
        sortOrder: 0,
      ),
      ModifierItem(
        id: 'mi-p-lg',
        name: 'Большая',
        price: Money.kopecks(15000),
        sortOrder: 1,
      ),
    ],
  );
  const sauceGroup = ModifierGroup(
    id: 'mg-sauce',
    name: 'Соусы',
    selectionType: ModifierSelectionType.multiple,
    minSelected: 0,
    maxSelected: 2,
    isRequired: false,
    sortOrder: 1,
    items: [
      ModifierItem(
        id: 'mi-s-spicy',
        name: 'Спайси',
        price: Money.kopecks(4000),
        sortOrder: 0,
      ),
    ],
  );
  return MenuItem(
    id: 'item-philadelphia',
    sku: 'R-001',
    name: 'Филадельфия',
    category: const MenuItemCategoryRef(id: 'cat-rolls', name: 'Роллы'),
    price: const Money.kopecks(39000),
    sortOrder: 0,
    isPopular: true,
    isNew: false,
    isHalal: true,
    available: true,
    modifierGroups: const [portionGroup, sauceGroup],
  );
}();

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
  group('CustomerCartBloc', () {
    blocTest<CustomerCartBloc, CartState>(
      'добавление товара с модификаторами: позиция с надбавками, итог '
      'пересчитан',
      build: CustomerCartBloc.new,
      act: (bloc) => bloc.add(
        CartItemAdded(
          item: _roll,
          selection: const {
            'mg-portion': {'mi-p-lg'},
            'mg-sauce': {'mi-s-spicy'},
          },
        ),
      ),
      expect: () => [
        predicate<CartState>(
          (s) =>
              s.lines.length == 1 &&
              s.lines.single.quantity == 1 &&
              s.lines.single.unitPrice == const Money.kopecks(39000 + 15000 + 4000) &&
              s.lines.single.modifiersLabel == 'Большая · Спайси' &&
              s.total == const Money.kopecks(58000) &&
              s.itemCount == 1,
        ),
      ],
    );

    blocTest<CustomerCartBloc, CartState>(
      'повторное добавление той же комбинации увеличивает количество',
      build: CustomerCartBloc.new,
      act: (bloc) => bloc
        ..add(const CartItemAdded(item: _drink))
        ..add(const CartItemAdded(item: _drink)),
      expect: () => [
        predicate<CartState>(
          (s) => s.lines.length == 1 && s.lines.single.quantity == 1,
        ),
        predicate<CartState>(
          (s) =>
              s.lines.length == 1 &&
              s.lines.single.quantity == 2 &&
              s.total == const Money.kopecks(30000) &&
              s.itemCount == 2,
        ),
      ],
    );

    blocTest<CustomerCartBloc, CartState>(
      'другой набор модификаторов — отдельная позиция',
      build: CustomerCartBloc.new,
      act: (bloc) => bloc
        ..add(
          CartItemAdded(
            item: _roll,
            selection: const {'mg-portion': {'mi-p-std'}},
          ),
        )
        ..add(
          CartItemAdded(
            item: _roll,
            selection: const {'mg-portion': {'mi-p-lg'}},
          ),
        ),
      expect: () => [
        predicate<CartState>((s) => s.lines.length == 1),
        predicate<CartState>(
          (s) =>
              s.lines.length == 2 &&
              s.total == const Money.kopecks(39000 + 39000 + 15000),
        ),
      ],
    );

    blocTest<CustomerCartBloc, CartState>(
      'изменение количества: +1 / −1, ноль удаляет позицию',
      build: CustomerCartBloc.new,
      act: (bloc) => bloc
        ..add(const CartItemAdded(item: _drink))
        ..add(
          const CartLineQuantityChanged(lineId: 'item-lemonade|', delta: 1),
        )
        ..add(
          const CartLineQuantityChanged(lineId: 'item-lemonade|', delta: -1),
        )
        ..add(
          const CartLineQuantityChanged(lineId: 'item-lemonade|', delta: -1),
        ),
      expect: () => [
        predicate<CartState>((s) => s.lines.single.quantity == 1),
        predicate<CartState>(
          (s) =>
              s.lines.single.quantity == 2 &&
              s.total == const Money.kopecks(30000),
        ),
        predicate<CartState>((s) => s.lines.single.quantity == 1),
        predicate<CartState>((s) => s.isEmpty && s.total == Money.zero),
      ],
    );

    blocTest<CustomerCartBloc, CartState>(
      'удаление позиции убирает её из корзины',
      build: CustomerCartBloc.new,
      act: (bloc) => bloc
        ..add(const CartItemAdded(item: _drink))
        ..add(const CartItemAdded(item: _drink))
        ..add(const CartLineRemoved(lineId: 'item-lemonade|')),
      expect: () => [
        predicate<CartState>((s) => s.lines.single.quantity == 1),
        predicate<CartState>((s) => s.lines.single.quantity == 2),
        predicate<CartState>((s) => s.isEmpty),
      ],
    );

    blocTest<CustomerCartBloc, CartState>(
      'очистка корзины после чекаута',
      build: CustomerCartBloc.new,
      act: (bloc) => bloc
        ..add(const CartItemAdded(item: _drink))
        ..add(
          CartItemAdded(
            item: _roll,
            selection: const {'mg-portion': {'mi-p-std'}},
          ),
        )
        ..add(const CartCleared()),
      expect: () => [
        predicate<CartState>((s) => s.lines.length == 1),
        predicate<CartState>((s) => s.lines.length == 2 && s.itemCount == 2),
        predicate<CartState>(
          (s) => s.isEmpty && s.itemCount == 0 && s.total == Money.zero,
        ),
      ],
    );
  });
}

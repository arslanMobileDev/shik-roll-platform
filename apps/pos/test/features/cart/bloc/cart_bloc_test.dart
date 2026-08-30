import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/utils/money.dart';
import 'package:pos/features/cart/bloc/cart_bloc.dart';
import 'package:pos/features/cart/bloc/cart_event.dart';
import 'package:pos/features/cart/bloc/cart_state.dart';
import 'package:pos/features/cart/domain/cart_line.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  final spicy = SelectedModifier(
    groupId: 'mg-sauce',
    groupName: 'Соус',
    optionId: 'mi-spicy',
    optionName: 'Спайси',
    price: const Money.kopecks(4000),
  );
  final unagi = SelectedModifier(
    groupId: 'mg-sauce',
    groupName: 'Соус',
    optionId: 'mi-unagi',
    optionName: 'Унаги',
    price: const Money.kopecks(4000),
  );

  group('CartBloc', () {
    blocTest<CartBloc, CartState>(
      'adds an item with its effective price',
      build: CartBloc.new,
      act: (bloc) => bloc.add(CartItemAdded(item: testMenuItem())),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.itemCount, 1);
        expect(bloc.state.total, const Money.kopecks(39000));
      },
    );

    blocTest<CartBloc, CartState>(
      'merges repeated adds of the same configuration into one line',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(CartItemAdded(item: testMenuItem())),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.quantity, 3);
        expect(bloc.state.total, const Money.kopecks(39000 * 3));
      },
    );

    blocTest<CartBloc, CartState>(
      'keeps different modifier configurations on separate lines',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [spicy])),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(2));
      },
    );

    blocTest<CartBloc, CartState>(
      'includes modifier surcharges in the total (exact decimal math)',
      build: CartBloc.new,
      act: (bloc) => bloc.add(
        CartItemAdded(item: testMenuItem(), modifiers: [spicy, unagi]),
      ),
      verify: (bloc) {
        final line = bloc.state.lines.single;
        // 390,00 + 40,00 + 40,00 = 470,00 ₽
        expect(line.unitPrice, const Money.kopecks(47000));
        expect(bloc.state.total, const Money.kopecks(47000));
      },
    );

    blocTest<CartBloc, CartState>(
      'modifier order does not affect line identity',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [spicy, unagi]))
        ..add(CartItemAdded(item: testMenuItem(), modifiers: [unagi, spicy])),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.quantity, 2);
      },
    );

    blocTest<CartBloc, CartState>(
      'quantity changes recalculate the line and cart totals',
      build: CartBloc.new,
      act: (bloc) async {
        bloc.add(CartItemAdded(item: testMenuItem()));
        await Future<void>.delayed(Duration.zero);
        final key = bloc.state.lines.single.key;
        bloc.add(CartLineQuantityChanged(key, 4));
      },
      verify: (bloc) {
        expect(bloc.state.itemCount, 4);
        expect(bloc.state.total, const Money.kopecks(39000 * 4));
      },
    );

    blocTest<CartBloc, CartState>(
      'quantity of zero removes the line',
      build: CartBloc.new,
      act: (bloc) async {
        bloc.add(CartItemAdded(item: testMenuItem()));
        await Future<void>.delayed(Duration.zero);
        final key = bloc.state.lines.single.key;
        bloc.add(CartLineQuantityChanged(key, 0));
      },
      verify: (bloc) => expect(bloc.state.isEmpty, isTrue),
    );

    blocTest<CartBloc, CartState>(
      'refuses to add unavailable or stop-listed items',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem(isAvailable: false)))
        ..add(CartItemAdded(item: testMenuItem(stopListed: true))),
      verify: (bloc) => expect(bloc.state.isEmpty, isTrue),
    );

    blocTest<CartBloc, CartState>(
      'clear empties the cart',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(CartItemAdded(item: testMenuItem()))
        ..add(const CartCleared()),
      verify: (bloc) {
        expect(bloc.state.isEmpty, isTrue);
        expect(bloc.state.total, Money.zero);
      },
    );
  });
}

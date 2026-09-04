import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/utils/money.dart';
import 'package:customer_mobile/features/cart/data/orders_repository.dart';
import 'package:customer_mobile/features/orders/bloc/order_history_bloc.dart';
import 'package:customer_mobile/features/orders/data/order_history_models.dart';
import 'package:customer_mobile/features/orders/data/order_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderHistoryRepository extends Mock
    implements OrderHistoryRepository {}

final _order = OrderHistoryEntry(
  id: 'order-1',
  orderNumber: '1042',
  status: 'COOKING',
  type: 'DELIVERY',
  totalAmount: const Money.kopecks(78000),
  createdAt: DateTime(2026, 9, 4, 12, 30),
  items: const [
    OrderHistoryItem(
      menuItemId: 'item-philadelphia',
      name: 'Филадельфия',
      quantity: 2,
      unitPrice: Money.kopecks(39000),
      modifiers: [],
    ),
  ],
);

void main() {
  late _MockOrderHistoryRepository repository;

  setUp(() => repository = _MockOrderHistoryRepository());

  group('OrderHistoryBloc', () {
    blocTest<OrderHistoryBloc, OrderHistoryState>(
      'успешная загрузка: loading → loaded со списком',
      build: () => OrderHistoryBloc(repository: repository),
      setUp: () => when(
        () => repository.getOrders(),
      ).thenAnswer((_) async => [_order]),
      act: (bloc) => bloc.add(const OrderHistoryStarted()),
      expect: () => [
        predicate<OrderHistoryState>(
          (s) => s.status == OrderHistoryStatus.loading,
        ),
        predicate<OrderHistoryState>(
          (s) =>
              s.status == OrderHistoryStatus.loaded &&
              s.orders.single.orderNumber == '1042',
        ),
      ],
    );

    blocTest<OrderHistoryBloc, OrderHistoryState>(
      'ошибка репозитория → failure с сообщением',
      build: () => OrderHistoryBloc(repository: repository),
      setUp: () => when(() => repository.getOrders()).thenThrow(
        const OrdersException(
          'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        ),
      ),
      act: (bloc) => bloc.add(const OrderHistoryStarted()),
      expect: () => [
        predicate<OrderHistoryState>(
          (s) => s.status == OrderHistoryStatus.loading,
        ),
        predicate<OrderHistoryState>(
          (s) =>
              s.status == OrderHistoryStatus.failure &&
              s.errorMessage ==
                  'Сервер не отвечает. Проверьте интернет и повторите попытку.',
        ),
      ],
    );

    blocTest<OrderHistoryBloc, OrderHistoryState>(
      'refresh перезапрашивает список',
      build: () => OrderHistoryBloc(repository: repository),
      setUp: () => when(
        () => repository.getOrders(),
      ).thenAnswer((_) async => [_order]),
      act: (bloc) async {
        bloc.add(const OrderHistoryStarted());
        await bloc.stream.firstWhere(
          (s) => s.status == OrderHistoryStatus.loaded,
        );
        bloc.add(const OrderHistoryRefreshed());
      },
      verify: (_) => verify(() => repository.getOrders()).called(2),
    );
  });
}

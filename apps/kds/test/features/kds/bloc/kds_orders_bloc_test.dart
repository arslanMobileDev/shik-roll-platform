import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/kds/bloc/kds_orders_bloc.dart';
import 'package:kds/features/kds/bloc/kds_orders_event.dart';
import 'package:kds/features/kds/bloc/kds_orders_state.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';

import '../../../helpers/test_fixtures.dart';

void main() {
  const branchId = 'branch-central';

  KdsOrdersBloc buildBloc(TestKdsOrdersRepository repository) =>
      KdsOrdersBloc(repository: repository, pollInterval: null);

  group('KdsOrdersBloc — загрузка', () {
    blocTest<KdsOrdersBloc, KdsOrdersState>(
      'начальная загрузка: Loading → Loaded, заказы отсортированы FIFO, '
      'COMPLETED/CANCELLED скрыты',
      build: () => buildBloc(
        TestKdsOrdersRepository(
          orders: [
            buildOrder(
              id: 'newer',
              createdAt: kNow.subtract(const Duration(minutes: 2)),
            ),
            buildOrder(
              id: 'older',
              createdAt: kNow.subtract(const Duration(minutes: 15)),
            ),
            buildOrder(id: 'done', status: KdsOrderStatus.completed),
            buildOrder(id: 'void', status: KdsOrderStatus.cancelled),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const KdsOrdersStarted(branchId: branchId)),
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersLoaded>()
            .having(
              (s) => s.orders.map((o) => o.id).toList(),
              'FIFO: старейший первым, завершённые скрыты',
              ['older', 'newer'],
            )
            .having(
              (s) => s.freshOrderIds,
              'первая загрузка не подсвечивает заказы как новые',
              isEmpty,
            ),
      ],
    );

    blocTest<KdsOrdersBloc, KdsOrdersState>(
      'ошибка начальной загрузки → Error',
      build: () => buildBloc(
        TestKdsOrdersRepository()..fetchError = StateError('нет сети'),
      ),
      act: (bloc) => bloc.add(const KdsOrdersStarted(branchId: branchId)),
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersError>().having(
          (s) => s.message,
          'message',
          contains('нет сети'),
        ),
      ],
    );

    blocTest<KdsOrdersBloc, KdsOrdersState>(
      'повторный опрос помечает появившиеся заказы как freshOrderIds',
      build: () =>
          buildBloc(TestKdsOrdersRepository(orders: [buildOrder(id: 'a')])),
      act: (bloc) async {
        bloc.add(const KdsOrdersStarted(branchId: branchId));
        await Future<void>.delayed(Duration.zero);
        // Прилетел новый заказ между опросами.
        (bloc.repository as TestKdsOrdersRepository).orders.add(
          buildOrder(id: 'b', orderNumber: '1002'),
        );
        bloc.add(const KdsOrdersPollTicked());
      },
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersLoaded>(),
        isA<KdsOrdersLoaded>().having(
          (s) => s.freshOrderIds,
          'только новый заказ подсвечен',
          {'b'},
        ),
      ],
    );

    blocTest<KdsOrdersBloc, KdsOrdersState>(
      'KdsOrdersNewOrdersAcknowledged снимает подсветку',
      build: () =>
          buildBloc(TestKdsOrdersRepository(orders: [buildOrder(id: 'a')])),
      act: (bloc) async {
        bloc.add(const KdsOrdersStarted(branchId: branchId));
        await Future<void>.delayed(Duration.zero);
        (bloc.repository as TestKdsOrdersRepository).orders.add(
          buildOrder(id: 'b'),
        );
        bloc.add(const KdsOrdersPollTicked());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const KdsOrdersNewOrdersAcknowledged());
      },
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersLoaded>(),
        isA<KdsOrdersLoaded>().having((s) => s.freshOrderIds, 'fresh', {'b'}),
        isA<KdsOrdersLoaded>().having(
          (s) => s.freshOrderIds,
          'подсветка снята',
          isEmpty,
        ),
      ],
    );

    blocTest<KdsOrdersBloc, KdsOrdersState>(
      'ошибка опроса при показанной доске не скрывает заказы',
      build: () =>
          buildBloc(TestKdsOrdersRepository(orders: [buildOrder(id: 'a')])),
      act: (bloc) async {
        bloc.add(const KdsOrdersStarted(branchId: branchId));
        await Future<void>.delayed(Duration.zero);
        (bloc.repository as TestKdsOrdersRepository).fetchError = StateError(
          'таймаут',
        );
        bloc.add(const KdsOrdersPollTicked());
      },
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersLoaded>(),
        // Ошибка опроса не порождает новых состояний — доска остаётся.
      ],
    );
  });

  group('KdsOrdersBloc — смена статуса', () {
    blocTest<KdsOrdersBloc, KdsOrdersState>(
      '«В работу»: ActionInProgress → Loaded, заказ переходит в COOKING',
      build: () => buildBloc(
        TestKdsOrdersRepository(
          orders: [buildOrder(id: 'a', status: KdsOrderStatus.confirmed)],
        ),
      ),
      act: (bloc) async {
        bloc.add(const KdsOrdersStarted(branchId: branchId));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const KdsOrderStatusChangeRequested(
            orderId: 'a',
            status: KdsOrderStatus.cooking,
          ),
        );
      },
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersLoaded>(),
        isA<KdsOrdersActionInProgress>().having(
          (s) => s.pendingOrderId,
          'pendingOrderId',
          'a',
        ),
        isA<KdsOrdersLoaded>().having(
          (s) => s.orders.single.status,
          'статус после перехода',
          KdsOrderStatus.cooking,
        ),
      ],
      verify: (bloc) {
        final repo = bloc.repository as TestKdsOrdersRepository;
        expect(repo.statusCalls, [('a', KdsOrderStatus.cooking)]);
      },
    );

    blocTest<KdsOrdersBloc, KdsOrdersState>(
      '«Готово»: COOKING → READY',
      build: () => buildBloc(
        TestKdsOrdersRepository(
          orders: [buildOrder(id: 'a', status: KdsOrderStatus.cooking)],
        ),
      ),
      act: (bloc) async {
        bloc.add(const KdsOrdersStarted(branchId: branchId));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const KdsOrderStatusChangeRequested(
            orderId: 'a',
            status: KdsOrderStatus.ready,
          ),
        );
      },
      verify: (bloc) {
        final repo = bloc.repository as TestKdsOrdersRepository;
        expect(repo.statusCalls, [('a', KdsOrderStatus.ready)]);
      },
    );

    blocTest<KdsOrdersBloc, KdsOrdersState>(
      '«Выдано»: READY → COMPLETED, заказ уходит с доски',
      build: () => buildBloc(
        TestKdsOrdersRepository(
          orders: [buildOrder(id: 'a', status: KdsOrderStatus.ready)],
        ),
      ),
      act: (bloc) async {
        bloc.add(const KdsOrdersStarted(branchId: branchId));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const KdsOrderStatusChangeRequested(
            orderId: 'a',
            status: KdsOrderStatus.completed,
          ),
        );
      },
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersLoaded>(),
        isA<KdsOrdersActionInProgress>(),
        isA<KdsOrdersLoaded>().having(
          (s) => s.orders,
          'доска пуста после выдачи',
          isEmpty,
        ),
      ],
    );

    blocTest<KdsOrdersBloc, KdsOrdersState>(
      'ошибка API: доска сохраняется, actionError передан в Loaded',
      build: () => buildBloc(
        TestKdsOrdersRepository(
          orders: [buildOrder(id: 'a', status: KdsOrderStatus.confirmed)],
        )..updateError = StateError('409 конфликт'),
      ),
      act: (bloc) async {
        bloc.add(const KdsOrdersStarted(branchId: branchId));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const KdsOrderStatusChangeRequested(
            orderId: 'a',
            status: KdsOrderStatus.cooking,
          ),
        );
      },
      expect: () => [
        const KdsOrdersLoading(),
        isA<KdsOrdersLoaded>(),
        isA<KdsOrdersActionInProgress>(),
        isA<KdsOrdersLoaded>()
            .having(
              (s) => s.orders.single.status,
              'статус не изменился',
              KdsOrderStatus.confirmed,
            )
            .having(
              (s) => s.actionError,
              'actionError',
              allOf(isNotNull, contains('409 конфликт')),
            ),
      ],
    );
  });
}

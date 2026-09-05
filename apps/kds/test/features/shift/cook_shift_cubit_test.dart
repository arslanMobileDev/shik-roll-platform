import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/shift/bloc/cook_shift_cubit.dart';
import 'package:kds/features/shift/data/cook_shift_models.dart';

import '../../helpers/test_fixtures.dart';

void main() {
  const branchId = 'branch-central';

  group('CookShiftCubit — загрузка смены', () {
    blocTest<CookShiftCubit, CookShiftState>(
      'load: loading → ready со списком поваров на линии',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository(
          cooks: [buildCook(), buildCook(id: 'cook-2', name: 'Иван')],
        ),
      ),
      act: (cubit) => cubit.load(branchId),
      expect: () => [
        isA<CookShiftState>()
            .having((s) => s.status, 'status', CookShiftStatus.loading)
            .having((s) => s.branchId, 'branchId', branchId),
        isA<CookShiftState>()
            .having((s) => s.status, 'status', CookShiftStatus.ready)
            .having((s) => s.shiftId, 'shiftId', 'shift-1')
            .having(
              (s) => s.lineCooks.map((c) => c.id),
              'повара на линии',
              ['cook-1', 'cook-2'],
            ),
      ],
    );

    blocTest<CookShiftCubit, CookShiftState>(
      'ошибка загрузки → failure с сообщением',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository()
          ..fetchError = StateError('нет сети'),
      ),
      act: (cubit) => cubit.load(branchId),
      expect: () => [
        isA<CookShiftState>().having(
          (s) => s.status,
          'status',
          CookShiftStatus.loading,
        ),
        isA<CookShiftState>()
            .having((s) => s.status, 'status', CookShiftStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('нет сети'),
            ),
      ],
    );
  });

  group('CookShiftCubit — выбор и clock-in', () {
    blocTest<CookShiftCubit, CookShiftState>(
      'selectCook назначает повара станции',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository(
          cooks: [buildCook(), buildCook(id: 'cook-2', name: 'Иван')],
        ),
      ),
      act: (cubit) async {
        await cubit.load(branchId);
        cubit.selectCook('cook-2');
      },
      skip: 2,
      expect: () => [
        isA<CookShiftState>().having(
          (s) => s.currentCook?.name,
          'текущий повар',
          'Иван',
        ),
      ],
    );

    blocTest<CookShiftCubit, CookShiftState>(
      'selectCook с неизвестным id игнорируется',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository(cooks: [buildCook()]),
      ),
      act: (cubit) async {
        await cubit.load(branchId);
        cubit.selectCook('cook-404');
      },
      skip: 2,
      expect: () => <CookShiftState>[],
    );

    blocTest<CookShiftCubit, CookShiftState>(
      'clockIn добавляет повара на линию и делает его текущим',
      build: () =>
          CookShiftCubit(repository: TestCookShiftRepository()),
      act: (cubit) async {
        await cubit.load(branchId);
        await cubit.clockIn(pin: '1111', name: 'Ахмед', role: CookRole.sushiChef);
      },
      skip: 2,
      expect: () => [
        isA<CookShiftState>().having(
          (s) => s.actionInFlight,
          'actionInFlight',
          isTrue,
        ),
        isA<CookShiftState>()
            .having((s) => s.actionInFlight, 'actionInFlight', isFalse)
            .having((s) => s.currentCook?.id, 'текущий повар', 'cook-1111')
            .having((s) => s.lineCooks.length, 'на линии', 1),
      ],
      verify: (cubit) {
        final repo = cubit.repository as TestCookShiftRepository;
        expect(repo.clockInCalls, [('1111', 'Ахмед', CookRole.sushiChef)]);
      },
    );

    blocTest<CookShiftCubit, CookShiftState>(
      'ошибка clockIn → errorMessage, повар не добавлен',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository()
          ..clockInError = StateError('неверный PIN'),
      ),
      act: (cubit) async {
        await cubit.load(branchId);
        await cubit.clockIn(pin: '0000', name: 'Ахмед', role: CookRole.sushiChef);
      },
      skip: 2,
      expect: () => [
        isA<CookShiftState>().having(
          (s) => s.actionInFlight,
          'actionInFlight',
          isTrue,
        ),
        isA<CookShiftState>()
            .having((s) => s.actionInFlight, 'actionInFlight', isFalse)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('неверный PIN'),
            )
            .having((s) => s.lineCooks, 'на линии', isEmpty),
      ],
    );
  });

  group('CookShiftCubit — clock-out и счётчик', () {
    blocTest<CookShiftCubit, CookShiftState>(
      'clockOutCurrent закрывает смену и снимает выбор станции',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository(
          cooks: [buildCook(), buildCook(id: 'cook-2', name: 'Иван')],
        ),
      ),
      act: (cubit) async {
        await cubit.load(branchId);
        cubit.selectCook('cook-1');
        await cubit.clockOutCurrent();
      },
      skip: 4,
      expect: () => [
        isA<CookShiftState>()
            .having((s) => s.currentCook, 'текущий повар', isNull)
            .having(
              (s) => s.lineCooks.map((c) => c.id),
              'остался только Иван',
              ['cook-2'],
            ),
      ],
      verify: (cubit) {
        final repo = cubit.repository as TestCookShiftRepository;
        expect(repo.clockOutCalls, [('cook-1', 'shift-1')]);
      },
    );

    blocTest<CookShiftCubit, CookShiftState>(
      'recordOrderCompleted инкрементирует счётчик и скользящее среднее',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository(
          cooks: [buildCook(completedOrders: 2, avgPrepSeconds: 600)],
        ),
      ),
      act: (cubit) async {
        await cubit.load(branchId);
        cubit.selectCook('cook-1');
        cubit.recordOrderCompleted(prepTime: const Duration(minutes: 15));
      },
      skip: 3,
      expect: () => [
        isA<CookShiftState>()
            .having((s) => s.currentCook?.completedOrders, 'выполнено', 3)
            .having(
              (s) => s.currentCook?.avgPrepSeconds,
              'среднее: (600*2 + 900) / 3',
              700,
            ),
      ],
    );

    blocTest<CookShiftCubit, CookShiftState>(
      'первый заказ смены: среднее = время этого заказа',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository(cooks: [buildCook()]),
      ),
      act: (cubit) async {
        await cubit.load(branchId);
        cubit.selectCook('cook-1');
        cubit.recordOrderCompleted(prepTime: const Duration(minutes: 8));
      },
      skip: 3,
      expect: () => [
        isA<CookShiftState>()
            .having((s) => s.currentCook?.completedOrders, 'выполнено', 1)
            .having(
              (s) => s.currentCook?.avgPrepSeconds,
              'среднее',
              8 * 60,
            ),
      ],
    );

    blocTest<CookShiftCubit, CookShiftState>(
      'без выбранного повара счётчик не меняется',
      build: () => CookShiftCubit(
        repository: TestCookShiftRepository(cooks: [buildCook()]),
      ),
      act: (cubit) async {
        await cubit.load(branchId);
        cubit.recordOrderCompleted(prepTime: const Duration(minutes: 8));
      },
      skip: 2,
      expect: () => <CookShiftState>[],
    );
  });
}

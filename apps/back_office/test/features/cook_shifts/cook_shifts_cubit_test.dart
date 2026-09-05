import 'package:back_office/features/cook_shifts/bloc/cook_shifts_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_cook_shifts_repository.dart';

void main() {
  const branchId = 'branch-center';

  group('CookShiftsCubit — загрузка', () {
    blocTest<CookShiftsCubit, CookShiftsState>(
      'load: loading → ready, активные смены первыми, затем свежие',
      build: () => CookShiftsCubit(
        repository: TestCookShiftsRepository(
          shifts: [
            buildShift(
              id: 'closed-old',
              clockInAt: kShiftNow.subtract(const Duration(days: 2)),
              clockOutAt: kShiftNow.subtract(const Duration(hours: 40)),
            ),
            buildShift(
              id: 'closed-recent',
              clockInAt: kShiftNow.subtract(const Duration(days: 1)),
              clockOutAt: kShiftNow.subtract(const Duration(hours: 16)),
            ),
            buildShift(id: 'active', cookName: 'Иван'),
          ],
        ),
      ),
      act: (cubit) => cubit.load(branchId),
      expect: () => [
        isA<CookShiftsState>()
            .having((s) => s.status, 'status', CookShiftsStatus.loading)
            .having((s) => s.branchId, 'branchId', branchId),
        isA<CookShiftsState>()
            .having((s) => s.status, 'status', CookShiftsStatus.ready)
            .having(
              (s) => s.displayShifts.map((s) => s.id),
              'активная первая, закрытые по убыванию',
              ['active', 'closed-recent', 'closed-old'],
            ),
      ],
    );

    blocTest<CookShiftsCubit, CookShiftsState>(
      'ошибка загрузки → failure с сообщением',
      build: () => CookShiftsCubit(
        repository: TestCookShiftsRepository()
          ..fetchError = StateError('нет сети'),
      ),
      act: (cubit) => cubit.load(branchId),
      expect: () => [
        isA<CookShiftsState>().having(
          (s) => s.status,
          'status',
          CookShiftsStatus.loading,
        ),
        isA<CookShiftsState>()
            .having((s) => s.status, 'status', CookShiftsStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('нет сети'),
            ),
      ],
    );

    blocTest<CookShiftsCubit, CookShiftsState>(
      'агрегаты: активные на линии и сумма выданных заказов',
      build: () => CookShiftsCubit(
        repository: TestCookShiftsRepository(
          shifts: [
            buildShift(id: 'a', completedOrders: 10),
            buildShift(
              id: 'b',
              completedOrders: 5,
              clockOutAt: kShiftNow,
            ),
            buildShift(
              id: 'other-branch',
              branchId: 'branch-north',
              completedOrders: 99,
            ),
          ],
        ),
      ),
      act: (cubit) => cubit.load(branchId),
      verify: (cubit) {
        expect(cubit.state.activeShifts.map((s) => s.id), ['a']);
        expect(cubit.state.totalCompletedOrders, 15);
      },
    );

    blocTest<CookShiftsCubit, CookShiftsState>(
      'повторная загрузка для другой точки обновляет список',
      build: () => CookShiftsCubit(
        repository: TestCookShiftsRepository(
          shifts: [
            buildShift(id: 'center-shift'),
            buildShift(id: 'north-shift', branchId: 'branch-north'),
          ],
        ),
      ),
      act: (cubit) async {
        await cubit.load('branch-center');
        await cubit.load('branch-north');
      },
      skip: 2,
      expect: () => [
        isA<CookShiftsState>().having(
          (s) => s.branchId,
          'branchId',
          'branch-north',
        ),
        isA<CookShiftsState>()
            .having((s) => s.branchId, 'branchId', 'branch-north')
            .having(
              (s) => s.shifts.map((s) => s.id),
              'только смены северной точки',
              ['north-shift'],
            ),
      ],
    );
  });
}

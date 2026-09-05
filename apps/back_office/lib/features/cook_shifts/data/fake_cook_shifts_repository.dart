import 'cook_shift_models.dart';
import 'cook_shifts_repository.dart';

/// Demo kitchen shift history (USE_FAKE_REPOSITORY=true).
///
/// Seeds two cooks currently on the line plus several closed shifts with
/// production metrics so the «Смены кухни» table is populated out of the box.
final class FakeCookShiftsRepository implements CookShiftsRepository {
  @override
  Future<List<CookShiftRecord>> fetchShifts({required String branchId}) async {
    final now = DateTime.now();
    final todayOpen = DateTime(now.year, now.month, now.day, 8);
    final yesterday = todayOpen.subtract(const Duration(days: 1));

    final all = <CookShiftRecord>[
      // Сейчас на линии.
      CookShiftRecord(
        id: 'shift-ahmed-today',
        cookId: 'cook-ahmed',
        cookName: 'Ахмед',
        role: CookRole.sushiChef,
        branchId: 'branch-center',
        clockInAt: todayOpen,
        completedOrders: 14,
        avgPrepSeconds: 11 * 60,
      ),
      CookShiftRecord(
        id: 'shift-ivan-today',
        cookId: 'cook-ivan',
        cookName: 'Иван',
        role: CookRole.hotChef,
        branchId: 'branch-center',
        clockInAt: todayOpen.add(const Duration(hours: 1, minutes: 30)),
        completedOrders: 9,
        avgPrepSeconds: 13 * 60 + 30,
      ),
      // Закрытые смены.
      CookShiftRecord(
        id: 'shift-ahmed-yesterday',
        cookId: 'cook-ahmed',
        cookName: 'Ахмед',
        role: CookRole.sushiChef,
        branchId: 'branch-center',
        clockInAt: yesterday,
        clockOutAt: yesterday.add(const Duration(hours: 8)),
        completedOrders: 32,
        avgPrepSeconds: 10 * 60,
      ),
      CookShiftRecord(
        id: 'shift-ivan-yesterday',
        cookId: 'cook-ivan',
        cookName: 'Иван',
        role: CookRole.hotChef,
        branchId: 'branch-center',
        clockInAt: yesterday.add(const Duration(hours: 2)),
        clockOutAt: yesterday.add(const Duration(hours: 10)),
        completedOrders: 27,
        avgPrepSeconds: 12 * 60 + 20,
      ),
      CookShiftRecord(
        id: 'shift-marina-yesterday',
        cookId: 'cook-marina',
        cookName: 'Марина',
        role: CookRole.sushiChef,
        branchId: 'branch-center',
        clockInAt: yesterday.add(const Duration(hours: 3)),
        clockOutAt: yesterday.add(const Duration(hours: 9, minutes: 30)),
        completedOrders: 21,
        avgPrepSeconds: 9 * 60 + 40,
      ),
      // Вторая точка.
      CookShiftRecord(
        id: 'shift-timur-today',
        cookId: 'cook-timur',
        cookName: 'Тимур',
        role: CookRole.hotChef,
        branchId: 'branch-north',
        clockInAt: todayOpen.add(const Duration(hours: 2)),
        completedOrders: 6,
        avgPrepSeconds: 12 * 60,
      ),
      CookShiftRecord(
        id: 'shift-timur-yesterday',
        cookId: 'cook-timur',
        cookName: 'Тимур',
        role: CookRole.hotChef,
        branchId: 'branch-north',
        clockInAt: yesterday.add(const Duration(hours: 1)),
        clockOutAt: yesterday.add(const Duration(hours: 9)),
        completedOrders: 18,
        avgPrepSeconds: 11 * 60 + 10,
      ),
    ];

    return List.unmodifiable(all.where((s) => s.branchId == branchId));
  }
}

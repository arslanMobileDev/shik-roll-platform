import 'package:back_office/features/cook_shifts/data/cook_shift_models.dart';
import 'package:back_office/features/cook_shifts/data/cook_shifts_repository.dart';

/// Fixed clock for deterministic shift records in tests.
final DateTime kShiftNow = DateTime(2026, 9, 5, 14, 0);

CookShiftRecord buildShift({
  String id = 'shift-1',
  String cookId = 'cook-1',
  String cookName = 'Ахмед',
  CookRole role = CookRole.sushiChef,
  String branchId = 'branch-center',
  DateTime? clockInAt,
  DateTime? clockOutAt,
  int completedOrders = 0,
  int? avgPrepSeconds,
}) => CookShiftRecord(
  id: id,
  cookId: cookId,
  cookName: cookName,
  role: role,
  branchId: branchId,
  clockInAt: clockInAt ?? kShiftNow.subtract(const Duration(hours: 3)),
  clockOutAt: clockOutAt,
  completedOrders: completedOrders,
  avgPrepSeconds: avgPrepSeconds,
);

/// Mutable in-memory shift repository for cubit/widget tests.
final class TestCookShiftsRepository implements CookShiftsRepository {
  TestCookShiftsRepository({List<CookShiftRecord> shifts = const []}) {
    this.shifts = List.of(shifts);
  }

  List<CookShiftRecord> shifts = [];
  Object? fetchError;
  final List<String> fetchCalls = [];

  @override
  Future<List<CookShiftRecord>> fetchShifts({required String branchId}) async {
    fetchCalls.add(branchId);
    if (fetchError != null) throw fetchError!;
    return List.unmodifiable(shifts.where((s) => s.branchId == branchId));
  }
}

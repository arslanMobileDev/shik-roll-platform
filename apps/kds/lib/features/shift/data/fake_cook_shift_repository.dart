import 'cook_shift_models.dart';
import 'cook_shift_repository.dart';

/// In-memory demo kitchen shift.
///
/// Keeps cook selection / clock-in usable without a backend (API_BASE_URL
/// unset) and seeds two cooks on the line so the quick-select list is
/// visible out of the box.
final class FakeCookShiftRepository implements CookShiftRepository {
  FakeCookShiftRepository() {
    final now = DateTime.now();
    _cooksByBranch = {
      'branch-central': [
        ActiveCook(
          id: 'cook-ahmed',
          name: 'Ахмед',
          role: CookRole.sushiChef,
          clockInAt: now.subtract(const Duration(hours: 2)),
          completedOrders: 7,
          avgPrepSeconds: 11 * 60,
        ),
        ActiveCook(
          id: 'cook-ivan',
          name: 'Иван',
          role: CookRole.hotChef,
          clockInAt: now.subtract(const Duration(hours: 1, minutes: 20)),
          completedOrders: 5,
          avgPrepSeconds: 14 * 60,
        ),
      ],
    };
  }

  static const String _demoShiftId = 'shift-demo-1';

  late final Map<String, List<ActiveCook>> _cooksByBranch;

  List<ActiveCook> _line(String branchId) =>
      _cooksByBranch.putIfAbsent(branchId, () => []);

  @override
  Future<ActiveShift> fetchActiveShift({required String branchId}) async =>
      ActiveShift(
        shiftId: _demoShiftId,
        branchId: branchId,
        cooks: List.unmodifiable(_line(branchId)),
      );

  @override
  Future<ClockInResult> clockIn({
    required String branchId,
    required String pin,
    required String name,
    required CookRole role,
  }) async {
    if (pin.length != 4 || int.tryParse(pin) == null) {
      throw ArgumentError('PIN должен состоять из 4 цифр');
    }
    final line = _line(branchId);
    final id = 'cook-pin-$pin';
    final existing = line.where((c) => c.id == id).firstOrNull;
    if (existing != null) return (shiftId: _demoShiftId, cook: existing);

    final cook = ActiveCook(
      id: id,
      name: name,
      role: role,
      clockInAt: DateTime.now(),
    );
    _cooksByBranch[branchId] = [...line, cook];
    return (shiftId: _demoShiftId, cook: cook);
  }

  @override
  Future<void> clockOut({required String cookId, required String shiftId}) async {
    for (final branchId in _cooksByBranch.keys.toList()) {
      _cooksByBranch[branchId] = [
        for (final cook in _line(branchId))
          if (cook.id != cookId) cook,
      ];
    }
  }
}

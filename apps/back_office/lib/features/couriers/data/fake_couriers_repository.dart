import 'couriers_repository.dart';

final class FakeCouriersRepository implements CouriersRepository {
  FakeCouriersRepository({List<CourierRecord> initial = const []})
    : _rows = List.of(initial);
  final List<CourierRecord> _rows;
  int _next = 0;
  @override
  Future<List<CourierRecord>> list(String branchId) async {
    final rows = _rows.where((r) => r.branchId == branchId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(rows);
  }

  @override
  Future<void> save({
    String? id,
    required String branchId,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
  }) async {
    if (id == null) {
      final normalized = normalizeCourierPhone(phone ?? '');
      if (!isRussianCourierPhone(normalized) ||
          !RegExp(r'^\d{4,8}$').hasMatch(pin ?? '') ||
          name.trim().isEmpty) {
        throw const CouriersApiException('Проверьте данные курьера.');
      }
      if (_rows.any((r) => r.phone == normalized)) {
        throw const CouriersApiException('Этот телефон уже зарегистрирован.');
      }
      _rows.add(
        CourierRecord(
          id: 'demo-courier-${++_next}',
          name: name.trim(),
          phone: normalized,
          branchId: branchId,
          isActive: true,
          isAvailable: true,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }
    final index = _rows.indexWhere((r) => r.id == id && r.branchId == branchId);
    if (index < 0) {
      throw const CouriersApiException('Курьер не найден.');
    }
    final current = _rows[index];
    _rows[index] = CourierRecord(
      id: id,
      name: name.trim(),
      phone: current.phone,
      branchId: current.branchId,
      isActive: isActive ?? current.isActive,
      isAvailable: current.isAvailable,
      createdAt: current.createdAt,
    );
  }
}

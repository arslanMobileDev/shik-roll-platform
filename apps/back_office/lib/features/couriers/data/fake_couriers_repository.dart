import 'couriers_repository.dart';

final class FakeCouriersRepository implements CouriersRepository {
  FakeCouriersRepository({List<CourierRecord> initial = const []})
    : _rows = List.of(initial);
  final List<CourierRecord> _rows;
  int _next = 0;
  @override
  Future<List<CourierRecord>> list(
    String branchId, {
    bool includeDeleted = false,
  }) async {
    final rows =
        _rows
            .where(
              (r) =>
                  r.branchId == branchId &&
                  (includeDeleted ? r.deletedAt != null : r.deletedAt == null),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(rows);
  }

  @override
  Future<void> restore(String id) async {
    final index = _rows.indexWhere((r) => r.id == id);
    final row = index < 0 ? null : _rows[index];
    // Same three refusals the backend folds into one 404: live already, no
    // number to log in with, or nothing to restore at all.
    if (row == null || row.deletedAt == null || row.phone == null) {
      throw const CouriersApiException(
        'Курьер уже активен или срок восстановления истёк.',
      );
    }
    if (_rows.any(
      (r) => r.id != id && r.deletedAt == null && r.phone == row.phone,
    )) {
      throw const CouriersApiException(
        'Этот телефон уже занят другим курьером.',
      );
    }
    _rows[index] = CourierRecord(
      id: row.id,
      name: row.name,
      phone: row.phone,
      branchId: row.branchId,
      isActive: true,
      isAvailable: row.isAvailable,
      createdAt: row.createdAt,
    );
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
      // Only live rows: the backend's unique index is partial on
      // `deleted_at IS NULL`, so a deleted row's number is free to reuse.
      if (_rows.any((r) => r.deletedAt == null && r.phone == normalized)) {
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
      deletedAt: current.deletedAt,
    );
  }
}

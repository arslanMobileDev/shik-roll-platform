String normalizeCourierPhone(String value) {
  final compact = value.replaceAll(RegExp(r'[\s()-]'), '');
  if (RegExp(r'^\d{10}$').hasMatch(compact)) return '+7$compact';
  if (RegExp(r'^[78]\d{10}$').hasMatch(compact)) {
    return '+7${compact.substring(1)}';
  }
  return compact;
}

bool isRussianCourierPhone(String value) =>
    RegExp(r'^\+7\d{10}$').hasMatch(normalizeCourierPhone(value));

final class CourierRecord {
  const CourierRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.branchId,
    required this.isActive,
    required this.isAvailable,
    required this.createdAt,
    this.deletedAt,
  });
  final String id, name, branchId;

  /// Null on a row the *old* deletion touched: it erased the number (the login
  /// key) while leaving the row as the anchor of the order history. Those rows
  /// are soft-deleted, so they only show up under `includeDeleted`, and neither
  /// the courier nor the owner can bring them back — the backend refuses a row
  /// without a number (nobody could log into it).
  final String? phone;
  final bool isActive, isAvailable;
  final DateTime createdAt;

  /// When the courier deleted the account himself, null on a live row. Staff
  /// blocking writes `isActive` alone, so this is never the panel's own doing.
  /// The account is restorable for [kCourierRestoreWindowDays] after this.
  final DateTime? deletedAt;
  factory CourierRecord.fromJson(Map<String, dynamic> json) => CourierRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    branchId: json['branchId'] as String,
    isActive: json['isActive'] as bool,
    isAvailable: json['isAvailable'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
    deletedAt: switch (json['deletedAt']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );
}

/// Mirrors `COURIER_RESTORE_WINDOW_DAYS` in the backend
/// (`services/backend/src/modules/couriers/couriers.config.ts`). Display only:
/// the backend re-checks the window on the restore itself, so a stale copy here
/// costs a wrong date, never a wrong row.
const kCourierRestoreWindowDays = 7;

final class CouriersApiException implements Exception {
  const CouriersApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class CouriersRepository {
  /// Live couriers, or — with [includeDeleted] — the self-deleted rows inside
  /// their restore window. The backend answers one or the other, never both.
  Future<List<CourierRecord>> list(
    String branchId, {
    bool includeDeleted = false,
  });
  Future<void> restore(String id);
  Future<void> save({
    String? id,
    required String branchId,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
  });
}

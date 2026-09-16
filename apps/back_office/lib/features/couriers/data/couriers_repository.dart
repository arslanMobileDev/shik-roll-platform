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
  });
  final String id, name, phone, branchId;
  final bool isActive, isAvailable;
  final DateTime createdAt;
  factory CourierRecord.fromJson(Map<String, dynamic> json) => CourierRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    branchId: json['branchId'] as String,
    isActive: json['isActive'] as bool,
    isAvailable: json['isAvailable'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

final class CouriersApiException implements Exception {
  const CouriersApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class CouriersRepository {
  Future<List<CourierRecord>> list(String branchId);
  Future<void> save({
    String? id,
    required String branchId,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
  });
}

import 'package:equatable/equatable.dart';

/// Kitchen station a cook works on (cooks API `role` wire value).
enum CookRole {
  sushiChef('SUSHI_CHEF', 'Сушист'),
  hotChef('HOT_CHEF', 'Горячий цех');

  const CookRole(this.wireName, this.label);

  final String wireName;

  /// Human-readable station name for the table.
  final String label;

  static CookRole fromWire(String value) => CookRole.values.firstWhere(
    (r) => r.wireName == value,
    orElse: () => CookRole.sushiChef,
  );
}

/// One kitchen shift record (open or closed) with production metrics.
final class CookShiftRecord extends Equatable {
  const CookShiftRecord({
    required this.id,
    required this.cookId,
    required this.cookName,
    required this.role,
    required this.branchId,
    required this.clockInAt,
    this.clockOutAt,
    this.completedOrders = 0,
    this.avgPrepSeconds,
    this.terminalCode = '',
    this.durationMinutes = 0,
  });

  final String terminalCode;
  final int durationMinutes;
  final String id;
  final String cookId;
  final String cookName;
  final CookRole role;
  final String branchId;
  final DateTime clockInAt;
  final DateTime? clockOutAt;

  /// Orders handed out («Выдано») during this shift.
  final int completedOrders;

  /// Average time from order creation to hand-out, if measured.
  final int? avgPrepSeconds;

  bool get isActive => clockOutAt == null;

  factory CookShiftRecord.fromJson(
    Map<String, dynamic> json,
  ) => CookShiftRecord(
    id: json['id'] as String? ?? '',
    cookId: json['cookId'] as String? ?? '',
    cookName: json['cookName'] as String? ?? '',
    role: CookRole.fromWire(json['role'] as String? ?? ''),
    branchId: json['branchId'] as String? ?? '',
    clockInAt:
        DateTime.tryParse(json['startedAt'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    clockOutAt: DateTime.tryParse(json['endedAt'] as String? ?? '')?.toLocal(),
    completedOrders: (json['ordersCooked'] as num?)?.toInt() ?? 0,
    avgPrepSeconds: ((json['averageCookingMinutes'] as num? ?? 0) * 60).round(),
    terminalCode: json['terminalCode'] as String? ?? '',
    durationMinutes: (json['durationMinutes'] as num? ?? 0).toInt(),
  );

  @override
  List<Object?> get props => [
    id,
    cookId,
    cookName,
    role,
    branchId,
    clockInAt,
    clockOutAt,
    completedOrders,
    avgPrepSeconds,
    terminalCode,
    durationMinutes,
  ];
}

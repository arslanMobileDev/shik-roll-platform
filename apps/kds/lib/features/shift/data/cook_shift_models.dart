import 'package:equatable/equatable.dart';

/// Kitchen station a cook works on (cooks API `role` wire value).
enum CookRole {
  sushiChef('SUSHI_CHEF', 'Сушист'),
  hotChef('HOT_CHEF', 'Горячий цех');

  const CookRole(this.wireName, this.label);

  final String wireName;

  /// Human-readable station name for badges and pickers.
  final String label;

  static CookRole fromWire(String value) => CookRole.values.firstWhere(
    (r) => r.wireName == value,
    orElse: () => CookRole.sushiChef,
  );
}

/// Cook currently clocked in on the kitchen line.
final class ActiveCook extends Equatable {
  const ActiveCook({
    required this.id,
    required this.name,
    required this.role,
    required this.clockInAt,
    this.completedOrders = 0,
    this.avgPrepSeconds,
  });

  final String id;
  final String name;
  final CookRole role;
  final DateTime clockInAt;

  /// Orders handed out («Выдано») by this cook during the current shift.
  final int completedOrders;

  /// Rolling average time from order creation to hand-out, if any.
  final int? avgPrepSeconds;

  ActiveCook copyWith({
    int? completedOrders,
    int? Function()? avgPrepSeconds,
  }) => ActiveCook(
    id: id,
    name: name,
    role: role,
    clockInAt: clockInAt,
    completedOrders: completedOrders ?? this.completedOrders,
    avgPrepSeconds: avgPrepSeconds != null
        ? avgPrepSeconds()
        : this.avgPrepSeconds,
  );

  factory ActiveCook.fromJson(Map<String, dynamic> json) => ActiveCook(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    role: CookRole.fromWire(json['role'] as String? ?? ''),
    clockInAt:
        DateTime.tryParse(json['clockInAt'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    completedOrders: (json['completedOrders'] as num?)?.toInt() ?? 0,
    avgPrepSeconds: (json['avgPrepSeconds'] as num?)?.toInt(),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    role,
    clockInAt,
    completedOrders,
    avgPrepSeconds,
  ];
}

/// Currently open kitchen shift of a branch with everyone on the line
/// (`GET /cooks/active-shift`).
final class ActiveShift extends Equatable {
  const ActiveShift({
    required this.shiftId,
    required this.branchId,
    this.cooks = const [],
  });

  final String shiftId;
  final String branchId;
  final List<ActiveCook> cooks;

  factory ActiveShift.fromJson(Map<String, dynamic> json) => ActiveShift(
    shiftId: json['shiftId'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    cooks: [
      for (final c in (json['cooks'] as List?) ?? const [])
        ActiveCook.fromJson(c as Map<String, dynamic>),
    ],
  );

  @override
  List<Object?> get props => [shiftId, branchId, cooks];
}

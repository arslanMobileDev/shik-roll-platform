enum DashboardPeriod {
  today('Сегодня'),
  yesterday('Вчера'),
  week('Неделя'),
  month('Месяц'),
  year('Год'),
  custom('Дата');

  const DashboardPeriod(this.label);
  final String label;
}

final class RevenueTotals {
  const RevenueTotals({
    required this.total,
    required this.ordersCount,
    required this.averageCheck,
  });
  final double total;
  final int ordersCount;
  final double averageCheck;
  factory RevenueTotals.fromJson(Map<String, dynamic> json) => RevenueTotals(
    total: (json['total'] as num).toDouble(),
    ordersCount: (json['ordersCount'] as num).toInt(),
    averageCheck: (json['averageCheck'] as num).toDouble(),
  );
}

final class RevenueDay {
  const RevenueDay({
    required this.date,
    required this.total,
    required this.count,
  });
  final DateTime date;
  final double total;
  final int count;
  double get averageCheck => count == 0 ? 0 : total / count;
  factory RevenueDay.fromJson(Map<String, dynamic> json) => RevenueDay(
    date: DateTime.parse(json['date'] as String),
    total: (json['total'] as num).toDouble(),
    count: (json['count'] as num).toInt(),
  );
}

final class RevenueItem {
  const RevenueItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.revenue,
  });
  final String menuItemId;
  final String name;
  final int quantity;
  final double revenue;
  factory RevenueItem.fromJson(Map<String, dynamic> json) => RevenueItem(
    menuItemId: json['menuItemId'] as String,
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toInt(),
    revenue: (json['revenue'] as num).toDouble(),
  );
}

final class RevenueSummary {
  const RevenueSummary({
    required this.from,
    required this.to,
    required this.label,
    required this.summary,
    required this.byDay,
    required this.topItems,
  });
  final DateTime from;
  final DateTime to;
  final String label;
  final RevenueTotals summary;
  final List<RevenueDay> byDay;
  final List<RevenueItem> topItems;
  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    return RevenueSummary(
      from: DateTime.parse(period['from'] as String),
      to: DateTime.parse(period['to'] as String),
      label: period['label'] as String,
      summary: RevenueTotals.fromJson(json['summary'] as Map<String, dynamic>),
      byDay: List.unmodifiable(
        (json['byDay'] as List).map(
          (v) => RevenueDay.fromJson(v as Map<String, dynamic>),
        ),
      ),
      topItems: List.unmodifiable(
        (json['topItems'] as List).map(
          (v) => RevenueItem.fromJson(v as Map<String, dynamic>),
        ),
      ),
    );
  }
}

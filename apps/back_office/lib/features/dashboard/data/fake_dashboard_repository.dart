import 'dashboard_repository.dart';
import 'models/revenue_summary.dart';

/// Explicit demo/test repository; never selected as a network-error fallback.
final class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  @override
  Future<RevenueSummary> fetchRevenue({
    required String branchId,
    required DashboardPeriod period,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final msk = _now().toUtc().add(const Duration(hours: 3));
    var from = DateTime.utc(msk.year, msk.month, msk.day);
    var end = from.add(const Duration(days: 1));
    switch (period) {
      case DashboardPeriod.today:
        break;
      case DashboardPeriod.yesterday:
        from = from.subtract(const Duration(days: 1));
        end = end.subtract(const Duration(days: 1));
      case DashboardPeriod.week:
        from = from.subtract(Duration(days: from.weekday - 1));
        end = from.add(const Duration(days: 7));
      case DashboardPeriod.month:
        from = DateTime.utc(msk.year, msk.month);
        end = DateTime.utc(msk.year, msk.month + 1);
      case DashboardPeriod.year:
        from = DateTime.utc(msk.year);
        end = DateTime.utc(msk.year + 1);
      case DashboardPeriod.custom:
        if (dateFrom == null || dateTo == null) {
          throw ArgumentError('Нужны даты');
        }
        from = DateTime.utc(dateFrom.year, dateFrom.month, dateFrom.day);
        end = DateTime.utc(dateTo.year, dateTo.month, dateTo.day + 1);
    }
    final days = <RevenueDay>[];
    for (
      var day = from;
      day.isBefore(end);
      day = day.add(const Duration(days: 1))
    ) {
      days.add(RevenueDay(date: day, total: 1500, count: 3));
    }
    return RevenueSummary(
      from: from.subtract(const Duration(hours: 3)),
      to: end.subtract(const Duration(hours: 3, milliseconds: 1)),
      label: period.label,
      summary: RevenueTotals(
        total: days.length * 1500,
        ordersCount: days.length * 3,
        averageCheck: 500,
      ),
      byDay: days,
      topItems: [
        RevenueItem(
          menuItemId: 'demo',
          name: 'Демо: Филадельфия',
          quantity: days.length * 3,
          revenue: days.length * 1500,
        ),
      ],
    );
  }
}

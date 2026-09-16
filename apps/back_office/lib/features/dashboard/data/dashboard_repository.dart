import 'models/revenue_summary.dart';

abstract interface class DashboardRepository {
  Future<RevenueSummary> fetchRevenue({
    required String branchId,
    required DashboardPeriod period,
    DateTime? dateFrom,
    DateTime? dateTo,
  });
}

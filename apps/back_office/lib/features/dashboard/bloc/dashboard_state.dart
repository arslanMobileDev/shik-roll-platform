import '../data/models/revenue_summary.dart';

enum DashboardStatus { initial, loading, loaded, error }

final class DashboardState {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.branchId = '',
    this.period = DashboardPeriod.today,
    this.dateFrom,
    this.dateTo,
    this.cards = const {},
    this.revenue,
    this.error,
  });
  final DashboardStatus status;
  final String branchId;
  final DashboardPeriod period;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Map<DashboardPeriod, RevenueSummary> cards;
  final RevenueSummary? revenue;
  final String? error;
}

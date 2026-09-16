import '../data/cooks_analytics_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/dashboard_repository.dart';
import '../data/models/revenue_summary.dart';
import 'dashboard_state.dart';

final class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required this.repository,
    CooksAnalyticsRepository? cooksRepository,
  }) : cooksRepository = cooksRepository ?? EmptyCooksAnalyticsRepository(),
       super(const DashboardState());
  final CooksAnalyticsRepository cooksRepository;
  final DashboardRepository repository;
  int _request = 0;
  static const cardPeriods = [
    DashboardPeriod.today,
    DashboardPeriod.week,
    DashboardPeriod.month,
    DashboardPeriod.year,
  ];

  Future<void> load(
    String branchId, {
    DashboardPeriod? period,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final request = ++_request;
    final selected = period ?? state.period;
    final from = selected == DashboardPeriod.custom
        ? dateFrom ?? state.dateFrom
        : null;
    final to = selected == DashboardPeriod.custom
        ? dateTo ?? state.dateTo
        : null;
    emit(
      DashboardState(
        status: DashboardStatus.loading,
        branchId: branchId,
        period: selected,
        dateFrom: from,
        dateTo: to,
      ),
    );
    try {
      final overview = await Future.wait(
        cardPeriods.map(
          (p) => repository.fetchRevenue(branchId: branchId, period: p),
        ),
      );
      final cards = Map<DashboardPeriod, RevenueSummary>.unmodifiable(
        Map.fromIterables(cardPeriods, overview),
      );
      final revenue =
          cards[selected] ??
          await repository.fetchRevenue(
            branchId: branchId,
            period: selected,
            dateFrom: from,
            dateTo: to,
          );
      if (isClosed || request != _request) return;
      emit(
        DashboardState(
          status: DashboardStatus.loaded,
          branchId: branchId,
          period: selected,
          dateFrom: from,
          dateTo: to,
          cards: cards,
          revenue: revenue,
        ),
      );
    } catch (_) {
      if (isClosed || request != _request) return;
      emit(
        DashboardState(
          status: DashboardStatus.error,
          branchId: branchId,
          period: selected,
          dateFrom: from,
          dateTo: to,
          error:
              'Не удалось загрузить выручку. Проверьте соединение и доступ к филиалу.',
        ),
      );
    }
  }

  Future<void> select(DashboardPeriod period, {DateTime? from, DateTime? to}) =>
      load(state.branchId, period: period, dateFrom: from, dateTo: to);
  Future<void> refresh() => load(state.branchId);
}

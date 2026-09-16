import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../bloc/dashboard_state.dart';

class TopCook {
  const TopCook(this.name, this.ordersCooked, this.averageCookingMinutes);
  final String name;
  final int ordersCooked;
  final double averageCookingMinutes;
}

abstract interface class CooksAnalyticsRepository {
  Future<List<TopCook>> load(DashboardState state);
}

class EmptyCooksAnalyticsRepository implements CooksAnalyticsRepository {
  @override
  Future<List<TopCook>> load(DashboardState state) async => [];
}

class RemoteCooksAnalyticsRepository implements CooksAnalyticsRepository {
  RemoteCooksAnalyticsRepository({ApiClient? client})
    : client = client ?? ApiClient();
  final ApiClient client;
  @override
  Future<List<TopCook>> load(DashboardState s) async {
    final r = await client.dio.get<Map<String, dynamic>>(
      '/staff/analytics/cooks',
      queryParameters: {
        'branchId': s.branchId,
        'period': s.period.name,
        if (s.dateFrom != null)
          'dateFrom': DateFormat('yyyy-MM-dd').format(s.dateFrom!),
        if (s.dateTo != null)
          'dateTo': DateFormat('yyyy-MM-dd').format(s.dateTo!),
      },
    );
    return (r.data!['cooks'] as List)
        .map(
          (j) => TopCook(
            j['name'] as String,
            (j['ordersCooked'] as num).toInt(),
            (j['averageCookingMinutes'] as num).toDouble(),
          ),
        )
        .toList();
  }
}

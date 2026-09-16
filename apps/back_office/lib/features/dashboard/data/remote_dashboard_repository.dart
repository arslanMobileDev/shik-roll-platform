import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import 'dashboard_repository.dart';
import 'models/revenue_summary.dart';

final class RemoteDashboardRepository implements DashboardRepository {
  RemoteDashboardRepository({ApiClient? client})
    : _dio = (client ?? ApiClient()).dio;
  final Dio _dio;
  @override
  Future<RevenueSummary> fetchRevenue({
    required String branchId,
    required DashboardPeriod period,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (period == DashboardPeriod.custom &&
        (dateFrom == null || dateTo == null)) {
      throw ArgumentError('Для выбранного периода нужны обе даты');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/staff/analytics/revenue',
      queryParameters: {
        'branchId': branchId,
        'period': period.name,
        if (period == DashboardPeriod.custom) ...{
          'dateFrom': DateFormat('yyyy-MM-dd').format(dateFrom!),
          'dateTo': DateFormat('yyyy-MM-dd').format(dateTo!),
        },
      },
    );
    final data = response.data;
    if (data == null) throw const FormatException('Пустой ответ аналитики');
    return RevenueSummary.fromJson(data);
  }
}

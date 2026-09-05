import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'cook_shift_models.dart';
import 'cook_shifts_repository.dart';

/// HTTP implementation of [CookShiftsRepository] against the live cooks API.
final class RemoteCookShiftsRepository implements CookShiftsRepository {
  RemoteCookShiftsRepository({ApiClient? client})
    : _dio = (client ?? ApiClient()).dio;

  final Dio _dio;

  @override
  Future<List<CookShiftRecord>> fetchShifts({required String branchId}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/cooks/shifts',
        queryParameters: {'branchId': branchId},
      );
      final payload = response.data;
      final data = switch (payload) {
        {'data': final List list} => list,
        final List list => list,
        _ => const <dynamic>[],
      };
      return data
          .whereType<Map<String, dynamic>>()
          .map(CookShiftRecord.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw BackOfficeApiException(
        'API ${e.response?.statusCode ?? 'error'}: ${e.message ?? 'network failure'}',
      );
    }
  }
}

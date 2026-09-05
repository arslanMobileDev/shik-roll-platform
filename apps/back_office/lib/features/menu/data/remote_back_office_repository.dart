import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'back_office_repository.dart';
import 'models/menu_item.dart';

/// HTTP implementation of [BackOfficeRepository] against the live
/// menu catalog API (API-706 v1.2.0).
final class RemoteBackOfficeRepository implements BackOfficeRepository {
  RemoteBackOfficeRepository({ApiClient? client})
    : _dio = (client ?? ApiClient()).dio;

  final Dio _dio;

  @override
  Future<List<MenuItem>> fetchMenuItems({required String branchId}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/menu-items',
        queryParameters: {'branchId': branchId},
      );
      final data = response.data ?? const <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(MenuItem.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw BackOfficeApiException(_describe(e));
    }
  }

  @override
  Future<MenuItem> createMenuItem(MenuItemDraft draft) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/menu-items',
        data: draft.toJson(),
      );
      return MenuItem.fromJson(response.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw BackOfficeApiException(_describe(e));
    }
  }

  @override
  Future<MenuItem> updateMenuItem(MenuItem item) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/menu-items/${item.id}',
        data: item.toJson(),
      );
      return MenuItem.fromJson(response.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw BackOfficeApiException(_describe(e));
    }
  }

  @override
  Future<void> setStopList({
    required String itemId,
    required String branchId,
    required bool stopped,
  }) async {
    try {
      await _dio.post<void>(
        '/menu-items/$itemId/stop-list',
        data: {'branchId': branchId, 'stopped': stopped},
      );
    } on DioException catch (e) {
      throw BackOfficeApiException(_describe(e));
    }
  }

  String _describe(DioException e) =>
      'API ${e.response?.statusCode ?? 'error'}: ${e.message ?? 'network failure'}';
}

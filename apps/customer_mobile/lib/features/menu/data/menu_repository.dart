import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'menu_models.dart';

/// Failure surfaced by the menu data layer.
final class MenuException implements Exception {
  const MenuException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MenuException($statusCode): $message';
}

/// Read-only guest menu access (Menu & Product API, API-706).
abstract interface class CustomerMenuRepository {
  Future<Paged<Category>> getCategories({String? brandId, int limit});

  /// Only published, sellable items are returned; modifiers arrive inline.
  Future<Paged<MenuItem>> getMenuItems({
    String? brandId,
    String? categoryId,
    int page,
    int limit,
  });
}

/// Remote implementation over the Menu & Product API contract.
final class RemoteCustomerMenuRepository implements CustomerMenuRepository {
  RemoteCustomerMenuRepository(this._client);

  final ApiClient _client;

  @override
  Future<Paged<Category>> getCategories({
    String? brandId,
    int limit = 100,
  }) async {
    final json = await _get(
      '/categories',
      queryParameters: {'brandId': ?brandId, 'limit': limit, 'page': 1},
    );
    return _parsePage(json, Category.fromJson);
  }

  @override
  Future<Paged<MenuItem>> getMenuItems({
    String? brandId,
    String? categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    final json = await _get(
      '/menu-items',
      queryParameters: {
        'brandId': ?brandId,
        'categoryId': ?categoryId,
        'status': 'PUBLISHED',
        'page': page,
        'limit': limit,
      },
    );
    return _parsePage(json, MenuItem.fromJson);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data == null) {
        throw MenuException(
          'Empty response from $path',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on DioException catch (e) {
      throw MenuException(
        e.message ?? 'Network error while calling $path',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Paged<T> _parsePage<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final meta = json['meta'] as Map<String, dynamic>;
      final page = (meta['page'] as num).toInt();
      final totalPages = (meta['totalPages'] as num).toInt();
      return Paged<T>(
        data: [
          for (final row in json['data'] as List<dynamic>)
            fromJson(row as Map<String, dynamic>),
        ],
        page: page,
        hasNextPage: page < totalPages,
      );
    } on TypeError catch (e) {
      throw MenuException('Malformed menu payload: $e');
    }
  }
}

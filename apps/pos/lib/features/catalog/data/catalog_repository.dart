import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'catalog_models.dart';

/// Failure surfaced by the catalog data layer.
final class CatalogException implements Exception {
  const CatalogException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'CatalogException($statusCode): $message';
}

/// Read-only catalog access for the POS (Menu & Product API, API-706).
abstract interface class CatalogRepository {
  Future<Paged<Menu>> getMenus({
    String? brandId,
    String? branchId,
    int page,
    int limit,
  });

  Future<Paged<Category>> getCategories({
    String? menuId,
    String? brandId,
    int page,
    int limit,
  });

  /// The POS always queries the public catalog (`status: PUBLISHED`, BE-906)
  /// and passes the branch context so prices, availability and the stop list
  /// resolve for the active branch.
  Future<Paged<MenuItem>> getMenuItems({
    required String brandId,
    String? branchId,
    String? categoryId,
    bool? isHalal,
    bool? availableOnly,
    String? search,
    int page,
    int limit,
  });
}

/// Remote implementation over the Menu & Product API contract.
final class RemoteCatalogRepository implements CatalogRepository {
  RemoteCatalogRepository(this._client);

  final ApiClient _client;

  @override
  Future<Paged<Menu>> getMenus({
    String? brandId,
    String? branchId,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _get(
      '/menus',
      queryParameters: {
        'page': page,
        'limit': limit,
        'brandId': ?brandId,
        'branchId': ?branchId,
      },
    );
    return _parsePage(json, Menu.fromJson);
  }

  @override
  Future<Paged<Category>> getCategories({
    String? menuId,
    String? brandId,
    int page = 1,
    int limit = 100,
  }) async {
    final json = await _get(
      '/categories',
      queryParameters: {
        'page': page,
        'limit': limit,
        'menuId': ?menuId,
        'brandId': ?brandId,
      },
    );
    return _parsePage(json, Category.fromJson);
  }

  @override
  Future<Paged<MenuItem>> getMenuItems({
    required String brandId,
    String? branchId,
    String? categoryId,
    bool? isHalal,
    bool? availableOnly,
    String? search,
    int page = 1,
    int limit = 30,
  }) async {
    final json = await _get(
      '/menu-items',
      queryParameters: {
        'page': page,
        'limit': limit,
        'brandId': brandId,
        'branchId': ?branchId,
        'categoryId': ?categoryId,
        'status': 'PUBLISHED',
        'isHalal': ?isHalal,
        'availableOnly': ?availableOnly,
        if (search != null && search.isNotEmpty) 'search': search,
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
        throw CatalogException(
          'Empty response from $path',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on DioException catch (e) {
      throw CatalogException(
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
      return Paged<T>(
        data: [
          for (final row in json['data'] as List<dynamic>)
            fromJson(row as Map<String, dynamic>),
        ],
        page: (meta['page'] as num).toInt(),
        limit: (meta['limit'] as num).toInt(),
        total: (meta['total'] as num).toInt(),
        totalPages: (meta['totalPages'] as num).toInt(),
      );
    } on TypeError catch (e) {
      throw CatalogException('Malformed catalog payload: $e');
    }
  }
}

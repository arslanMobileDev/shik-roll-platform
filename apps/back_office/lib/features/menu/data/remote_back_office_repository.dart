import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'back_office_repository.dart';
import 'models/menu_item.dart';
import 'models/menu_ref.dart';
import 'models/menu_category_ref.dart';

/// HTTP implementation of [BackOfficeRepository] against the live
/// menu catalog API (API-706 v1.2.0).
final class RemoteBackOfficeRepository implements BackOfficeRepository {
  RemoteBackOfficeRepository({ApiClient? client})
    : _dio = (client ?? ApiClient()).dio;

  final Dio _dio;

  @override
  Future<List<MenuRef>> fetchMenus({required String brandId}) async {
    try {
      return (await _fetchReferences('/menus', {
        'brandId': brandId,
      })).map(MenuRef.fromJson).toList(growable: false);
    } on DioException catch (e) {
      throw BackOfficeApiException(
        'Не удалось загрузить меню: ${_describe(e)}',
      );
    } on Object {
      throw const BackOfficeApiException('Некорректный ответ справочника меню');
    }
  }

  @override
  Future<List<MenuCategoryRef>> fetchCategories({
    required String menuId,
  }) async {
    try {
      return (await _fetchReferences('/categories', {
        'menuId': menuId,
        'includeInactive': 'true',
      })).map(MenuCategoryRef.fromJson).toList(growable: false);
    } on DioException catch (e) {
      throw BackOfficeApiException(
        'Не удалось загрузить категории: ${_describe(e)}',
      );
    } on Object {
      throw const BackOfficeApiException(
        'Некорректный ответ справочника категорий',
      );
    }
  }

  @override
  Future<MenuCategoryRef> createCategory({
    required String menuId,
    required CategoryDraft draft,
    required int sortOrder,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/categories',
        data: {'menuId': menuId, 'sortOrder': sortOrder, ...draft.toJson()},
      );
      return MenuCategoryRef.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw BackOfficeApiException(
        'Не удалось создать категорию: ${_describe(e)}',
      );
    } on Object {
      throw const BackOfficeApiException(
        'Некорректный ответ при создании категории',
      );
    }
  }

  @override
  Future<MenuCategoryRef> updateCategory({
    required String id,
    required CategoryDraft draft,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/categories/$id',
        data: draft.toJson(),
      );
      return MenuCategoryRef.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw BackOfficeApiException(
        'Не удалось сохранить категорию: ${_describe(e)}',
      );
    } on Object {
      throw const BackOfficeApiException(
        'Некорректный ответ при сохранении категории',
      );
    }
  }

  /// API-706 wraps single resources in `{data: {...}}` on some routes and
  /// returns them bare on others; both shapes land here.
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    final data = body ?? const <String, dynamic>{};
    return data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
  }

  Future<List<Map<String, dynamic>>> _fetchReferences(
    String path,
    Map<String, String> query,
  ) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: {...query, if (page > 1) 'page': page},
      );
      final raw = response.data;
      final dynamic rows = raw is Map<String, dynamic> ? raw['data'] : raw;
      if (rows is! List) {
        throw const FormatException('Expected a reference list');
      }
      result.addAll(rows.map((row) => Map<String, dynamic>.from(row as Map)));
      final dynamic meta = raw is Map<String, dynamic> ? raw['meta'] : null;
      final dynamic totalPages = meta is Map ? meta['totalPages'] : null;
      if (totalPages is! int || page >= totalPages || rows.isEmpty) break;
      page++;
    }
    return result;
  }

  @override
  Future<List<MenuItem>> fetchMenuItems({required String branchId}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/menu-items',
        queryParameters: {'branchId': branchId},
      );

      final dynamic raw = response.data;
      final List<dynamic> itemsList;
      if (raw is Map<String, dynamic> && raw['data'] is List) {
        itemsList = raw['data'] as List<dynamic>;
      } else if (raw is List) {
        itemsList = raw;
      } else {
        itemsList = const <dynamic>[];
      }

      return itemsList
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
      return MenuItem.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw BackOfficeApiException(_describe(e));
    }
  }

  @override
  Future<MenuItem> updateMenuItem({
    required String id,
    required MenuItemDraft draft,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/menu-items/$id',
        data: draft.toJson(),
      );
      return MenuItem.fromJson(_unwrap(response.data));
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
      await _dio.patch<void>(
        '/menu-items/$itemId/stop-list',
        data: {'branchId': branchId, 'isActive': stopped},
      );
    } on DioException catch (e) {
      throw BackOfficeApiException(_describe(e));
    }
  }

  String _describe(DioException e) =>
      'API ${e.response?.statusCode ?? 'error'}: ${e.message ?? 'network failure'}';
}

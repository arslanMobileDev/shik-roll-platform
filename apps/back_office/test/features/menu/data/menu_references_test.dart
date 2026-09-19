import 'dart:convert';
import 'dart:typed_data';
import 'package:back_office/core/network/api_client.dart';
import 'package:back_office/features/menu/bloc/menu_catalog_state.dart';
import 'package:back_office/features/menu/data/back_office_repository.dart';
import 'package:back_office/features/menu/data/fake_back_office_repository.dart';
import 'package:back_office/features/menu/data/remote_back_office_repository.dart';
import 'package:back_office/features/menu/data/models/menu_item.dart';
import 'package:back_office/features/menu/data/models/menu_ref.dart';
import 'package:back_office/features/menu/data/models/menu_category_ref.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);
  final List<Object> responses;
  final List<RequestOptions> requests = [];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(responses.removeAt(0)),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'staff.token': 'test-staff'});
    FlutterSecureStorage.setMockInitialValues({'staff.token': 'test-staff'});
  });
  const menu = {
    'id': '00000000-0000-4000-8000-000000000100',
    'name': 'Меню',
    'brandId': 'brand',
  };
  const category = {
    'id': '00000000-0000-4000-8000-000000000101',
    'name': 'Категория БД',
    'menuId': 'menu',
  };
  RemoteBackOfficeRepository remote(_Adapter adapter) {
    final client = ApiClient(
      baseUrl: 'https://api.example.test',
      diagnostics: false,
    );
    client.dio.httpClientAdapter = adapter;
    return RemoteBackOfficeRepository(client: client);
  }

  for (final wrapped in [true, false]) {
    test(
      'menus parse wrapped=$wrapped, pass brand filter and staff token',
      () async {
        final adapter = _Adapter([
          wrapped
              ? {
                  'data': [menu],
                }
              : [menu],
        ]);
        final items = await remote(adapter).fetchMenus(brandId: 'brand');
        expect(items.single, MenuRef.fromJson(menu));
        expect(adapter.requests.single.uri.path, '/menus');
        expect(adapter.requests.single.queryParameters, {'brandId': 'brand'});
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer test-staff',
        );
      },
    );
    test('categories parse wrapped=$wrapped and pass menu filter', () async {
      final adapter = _Adapter([
        wrapped
            ? {
                'data': [category],
              }
            : [category],
      ]);
      final items = await remote(adapter).fetchCategories(menuId: 'menu');
      expect(items.single, MenuCategoryRef.fromJson(category));
      expect(adapter.requests.single.uri.path, '/categories');
      expect(adapter.requests.single.queryParameters, {'menuId': 'menu'});
    });
  }
  test('references follow pagination without reordering first page', () async {
    final adapter = _Adapter([
      {
        'data': [category],
        'meta': {'totalPages': 2},
      },
      {
        'data': [
          {...category, 'id': 'second'},
        ],
        'meta': {'totalPages': 2},
      },
    ]);
    final items = await remote(adapter).fetchCategories(menuId: 'menu');
    expect(items.map((e) => e.id), [category['id'], 'second']);
    expect(adapter.requests.last.queryParameters, {
      'menuId': 'menu',
      'page': 2,
    });
  });
  test('malformed response is an error, not a silently empty list', () async {
    await expectLater(
      remote(
        _Adapter([
          {'unexpected': true},
        ]),
      ).fetchMenus(brandId: 'brand'),
      throwsA(isA<BackOfficeApiException>()),
    );
  });
  test('HTTP failure is surfaced in Russian', () async {
    final adapter = _Adapter([{}])..status = 503;
    await expectLater(
      remote(adapter).fetchCategories(menuId: 'menu'),
      throwsA(
        isA<BackOfficeApiException>().having(
          (e) => e.message,
          'message',
          contains('Не удалось загрузить категории'),
        ),
      ),
    );
  });
  test(
    'fake returns one menu for requested brand and five stable UUID categories',
    () async {
      final fake = FakeBackOfficeRepository(latency: Duration.zero);
      final menus = await fake.fetchMenus(brandId: 'brand');
      expect(menus.single.brandId, 'brand');
      final categories = await fake.fetchCategories(menuId: menus.single.id);
      expect(categories.length, 5);
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuid.hasMatch(menus.single.id), isTrue);
      expect(
        categories.every(
          (e) => uuid.hasMatch(e.id) && e.menuId == menus.single.id,
        ),
        isTrue,
      );
      expect(await fake.fetchCategories(menuId: menus.single.id), categories);
      expect(await fake.fetchCategories(menuId: 'unknown'), isEmpty);
      final items = await fake.fetchMenuItems(branchId: 'branch');
      expect(
        items.every((item) => categories.any((c) => c.id == item.categoryId)),
        isTrue,
      );
    },
  );
  test('MenuItem parses nested category UUID and preserves it in copyWith', () {
    final item = MenuItem.fromJson({
      'id': 'item',
      'name': 'Блюдо',
      'category': category,
    });
    expect(item.categoryId, category['id']);
    expect(item.copyWith(name: 'Новое имя').categoryId, category['id']);
    expect(
      MenuItem.fromJson({'id': 'legacy', 'category': 'rolls'}).categoryId,
      isNull,
    );
  });
  test(
    'reference fields participate in state equality and selected menu can clear',
    () {
      const state = MenuCatalogState();
      expect(state.copyWith(menus: [MenuRef.fromJson(menu)]), isNot(state));
      expect(
        state.copyWith(categories: [MenuCategoryRef.fromJson(category)]),
        isNot(state),
      );
      final selected = state.copyWith(selectedMenuId: 'menu');
      expect(selected, isNot(state));
      expect(selected.copyWith(clearSelectedMenu: true), state);
    },
  );
}

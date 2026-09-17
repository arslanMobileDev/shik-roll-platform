import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:back_office/core/network/api_client.dart';
import 'package:back_office/features/menu/cubit/menu_image_upload_cubit.dart';
import 'package:back_office/features/menu/cubit/menu_image_upload_state.dart';
import 'package:back_office/features/menu/data/menu_image_picker.dart';
import 'package:back_office/features/menu/data/menu_image_upload_repository.dart';
import 'package:back_office/features/menu/view/widgets/menu_image_upload_field.dart';
import 'package:back_office/features/menu/view/widgets/menu_item_form_dialog.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAdapter implements HttpClientAdapter {
  int status = 201;
  String url = '/uploads/menu/test.webp';
  RequestOptions? lastRequest;
  String? multipart;
  int calls = 0;
  Completer<void>? pending;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastRequest = options;
    final bytes = <int>[];
    await for (final chunk in stream ?? const Stream<Uint8List>.empty()) {
      bytes.addAll(chunk);
    }
    multipart = utf8.decode(bytes, allowMalformed: true);
    if (pending != null) await pending!.future;
    return ResponseBody.fromString(
      jsonEncode({'url': url}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class TestPicker extends MenuImagePicker {
  TestPicker(this.file);
  MenuImageFile? file;
  @override
  Future<MenuImageFile?> pick() async => file;
}

class TestFilePickerPlatform extends FilePickerPlatform {
  int calls = 0;
  List<String>? extensions;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    extensions = allowedExtensions;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestAdapter adapter;
  late MenuImageUploadRepository repository;
  final file = MenuImageFile(
    name: 'photo.png',
    length: () async => 3,
    read: () async => Uint8List.fromList([1, 2, 3]),
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({'staff.token': 'staff-test-token'});
    final client = ApiClient(
      baseUrl: 'https://api.example.test/api',
      diagnostics: false,
    );
    adapter = TestAdapter();
    client.dio.httpClientAdapter = adapter;
    repository = MenuImageUploadRepository(client: client);
  });

  test(
    'picker -> upload -> success, multipart and staff token, URL uses origin',
    () async {
      final cubit = MenuImageUploadCubit(
        picker: TestPicker(file),
        repository: repository,
      );
      final states = <MenuImageUploadState>[cubit.state];
      final sub = cubit.stream.listen(states.add);
      await cubit.pick();
      await Future<void>.delayed(Duration.zero);
      expect(
        states.map((s) => s.status).toList(),
        containsAllInOrder([
          MenuImageUploadStatus.idle,
          MenuImageUploadStatus.picking,
          MenuImageUploadStatus.uploading,
          MenuImageUploadStatus.success,
        ]),
      );
      expect(
        cubit.state.url,
        'https://api.example.test/uploads/menu/test.webp',
      );
      expect(
        adapter.lastRequest!.headers['Authorization'],
        'Bearer staff-test-token',
      );
      expect(
        adapter.lastRequest!.contentType,
        startsWith('multipart/form-data; boundary='),
      );
      expect(adapter.multipart, contains('name="file"; filename="photo.png"'));
      expect(adapter.multipart, contains('image/png'));
      expect(adapter.lastRequest!.uri.path, '/api/uploads/menu');
      await sub.cancel();
      await cubit.close();
    },
  );

  for (final status in [400, 413, 415, 422, 503]) {
    test(
      'HTTP $status produces Russian failure and preserves previous URL',
      () async {
        adapter.status = status;
        final cubit = MenuImageUploadCubit(
          picker: TestPicker(file),
          repository: repository,
          initialUrl: 'old',
        );
        final states = <MenuImageUploadStatus>[];
        final sub = cubit.stream.listen((s) => states.add(s.status));
        await cubit.pick();
        await Future<void>.delayed(Duration.zero);
        expect(
          states,
          containsAllInOrder([
            MenuImageUploadStatus.picking,
            MenuImageUploadStatus.uploading,
            MenuImageUploadStatus.failure,
          ]),
        );
        expect(cubit.state.url, 'old');
        expect(cubit.state.message, matches(RegExp('[А-Яа-я]')));
        if (status == 413) expect(cubit.state.message, contains('15 МБ'));
        await sub.cancel();
        await cubit.close();
      },
    );
  }

  test('cancel picker leaves previous URL and returns idle', () async {
    final cubit = MenuImageUploadCubit(
      picker: TestPicker(null),
      repository: repository,
      initialUrl: 'old',
    );
    await cubit.pick();
    expect(cubit.state.status, MenuImageUploadStatus.idle);
    expect(cubit.state.url, 'old');
    expect(adapter.calls, 0);
    await cubit.close();
  });

  test('oversize file rejected before reading bytes', () async {
    var read = false;
    final large = MenuImageFile(
      name: 'large.jpg',
      length: () async => MenuImageUploadRepository.maxBytes + 1,
      read: () async {
        read = true;
        return Uint8List(0);
      },
    );
    final cubit = MenuImageUploadCubit(repository: repository);
    await cubit.drop(large);
    expect(read, false);
    expect(adapter.calls, 0);
    expect(cubit.state.status, MenuImageUploadStatus.failure);
    await cubit.close();
  });

  test(
    'second upload blocked; close cancels outstanding request and ignores late response',
    () async {
      adapter.pending = Completer<void>();
      final cubit = MenuImageUploadCubit(repository: repository);
      final upload = cubit.drop(file);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await cubit.drop(file);
      expect(adapter.calls, 1);
      final token = adapter.lastRequest!.cancelToken!;
      await cubit.close();
      expect(token.isCancelled, true);
      adapter.pending!.complete();
      await upload;
    },
  );

  test('unsafe response scheme rejected', () async {
    adapter.url = 'javascript:alert(1)';
    final cubit = MenuImageUploadCubit(repository: repository);
    await cubit.drop(file);
    expect(cubit.state.status, MenuImageUploadStatus.failure);
    await cubit.close();
  });

  Future<void> mount(
    WidgetTester tester,
    MenuImageUploadCubit cubit,
    TextEditingController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MenuImageUploadField(cubit: cubit, controller: controller),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'zone click invokes actual file_picker facade with mocked platform',
    (tester) async {
      final original = FilePickerPlatform.instance;
      final platform = TestFilePickerPlatform();
      FilePickerPlatform.instance = platform;
      addTearDown(() => FilePickerPlatform.instance = original);
      final cubit = MenuImageUploadCubit(repository: repository);
      final controller = TextEditingController(text: 'manual');
      await mount(tester, cubit, controller);
      await tester.tap(find.byKey(const ValueKey('menuImage.pick')));
      await tester.pumpAndSettle();
      expect(platform.calls, 1);
      expect(platform.extensions, ['jpg', 'jpeg', 'png', 'webp']);
      expect(controller.text, 'manual');
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
      controller.dispose();
    },
  );

  testWidgets(
    'mock desktop drop uploads, updates controller, displays thumbnail and can remove',
    (tester) async {
      final cubit = MenuImageUploadCubit(repository: repository);
      final controller = TextEditingController();
      await mount(tester, cubit, controller);
      tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
        DropDoneDetails(
          files: [
            DropItemFile.fromData(
              Uint8List.fromList([1, 2, 3]),
              name: 'drop.png',
              path: '/tmp/drop.png',
            ),
          ],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        controller.text,
        'https://api.example.test/uploads/menu/test.webp',
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menuImage.remove')));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(cubit.state.status, MenuImageUploadStatus.idle);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
      controller.dispose();
    },
  );

  testWidgets('HTTP 413 displays snackbar and keeps manual URL', (
    tester,
  ) async {
    adapter.status = 413;
    final cubit = MenuImageUploadCubit(
      repository: repository,
      picker: TestPicker(file),
    );
    final controller = TextEditingController(
      text: 'https://example.test/old.webp',
    );
    await mount(tester, cubit, controller);
    await tester.tap(find.byKey(const ValueKey('menuImage.pick')));
    await tester.pumpAndSettle();
    expect(find.text('Размер изображения превышает 15 МБ'), findsOneWidget);
    expect(controller.text, 'https://example.test/old.webp');
    await tester.pumpWidget(const SizedBox());
    await cubit.close();
    controller.dispose();
  });

  testWidgets(
    'form disables save while upload is pending and restores it afterwards',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      adapter.pending = Completer<void>();
      final cubit = MenuImageUploadCubit(
        repository: repository,
        picker: TestPicker(file),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MenuItemFormDialog(uploadCubit: cubit)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('menuImage.pick')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('menuItemForm.save')),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      adapter.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('menuItemForm.save')),
            )
            .onPressed,
        isNotNull,
      );
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('menuItemForm.imageUrl')),
      );
      expect(field.controller!.text, endsWith('/uploads/menu/test.webp'));
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );
}

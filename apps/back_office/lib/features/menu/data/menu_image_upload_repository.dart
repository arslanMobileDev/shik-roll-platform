import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'menu_image_picker.dart';

class MenuImageUploadException implements Exception {
  const MenuImageUploadException(this.message);
  final String message;
}

class MenuImageUploadRepository {
  MenuImageUploadRepository({ApiClient? client})
    : _dio = (client ?? ApiClient()).dio;
  final Dio _dio;
  static const maxBytes = 15 * 1024 * 1024;

  /// Static files live at the API origin even when requests use /api.
  String resolveUrl(String value) {
    final origin = Uri.parse(_dio.options.baseUrl).origin;
    final resolved = Uri.parse('$origin/').resolve(value);
    if (!['http', 'https'].contains(resolved.scheme) ||
        resolved.host.isEmpty ||
        resolved.userInfo.isNotEmpty) {
      throw const MenuImageUploadException(
        'Сервер вернул некорректный адрес изображения',
      );
    }
    return resolved.toString();
  }

  Future<String> upload(
    MenuImageFile file, {
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  }) async {
    final extension = file.name.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const MenuImageUploadException(
        'Выберите изображение JPG, PNG или WebP',
      ),
    };
    final size = await file.length();
    if (size != null && size > maxBytes) {
      throw const MenuImageUploadException(
        'Размер изображения превышает 15 МБ',
      );
    }
    if (cancelToken.isCancelled) {
      throw const MenuImageUploadException('Загрузка отменена');
    }
    final bytes = await file.read();
    if (bytes.isEmpty) {
      throw const MenuImageUploadException('Выбранный файл пуст');
    }
    if (bytes.length > maxBytes) {
      throw const MenuImageUploadException(
        'Размер изображения превышает 15 МБ',
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/uploads/menu',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: file.name,
            contentType: DioMediaType.parse(mime),
          ),
        }),
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 1),
        ),
        cancelToken: cancelToken,
        onSendProgress: onProgress,
      );
      final url = response.data?['url'];
      if (url is! String || url.trim().isEmpty) {
        throw const MenuImageUploadException(
          'Сервер не вернул адрес изображения',
        );
      }
      return resolveUrl(url);
    } on DioException catch (error) {
      throw MenuImageUploadException(switch (error.response?.statusCode) {
        400 => 'Не удалось принять изображение. Выберите файл повторно',
        413 => 'Размер изображения превышает 15 МБ',
        415 => 'Поддерживаются только JPG, PNG и WebP',
        422 => 'Изображение повреждено, анимировано или превышает 40 Мп',
        503 => 'Сервис обработки занят. Попробуйте немного позже',
        401 || 403 => 'Нет доступа к загрузке. Проверьте вход сотрудника',
        _ =>
          error.error == 'STAFF_TOKEN_MISSING'
              ? 'Войдите в аккаунт сотрудника для загрузки фото'
              : 'Не удалось загрузить изображение. Проверьте соединение и повторите',
      });
    }
  }
}

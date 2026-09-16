import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'couriers_repository.dart';

final class RemoteCouriersRepository implements CouriersRepository {
  RemoteCouriersRepository({ApiClient? client})
    : _dio = (client ?? ApiClient()).dio;
  final Dio _dio;
  CouriersApiException _error(DioException error) =>
      CouriersApiException(switch (error.response?.statusCode) {
        409 => 'Этот телефон уже зарегистрирован.',
        400 => 'Проверьте имя, российский телефон и PIN из 4–8 цифр.',
        401 => 'Сессия недействительна. Войдите повторно.',
        403 => 'Управление курьерами доступно владельцу и разработчику.',
        404 => 'Курьер или филиал не найден. Обновите список.',
        _ => 'Нет связи с сервером. Попробуйте снова.',
      });
  @override
  Future<List<CourierRecord>> list(String branchId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/staff/couriers',
        queryParameters: {'branchId': branchId},
      );
      final data = response.data;
      if (data == null) {
        throw const CouriersApiException('Сервер вернул пустой ответ.');
      }
      return List.unmodifiable(
        data.map((row) => CourierRecord.fromJson(row as Map<String, dynamic>)),
      );
    } on DioException catch (error) {
      throw _error(error);
    }
  }

  @override
  Future<void> save({
    String? id,
    required String branchId,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      if (pin != null && pin.isNotEmpty) 'pin': pin,
      'isActive': ?isActive,
    };
    try {
      if (id == null) {
        await _dio.post<void>(
          '/staff/couriers',
          data: {
            ...data,
            'branchId': branchId,
            'phone': normalizeCourierPhone(phone ?? ''),
          },
        );
      } else {
        await _dio.patch<void>('/staff/couriers/$id', data: data);
      }
    } on DioException catch (error) {
      throw _error(error);
    }
  }
}

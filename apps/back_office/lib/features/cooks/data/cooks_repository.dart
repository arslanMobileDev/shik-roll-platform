import '../../../core/network/api_client.dart';

final class CookRecord {
  const CookRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
  });
  final String id, name, phone;
  final bool isActive;
  factory CookRecord.fromJson(Map<String, dynamic> j) => CookRecord(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    isActive: j['isActive'] as bool,
  );
}

class CooksRepository {
  CooksRepository({ApiClient? client}) : client = client ?? ApiClient();
  final ApiClient client;
  Future<List<CookRecord>> list(String branch) async {
    final r = await client.dio.get<List<dynamic>>(
      '/staff/cooks',
      queryParameters: {'branchId': branch},
    );
    return r.data!
        .map((j) => CookRecord.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> save({
    String? id,
    required String branchId,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      if (pin != null && pin.isNotEmpty) 'pin': pin,
      'isActive': ?isActive,
    };
    if (id == null) {
      await client.dio.post<void>(
        '/staff/cooks',
        data: {...data, 'phone': phone, 'branchId': branchId},
      );
    } else {
      await client.dio.patch<void>('/staff/cooks/$id', data: data);
    }
  }
}

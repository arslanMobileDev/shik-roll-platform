import '../../../core/network/api_client.dart';
import 'cook_shift_models.dart';

/// Result of a successful clock-in: the shift the cook joined and their
/// own line record.
typedef ClockInResult = ({String shiftId, ActiveCook cook});

/// Source of kitchen shift data (cooks API contract).
///
/// The board needs the open shift to offer quick cook selection and to
/// attribute status transitions (COOKING/READY/COMPLETED) to a personal
/// author via `cookId`/`shiftId`.
abstract interface class CookShiftRepository {
  /// `GET /cooks/active-shift?branchId=…` — open shift + cooks on the line.
  Future<ActiveShift> fetchActiveShift({required String branchId});

  /// `POST /cooks/shift/clock-in` — body: `{pin, name, role}`.
  Future<ClockInResult> clockIn({
    required String branchId,
    required String pin,
    required String name,
    required CookRole role,
  });

  /// `POST /cooks/shift/clock-out` — closes the cook's shift.
  Future<void> clockOut({required String cookId, required String shiftId});
}

/// Remote implementation against the live cooks API.
final class RemoteCookShiftRepository implements CookShiftRepository {
  RemoteCookShiftRepository(ApiClient client) : _client = client;

  final ApiClient _client;

  @override
  Future<ActiveShift> fetchActiveShift({required String branchId}) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/cooks/active-shift',
      queryParameters: {'branchId': branchId},
    );
    return ActiveShift.fromJson(response.data ?? const <String, dynamic>{});
  }

  @override
  Future<ClockInResult> clockIn({
    required String branchId,
    required String pin,
    required String name,
    required CookRole role,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/cooks/shift/clock-in',
      data: {
        'branchId': branchId,
        'pin': pin,
        'name': name,
        'role': role.wireName,
      },
    );
    final body = response.data ?? const <String, dynamic>{};
    return (
      shiftId: body['shiftId'] as String? ?? '',
      cook: ActiveCook.fromJson(
        (body['cook'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  Future<void> clockOut({required String cookId, required String shiftId}) =>
      _client.dio.post<void>(
        '/cooks/shift/clock-out',
        data: {'cookId': cookId, 'shiftId': shiftId},
      );
}

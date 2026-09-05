import 'cook_shift_models.dart';

export '../../menu/data/back_office_repository.dart'
    show BackOfficeApiException;

/// Kitchen shift history data source (cooks API contract).
abstract interface class CookShiftsRepository {
  /// `GET /cooks/shifts?branchId={id}` — open and closed shifts of the
  /// branch with per-cook production metrics. Extends the minimal cooks
  /// contract (`/cooks/active-shift`, clock-in/out) with the history view
  /// required by the Back Office.
  Future<List<CookShiftRecord>> fetchShifts({required String branchId});
}

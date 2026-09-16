import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/cook_shift_models.dart';
import '../data/cook_shifts_repository.dart';

enum CookShiftsStatus { initial, loading, ready, failure }

/// Kitchen shift table state for the «Смены кухни» section.
final class CookShiftsState extends Equatable {
  const CookShiftsState({
    this.status = CookShiftsStatus.initial,
    this.branchId = '',
    this.period = 'today',
    this.dateFrom,
    this.dateTo,
    this.shifts = const [],
    this.errorMessage,
  });

  final CookShiftsStatus status;
  final String branchId;
  final String period;
  final DateTime? dateFrom, dateTo;
  final List<CookShiftRecord> shifts;
  final String? errorMessage;

  /// Shifts still open — «На смене».
  List<CookShiftRecord> get activeShifts =>
      shifts.where((s) => s.isActive).toList(growable: false);

  /// Orders handed out across all loaded shifts.
  int get totalCompletedOrders =>
      shifts.fold(0, (sum, s) => sum + s.completedOrders);

  /// Open shifts first, then the most recently clocked-in.
  List<CookShiftRecord> get displayShifts {
    final sorted = [...shifts]
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.clockInAt.compareTo(a.clockInAt);
      });
    return List.unmodifiable(sorted);
  }

  CookShiftsState copyWith({
    CookShiftsStatus? status,
    String? branchId,
    String? period,
    DateTime? dateFrom,
    DateTime? dateTo,
    List<CookShiftRecord>? shifts,
    String? Function()? errorMessage,
  }) => CookShiftsState(
    status: status ?? this.status,
    branchId: branchId ?? this.branchId,
    period: period ?? this.period,
    dateFrom: dateFrom ?? this.dateFrom,
    dateTo: dateTo ?? this.dateTo,
    shifts: shifts ?? this.shifts,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    branchId,
    shifts,
    errorMessage,
    period,
    dateFrom,
    dateTo,
  ];
}

/// Loads kitchen shift history for the active branch.
final class CookShiftsCubit extends Cubit<CookShiftsState> {
  CookShiftsCubit({required this.repository}) : super(const CookShiftsState());

  final CookShiftsRepository repository;

  int _request = 0;
  Future<void> load(
    String branchId, {
    String? period,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final request = ++_request;
    emit(
      state.copyWith(
        status: CookShiftsStatus.loading,
        branchId: branchId,
        period: period,
        dateFrom: dateFrom,
        dateTo: dateTo,
        errorMessage: () => null,
      ),
    );
    try {
      final shifts = await repository.fetchShifts(
        branchId: branchId,
        period: state.period,
        dateFrom: state.period == 'custom' ? state.dateFrom : null,
        dateTo: state.period == 'custom' ? state.dateTo : null,
      );
      if (isClosed || request != _request) return;
      emit(state.copyWith(status: CookShiftsStatus.ready, shifts: shifts));
    } on Object catch (e) {
      if (isClosed || request != _request) return;
      emit(
        state.copyWith(
          status: CookShiftsStatus.failure,
          errorMessage: () => 'Не удалось загрузить смены: $e',
        ),
      );
    }
  }
}

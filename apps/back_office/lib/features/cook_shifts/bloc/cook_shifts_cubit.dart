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
    this.shifts = const [],
    this.errorMessage,
  });

  final CookShiftsStatus status;
  final String branchId;
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
    final sorted = [...shifts]..sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.clockInAt.compareTo(a.clockInAt);
    });
    return List.unmodifiable(sorted);
  }

  CookShiftsState copyWith({
    CookShiftsStatus? status,
    String? branchId,
    List<CookShiftRecord>? shifts,
    String? Function()? errorMessage,
  }) => CookShiftsState(
    status: status ?? this.status,
    branchId: branchId ?? this.branchId,
    shifts: shifts ?? this.shifts,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
  );

  @override
  List<Object?> get props => [status, branchId, shifts, errorMessage];
}

/// Loads kitchen shift history for the active branch.
final class CookShiftsCubit extends Cubit<CookShiftsState> {
  CookShiftsCubit({required this.repository}) : super(const CookShiftsState());

  final CookShiftsRepository repository;

  Future<void> load(String branchId) async {
    emit(
      state.copyWith(
        status: CookShiftsStatus.loading,
        branchId: branchId,
        errorMessage: () => null,
      ),
    );
    try {
      final shifts = await repository.fetchShifts(branchId: branchId);
      emit(state.copyWith(status: CookShiftsStatus.ready, shifts: shifts));
    } on Object catch (e) {
      emit(
        state.copyWith(
          status: CookShiftsStatus.failure,
          errorMessage: () => 'Не удалось загрузить смены: $e',
        ),
      );
    }
  }
}

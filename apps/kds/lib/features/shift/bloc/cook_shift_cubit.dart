import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/cook_shift_models.dart';
import '../data/cook_shift_repository.dart';

enum CookShiftStatus { initial, loading, ready, failure }

/// Kitchen shift state: the open shift, everyone on the line and the cook
/// currently selected on this station.
final class CookShiftState extends Equatable {
  const CookShiftState({
    this.status = CookShiftStatus.initial,
    this.shiftId,
    this.branchId,
    this.lineCooks = const [],
    this.currentCookId,
    this.actionInFlight = false,
    this.errorMessage,
  });

  final CookShiftStatus status;

  /// Open shift id — attached to order status transitions as `shiftId`.
  final String? shiftId;

  final String? branchId;

  /// Cooks clocked in on the line.
  final List<ActiveCook> lineCooks;

  /// Cook operating this station; their id goes to transitions as `cookId`.
  final String? currentCookId;

  /// Clock-in/clock-out request in flight — dialog shows progress.
  final bool actionInFlight;

  final String? errorMessage;

  ActiveCook? get currentCook {
    for (final cook in lineCooks) {
      if (cook.id == currentCookId) return cook;
    }
    return null;
  }

  CookShiftState copyWith({
    CookShiftStatus? status,
    String? shiftId,
    String? branchId,
    List<ActiveCook>? lineCooks,
    String? Function()? currentCookId,
    bool? actionInFlight,
    String? Function()? errorMessage,
  }) => CookShiftState(
    status: status ?? this.status,
    shiftId: shiftId ?? this.shiftId,
    branchId: branchId ?? this.branchId,
    lineCooks: lineCooks ?? this.lineCooks,
    currentCookId: currentCookId != null ? currentCookId() : this.currentCookId,
    actionInFlight: actionInFlight ?? this.actionInFlight,
    errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    shiftId,
    branchId,
    lineCooks,
    currentCookId,
    actionInFlight,
    errorMessage,
  ];
}

/// Owns kitchen-shift logic: loading the open shift, cook selection,
/// clock-in/clock-out and the personal production counter.
class CookShiftCubit extends Cubit<CookShiftState> {
  CookShiftCubit({required this.repository}) : super(const CookShiftState());

  final CookShiftRepository repository;

  /// Loads the open shift and its line for [branchId].
  Future<void> load(String branchId) async {
    emit(
      state.copyWith(
        status: CookShiftStatus.loading,
        branchId: branchId,
        errorMessage: () => null,
      ),
    );
    try {
      final shift = await repository.fetchActiveShift(branchId: branchId);
      emit(
        state.copyWith(
          status: CookShiftStatus.ready,
          shiftId: shift.shiftId,
          lineCooks: shift.cooks,
          errorMessage: () => null,
        ),
      );
    } on Object catch (e) {
      emit(
        state.copyWith(
          status: CookShiftStatus.failure,
          errorMessage: () => 'Не удалось загрузить смену: $e',
        ),
      );
    }
  }

  /// Puts a cook already on the line in charge of this station.
  void selectCook(String cookId) {
    if (state.lineCooks.every((c) => c.id != cookId)) return;
    emit(state.copyWith(currentCookId: () => cookId));
  }

  /// Clocks a cook in by PIN and makes them the station cook.
  Future<void> clockIn({
    required String pin,
    required String name,
    required CookRole role,
  }) async {
    final branchId = state.branchId;
    if (branchId == null || state.actionInFlight) return;
    emit(state.copyWith(actionInFlight: true, errorMessage: () => null));
    try {
      final result = await repository.clockIn(
        branchId: branchId,
        pin: pin,
        name: name,
        role: role,
      );
      final alreadyOnLine = state.lineCooks.any((c) => c.id == result.cook.id);
      emit(
        state.copyWith(
          shiftId: result.shiftId,
          lineCooks: alreadyOnLine
              ? state.lineCooks
              : [...state.lineCooks, result.cook],
          currentCookId: () => result.cook.id,
          actionInFlight: false,
        ),
      );
    } on Object catch (e) {
      emit(
        state.copyWith(
          actionInFlight: false,
          errorMessage: () => 'Не удалось открыть смену: $e',
        ),
      );
    }
  }

  /// Closes the current cook's shift and clears the station selection.
  Future<void> clockOutCurrent() async {
    final cook = state.currentCook;
    final shiftId = state.shiftId;
    if (cook == null || shiftId == null || state.actionInFlight) return;
    emit(state.copyWith(actionInFlight: true, errorMessage: () => null));
    try {
      await repository.clockOut(cookId: cook.id, shiftId: shiftId);
      emit(
        state.copyWith(
          lineCooks: [
            for (final c in state.lineCooks)
              if (c.id != cook.id) c,
          ],
          currentCookId: () => null,
          actionInFlight: false,
        ),
      );
    } on Object catch (e) {
      emit(
        state.copyWith(
          actionInFlight: false,
          errorMessage: () => 'Не удалось закрыть смену: $e',
        ),
      );
    }
  }

  /// Increments the current cook's personal counter when they hand out an
  /// order («Выдано») and folds [prepTime] into their rolling average.
  void recordOrderCompleted({required Duration prepTime}) {
    final cook = state.currentCook;
    if (cook == null) return;
    final count = cook.completedOrders;
    final previousAvg = cook.avgPrepSeconds;
    final nextAvg = previousAvg == null
        ? prepTime.inSeconds
        : ((previousAvg * count + prepTime.inSeconds) / (count + 1)).round();
    final updated = cook.copyWith(
      completedOrders: count + 1,
      avgPrepSeconds: () => nextAvg,
    );
    emit(
      state.copyWith(
        lineCooks: [
          for (final c in state.lineCooks)
            if (c.id == cook.id) updated else c,
        ],
      ),
    );
  }
}

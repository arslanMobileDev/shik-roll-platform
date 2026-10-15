import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/couriers_repository.dart';

enum CouriersStatus { initial, loading, loaded, error }

final class CouriersState {
  const CouriersState({
    this.status = CouriersStatus.initial,
    this.branchId = '',
    this.rows = const [],
    this.saving = false,
    this.includeDeleted = false,
    this.error,
  });
  final CouriersStatus status;
  final String branchId;
  final List<CourierRecord> rows;
  final bool saving;

  /// Which half of the list is on screen: live couriers, or the self-deleted
  /// ones still inside their restore window. Never both — the backend answers
  /// either-or, and a deleted account has no business standing next to a
  /// working one.
  final bool includeDeleted;
  final String? error;
}

final class CouriersCubit extends Cubit<CouriersState> {
  CouriersCubit(this.repository) : super(const CouriersState());
  final CouriersRepository repository;
  int _request = 0;
  bool _saving = false;
  String _message(Object error) => error is CouriersApiException
      ? error.message
      : 'Не удалось выполнить запрос. Попробуйте снова.';
  Future<void> load(String branchId, {bool includeDeleted = false}) async {
    final request = ++_request;
    emit(
      CouriersState(
        status: CouriersStatus.loading,
        branchId: branchId,
        saving: _saving,
        includeDeleted: includeDeleted,
      ),
    );
    try {
      final rows = await repository.list(
        branchId,
        includeDeleted: includeDeleted,
      );
      if (!isClosed && request == _request) {
        emit(
          CouriersState(
            status: CouriersStatus.loaded,
            branchId: branchId,
            rows: List.unmodifiable(rows),
            saving: _saving,
            includeDeleted: includeDeleted,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && request == _request) {
        emit(
          CouriersState(
            status: CouriersStatus.error,
            branchId: branchId,
            saving: _saving,
            includeDeleted: includeDeleted,
            error: _message(error),
          ),
        );
      }
    }
  }

  Future<void> loadDeleted() => load(state.branchId, includeDeleted: true);

  /// Hands a self-deleted account back, then reloads the tab it was listed in —
  /// the row is gone from "Удалённые" the moment it works, so a local edit
  /// would leave a ghost card behind.
  Future<bool> restore(String id) async {
    if (_saving || state.status == CouriersStatus.loading) return false;
    final branch = state.branchId;
    _saving = true;
    emit(
      CouriersState(
        status: state.status,
        branchId: branch,
        rows: state.rows,
        saving: true,
        includeDeleted: state.includeDeleted,
      ),
    );
    try {
      await repository.restore(id);
    } catch (error) {
      _saving = false;
      if (!isClosed) {
        emit(
          CouriersState(
            status: state.status,
            branchId: branch,
            rows: state.rows,
            includeDeleted: state.includeDeleted,
            error: _message(error),
          ),
        );
      }
      return false;
    }
    _saving = false;
    // The mutation succeeded, so the refresh cannot undo it: a failed reload
    // leaves the stale card with an error above it, not a duplicate restore.
    if (!isClosed) await load(branch, includeDeleted: state.includeDeleted);
    return true;
  }

  Future<bool> save({
    String? id,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
    String? expectedBranchId,
  }) async {
    if (_saving ||
        state.status == CouriersStatus.loading ||
        state.branchId.isEmpty) {
      return false;
    }
    final branch = state.branchId;
    if (expectedBranchId != null && expectedBranchId != branch) {
      return false;
    }
    _saving = true;
    emit(
      CouriersState(
        status: state.status,
        branchId: branch,
        rows: state.rows,
        saving: true,
        includeDeleted: state.includeDeleted,
      ),
    );
    try {
      await repository.save(
        id: id,
        branchId: branch,
        name: name,
        phone: phone,
        pin: pin,
        isActive: isActive,
      );
    } catch (error) {
      _saving = false;
      if (!isClosed) {
        emit(
          CouriersState(
            status: state.status,
            branchId: state.branchId,
            rows: state.rows,
            includeDeleted: state.includeDeleted,
            error: state.branchId == branch ? _message(error) : null,
          ),
        );
      }
      return false;
    }
    _saving = false;
    if (!isClosed) {
      // The mutation succeeded. A failed refresh must not cause duplicate creation.
      if (state.branchId == branch) {
        await load(branch);
      } else {
        emit(
          CouriersState(
            status: state.status,
            branchId: state.branchId,
            rows: state.rows,
            includeDeleted: state.includeDeleted,
            error: state.error,
          ),
        );
      }
    }
    return true;
  }
}

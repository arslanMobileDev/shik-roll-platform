import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/couriers_repository.dart';

enum CouriersStatus { initial, loading, loaded, error }

final class CouriersState {
  const CouriersState({
    this.status = CouriersStatus.initial,
    this.branchId = '',
    this.rows = const [],
    this.saving = false,
    this.error,
  });
  final CouriersStatus status;
  final String branchId;
  final List<CourierRecord> rows;
  final bool saving;
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
  Future<void> load(String branchId) async {
    final request = ++_request;
    emit(
      CouriersState(
        status: CouriersStatus.loading,
        branchId: branchId,
        saving: _saving,
      ),
    );
    try {
      final rows = await repository.list(branchId);
      if (!isClosed && request == _request) {
        emit(
          CouriersState(
            status: CouriersStatus.loaded,
            branchId: branchId,
            rows: List.unmodifiable(rows),
            saving: _saving,
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
            error: _message(error),
          ),
        );
      }
    }
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
            error: state.error,
          ),
        );
      }
    }
    return true;
  }
}

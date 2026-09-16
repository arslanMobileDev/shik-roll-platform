import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/cooks_repository.dart';

class CooksState {
  const CooksState({this.rows = const [], this.loading = false, this.error});
  final List<CookRecord> rows;
  final bool loading;
  final String? error;
}

class CooksCubit extends Cubit<CooksState> {
  CooksCubit(this.repository) : super(const CooksState());
  final CooksRepository repository;
  String branch = '';
  int request = 0;
  Future<void> load(String id) async {
    branch = id;
    final generation = ++request;
    emit(const CooksState(loading: true));
    try {
      final rows = await repository.list(id);
      if (!isClosed && generation == request) emit(CooksState(rows: rows));
    } catch (_) {
      if (!isClosed && generation == request) {
        emit(const CooksState(error: 'Не удалось загрузить поваров'));
      }
    }
  }

  Future<bool> save({
    String? id,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
  }) async {
    if (state.loading) return false;
    final selected = branch;
    emit(CooksState(rows: state.rows, loading: true));
    try {
      await repository.save(
        id: id,
        branchId: selected,
        name: name,
        phone: phone,
        pin: pin,
        isActive: isActive,
      );
      if (!isClosed) await load(branch);
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(
          CooksState(
            rows: state.rows,
            error:
                'Не удалось сохранить. Проверьте данные и уникальность телефона.',
          ),
        );
      }
      return false;
    }
  }
}

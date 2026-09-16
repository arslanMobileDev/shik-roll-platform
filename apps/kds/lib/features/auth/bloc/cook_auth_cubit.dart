import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/cook_auth_repository.dart';

final class CookAuthState {
  const CookAuthState({this.session, this.loading = false, this.error});
  final CookSession? session;
  final bool loading;
  final String? error;
}

final class CookAuthCubit extends Cubit<CookAuthState> {
  CookAuthCubit(this.repository) : super(const CookAuthState());
  final CookAuthRepository repository;
  Future<void> login(String phone, String pin) async {
    if (state.loading) return;
    if (phone.trim().isEmpty || !RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      emit(const CookAuthState(error: 'Введите телефон и PIN из 4–8 цифр'));
      return;
    }
    emit(const CookAuthState(loading: true));
    try {
      final s = await repository.login(phone.trim(), pin);
      if (!isClosed) emit(CookAuthState(session: s));
    } catch (_) {
      if (!isClosed) {
        emit(
          const CookAuthState(
            error: 'Не удалось войти. Проверьте телефон, PIN и связь.',
          ),
        );
      }
    }
  }

  Future<bool> logout() async {
    final s = state.session;
    if (s == null) return true;
    if (state.loading) return false;
    emit(CookAuthState(session: s, loading: true));
    try {
      await repository.logout(s);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        if (!isClosed) {
          emit(
            CookAuthState(
              session: s,
              error: 'Не удалось закрыть смену. Повторите при наличии связи.',
            ),
          );
        }
        return false;
      }
    } catch (_) {
      if (!isClosed) {
        emit(CookAuthState(session: s, error: 'Не удалось закрыть смену'));
      }
      return false;
    }
    if (!isClosed) emit(const CookAuthState());
    return true;
  }

  void expire() {
    if (!isClosed) {
      emit(const CookAuthState(error: 'Личная сессия истекла. Войдите снова.'));
    }
  }
}

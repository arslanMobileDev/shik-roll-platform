import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import 'login_state.dart';

/// Drives the login form: submits credentials, exposes submitting /
/// success / failure states. All errors are already human-readable.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required this._repository})
    : super(const LoginIdle());

  final AuthRepository _repository;

  Future<void> submit({required String phone, required String pin}) async {
    emit(const LoginSubmitting());
    try {
      final result = await _repository.login(phone: phone, pin: pin);
      emit(LoginSuccess(result.profile));
    } on AuthException catch (e) {
      emit(LoginFailure(e.message));
    } catch (_) {
      emit(const LoginFailure('Непредвиденная ошибка. Попробуйте ещё раз.'));
    }
  }

  void reset() => emit(const LoginIdle());
}

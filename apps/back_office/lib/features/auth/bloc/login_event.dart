import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// User pressed "Войти": phone and PIN come from the form fields.
class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.phone, required this.pin});
  final String phone;
  final String pin;

  @override
  List<Object?> get props => [phone, pin];
}

/// Reset the form back to idle (e.g. the user starts typing again).
class LoginReset extends LoginEvent {
  const LoginReset();
}

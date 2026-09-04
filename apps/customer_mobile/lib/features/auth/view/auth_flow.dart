import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/legal_links.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'widgets/phone_input_formatter.dart';

/// Seconds before the «Отправить повторно» button unlocks.
const int kOtpResendDelaySeconds = 60;

/// Modal SMS login. Resolves with `true` once the guest is authenticated,
/// `false` when dismissed — the caller (checkout) continues on `true`.
Future<bool> showAuthFlowSheet(BuildContext context) async {
  final authBloc = context.read<AuthBloc>();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: authBloc,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const SafeArea(child: AuthFlowView()),
      ),
    ),
  );
  return result ?? false;
}

/// Phone → OTP steps driven by [AuthBloc]; pops `true` on success.
class AuthFlowView extends StatelessWidget {
  const AuthFlowView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, next) => previous.status != next.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s12,
            AppSpacing.s16,
            AppSpacing.s16,
          ),
          child: switch (state.status) {
            AuthStatus.otpSent => const _OtpStep(),
            _ => const _PhoneStep(),
          },
        );
      },
    );
  }
}

class _PhoneStep extends StatefulWidget {
  const _PhoneStep();

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AuthBloc>().state;
    final phone = e164FromMaskedPhone(_controller.text);
    final canSubmit = phone != null && !state.isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Вход по номеру телефона', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Отправим SMS с кодом подтверждения',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.gray600,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        TextField(
          key: const ValueKey('phone-field'),
          controller: _controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          inputFormatters: [const PhoneInputFormatter()],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (canSubmit) _submit(phone);
          },
          decoration: const InputDecoration(
            labelText: 'Номер телефона',
            prefixText: '+7 ',
            hintText: '(999) 123-45-67',
            border: OutlineInputBorder(),
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            state.errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        FilledButton(
          key: const ValueKey('send-code-button'),
          onPressed: canSubmit ? () => _submit(phone) : null,
          child: state.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text('Получить код'),
        ),
        const SizedBox(height: AppSpacing.s12),
        const LegalLinksText(),
      ],
    );
  }

  void _submit(String phone) {
    context.read<AuthBloc>().add(AuthOtpSendRequested(phone: phone));
  }
}

class _OtpStep extends StatefulWidget {
  const _OtpStep();

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = kOtpResendDelaySeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = kOtpResendDelaySeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AuthBloc>().state;
    final code = _controller.text;
    final canSubmit = code.length == 4 && !state.isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Код из SMS', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Отправили на ${state.phone ?? ''}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.gray600,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        TextField(
          key: const ValueKey('otp-field'),
          controller: _controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          onChanged: (value) {
            setState(() {});
            if (value.length == 4) _submit(value);
          },
          decoration: const InputDecoration(
            labelText: 'Код из SMS',
            hintText: '••••',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        FilledButton(
          key: const ValueKey('verify-code-button'),
          onPressed: canSubmit ? () => _submit(code) : null,
          child: state.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text('Подтвердить'),
        ),
        const SizedBox(height: AppSpacing.s8),
        Center(
          child: _secondsLeft > 0
              ? Text(
                  'Отправить код повторно через ${_formatSeconds(_secondsLeft)}',
                  key: const ValueKey('resend-timer'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.gray600,
                  ),
                )
              : TextButton(
                  key: const ValueKey('resend-code-button'),
                  onPressed: state.isLoading
                      ? null
                      : () {
                          context.read<AuthBloc>().add(
                            const AuthOtpResendRequested(),
                          );
                          _startTimer();
                        },
                  child: const Text('Отправить код повторно'),
                ),
        ),
        Center(
          child: TextButton(
            key: const ValueKey('change-phone-button'),
            onPressed: state.isLoading
                ? null
                : () => context.read<AuthBloc>().add(
                    const AuthOtpCancelled(),
                  ),
            child: const Text('Изменить номер'),
          ),
        ),
      ],
    );
  }

  void _submit(String code) {
    context.read<AuthBloc>().add(AuthOtpVerifyRequested(code: code));
  }

  static String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../bloc/kitchen_auth_cubit.dart';

/// ADR-1618 — kitchen terminal login.
///
/// Shared device identity: terminal code + 4-digit PIN. The JWT that follows
/// scopes every board request to the terminal's branch — no branch picker
/// exists on this screen by design.
class KitchenLoginScreen extends StatefulWidget {
  const KitchenLoginScreen({super.key});

  @override
  State<KitchenLoginScreen> createState() => _KitchenLoginScreenState();
}

class _KitchenLoginScreenState extends State<KitchenLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<KitchenAuthCubit>().login(
      terminalCode: _codeController.text.trim(),
      pin: _pinController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: BlocBuilder<KitchenAuthCubit, KitchenAuthState>(
              builder: (context, state) {
                final busy = state is KitchenUnauthenticated && state.busy;
                final error = state is KitchenUnauthenticated
                    ? state.errorMessage
                    : null;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.soup_kitchen_outlined,
                        size: 56,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        'Кухня — SHIK ROLL',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: AppColors.gray900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Вход кухонного терминала',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      TextFormField(
                        key: const Key('kitchen-login-code'),
                        controller: _codeController,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: _inputDecoration(
                          label: 'Код терминала',
                          hint: 'KDS-01',
                          icon: Icons.point_of_sale_outlined,
                        ),
                        onFieldSubmitted: (_) => _pinFocus.requestFocus(),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Введите код терминала'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      TextFormField(
                        key: const Key('kitchen-login-pin'),
                        controller: _pinController,
                        focusNode: _pinFocus,
                        enabled: !busy,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          letterSpacing: 12,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: _inputDecoration(
                          label: 'PIN',
                          hint: '••••',
                          icon: Icons.lock_outline,
                        ).copyWith(counterText: ''),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) =>
                            (value == null || value.length != 4)
                            ? 'PIN — ровно 4 цифры'
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Container(
                          key: const Key('kitchen-login-error'),
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: AppColors.onErrorContainer,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  error,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s24),
                      FilledButton.icon(
                        key: const Key('kitchen-login-submit'),
                        onPressed: busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          textStyle: textTheme.titleMedium,
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(busy ? 'Входим…' : 'Войти'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r12),
    ),
  );
}

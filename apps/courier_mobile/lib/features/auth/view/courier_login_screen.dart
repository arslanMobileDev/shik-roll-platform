import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/shik_branches.dart';
import '../../../core/theme/halal_badge.dart';
import '../../../data/models/branch.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';

/// Быстрый вход курьера: телефон + 4-значный PIN + выбор филиала.
class CourierLoginScreen extends StatefulWidget {
  const CourierLoginScreen({super.key});

  @override
  State<CourierLoginScreen> createState() => _CourierLoginScreenState();
}

class _CourierLoginScreenState extends State<CourierLoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Branch _selectedBranch = shikBranches.first;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _errorText = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().login(
          pin: _pinController.text.trim(),
          phone: _phoneController.text.trim(),
          branch: _selectedBranch,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            setState(() => _errorText = state.message);
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'SHIK ROLL',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Курьер · Internal Use Only',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      const Center(child: HalalBadge()),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const Key('login_phone_field'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Телефон',
                          hintText: '+7 999 123-45-67',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (value) {
                          final digits = (value ?? '').replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          if (digits.length < 10) {
                            return 'Введите номер телефона';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('login_pin_field'),
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'PIN-код',
                          hintText: '4 цифры',
                          counterText: '',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) =>
                            (value ?? '').length == 4 ? null : 'PIN — 4 цифры',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Branch>(
                        key: const Key('login_branch_dropdown'),
                        initialValue: _selectedBranch,
                        decoration: const InputDecoration(
                          labelText: 'Точка',
                          prefixIcon: Icon(Icons.store),
                        ),
                        items: shikBranches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(b.name),
                              ),
                            )
                            .toList(),
                        onChanged: (branch) {
                          if (branch != null) {
                            setState(() => _selectedBranch = branch);
                          }
                        },
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final loading = state is AuthLoading;
                          return FilledButton(
                            key: const Key('login_submit_button'),
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Войти'),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

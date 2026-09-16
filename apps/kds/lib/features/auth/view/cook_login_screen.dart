import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/cook_auth_cubit.dart';

class CookLoginScreen extends StatefulWidget {
  const CookLoginScreen({super.key});
  @override
  State<CookLoginScreen> createState() => _CookLoginScreenState();
}

class _CookLoginScreenState extends State<CookLoginScreen> {
  final phone = TextEditingController(), pin = TextEditingController();
  @override
  void dispose() {
    phone.dispose();
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: BlocBuilder<CookAuthCubit, CookAuthState>(
            builder: (context, state) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Вход повара',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('cook-phone'),
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  enabled: !state.loading,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('cook-pin'),
                  controller: pin,
                  obscureText: true,
                  maxLength: 8,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !state.loading,
                  decoration: const InputDecoration(labelText: 'Личный PIN'),
                  onSubmitted: (_) =>
                      context.read<CookAuthCubit>().login(phone.text, pin.text),
                ),
                if (state.error != null)
                  Text(state.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('cook-login'),
                  onPressed: state.loading
                      ? null
                      : () => context.read<CookAuthCubit>().login(
                          phone.text,
                          pin.text,
                        ),
                  child: Text(state.loading ? 'Входим…' : 'Начать смену'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

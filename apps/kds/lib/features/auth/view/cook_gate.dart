import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/cook_auth_cubit.dart';
import '../data/cook_auth_repository.dart';
import 'cook_login_screen.dart';

class CookGate extends StatelessWidget {
  const CookGate({super.key, required this.cubit, required this.child});
  final CookAuthCubit cubit;
  final Widget child;
  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: cubit,
    child: BlocBuilder<CookAuthCubit, CookAuthState>(
      builder: (context, state) =>
          state.session == null ? const CookLoginScreen() : child,
    ),
  );
}

class CookHeader extends StatelessWidget {
  const CookHeader({super.key, required this.onStats});
  final void Function(CookAuthRepository, CookSession) onStats;
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CookAuthCubit>();
    final s = cubit.state;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(s.session?.name ?? '', overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          tooltip: 'Моя статистика',
          icon: const Icon(Icons.bar_chart),
          onPressed: s.session == null
              ? null
              : () => onStats(cubit.repository, s.session!),
        ),
        IconButton(
          tooltip: 'Сменить повара',
          icon: const Icon(Icons.switch_account),
          onPressed: s.loading
              ? null
              : () async {
                  await cubit.logout();
                  if (context.mounted && cubit.state.error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(cubit.state.error!)));
                  }
                },
        ),
      ],
    );
  }
}

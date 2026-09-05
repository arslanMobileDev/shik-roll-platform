import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../bloc/cook_shift_cubit.dart';
import 'shift_production_badge.dart';
import 'shift_select_dialog.dart';

/// Cook indicator for the KDS header: avatar + name of the station cook,
/// their [ShiftProductionBadge] and a «Сменить / Завершить смену» menu.
///
/// Without a selected cook renders a single «Выбрать смену» button that
/// opens [ShiftSelectDialog].
class CookShiftHeader extends StatelessWidget {
  const CookShiftHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // Below the tablet breakpoint the name/role column collapses, keeping
    // badge, avatar and menu visible on narrow station displays.
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.tablet;
    return BlocBuilder<CookShiftCubit, CookShiftState>(
      builder: (context, state) {
        final cook = state.currentCook;
        if (cook == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            child: FilledButton.tonalIcon(
              key: const Key('open-shift-select'),
              onPressed: () => showShiftSelectDialog(context),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Выбрать смену'),
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShiftProductionBadge(
              completedCount: cook.completedOrders,
              avgPrepTime: cook.avgPrepSeconds == null
                  ? null
                  : Duration(seconds: cook.avgPrepSeconds!),
            ),
            const SizedBox(width: AppSpacing.s8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                _initials(cook.name),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: AppSpacing.s8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cook.name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    cook.role.label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.gray600),
                  ),
                ],
              ),
            ],
            PopupMenuButton<String>(
              key: const Key('cook-shift-menu'),
              tooltip: 'Смена',
              onSelected: (action) => switch (action) {
                'change' => showShiftSelectDialog(context),
                'clockOut' => context.read<CookShiftCubit>().clockOutCurrent(),
                _ => null,
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'change', child: Text('Сменить повара')),
                PopupMenuItem(
                  value: 'clockOut',
                  child: Text('Завершить смену'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}

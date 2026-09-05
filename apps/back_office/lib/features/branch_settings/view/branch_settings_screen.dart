import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../bloc/branch_settings_cubit.dart';

/// Branch configuration: which service modes are enabled at the point.
class BranchSettingsScreen extends StatelessWidget {
  const BranchSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Настройки точки',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Форматы обслуживания на активной точке',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Expanded(child: _ServiceModesCard()),
        ],
      ),
    );
  }
}

class _ServiceModesCard extends StatelessWidget {
  const _ServiceModesCard();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BranchSettingsCubit>();
    final modes = context.watch<BranchSettingsCubit>().state;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeTile(
                key: const ValueKey('serviceMode.delivery'),
                icon: Icons.two_wheeler_rounded,
                title: 'Доставка курьером',
                subtitle: 'Заказы с доставкой по зоне покрытия точки',
                value: modes.courierDelivery,
                onChanged: cubit.toggleCourierDelivery,
              ),
              const Divider(),
              _ModeTile(
                key: const ValueKey('serviceMode.pickup'),
                icon: Icons.shopping_bag_outlined,
                title: 'Самовывоз со стойки',
                subtitle: 'Гость забирает заказ самостоятельно',
                value: modes.counterPickup,
                onChanged: cubit.toggleCounterPickup,
              ),
              const Divider(),
              _ModeTile(
                key: const ValueKey('serviceMode.dineIn'),
                icon: Icons.deck_outlined,
                title: 'Обслуживание в зале',
                subtitle: 'Заказы к столикам и посадка в зале',
                value: modes.dineIn,
                onChanged: cubit.toggleDineIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Icon(icon, color: AppColors.terracotta),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

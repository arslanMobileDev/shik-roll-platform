import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Placeholder for an empty cart with a shortcut back to the menu.
class CartEmptyView extends StatelessWidget {
  const CartEmptyView({super.key, required this.onGoToMenu});

  final VoidCallback onGoToMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text('Корзина пуста', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Добавьте блюда из меню',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton.tonal(
              key: const ValueKey('go-to-menu-button'),
              onPressed: onGoToMenu,
              child: const Text('Перейти к меню'),
            ),
          ],
        ),
      ),
    );
  }
}

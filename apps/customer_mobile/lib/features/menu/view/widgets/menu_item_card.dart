import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/halal_status_badge.dart';
import '../../data/menu_models.dart';

/// Guest-facing product card for the menu grid.
///
/// Tapping the card (or "Выбрать" for modifier-bearing dishes) opens the
/// details sheet; plain dishes go straight into the cart via [onAddToCart].
class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAddToCart,
    required this.onSelect,
  });

  final MenuItem item;
  final VoidCallback onAddToCart;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = item.hasModifiers ? onSelect : onAddToCart;

    return Card(
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo placeholder
              AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.restaurant_outlined,
                      size: 36,
                      color: AppColors.gray400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  HalalStatusBadge(isHalal: item.isHalal, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                item.description ?? item.category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.gray600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.price.format(),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: item.available ? primary : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      item.hasModifiers ? 'Выбрать' : 'В корзину',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

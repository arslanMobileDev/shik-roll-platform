import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/availability_status_badge.dart';
import '../../../../core/widgets/halal_status_badge.dart';
import '../../data/catalog_models.dart';

/// UI-803 Commerce — product card for the POS catalog grid.
///
/// Disabled state: items that are not sellable in the branch context
/// (unavailable or stop-listed) render dimmed and do not respond to taps.
class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final MenuItem item;
  final ValueChanged<MenuItem> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = item.available;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Card(
        child: InkWell(
          onTap: enabled ? () => onTap(item) : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardBadges(item: item),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                if (item.weight != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${item.weight} г',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.gray600,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.price.effective.format(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: enabled
                              ? AppColors.gray900
                              : AppColors.gray500,
                        ),
                      ),
                    ),
                    Icon(
                      enabled ? Icons.add_circle : Icons.block,
                      size: 24,
                      color: enabled
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.gray400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBadges extends StatelessWidget {
  const _CardBadges({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s4,
      runSpacing: AppSpacing.s4,
      children: [
        HalalStatusBadge(isHalal: item.isHalal, compact: true),
        AvailabilityStatusBadge(
          status: switch ((item.availability.isAvailable, item.stopList.isActive)) {
            (false, _) => AvailabilityStatus.unavailable,
            (true, true) => AvailabilityStatus.stopListed,
            _ => AvailabilityStatus.available,
          },
          stopListReason: item.stopList.reason,
        ),
        if (item.isPopular) const _MerchChip(label: 'Хит'),
        if (item.isNew) const _MerchChip(label: 'Новинка'),
      ],
    );
  }
}

class _MerchChip extends StatelessWidget {
  const _MerchChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

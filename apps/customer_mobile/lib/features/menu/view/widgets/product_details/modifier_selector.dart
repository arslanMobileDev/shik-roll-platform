import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../data/menu_models.dart';
import 'product_details_cubit.dart';

/// Tree of modifier groups (single-choice radio / multiple checkboxes).
///
/// Renders group headers + option rows and reports toggles to the cubit;
/// business rules (min/max, required, total) live in [ProductDetailsCubit].
class ModifierSelector extends StatelessWidget {
  const ModifierSelector({
    super.key,
    required this.groups,
    required this.selection,
    required this.onToggle,
  });

  final List<ModifierGroup> groups;
  final ModifierSelection selection;
  final void Function(String groupId, String optionId, bool selected)
  onToggle;

  @override
  Widget build(BuildContext context) {
    final sorted = [...groups]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in sorted) ...[
          _ModifierGroupNode(
            key: ValueKey(group.id),
            group: group,
            selectedIds: selection[group.id] ?? const <String>{},
            onToggle: onToggle,
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
      ],
    );
  }
}

class _ModifierGroupNode extends StatelessWidget {
  const _ModifierGroupNode({
    super.key,
    required this.group,
    required this.selectedIds,
    required this.onToggle,
  });

  final ModifierGroup group;
  final Set<String> selectedIds;
  final void Function(String groupId, String optionId, bool selected)
  onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sorted = [...group.items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(group.name, style: textTheme.titleSmall),
            ),
            if (group.isRequired)
              Text(
                'обязательно',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                ),
              )
            else if (group.maxSelected != null)
              Text(
                'до ${group.maxSelected}',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.gray500,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        for (final option in sorted)
          _ModifierOptionTile(
            option: option,
            singleChoice: group.isSingleChoice,
            selected: selectedIds.contains(option.id),
            onTap: () => onToggle(
              group.id,
              option.id,
              !selectedIds.contains(option.id),
            ),
          ),
      ],
    );
  }
}

class _ModifierOptionTile extends StatelessWidget {
  const _ModifierOptionTile({
    required this.option,
    required this.singleChoice,
    required this.selected,
    required this.onTap,
  });

  final ModifierItem option;
  final bool singleChoice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = option.price;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Row(
          children: [
            Icon(
              singleChoice
                  ? (selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off)
                  : (selected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank),
              size: 24,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.gray500,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: Text(option.name, style: textTheme.bodyMedium)),
            if (!price.isZero)
              Text(
                '+${price.format()}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.gray700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

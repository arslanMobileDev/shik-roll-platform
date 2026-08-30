import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/catalog_models.dart';

/// UI-level classification of a modifier group (UI-803).
///
/// The Menu & Product API carries no explicit kind, so the host maps groups
/// to kinds (by id, source key or configuration); the kind drives the icon
/// and presentation accent of the group node.
enum ModifierKind {
  weight,
  portion,
  addon,
  sauce;

  IconData get icon => switch (this) {
    ModifierKind.weight => Icons.scale_outlined,
    ModifierKind.portion => Icons.dinner_dining_outlined,
    ModifierKind.addon => Icons.add_circle_outline,
    ModifierKind.sauce => Icons.water_drop_outlined,
  };
}

/// Current selection of the [ModifierTreeSelector]:
/// modifier group id → selected option ids.
typedef ModifierSelection = Map<String, Set<String>>;

/// UI-803 Commerce — tree selector for modifier groups.
///
/// Renders groups as an expandable tree (group node → option children).
/// SINGLE groups behave as radio lists, MULTIPLE as checkboxes; when
/// [ModifierGroup.maxSelected] is reached, unselected options render
/// disabled. Selection state comes from the parent; the widget only
/// reports toggles through [onToggle].
class ModifierTreeSelector extends StatelessWidget {
  const ModifierTreeSelector({
    super.key,
    required this.groups,
    required this.selection,
    required this.onToggle,
    this.kinds = const {},
  });

  final List<ModifierGroup> groups;

  /// Currently selected option ids per group id.
  final ModifierSelection selection;

  /// Reports a tap on an option: `(groupId, optionId, isNowSelected)`.
  final void Function(String groupId, String optionId, bool selected)
  onToggle;

  /// Optional UI classification per group id.
  final Map<String, ModifierKind> kinds;

  @override
  Widget build(BuildContext context) {
    final sorted = [...groups]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in sorted) ...[
          _ModifierGroupNode(
            key: ValueKey(group.id),
            group: group,
            kind: kinds[group.id] ?? ModifierKind.addon,
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
    required this.kind,
    required this.selectedIds,
    required this.onToggle,
  });

  final ModifierGroup group;
  final ModifierKind kind;
  final Set<String> selectedIds;
  final void Function(String groupId, String optionId, bool selected)
  onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sorted = [...group.items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final maxReached =
        group.maxSelected != null && selectedIds.length >= group.maxSelected!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s12,
              AppSpacing.s12,
              AppSpacing.s12,
              AppSpacing.s4,
            ),
            child: Row(
              children: [
                Icon(kind.icon, size: 20, color: AppColors.gray700),
                const SizedBox(width: AppSpacing.s8),
                Expanded(child: Text(group.name, style: textTheme.titleSmall)),
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
          ),
          for (final option in sorted)
            _ModifierOptionTile(
              option: option,
              singleChoice: group.isSingleChoice,
              selected: selectedIds.contains(option.id),
              enabled:
                  selectedIds.contains(option.id) ||
                  group.isSingleChoice ||
                  !maxReached,
              onTap: () => onToggle(
                group.id,
                option.id,
                !selectedIds.contains(option.id),
              ),
            ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    );
  }
}

class _ModifierOptionTile extends StatelessWidget {
  const _ModifierOptionTile({
    required this.option,
    required this.singleChoice,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ModifierItem option;
  final bool singleChoice;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = option.price;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s4,
          ),
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
      ),
    );
  }
}

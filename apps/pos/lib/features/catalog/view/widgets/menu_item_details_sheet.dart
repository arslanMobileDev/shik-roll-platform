import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../cart/domain/cart_line.dart';
import '../../data/catalog_models.dart';
import 'modifier_tree_selector.dart';

/// Maps a modifier group to its UI kind. Groups are classified by name
/// keywords until the API exposes an explicit kind field.
ModifierKind resolveModifierKind(ModifierGroup group) {
  final name = group.name.toLowerCase();
  if (name.contains('вес') || name.contains('грамм')) {
    return ModifierKind.weight;
  }
  if (name.contains('порци') || name.contains('размер')) {
    return ModifierKind.portion;
  }
  if (name.contains('соус')) {
    return ModifierKind.sauce;
  }
  return ModifierKind.addon;
}

/// Bottom sheet for configuring a menu item before it lands in the cart:
/// modifier tree, validation of required groups, quantity.
class MenuItemDetailsSheet extends StatefulWidget {
  const MenuItemDetailsSheet({
    super.key,
    required this.item,
    required this.onAdd,
  });

  final MenuItem item;

  /// Called with the chosen modifiers when the cashier confirms.
  final void Function(List<SelectedModifier> modifiers) onAdd;

  static Future<void> show(
    BuildContext context, {
    required MenuItem item,
    required void Function(List<SelectedModifier> modifiers) onAdd,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MenuItemDetailsSheet(item: item, onAdd: onAdd),
    );
  }

  @override
  State<MenuItemDetailsSheet> createState() => _MenuItemDetailsSheetState();
}

class _MenuItemDetailsSheetState extends State<MenuItemDetailsSheet> {
  final ModifierSelection _selection = {};

  bool get _isValid {
    for (final group in widget.item.modifierGroups) {
      final count = _selection[group.id]?.length ?? 0;
      if (count < group.minSelected) return false;
      if (group.isRequired && count == 0) return false;
    }
    return true;
  }

  void _toggle(String groupId, String optionId, bool selected) {
    final group = widget.item.modifierGroups.firstWhere(
      (g) => g.id == groupId,
    );
    setState(() {
      final current = {...(_selection[groupId] ?? const <String>{})};
      if (group.isSingleChoice) {
        current
          ..clear()
          ..add(optionId);
      } else if (selected) {
        final max = group.maxSelected;
        if (max == null || current.length < max) current.add(optionId);
      } else {
        current.remove(optionId);
      }
      _selection[groupId] = current;
    });
  }

  List<SelectedModifier> _collectModifiers() {
    return [
      for (final group in widget.item.modifierGroups)
        for (final option in group.items)
          if (_selection[group.id]?.contains(option.id) ?? false)
            SelectedModifier(
              groupId: group.id,
              groupName: group.name,
              optionId: option.id,
              optionName: option.name,
              price: option.price,
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.name, style: textTheme.headlineSmall),
                  ),
                  Text(
                    item.price.effective.format(),
                    style: textTheme.titleLarge,
                  ),
                ],
              ),
              if (item.description != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  item.description!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              ModifierTreeSelector(
                groups: item.modifierGroups,
                kinds: {
                  for (final g in item.modifierGroups)
                    g.id: resolveModifierKind(g),
                },
                selection: _selection,
                onToggle: _toggle,
              ),
              const SizedBox(height: AppSpacing.s16),
              FilledButton.icon(
                onPressed: _isValid
                    ? () {
                        widget.onAdd(_collectModifiers());
                        Navigator.of(context).pop();
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Добавить в заказ'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

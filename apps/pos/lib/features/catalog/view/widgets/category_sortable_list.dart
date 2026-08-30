import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/catalog_models.dart';

/// UI-803 Commerce — category list for the POS catalog rail.
///
/// Selection mode (POS): tap a category to filter the grid.
/// When [onReorder] is provided the list becomes reorderable (Back Office
/// category ordering flow from UI-805); the index becomes `sort_order`.
class CategorySortableList extends StatelessWidget {
  const CategorySortableList({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    this.onReorder,
    this.allLabel = 'Все',
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  /// When set, enables drag-to-reorder and reports the new id order.
  final ValueChanged<List<String>>? onReorder;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final onReorder = this.onReorder;
    if (onReorder != null) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: categories.length,
        // onReorderItem receives newIndex already adjusted for the
        // removed item (no manual decrement needed).
        onReorderItem: (oldIndex, newIndex) {
          final ordered = [for (final c in categories) c.id];
          ordered.insert(newIndex, ordered.removeAt(oldIndex));
          onReorder(ordered);
        },
        itemBuilder: (context, index) {
          final category = categories[index];
          return ReorderableDragStartListener(
            key: ValueKey(category.id),
            index: index,
            child: _CategoryTile(
              key: ValueKey('tile-${category.id}'),
              category: category,
              selected: category.id == selectedCategoryId,
              onTap: () => onSelected(category.id),
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      children: [
        _AllCategoriesTile(
          label: allLabel,
          selected: selectedCategoryId == null,
          onTap: () => onSelected(null),
        ),
        for (final category in categories)
          _CategoryTile(
            key: ValueKey(category.id),
            category: category,
            selected: category.id == selectedCategoryId,
            onTap: () => onSelected(category.id),
          ),
      ],
    );
  }
}

class _AllCategoriesTile extends StatelessWidget {
  const _AllCategoriesTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CategoryTileShell(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.grid_view_rounded, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CategoryTileShell(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            '${category.itemCount}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.gray500),
          ),
        ],
      ),
    );
  }
}

class _CategoryTileShell extends StatelessWidget {
  const _CategoryTileShell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      child: Material(
        color: selected ? colorScheme.primaryContainer : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

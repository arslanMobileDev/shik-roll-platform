import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../bloc/menu_bloc.dart';
import '../../bloc/menu_event.dart';
import '../../data/menu_models.dart';

/// Horizontal ribbon of categories above the product grid.
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({super.key, required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final selected = context.select(
      (MenuBloc bloc) => bloc.state.selectedCategoryId,
    );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        children: [
          _CategoryChip(
            label: 'Все',
            selected: selected == null,
            onTap: () => context.read<MenuBloc>().add(MenuCategorySelected(null)),
          ),
          for (final category in categories)
            _CategoryChip(
              label: category.name,
              selected: selected == category.id,
              onTap: () => context
                  .read<MenuBloc>()
                  .add(MenuCategorySelected(category.id)),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

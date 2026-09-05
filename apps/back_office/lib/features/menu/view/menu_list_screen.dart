import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/menu_catalog_bloc.dart';
import '../bloc/menu_catalog_event.dart';
import '../bloc/menu_catalog_state.dart';
import '../data/models/menu_item.dart';
import 'widgets/menu_item_form_dialog.dart';
import 'widgets/menu_item_table.dart';

/// Catalog manager: category filters + dish table with stop-list switches.
class MenuListScreen extends StatelessWidget {
  const MenuListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<MenuCatalogBloc, MenuCatalogState>(
      listenWhen: (prev, next) => next.notice != null && prev.notice != next.notice,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.notice!)));
        context.read<MenuCatalogBloc>().add(const MenuCatalogNoticeConsumed());
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 16),
            const _CategoryFilters(),
            const SizedBox(height: 16),
            const Expanded(child: _Body()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MenuCatalogBloc>().state;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Меню и блюда', style: Theme.of(context).textTheme.headlineSmall),
            Text(
              '${state.items.length} позиций в каталоге',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          key: const ValueKey('menuList.addItem'),
          onPressed: () => openMenuItemForm(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Новое блюдо'),
        ),
      ],
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters();

  @override
  Widget build(BuildContext context) {
    final selected = context
        .select<MenuCatalogBloc, MenuCategory?>(
          (bloc) => bloc.state.categoryFilter,
        );
    final bloc = context.read<MenuCatalogBloc>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const ValueKey('categoryFilter.all'),
          label: const Text('Все'),
          selected: selected == null,
          onSelected: (_) =>
              bloc.add(const MenuCategoryFilterChanged(null)),
        ),
        for (final category in MenuCategory.values)
          ChoiceChip(
            key: ValueKey('categoryFilter.${category.name}'),
            label: Text(category.label),
            selected: selected == category,
            onSelected: (_) =>
                bloc.add(MenuCategoryFilterChanged(category)),
          ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MenuCatalogBloc>().state;
    switch (state.status) {
      case MenuCatalogStatus.initial:
      case MenuCatalogStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case MenuCatalogStatus.failure:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage ?? 'Ошибка загрузки'),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('menuList.retry'),
                onPressed: () => context.read<MenuCatalogBloc>().add(
                  MenuCatalogRequested(branchId: state.branchId),
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        );
      case MenuCatalogStatus.ready:
        return MenuItemTable(
          items: state.visibleItems,
          pendingItemIds: state.pendingItemIds,
          onToggleStopList: (item) => context.read<MenuCatalogBloc>().add(
            MenuItemStopListToggled(item.id),
          ),
          onEdit: (item) => openMenuItemForm(context, item: item),
        );
    }
  }
}

/// Opens the create/edit dish dialog and dispatches the result.
Future<void> openMenuItemForm(BuildContext context, {MenuItem? item}) async {
  final draft = await MenuItemFormDialog.show(context, initial: item);
  if (draft != null && context.mounted) {
    context.read<MenuCatalogBloc>().add(
      MenuItemSubmitted(draft: draft, editingId: item?.id),
    );
  }
}

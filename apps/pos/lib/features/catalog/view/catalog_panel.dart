import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../cart/domain/cart_line.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../data/catalog_models.dart';
import 'widgets/category_sortable_list.dart';
import 'widgets/menu_item_card.dart';
import 'widgets/menu_item_details_sheet.dart';

/// Catalog panel: category rail, search, HALAL filter and the paged
/// product grid of published items (UI-806 New Order).
class CatalogPanel extends StatefulWidget {
  const CatalogPanel({
    super.key,
    required this.onAddToCart,
    this.showCategoryRail = true,
  });

  /// Called when the cashier confirms adding an item to the cart.
  final void Function(MenuItem item, List<SelectedModifier> modifiers)
  onAddToCart;

  /// Desktop shows categories as a side rail; tablets as a top bar.
  final bool showCategoryRail;

  @override
  State<CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends State<CatalogPanel> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.read<CatalogBloc>().add(CatalogSearchChanged(query));
      }
    });
  }

  void _onItemTap(MenuItem item) {
    if (item.modifierGroups.isEmpty) {
      widget.onAddToCart(item, const []);
      return;
    }
    MenuItemDetailsSheet.show(
      context,
      item: item,
      onAdd: (modifiers) => widget.onAddToCart(item, modifiers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CatalogToolbar(
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
        ),
        const SizedBox(height: AppSpacing.s8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showCategoryRail) ...[
                SizedBox(
                  width: 220,
                  child: BlocBuilder<CatalogBloc, CatalogState>(
                    buildWhen: (p, c) =>
                        p.categories != c.categories ||
                        p.selectedCategoryId != c.selectedCategoryId,
                    builder: (context, state) => CategorySortableList(
                      categories: state.categories,
                      selectedCategoryId: state.selectedCategoryId,
                      onSelected: (id) => context.read<CatalogBloc>().add(
                        CatalogCategorySelected(id),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(),
              ],
              Expanded(child: _CatalogGrid(onItemTap: _onItemTap)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogToolbar extends StatelessWidget {
  const _CatalogToolbar({
    required this.searchController,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Поиск по названию, SKU или составу',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        BlocBuilder<CatalogBloc, CatalogState>(
          buildWhen: (p, c) => p.halalOnly != c.halalOnly,
          builder: (context, state) {
            return Semantics(
              label: 'Фильтр Халяль',
              child: FilterChip(
                avatar: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Халяль'),
                selected: state.halalOnly,
                selectedColor: AppColors.statusHalalContainer,
                onSelected: (selected) => context.read<CatalogBloc>().add(
                  CatalogHalalFilterChanged(selected),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.onItemTap});

  final ValueChanged<MenuItem> onItemTap;

  bool _handleScroll(
    ScrollNotification notification,
    CatalogState state,
    BuildContext context,
  ) {
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels >
            notification.metrics.maxScrollExtent - 240 &&
        state.hasMore &&
        !state.isLoadingMore) {
      context.read<CatalogBloc>().add(const CatalogNextPageRequested());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        switch (state.status) {
          case CatalogStatus.initial:
          case CatalogStatus.loading:
            return const LoadingView(label: 'Загрузка каталога…');
          case CatalogStatus.failure:
            return ErrorView(
              title: 'Не удалось загрузить каталог',
              message: state.errorMessage,
              onRetry: () =>
                  context.read<CatalogBloc>().add(const CatalogRefreshed()),
            );
          case CatalogStatus.loaded:
            if (state.items.isEmpty) {
              return EmptyView(
                title: 'Ничего не найдено',
                message: state.halalOnly || state.searchQuery.isNotEmpty
                    ? 'Попробуйте изменить фильтры или запрос'
                    : 'В категории пока нет опубликованных позиций',
                icon: Icons.restaurant_menu_outlined,
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (n) => _handleScroll(n, state, context),
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.s12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: AppSpacing.s12,
                  crossAxisSpacing: AppSpacing.s12,
                  mainAxisExtent: 190,
                ),
                itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.items.length) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  final item = state.items[index];
                  return MenuItemCard(item: item, onTap: onItemTap);
                },
              ),
            );
        }
      },
    );
  }
}

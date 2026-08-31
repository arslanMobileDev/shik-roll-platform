import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../features/cart/bloc/cart_event.dart';
import '../../../features/cart/bloc/customer_cart_bloc.dart';
import '../bloc/menu_bloc.dart';
import '../bloc/menu_event.dart';
import '../bloc/menu_state.dart';
import '../data/menu_models.dart';
import 'widgets/category_strip.dart';
import 'widgets/menu_item_card.dart';
import 'widgets/order_type_toggle.dart';
import 'widgets/product_details/product_details_view.dart';

/// Guest menu showcase: delivery/pickup toggle, category ribbon and the
/// product grid.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s4,
            ),
            child: OrderTypeToggle(),
          ),
          BlocBuilder<MenuBloc, MenuState>(
            builder: (context, state) {
              switch (state.status) {
                case MenuStatus.loading:
                  return const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  );
                case MenuStatus.failure:
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Не удалось загрузить меню',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          FilledButton.tonal(
                            onPressed: () => context
                                .read<MenuBloc>()
                                .add(MenuRefreshed()),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  );
                case MenuStatus.loaded:
                  return Expanded(
                    child: _MenuContent(
                      categories: state.categories,
                      items: state.items,
                      selectedCategoryId: state.selectedCategoryId,
                    ),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MenuContent extends StatelessWidget {
  const _MenuContent({
    required this.categories,
    required this.items,
    required this.selectedCategoryId,
  });

  final List<Category> categories;
  final List<MenuItem> items;
  final String? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        context.read<MenuBloc>().add(MenuRefreshed());
        return Future.value();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                CategoryStrip(categories: categories),
                const SizedBox(height: AppSpacing.s12),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.s12,
                mainAxisSpacing: AppSpacing.s12,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  return MenuItemCard(
                    item: item,
                    onAddToCart: () {
                      context.read<CustomerCartBloc>().add(
                        CartItemAdded(item: item),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item.name} — в корзине')),
                      );
                    },
                    onSelect: () => showProductDetails(context, item),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

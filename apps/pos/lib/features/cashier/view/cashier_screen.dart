import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/pos_config.dart';
import '../../../core/config/pos_context_cubit.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/context_selectors.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../cart/bloc/cart_event.dart';
import '../../cart/bloc/cart_state.dart';
import '../../cart/view/cart_panel.dart';
import '../../catalog/bloc/catalog_bloc.dart';
import '../../catalog/bloc/catalog_event.dart';
import '../../catalog/view/catalog_panel.dart';
import '../../tables/bloc/order_mode_cubit.dart';
import '../../tables/view/order_mode_selector.dart';

/// Cashier screen (UI-806 New Order), desktop-first:
///
/// - ≥1280 px — category rail, wide product grid, fixed cart panel;
/// - 1024–1279 px — same layout, compact cart panel;
/// - <1024 px — tablet fallback: catalog full width, cart via sheet.
class CashierScreen extends StatelessWidget {
  const CashierScreen({super.key, this.onCheckout});

  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PosContextCubit, PosContextState>(
      listenWhen: (previous, current) => previous != current,
      listener: (context, contextState) {
        context.read<CatalogBloc>().add(
          CatalogStarted(
            brandId: contextState.brandId,
            branchId: contextState.branchId,
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isCompact = width < AppBreakpoints.tablet;
          return Scaffold(
            appBar: const _CashierAppBar(),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: CatalogPanel(
                      showCategoryRail: !isCompact,
                      onAddToCart: (item, modifiers) {
                        context.read<CartBloc>().add(
                          CartItemAdded(item: item, modifiers: modifiers),
                        );
                      },
                    ),
                  ),
                ),
                if (!isCompact)
                  Container(
                    width: AppBreakpoints.isDesktop(width) ? 400 : 340,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        left: BorderSide(color: AppColors.gray200),
                      ),
                    ),
                    child: CartPanel(onCheckout: onCheckout),
                  ),
              ],
            ),
            floatingActionButton: isCompact
                ? TabletCartButton(onCheckout: onCheckout)
                : null,
          );
        },
      ),
    );
  }
}

/// Cart access for the tablet layout (<1024 px).
class TabletCartButton extends StatelessWidget {
  const TabletCartButton({super.key, this.onCheckout});

  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        return FloatingActionButton.extended(
          onPressed: () => _showCartSheet(context),
          icon: Badge(
            isLabelVisible: state.itemCount > 0,
            label: Text('${state.itemCount}'),
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          label: Text(state.total.format()),
        );
      },
    );
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<CartBloc>()),
            BlocProvider.value(value: context.read<OrderModeCubit>()),
          ],
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: CartPanel(onCheckout: onCheckout),
          ),
        );
      },
    );
  }
}

class _CashierAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CashierAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpacing.s16,
      title: BlocBuilder<PosContextCubit, PosContextState>(
        builder: (context, contextState) {
          return Row(
            children: [
              BrandSelector(
                brands: PosDirectory.brands,
                selectedBrandId: contextState.brandId,
                onChanged: (id) =>
                    context.read<PosContextCubit>().selectBrand(id),
              ),
              const SizedBox(width: AppSpacing.s4),
              BranchSelector(
                branches: PosDirectory.branches,
                selectedBranchId: contextState.branchId,
                onChanged: (id) =>
                    context.read<PosContextCubit>().selectBranch(id),
              ),
            ],
          );
        },
      ),
      actions: const [
        OrderModeSelector(),
        SizedBox(width: AppSpacing.s16),
      ],
    );
  }
}

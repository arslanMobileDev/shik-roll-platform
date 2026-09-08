import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/money.dart';
import '../../../../../core/widgets/halal_status_badge.dart';
import '../../../../cart/bloc/cart_event.dart';
import '../../../../cart/bloc/customer_cart_bloc.dart';
import '../../../../loyalty/bloc/loyalty_cubit.dart';
import '../../../../loyalty/domain/bonus_math.dart';
import '../../../data/menu_models.dart';
import 'modifier_selector.dart';
import 'product_details_cubit.dart';

/// Body of the product-details bottom sheet.
///
/// Exposes a value-keyed add-to-cart button for widget tests; selection and
/// total math live in [ProductDetailsCubit]. [cashbackRate] (ADR-1614, %)
/// drives the «+X бонусов при заказе» badge; 0 hides it.
class ProductDetailsView extends StatelessWidget {
  ProductDetailsView({super.key, required this.item, this.cashbackRate = 0})
    : cubit = ProductDetailsCubit(item);

  final MenuItem item;

  /// Cashback rate in percent for the bonus-earn badge preview.
  final double cashbackRate;

  /// Owned cubit instance (avoids creating it in BlocProvider builder).
  final ProductDetailsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductDetailsCubit>.value(
      value: cubit,
      child: _ProductDetailsContent(item: item, cashbackRate: cashbackRate),
    );
  }
}

class _ProductDetailsContent extends StatelessWidget {
  const _ProductDetailsContent({
    required this.item,
    required this.cashbackRate,
  });

  final MenuItem item;
  final double cashbackRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Padding header(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: child,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeArea(
          child: Container(
            margin: const EdgeInsets.only(top: AppSpacing.s8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray400,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.s12),
                      // Photo placeholder
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant_outlined,
                            size: 48,
                            color: AppColors.gray400,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          HalalStatusBadge(isHalal: item.isHalal),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      if (item.description != null)
                        Text(
                          item.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.gray700,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        _infoLine(item),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                    ],
                  ),
                ),
                header(
                  ModifierSelector(
                    groups: item.modifierGroups,
                    onToggle: context.read<ProductDetailsCubit>().toggleOption,
                    selection: context
                        .watch<ProductDetailsCubit>()
                        .state
                        .selection,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
              builder: (context, state) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BonusEarnBadge(
                      totalPrice: state.totalPrice,
                      cashbackRate: cashbackRate,
                    ),
                    FilledButton(
                      key: const ValueKey('add-to-cart-button'),
                      onPressed: state.isValid
                          ? () {
                              context.read<CustomerCartBloc>().add(
                                CartItemAdded(
                                  item: item,
                                  selection: state.selection,
                                ),
                              );
                              // Show the snackbar before popping: after pop()
                              // this context is deactivated and ancestor lookup
                              // would throw.
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Добавлено в корзину'),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          : null,
                      child: Text(
                        'Добавить в корзину за ${state.totalPrice.format()}',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static String _infoLine(MenuItem item) {
    final parts = <String>[
      if (item.weight != null) '${item.weight} г',
      if (item.calories != null) '${item.calories} ккал',
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

/// «+X бонусов при заказе» (ADR-1614): превью кешбэка от текущей суммы с
/// модификаторами. Скрыт, пока ставка неизвестна или начисление равно 0.
class _BonusEarnBadge extends StatelessWidget {
  const _BonusEarnBadge({required this.totalPrice, required this.cashbackRate});

  final Money totalPrice;
  final double cashbackRate;

  @override
  Widget build(BuildContext context) {
    final points = cashbackPointsFor(totalPrice, cashbackRate);
    if (points <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: DecoratedBox(
        key: const ValueKey('bonus-earn-badge'),
        decoration: BoxDecoration(
          color: AppColors.warningContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  '+$points бонусов при заказе',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the product sheet.
///
/// The sheet's route is pushed onto the Navigator above the shell's
/// `MultiBlocProvider`, so the sheet's own context cannot see the app-wide
/// blocs. Capture [CustomerCartBloc] from the caller and re-provide it
/// inside the sheet for the add-to-cart button.
void showProductDetails(BuildContext context, MenuItem item) {
  final cartBloc = context.read<CustomerCartBloc>();
  // Cashback rate for the «+X бонусов» badge (ADR-1614); the loyalty cubit
  // is absent in isolated tests — then the badge stays hidden.
  var cashbackRate = 0.0;
  try {
    cashbackRate = context.read<LoyaltyCubit>().state.cashbackRate;
  } on ProviderNotFoundException {
    cashbackRate = 0;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => BlocProvider<CustomerCartBloc>.value(
      value: cartBloc,
      child: ProductDetailsView(item: item, cashbackRate: cashbackRate),
    ),
  );
}

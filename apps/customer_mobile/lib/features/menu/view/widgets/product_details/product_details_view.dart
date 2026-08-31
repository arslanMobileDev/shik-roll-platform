import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/halal_status_badge.dart';
import '../../../../cart/bloc/cart_event.dart';
import '../../../../cart/bloc/customer_cart_bloc.dart';
import '../../../data/menu_models.dart';
import 'modifier_selector.dart';
import 'product_details_cubit.dart';

/// Body of the product-details bottom sheet.
///
/// Exposes a value-keyed add-to-cart button for widget tests; selection and
/// total math live in [ProductDetailsCubit].
class ProductDetailsView extends StatelessWidget {
  ProductDetailsView({super.key, required this.item})
    : cubit = ProductDetailsCubit(item);

  final MenuItem item;

  /// Owned cubit instance (avoids creating it in BlocProvider builder).
  final ProductDetailsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductDetailsCubit>.value(
      value: cubit,
      child: _ProductDetailsContent(item: item),
    );
  }
}

class _ProductDetailsContent extends StatelessWidget {
  const _ProductDetailsContent({required this.item});

  final MenuItem item;

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
                    onToggle: context
                        .read<ProductDetailsCubit>()
                        .toggleOption,
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
                return FilledButton(
                  key: const ValueKey('add-to-cart-button'),
                  onPressed: state.isValid
                      ? () {
                          context.read<CustomerCartBloc>().add(
                            CartItemAdded(
                              item: item,
                              selection: state.selection,
                            ),
                          );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Добавлено в корзину'),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    'Добавить в корзину за ${state.totalPrice.format()}',
                  ),
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

/// Opens the product sheet.
void showProductDetails(BuildContext context, MenuItem item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ProductDetailsView(item: item),
  );
}

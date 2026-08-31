import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/money.dart';
import '../../../data/menu_models.dart';

/// Current modifier selection: modifier group id → selected option ids.
typedef ModifierSelection = Map<String, Set<String>>;

final class ProductDetailsState extends Equatable {
  const ProductDetailsState({
    required this.selection,
    required this.isValid,
    required this.totalPrice,
  });

  final ModifierSelection selection;

  /// True when every required group satisfies `minSelected`.
  final bool isValid;

  /// Base price plus the surcharge of all selected modifiers.
  final Money totalPrice;

  @override
  List<Object?> get props => [selection, isValid, totalPrice];
}

/// Business logic of the product-details sheet: validator + total
/// recalculation. Widgets only dispatch [toggleOption].
class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  ProductDetailsCubit(this._item) : super(_initial(_item));

  final MenuItem _item;

  static ProductDetailsState _initial(MenuItem item) {
    final preselected = <String, Set<String>>{
      for (final group in item.modifierGroups)
        if (group.isRequired && group.isSingleChoice && group.items.isNotEmpty)
          group.id: {group.items.first.id},
    };
    return _compute(item, preselected);
  }

  void toggleOption(String groupId, String optionId, bool selected) {
    final group = _item.modifierGroups.firstWhere((g) => g.id == groupId);
    final next = <String, Set<String>>{
      for (final entry in state.selection.entries)
        entry.key: {...entry.value},
    };
    if (group.isSingleChoice) {
      // Radio semantics: tap selects, re-tap on selected option is ignored.
      if (!selected) return;
      next[groupId] = {optionId};
    } else {
      final current = next[groupId] ?? <String>{};
      if (selected) {
        final max = group.maxSelected;
        if (max != null && current.length >= max && !current.contains(optionId)) {
          return; // ignore selections past maxSelected
        }
        current.add(optionId);
      } else {
        current.remove(optionId);
      }
      next[groupId] = current;
    }
    emit(_compute(_item, next));
  }

  static ProductDetailsState _compute(MenuItem item, ModifierSelection sel) {
    var total = item.price;
    var valid = true;
    for (final group in item.modifierGroups) {
      final selectedIds = sel[group.id] ?? const <String>{};
      for (final option in group.items) {
        if (selectedIds.contains(option.id)) {
          total = total + option.price;
        }
      }
      if (group.isRequired && selectedIds.length < group.minSelected) {
        valid = false;
      }
    }
    return ProductDetailsState(
      selection: sel,
      isValid: valid,
      totalPrice: total,
    );
  }
}

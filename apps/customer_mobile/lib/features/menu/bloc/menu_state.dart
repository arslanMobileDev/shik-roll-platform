import 'package:equatable/equatable.dart';

import '../data/menu_models.dart';

enum MenuStatus { loading, loaded, failure }

final class MenuState extends Equatable {
  const MenuState({
    this.status = MenuStatus.loading,
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.errorMessage,
  });

  final MenuStatus status;
  final List<Category> categories;
  final List<MenuItem> items;
  final String? selectedCategoryId;
  final String? errorMessage;

  MenuState copyWith({
    MenuStatus? status,
    List<Category>? categories,
    List<MenuItem>? items,
    String? selectedCategoryId,
    String? errorMessage,
  }) {
    return MenuState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    items,
    selectedCategoryId,
    errorMessage,
  ];
}

sealed class MenuEvent {}

final class MenuStarted extends MenuEvent {}

final class MenuCategorySelected extends MenuEvent {
  MenuCategorySelected(this.categoryId);

  /// Null means "all categories".
  final String? categoryId;
}

final class MenuRefreshed extends MenuEvent {}

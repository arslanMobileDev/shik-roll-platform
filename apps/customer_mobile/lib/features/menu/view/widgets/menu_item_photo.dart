import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Dish photo for the menu card and the product sheet.
///
/// Falls back to the restaurant-icon placeholder when the URL is missing or
/// empty, while the photo loads, and when the request fails (404 / offline) —
/// the card must never end up as an empty box.
class MenuItemPhoto extends StatelessWidget {
  const MenuItemPhoto({super.key, required this.imageUrl, this.iconSize = 36});

  final String? imageUrl;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url == null || url.isEmpty
          ? _Placeholder(iconSize: iconSize)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _Placeholder(iconSize: iconSize),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _Placeholder(iconSize: iconSize),
            ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.gray100,
      child: Center(
        child: Icon(
          Icons.restaurant_outlined,
          size: iconSize,
          color: AppColors.gray400,
        ),
      ),
    );
  }
}

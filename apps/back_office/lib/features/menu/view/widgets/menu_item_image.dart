import 'package:flutter/material.dart';

/// Dish photo preview with graceful placeholder for missing/failed URLs.
class MenuItemImage extends StatelessWidget {
  const MenuItemImage({super.key, required this.imageUrl, this.size = 44});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? const _ImagePlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ImagePlaceholder(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _ImagePlaceholder(),
              ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF0E9E4),
      child: Icon(
        Icons.restaurant_rounded,
        color: Colors.brown.shade200,
        size: 22,
      ),
    );
  }
}

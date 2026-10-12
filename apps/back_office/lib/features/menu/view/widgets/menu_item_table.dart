import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/menu_item.dart';
import 'menu_item_image.dart';

/// Catalog positions with quick stop-list switches — a table on desktop,
/// stacked cards on phones.
class MenuItemTable extends StatelessWidget {
  const MenuItemTable({
    super.key,
    required this.items,
    required this.pendingItemIds,
    required this.onToggleStopList,
    required this.onEdit,
  });

  final List<MenuItem> items;
  final Set<String> pendingItemIds;
  final ValueChanged<MenuItem> onToggleStopList;
  final ValueChanged<MenuItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)) {
      if (items.isEmpty) return const Center(child: Text('Позиции не найдены'));
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _MenuItemCard(
          item: items[index],
          isPending: pendingItemIds.contains(items[index].id),
          onToggleStopList: onToggleStopList,
          onEdit: onEdit,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 60),
                Expanded(
                  flex: 3,
                  child: Text('Блюдо', style: textTheme.bodySmall),
                ),
                Expanded(child: Text('Категория', style: textTheme.bodySmall)),
                SizedBox(
                  width: 110,
                  child: Text('Цена', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 110,
                  child: Text('Доступность', style: textTheme.bodySmall),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Позиции не найдены'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) => _MenuItemRow(
                      item: items[index],
                      isPending: pendingItemIds.contains(items[index].id),
                      onToggleStopList: onToggleStopList,
                      onEdit: onEdit,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
    required this.isPending,
    required this.onToggleStopList,
    required this.onEdit,
  });

  final MenuItem item;
  final bool isPending;
  final ValueChanged<MenuItem> onToggleStopList;
  final ValueChanged<MenuItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stopped = !item.isAvailable;
    return Container(
      color: stopped ? AppColors.stopListBg : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: MenuItemImage(imageUrl: item.imageUrl),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isHalal) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.halalGreen,
                      ),
                    ],
                  ],
                ),
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(child: _CategoryChip(name: item.categoryName)),
          SizedBox(
            width: 110,
            child: Text(
              item.price.format(),
              style: textTheme.titleMedium,
            ),
          ),
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Switch(
                  key: ValueKey('stopListSwitch-${item.id}'),
                  value: item.isAvailable,
                  onChanged: isPending ? null : (_) => onToggleStopList(item),
                ),
                if (stopped)
                  Text(
                    'Стоп',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: IconButton(
              key: ValueKey('editItem-${item.id}'),
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => onEdit(item),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone layout of [_MenuItemRow]: same data, same keys, stacked.
class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.isPending,
    required this.onToggleStopList,
    required this.onEdit,
  });

  final MenuItem item;
  final bool isPending;
  final ValueChanged<MenuItem> onToggleStopList;
  final ValueChanged<MenuItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stopped = !item.isAvailable;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: stopped ? AppColors.stopListBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuItemImage(imageUrl: item.imageUrl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isHalal) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.halalGreen,
                      ),
                    ],
                  ],
                ),
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    style: textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(child: _CategoryChip(name: item.categoryName)),
                    const SizedBox(width: 8),
                    Text(item.price.format(), style: textTheme.titleMedium),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Text(
                      stopped ? 'Стоп' : 'В наличии',
                      style: textTheme.bodySmall?.copyWith(
                        color: stopped ? AppColors.danger : null,
                        fontWeight: stopped ? FontWeight.w700 : null,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      key: ValueKey('stopListSwitch-${item.id}'),
                      value: item.isAvailable,
                      onChanged: isPending
                          ? null
                          : (_) => onToggleStopList(item),
                    ),
                    IconButton(
                      key: ValueKey('editItem-${item.id}'),
                      tooltip: 'Редактировать',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => onEdit(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.scaffold,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.ink),
        ),
      ),
    );
  }
}

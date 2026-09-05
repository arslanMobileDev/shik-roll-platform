import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/menu_catalog_bloc.dart';
import '../bloc/menu_catalog_event.dart';
import '../bloc/menu_catalog_state.dart';
import 'menu_list_screen.dart' show openMenuItemForm;
import 'widgets/menu_item_table.dart';

/// Stop-list view: catalog positions currently unavailable at the branch.
class StopListScreen extends StatelessWidget {
  const StopListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MenuCatalogBloc>().state;
    final stopped = state.stoppedItems;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Стоп-листы', style: Theme.of(context).textTheme.headlineSmall),
          Text(
            '${stopped.length} позиций снято с продажи на активной точке',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.status == MenuCatalogStatus.ready
                ? stopped.isEmpty
                      ? const Center(
                          child: Text('Стоп-лист пуст — все блюда доступны'),
                        )
                      : MenuItemTable(
                          items: stopped,
                          pendingItemIds: state.pendingItemIds,
                          onToggleStopList: (item) => context
                              .read<MenuCatalogBloc>()
                              .add(MenuItemStopListToggled(item.id)),
                          onEdit: (item) =>
                              openMenuItemForm(context, item: item),
                        )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

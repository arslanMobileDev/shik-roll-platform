import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/halal_badge.dart';
import '../../../core/widgets/shik_roll_logo.dart';
import '../bloc/branch_cubit.dart';
import 'branch_selector.dart';

/// Sidebar destinations of the Back Office.
enum BackOfficeSection {
  menu('Меню и блюда', Icons.restaurant_menu_rounded),
  stopLists('Стоп-листы', Icons.block_rounded),
  cookShifts('Смены кухни', Icons.soup_kitchen_rounded),
  branchSettings('Настройки точки', Icons.store_mall_directory_outlined);

  const BackOfficeSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// App frame: dark sidebar + light top bar + section content.
/// Desktop-first; the sidebar collapses to icons below 1280px.
class BackOfficeShell extends StatefulWidget {
  const BackOfficeShell({
    super.key,
    required this.sectionBuilder,
  });

  /// Builds the content widget for a section (keeps shell independent
  /// from feature screens for easy testing).
  final Widget Function(BackOfficeSection section) sectionBuilder;

  @override
  State<BackOfficeShell> createState() => _BackOfficeShellState();
}

class _BackOfficeShellState extends State<BackOfficeShell> {
  BackOfficeSection _section = BackOfficeSection.menu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            active: _section,
            onSelected: (section) => setState(() => _section = section),
          ),
          Expanded(
            child: Column(
              children: [
                BackOfficeTopBar(title: _section.label),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: KeyedSubtree(
                      key: ValueKey(_section),
                      child: widget.sectionBuilder(_section),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Light top bar: active branch selector + Halal compliance badge.
class BackOfficeTopBar extends StatelessWidget {
  const BackOfficeTopBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          const BranchSelector(),
          const SizedBox(width: 12),
          const HalalBadge(),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.active, required this.onSelected});

  final BackOfficeSection active;
  final ValueChanged<BackOfficeSection> onSelected;

  static const double _expandedWidth = 264;
  static const double _collapsedWidth = 76;
  static const double _desktopBreakpoint = 1280;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded =
            MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: expanded ? _expandedWidth : _collapsedWidth,
          color: AppColors.sidebar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 20 : 0,
                  vertical: 20,
                ),
                child: expanded
                    ? const ShikRollLogo()
                    : const Center(
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.terracotta,
                          child: Text(
                            'SR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
              ),
              const Divider(color: Color(0xFF3A2F2A)),
              const SizedBox(height: 8),
              for (final section in BackOfficeSection.values)
                _SidebarItem(
                  section: section,
                  expanded: expanded,
                  selected: section == active,
                  onTap: () => onSelected(section),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: expanded
                    ? BlocBuilder<BranchCubit, Branch>(
                        builder: (context, branch) => Text(
                          branch.name,
                          style: const TextStyle(
                            color: Color(0xFF8A7D76),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF8A7D76),
                        size: 18,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final BackOfficeSection section;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.terracotta : const Color(0xFFB8ACA4);
    final tile = InkWell(
      key: ValueKey('sidebar.${section.name}'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 12 : 0,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.sidebarActive : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(section.icon, color: color, size: 20),
            if (expanded) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (expanded) return tile;
    return Tooltip(message: section.label, child: tile);
  }
}

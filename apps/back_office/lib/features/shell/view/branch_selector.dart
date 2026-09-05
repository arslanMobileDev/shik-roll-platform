import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../branch_settings/bloc/branch_settings_cubit.dart';
import '../../../core/theme/app_theme.dart';
import '../../cook_shifts/bloc/cook_shifts_cubit.dart';
import '../../menu/bloc/menu_catalog_bloc.dart';
import '../../menu/bloc/menu_catalog_event.dart';
import '../bloc/branch_cubit.dart';

/// Top bar dropdown with the active branch. Switching the branch
/// reloads the catalog and the branch settings.
class BranchSelector extends StatelessWidget {
  const BranchSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.watch<BranchCubit>().state;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Branch>(
          key: const ValueKey('branchSelector'),
          value: active,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            for (final branch in BranchCubit.branches)
              DropdownMenuItem(
                value: branch,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(width: 8),
                    Text(branch.name),
                  ],
                ),
              ),
          ],
          onChanged: (branch) {
            if (branch == null || branch == active) return;
            context.read<BranchCubit>().select(branch);
            context.read<BranchSettingsCubit>().selectBranch(branch.id);
            context.read<MenuCatalogBloc>().add(
              MenuCatalogRequested(branchId: branch.id),
            );
            context.read<CookShiftsCubit>().load(branch.id);
          },
        ),
      ),
    );
  }
}

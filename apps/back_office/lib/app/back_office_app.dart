import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../features/branch_settings/bloc/branch_settings_cubit.dart';
import '../features/branch_settings/view/branch_settings_screen.dart';
import '../features/cook_shifts/bloc/cook_shifts_cubit.dart';
import '../features/cook_shifts/data/cook_shifts_repository.dart';
import '../features/cook_shifts/view/cook_shifts_screen.dart';
import '../features/menu/bloc/menu_catalog_bloc.dart';
import '../features/menu/bloc/menu_catalog_event.dart';
import '../features/menu/data/back_office_repository.dart';
import '../features/menu/view/menu_list_screen.dart';
import '../features/menu/view/stop_list_screen.dart';
import '../features/shell/bloc/branch_cubit.dart';
import '../features/shell/view/back_office_shell.dart';

/// SHIK ROLL Back Office root widget (Flutter Web, ADR-1600 / UI-805).
class BackOfficeApp extends StatelessWidget {
  const BackOfficeApp({
    super.key,
    required this.repository,
    required this.cookShiftsRepository,
  });

  final BackOfficeRepository repository;
  final CookShiftsRepository cookShiftsRepository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<BackOfficeRepository>.value(
      value: repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => BranchCubit()),
          BlocProvider(
            create: (_) =>
                MenuCatalogBloc(repository: repository)..add(
                  MenuCatalogRequested(branchId: BranchCubit.branches.first.id),
                ),
          ),
          BlocProvider(
            create: (_) => BranchSettingsCubit()
              ..selectBranch(BranchCubit.branches.first.id),
          ),
          BlocProvider(
            create: (_) => CookShiftsCubit(repository: cookShiftsRepository)
              ..load(BranchCubit.branches.first.id),
          ),
        ],
        child: MaterialApp(
          title: 'SHIK ROLL · Back Office',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: BackOfficeShell(
            sectionBuilder: (section) => switch (section) {
              BackOfficeSection.menu => const MenuListScreen(),
              BackOfficeSection.stopLists => const StopListScreen(),
              BackOfficeSection.cookShifts => const CookShiftsScreen(),
              BackOfficeSection.branchSettings => const BranchSettingsScreen(),
            },
          ),
        ),
      ),
    );
  }
}

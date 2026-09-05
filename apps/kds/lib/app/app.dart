import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config/kds_config.dart';
import '../core/theme/app_theme.dart';
import '../features/kds/bloc/kds_orders_bloc.dart';
import '../features/kds/bloc/kds_orders_event.dart';
import '../features/kds/data/kds_orders_repository.dart';
import '../features/kds/view/kds_screen.dart';
import '../features/shift/bloc/cook_shift_cubit.dart';
import '../features/shift/data/cook_shift_repository.dart';
import 'injection.dart';

/// SHIK Platform KDS — kitchen display system (UI-804).
class KdsApp extends StatelessWidget {
  KdsApp({
    super.key,
    KdsOrdersRepository? ordersRepository,
    CookShiftRepository? cookShiftRepository,
  }) : _ordersRepository = ordersRepository ?? getIt<KdsOrdersRepository>(),
       _cookShiftRepository =
           cookShiftRepository ?? getIt<CookShiftRepository>();

  final KdsOrdersRepository _ordersRepository;
  final CookShiftRepository _cookShiftRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => KdsOrdersBloc(
            repository: _ordersRepository,
            pollInterval: KdsConfig.pollInterval,
          )..add(const KdsOrdersStarted(branchId: KdsConfig.defaultBranchId)),
        ),
        BlocProvider(
          create: (_) =>
              CookShiftCubit(repository: _cookShiftRepository)
                ..load(KdsConfig.defaultBranchId),
        ),
      ],
      child: MaterialApp(
        title: 'SHIK KDS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const KdsScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config/kds_config.dart';
import '../core/theme/app_theme.dart';
import '../features/kds/bloc/kds_orders_bloc.dart';
import '../features/kds/bloc/kds_orders_event.dart';
import '../features/kds/data/kds_orders_repository.dart';
import '../features/kds/view/kds_screen.dart';
import 'injection.dart';

/// SHIK Platform KDS — kitchen display system (UI-804).
class KdsApp extends StatelessWidget {
  KdsApp({super.key, KdsOrdersRepository? ordersRepository})
    : _ordersRepository = ordersRepository ?? getIt<KdsOrdersRepository>();

  final KdsOrdersRepository _ordersRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => KdsOrdersBloc(
        repository: _ordersRepository,
        pollInterval: KdsConfig.pollInterval,
      )..add(const KdsOrdersStarted(branchId: KdsConfig.defaultBranchId)),
      child: MaterialApp(
        title: 'SHIK KDS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const KdsScreen(),
      ),
    );
  }
}

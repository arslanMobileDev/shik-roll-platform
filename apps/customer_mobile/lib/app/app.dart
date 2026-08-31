import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/menu/data/menu_repository.dart';
import '../features/shell/home_shell.dart';

/// Root widget; theme and startup route for the guest app.
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key, required this.repository});

  final CustomerMenuRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHIK ROLL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeShell(repository: repository),
    );
  }
}

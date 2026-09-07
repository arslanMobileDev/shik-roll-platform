import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/orders/presentation/screens/order_tracking_screen.dart';
import 'features/profile/bloc/user_settings_cubit.dart';
import 'features/profile/data/user_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final userSettingsRepository = SharedPreferencesUserSettingsRepository(
    await SharedPreferences.getInstance(),
  );
  runApp(TrackerPreviewApp(userSettingsRepository: userSettingsRepository));
}

class TrackerPreviewApp extends StatelessWidget {
  const TrackerPreviewApp({super.key, required this.userSettingsRepository});

  final UserSettingsRepository userSettingsRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserSettingsCubit>(
      lazy: false,
      create: (_) => UserSettingsCubit(userSettingsRepository)..load(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SHIK-ROLL Tracking Preview',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          fontFamily: 'Roboto',
        ),
        home: const OrderTrackingScreen(),
      ),
    );
  }
}

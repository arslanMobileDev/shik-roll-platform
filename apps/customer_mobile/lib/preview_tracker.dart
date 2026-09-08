import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/orders/data/order_tracking_repository.dart';
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
        home: OrderTrackingScreen(
          orderId: 'demo-order',
          orderNumber: 'DL-4820',
          trackingRepository: FakeOrderTrackingRepository(
            latency: const Duration(milliseconds: 500),
            stepDelay: const Duration(seconds: 5),
          ),
          deliveryAddress: 'ул. Ленина, д. 42, кв. 15',
          items: const [
            {'name': 'Филадельфия Классик', 'count': 2, 'price': 980},
            {'name': 'Калифорния с крабом', 'count': 1, 'price': 420},
            {'name': 'Морс клюквенный 0.5л', 'count': 1, 'price': 150},
          ],
          totalPrice: 1550,
        ),
      ),
    );
  }
}

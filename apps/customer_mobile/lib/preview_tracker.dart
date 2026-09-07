import 'package:flutter/material.dart';
import 'features/orders/presentation/screens/order_tracking_screen.dart';

void main() {
  runApp(const TrackerPreviewApp());
}

class TrackerPreviewApp extends StatelessWidget {
  const TrackerPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHIK-ROLL Tracking Preview',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
      ),
      home: const OrderTrackingScreen(),
    );
  }
}

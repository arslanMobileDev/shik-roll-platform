import 'package:courier_mobile/app.dart';
import 'package:courier_mobile/core/storage/courier_auth_storage.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/auth/view/courier_login_screen.dart';
import 'package:courier_mobile/features/orders/view/courier_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<CourierApp> buildApp() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return CourierApp(
    repository: FakeCourierRepository(),
    storage: CourierAuthStorage(prefs),
  );
}

void main() {
  testWidgets('login screen renders phone, PIN, branch and Halal badge',
      (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byType(CourierLoginScreen), findsOneWidget);
    expect(find.text('SHIK ROLL'), findsOneWidget);
    expect(find.text('100% Halal'), findsOneWidget);
    expect(find.byKey(const Key('login_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('login_pin_field')), findsOneWidget);
    expect(find.byKey(const Key('login_branch_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
  });

  testWidgets('invalid PIN shows validation error and stays on login',
      (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_phone_field')),
      '+79171234567',
    );
    await tester.enterText(find.byKey(const Key('login_pin_field')), '12');
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('PIN — 4 цифры'), findsOneWidget);
    expect(find.byType(CourierLoginScreen), findsOneWidget);
    expect(find.byType(CourierOrdersScreen), findsNothing);
  });

  testWidgets('successful PIN login navigates to orders screen',
      (tester) async {
    final app = await buildApp();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_phone_field')),
      '+79171234567',
    );
    await tester.enterText(find.byKey(const Key('login_pin_field')), '1234');
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(CourierOrdersScreen), findsOneWidget);
    expect(find.byKey(const Key('orders_tab_switcher')), findsOneWidget);
  });
}

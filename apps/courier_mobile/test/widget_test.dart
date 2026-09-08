import 'package:courier_mobile/app.dart';
import 'package:courier_mobile/core/storage/courier_auth_storage.dart';
import 'package:courier_mobile/core/storage/courier_token_storage.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/auth/view/courier_login_screen.dart';
import 'package:courier_mobile/features/location/data/courier_location_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_fakes.dart';

void main() {
  testWidgets('app starts on the login screen when no session is stored', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      CourierApp(
        repository: FakeCourierRepository(),
        locationRepository: FakeCourierLocationRepository(),
        storage: CourierAuthStorage(prefs),
        tokenStorage: InMemoryCourierTokenStorage(),
        locationSource: FakeLocationSource(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CourierLoginScreen), findsOneWidget);
  });
}

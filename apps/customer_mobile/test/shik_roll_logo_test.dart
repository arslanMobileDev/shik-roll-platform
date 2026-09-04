import 'package:customer_mobile/core/theme/app_colors.dart';
import 'package:customer_mobile/core/widgets/shik_roll_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('логотип: «SHIK» белым, «ROLL» терракотовым, бейдж HALAL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShikRollLogo())),
    );

    final logo = tester.widget<Text>(
      find.byKey(const ValueKey('shik-roll-logo')),
    );
    final span = logo.textSpan! as TextSpan;
    final children = span.children!.cast<TextSpan>();

    expect(children[0].text, 'SHIK ');
    expect(children[0].style?.color, AppColors.onPrimary);
    expect(children[1].text, 'ROLL');
    expect(children[1].style?.color, AppColors.brandAccent);
    expect(AppColors.brandAccent, const Color(0xFFFF5722));

    // Бейдж Halal рядом с логотипом.
    expect(find.text('HALAL'), findsOneWidget);
  });
}

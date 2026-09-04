import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Legal documents referenced across the guest app (checkout, auth,
/// profile). The full texts are published by ИП Хаджимуратов М. М.;
/// the dialogs show the summary and the operator details.
abstract final class LegalDocuments {
  static const operatorName = 'ИП Хаджимуратов М. М.';

  static const offerTitle = 'Публичная оферта';
  static const offerBody =
      'Полный текст оферты публикуется на сайте SHIK ROLL. '
      'Оформляя заказ, вы принимаете условия продажи товаров и '
      'даёте согласие на обработку персональных данных.';

  static const privacyTitle = 'Политика обработки персональных данных';
  static const privacyBody =
      'Оператор персональных данных — $operatorName. '
      'Номер телефона и имя используются для оформления и доставки заказов '
      'в соответствии с Федеральным законом № 152-ФЗ '
      '«О персональных данных». Полный текст политики публикуется '
      'на сайте SHIK ROLL.';

  static void showOffer(BuildContext context) =>
      _show(context, offerTitle, offerBody);

  static void showPrivacy(BuildContext context) =>
      _show(context, privacyTitle, privacyBody);

  static void _show(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

/// Inline footnote with tappable links to the offer and the privacy policy.
class LegalLinksText extends StatefulWidget {
  const LegalLinksText({super.key, this.prefix = 'Продолжая, вы принимаете '});

  /// Text before the first link (auth and checkout phrase it differently).
  final String prefix;

  @override
  State<LegalLinksText> createState() => _LegalLinksTextState();
}

class _LegalLinksTextState extends State<LegalLinksText> {
  late final TapGestureRecognizer _offerRecognizer = TapGestureRecognizer()
    ..onTap = () => LegalDocuments.showOffer(context);
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => LegalDocuments.showPrivacy(context);

  @override
  void dispose() {
    _offerRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.gray600),
        children: [
          TextSpan(text: widget.prefix),
          TextSpan(
            text: 'Публичную оферту',
            style: linkStyle,
            recognizer: _offerRecognizer,
          ),
          const TextSpan(text: ' и '),
          TextSpan(
            text: 'Политику обработки персональных данных',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: ' (152-ФЗ).'),
        ],
      ),
    );
  }
}

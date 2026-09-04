import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../features/legal/data/legal_constants.dart';
import '../../features/legal/data/legal_document.dart';
import '../../features/legal/view/legal_document_viewer_screen.dart';
import '../theme/app_colors.dart';

/// Legal documents referenced across the guest app (checkout, auth,
/// profile). Full texts live in `features/legal`; these helpers open the
/// modal viewer with the corresponding document.
abstract final class LegalDocuments {
  static const operatorName = LegalConstants.operatorName;

  static const offerTitle = 'Публичная оферта';
  static const privacyTitle = 'Политика конфиденциальности';

  static void showOffer(BuildContext context) =>
      showLegalDocumentSheet(context, LegalDocument.offer);

  static void showPrivacy(BuildContext context) =>
      showLegalDocumentSheet(context, LegalDocument.privacy);
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

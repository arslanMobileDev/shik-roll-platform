import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/legal_document.dart';

/// Полноэкранный просмотр правового документа со скроллом.
///
/// Открывается переходом из раздела «Правовая информация» в профиле;
/// с экрана чекаута тот же документ показывается модально —
/// см. [showLegalDocumentSheet].
class LegalDocumentViewerScreen extends StatelessWidget {
  const LegalDocumentViewerScreen({super.key, required this.document});

  final LegalDocument document;

  static Route<void> route(LegalDocument document) => MaterialPageRoute<void>(
    builder: (_) => LegalDocumentViewerScreen(document: document),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(child: LegalDocumentView(document: document)),
    );
  }
}

/// Прокручиваемое содержимое документа: подзаголовки разделов и абзацы.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        for (final section in document.sections) ...[
          if (section.heading != null) ...[
            Text(section.heading!, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.s4),
          ],
          Text(section.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.s16),
        ],
      ],
    );
  }
}

/// Модальное окно для чтения документа без ухода с текущего экрана
/// (сноска на чекауте, чекбокс согласия, ссылки на экране входа).
Future<void> showLegalDocumentSheet(
  BuildContext context,
  LegalDocument document,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('legal-sheet-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: LegalDocumentView(document: document)),
            ],
          ),
        ),
      );
    },
  );
}

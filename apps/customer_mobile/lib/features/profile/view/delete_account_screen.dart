import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/account_repository.dart';

/// Двухшаговое самообслуживание удаления аккаунта (требование Apple).
///
/// Шаг 1 — серверный запрос удаления: показываем, что гость теряет
/// (сгорающие бонусы) и доступно ли удаление сейчас. Шаг 2 — диалог
/// подтверждения и `confirmDeletion` по одноразовому токену.
///
/// Возвращает `true` через [Navigator.pop], если аккаунт удалён:
/// вызывающий экран сбрасывает сессию.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.repository});

  final AccountRepository repository;

  static Route<bool> route(AccountRepository repository) =>
      MaterialPageRoute<bool>(
        builder: (_) => DeleteAccountScreen(repository: repository),
      );

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  DeletionRequest? _request;
  String? _loadError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _request = null;
    });
    try {
      final request = await widget.repository.requestDeletion();
      if (!mounted) return;
      setState(() => _request = request);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Удаление аккаунта')),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_loadError != null) return _ErrorView(message: _loadError!, onRetry: _load);
    final request = _request;
    if (request == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _DeletionSummary(
      request: request,
      submitting: _submitting,
      onConfirm: _confirm,
    );
  }

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Отменить это действие нельзя. Бонусы сгорят, а войти по этому '
          'номеру телефона получится только через 30 дней.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('delete-account-final-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await _submit();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await widget.repository.confirmDeletion(
        deletionToken: _request!.deletionToken,
      );
      if (!mounted) return;
      navigator.pop(true);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Аккаунт уже удалён (например, ответ первого запроса потерялся) —
      // цель достигнута, гость не должен остаться на экране удаления.
      if (e.isAlreadyDeleted) {
        navigator.pop(true);
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Шаг 1: сводка «что произойдёт» и кнопка подтверждения.
class _DeletionSummary extends StatelessWidget {
  const _DeletionSummary({
    required this.request,
    required this.submitting,
    required this.onConfirm,
  });

  final DeletionRequest request;
  final bool submitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        Text('Что произойдёт', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.s8),
        const _Bullet('Аккаунт и персональные данные будут удалены.'),
        const _Bullet('Войти в удалённый аккаунт нельзя.'),
        const _Bullet('История заказов останется как финансовая запись.'),
        const _Bullet(
          'Номер телефона освободится для новой регистрации через 30 дней.',
        ),
        const SizedBox(height: AppSpacing.s16),
        if (request.bonusBalance > 0)
          Card(
            key: const ValueKey('delete-account-bonus'),
            color: AppColors.warningContainer,
            child: ListTile(
              leading: const Icon(
                Icons.local_fire_department_outlined,
                color: AppColors.warning,
              ),
              title: Text(
                'Сгорят бонусы: ${request.bonusBalance}',
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                'Восстановить их после удаления не получится.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.gray700,
                ),
              ),
            ),
          ),
        if (!request.canDelete) ...[
          Card(
            key: const ValueKey('delete-account-blocked'),
            child: ListTile(
              leading: const Icon(Icons.schedule, color: AppColors.gray600),
              title: const Text('Есть незавершённый заказ'),
              subtitle: const Text(
                'Удаление станет доступно, когда заказ будет завершён.',
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        FilledButton(
          key: const ValueKey('delete-account-confirm'),
          onPressed: request.canDelete && !submitting ? onConfirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onPrimary,
          ),
          child: Text(submitting ? 'Удаляем…' : 'Удалить аккаунт'),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: AppSpacing.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton(
              key: const ValueKey('delete-account-retry'),
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

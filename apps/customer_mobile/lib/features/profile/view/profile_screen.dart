import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/legal_links.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/view/auth_flow.dart';

/// Guest profile tab: identity, legal documents and logout for the
/// authenticated guest; a login prompt for the anonymous one.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Text('Профиль', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.s12),
              if (state.isAuthenticated)
                _ProfileCard(state: state)
              else
                const _LoginCard(),
              const SizedBox(height: AppSpacing.s16),
              const _LegalSection(),
              if (state.isAuthenticated) ...[
                const SizedBox(height: AppSpacing.s16),
                const _LogoutButton(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.person_outline,
              size: 48,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Вы не вошли в аккаунт',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Войдите по номеру телефона, чтобы видеть историю заказов',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            FilledButton(
              key: const ValueKey('login-button'),
              onPressed: () => showAuthFlowSheet(context),
              child: const Text('Войти по номеру телефона'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = state.customer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(
                Icons.person_outline,
                size: 28,
                color: AppColors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'Гость',
                    key: const ValueKey('profile-name'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    customer?.phone ?? state.phone ?? '',
                    key: const ValueKey('profile-phone'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('edit-name-button'),
              onPressed: () => _editName(context),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Изменить имя',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final controller = TextEditingController(
      text: authBloc.state.customer?.name ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Как к вам обращаться?'),
        content: TextField(
          key: const ValueKey('name-field'),
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Имя',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('save-name-button'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    authBloc.add(AuthNameSubmitted(name: trimmed));
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s4,
            ),
            child: Text('Правовая информация', style: theme.textTheme.titleSmall),
          ),
          ListTile(
            key: const ValueKey('offer-tile'),
            leading: const Icon(Icons.description_outlined),
            title: const Text(LegalDocuments.offerTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LegalDocuments.showOffer(context),
          ),
          const Divider(indent: AppSpacing.s16, endIndent: AppSpacing.s16),
          ListTile(
            key: const ValueKey('privacy-tile'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Политика конфиденциальности'),
            subtitle: const Text('Оператор — ${LegalDocuments.operatorName}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LegalDocuments.showPrivacy(context),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('logout-button'),
      onPressed: () => _confirmLogout(context),
      icon: const Icon(Icons.logout, color: AppColors.error),
      label: const Text(
        'Выйти из аккаунта',
        style: TextStyle(color: AppColors.error),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'История заказов останется доступна после повторного входа '
          'по этому номеру телефона.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('logout-confirm-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      authBloc.add(const AuthLoggedOut());
    }
  }
}

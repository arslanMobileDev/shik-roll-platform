import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/restaurant_contacts.dart';
import '../domain/external_launcher.dart';
import 'restaurant_contact_cubit.dart';

Future<void> showRestaurantContactSheet(
  BuildContext context, {
  ContactTarget? target,
  GetRestaurantContactsUseCase? getContacts,
  ExternalLauncher? launcher,
}) async {
  final locator = GetIt.instance;
  if (getContacts == null &&
      !locator.isRegistered<GetRestaurantContactsUseCase>()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Контакты пока недоступны. Попробуйте позже.'),
      ),
    );
    return;
  }
  final useCase = getContacts ?? locator<GetRestaurantContactsUseCase>();
  final actions = launcher ?? locator<ExternalLauncher>();
  final destination =
      target ?? const ContactTarget.branch(AppConfig.defaultBranchId);
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
    ),
    builder: (_) => BlocProvider(
      create: (_) => RestaurantContactCubit(useCase)..load(destination),
      child: RestaurantContactSheet(
        target: destination,
        launcher: actions,
        messenger: messenger,
      ),
    ),
  );
}

class RestaurantContactSheet extends StatefulWidget {
  const RestaurantContactSheet({
    super.key,
    required this.target,
    required this.launcher,
    required this.messenger,
  });
  final ContactTarget target;
  final ExternalLauncher launcher;
  final ScaffoldMessengerState messenger;
  @override
  State<RestaurantContactSheet> createState() => _RestaurantContactSheetState();
}

class _RestaurantContactSheetState extends State<RestaurantContactSheet> {
  bool _launching = false;
  Future<void> _open(ContactAction action, String value) async {
    if (_launching) return;
    setState(() => _launching = true);
    LaunchResult result;
    try {
      result = await widget.launcher.open(action, value);
    } on Exception {
      result = LaunchResult.failed;
    }
    if (!mounted) return;
    setState(() => _launching = false);
    if (result != LaunchResult.opened && widget.messenger.mounted) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(
            action == ContactAction.call
                ? 'Звонки недоступны на этом устройстве. Номер: $value'
                : 'Не удалось открыть приложение или браузер. Попробуйте позже.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: BlocBuilder<RestaurantContactCubit, RestaurantContactState>(
          builder: (context, state) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Связаться с рестораном',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s16),
              if (state is ContactInitial || state is ContactLoading)
                const Center(child: CircularProgressIndicator()),
              if (state is ContactError) ...[
                const Text(
                  'Не удалось получить контакты филиала. Проверьте подключение и попробуйте снова.',
                ),
                TextButton(
                  onPressed: () => context.read<RestaurantContactCubit>().load(
                    widget.target,
                  ),
                  child: const Text('Повторить'),
                ),
              ],
              if (state is ContactLoaded) ..._details(state.result),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _details(ContactResult result) {
    final contacts = result.contacts;
    return [
      if (result.source != ContactSource.server)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.s12),
          child: Text('Показаны резервные контакты. Данные могли измениться.'),
        ),
      SelectableText(contacts.workingHours ?? 'Режим работы не указан'),
      const SizedBox(height: AppSpacing.s8),
      SelectableText(contacts.address ?? 'Адрес не указан'),
      const SizedBox(height: AppSpacing.s16),
      if (contacts.phone != null) ...[
        SelectableText(contacts.phone!),
        _button(
          'Позвонить',
          Icons.call_outlined,
          ContactAction.call,
          contacts.phone!,
        ),
      ],
      if (contacts.whatsapp != null)
        _button(
          'Написать в WhatsApp',
          Icons.chat_outlined,
          ContactAction.whatsapp,
          contacts.whatsapp!,
        ),
      if (contacts.telegram != null)
        _button(
          'Написать в Telegram',
          Icons.send_outlined,
          ContactAction.telegram,
          contacts.telegram!,
        ),
      if (contacts.address != null)
        _button(
          'Открыть в картах',
          Icons.map_outlined,
          ContactAction.maps,
          contacts.address!,
        ),
      if (contacts.phone == null &&
          contacts.whatsapp == null &&
          contacts.telegram == null)
        const Text('Телефон и мессенджеры пока не указаны.'),
    ];
  }

  Widget _button(
    String label,
    IconData icon,
    ContactAction action,
    String value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
    child: OutlinedButton.icon(
      onPressed: _launching ? null : () => _open(action, value),
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.all(AppSpacing.s12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
      ),
    ),
  );
}

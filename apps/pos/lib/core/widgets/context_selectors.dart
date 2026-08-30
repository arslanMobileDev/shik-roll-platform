import 'package:flutter/material.dart';

import '../config/pos_config.dart';
import '../theme/app_spacing.dart';

/// UI-803 Controls — brand selector for the POS context bar.
///
/// Business-logic independent: options arrive via [brands], the current
/// value via [selectedBrandId], and changes are reported through
/// [onChanged].
class BrandSelector extends StatelessWidget {
  const BrandSelector({
    super.key,
    required this.brands,
    required this.selectedBrandId,
    required this.onChanged,
    this.enabled = true,
  });

  final List<BrandOption> brands;
  final String? selectedBrandId;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _ContextSelector(
      semanticLabel: 'Бренд',
      icon: Icons.storefront,
      options: [for (final b in brands) (id: b.id, label: b.name)],
      selectedId: selectedBrandId,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

/// UI-803 Controls — branch selector for the POS context bar.
class BranchSelector extends StatelessWidget {
  const BranchSelector({
    super.key,
    required this.branches,
    required this.selectedBranchId,
    required this.onChanged,
    this.enabled = true,
  });

  final List<BranchOption> branches;
  final String? selectedBranchId;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _ContextSelector(
      semanticLabel: 'Филиал',
      icon: Icons.location_on_outlined,
      options: [for (final b in branches) (id: b.id, label: b.name)],
      selectedId: selectedBranchId,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class _ContextSelector extends StatelessWidget {
  const _ContextSelector({
    required this.semanticLabel,
    required this.icon,
    required this.options,
    required this.selectedId,
    required this.onChanged,
    required this.enabled,
  });

  final String semanticLabel;
  final IconData icon;
  final List<({String id, String label})> options;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = selectedId == null
        ? null
        : options.where((o) => o.id == selectedId).firstOrNull;

    return Semantics(
      label: semanticLabel,
      child: PopupMenuButton<String>(
        enabled: enabled && options.isNotEmpty,
        tooltip: semanticLabel,
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<String>(
              value: option.id,
              child: Row(
                children: [
                  Icon(
                    option.id == selectedId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(option.label),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.s8),
              Text(
                selected?.label ?? semanticLabel,
                style: textTheme.labelLarge,
              ),
              const SizedBox(width: AppSpacing.s4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

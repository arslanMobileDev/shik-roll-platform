import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

/// Lays filter chips out like a [Wrap] from 600 px up, but as a single
/// horizontally scrolling row on phones (UI-303): a four-row chip stack pushes
/// the very list it filters off screen.
///
/// Uses [SingleChildScrollView] rather than a lazy list on purpose —
/// every chip stays in the tree (tests can find one scrolled out of view) and
/// the row keeps its natural height, so a `ChoiceChip` still gets the 48 px its
/// tap target needs.
class AdaptiveChipRow extends StatelessWidget {
  const AdaptiveChipRow({super.key, required this.children, this.spacing = 8});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)) {
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: spacing, children: children),
    );
  }
}

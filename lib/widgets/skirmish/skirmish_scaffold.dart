// File: lib/widgets/skirmish/skirmish_scaffold.dart
// Frame shared by the skirmish screens: a top bar with the step or turn
// above the skirmish name (double-click to rename), three columns
// (player 1 | center | player 2), and an optional bottom action bar.
// Below the wide breakpoint the columns become tabs.

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../inline_editable_text.dart';

/// One of the three columns, with the label used for its tab.
typedef SkirmishColumn = ({String label, Widget child});

class SkirmishScaffold extends StatelessWidget {
  const SkirmishScaffold({
    super.key,
    required this.eyebrow,
    required this.name,
    required this.onRename,
    required this.columns,
    this.actions = const [],
    this.bottomBar,
  }) : assert(columns.length == 3);

  /// Small accent line above the name, e.g. "NEW SKIRMISH · MAP SELECTION".
  final String eyebrow;
  final String name;
  final ValueChanged<String> onRename;
  final List<SkirmishColumn> columns;
  final List<Widget> actions;
  final Widget? bottomBar;

  static const double wideBreakpoint = 1200;
  static const double _barHeight = 76;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        final appBar = AppBar(
          toolbarHeight: _barHeight,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.accent,
                ),
              ),
              InlineEditableText(
                value: name,
                onChanged: onRename,
                display: (v) => v.toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [...actions, const SizedBox(width: 12)],
          bottom: wide
              ? null
              : TabBar(tabs: [for (final c in columns) Tab(text: c.label)]),
        );
        final body = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: columns[0].child),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: ColoredBox(
                      color: const Color(0xFF12161A),
                      child: columns[1].child,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: columns[2].child),
                ],
              )
            : TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [for (final c in columns) c.child],
              );
        final scaffold = Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomBar,
        );
        return wide
            ? scaffold
            : DefaultTabController(length: 3, child: scaffold);
      },
    );
  }
}

/// The bar along the bottom of a skirmish screen: a status line on the
/// left, buttons on the right.
class SkirmishBottomBar extends StatelessWidget {
  const SkirmishBottomBar({
    super.key,
    required this.status,
    required this.children,
  });

  final String status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                status,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              c,
            ],
          ],
        ),
      ),
    );
  }
}

/// Square-cornered button styles used across the skirmish screens.
abstract final class SkirmishButtons {
  static const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(2)),
  );
  static const text = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static Widget filled(String label, VoidCallback? onPressed) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(140, 44),
      shape: shape,
    ),
    child: Text(label, style: text),
  );

  static Widget outlined(String label, VoidCallback? onPressed) =>
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(110, 44),
          shape: shape,
        ),
        child: Text(label, style: text),
      );
}

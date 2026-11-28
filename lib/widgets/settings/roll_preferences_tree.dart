// File: lib/widgets/settings/roll_preferences_tree.dart
// The dice roll checklist: one panel per group in rollCatalog, with nested
// rolls indented under their parent. A checked roll is made by the app.
// Unchecking a group greys out the rolls under it (they are then rolled by
// the players) but keeps their own checks for when the group is checked
// again.

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';

class RollPreferencesTree extends StatelessWidget {
  const RollPreferencesTree({
    super.key,
    required this.preferences,
    required this.onChanged,
  });

  final RollPreferences preferences;
  final ValueChanged<RollPreferences> onChanged;

  static const double _gap = 16;
  static const double _twoColumnWidth = 820;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= _twoColumnWidth;
        final width = twoColumns
            ? (constraints.maxWidth - _gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final group in rollCatalog)
              SizedBox(
                width: width,
                child: _GroupPanel(
                  group: group,
                  preferences: preferences,
                  onChanged: onChanged,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GroupPanel extends StatelessWidget {
  const _GroupPanel({
    required this.group,
    required this.preferences,
    required this.onChanged,
  });

  final RollOption group;
  final RollPreferences preferences;
  final ValueChanged<RollPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(RollOption option, int depth, bool enabled) {
      rows.add(
        _RollRow(
          option: option,
          depth: depth,
          checked: preferences.isChecked(option.id),
          enabled: enabled,
          onChanged: (checked) =>
              onChanged(preferences.withChecked(option.id, checked: checked)),
        ),
      );
      final childrenEnabled = enabled && preferences.isChecked(option.id);
      for (final c in option.children) {
        add(c, depth + 1, childrenEnabled);
      }
    }

    add(group, 0, true);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border.all(color: AppColors.cellBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _RollRow extends StatelessWidget {
  const _RollRow({
    required this.option,
    required this.depth,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final RollOption option;
  final int depth;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isGroup = depth == 0;
    final detail = option.detail;
    return CheckboxListTile(
      value: checked,
      enabled: enabled,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      dense: !isGroup,
      contentPadding: EdgeInsets.only(left: 8 + depth * 28.0, right: 12),
      title: Text(
        isGroup ? option.label.toUpperCase() : option.label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isGroup ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: isGroup ? 1.6 : 0,
          color: enabled ? AppColors.text : AppColors.textDim,
        ),
      ),
      subtitle: detail == null
          ? null
          : Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? AppColors.textDim : AppColors.iconDim,
              ),
            ),
    );
  }
}

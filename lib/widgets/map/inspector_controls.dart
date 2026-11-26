// File: lib/widgets/map/inspector_controls.dart
// Small controls shared by the hex inspectors: the map editor's
// HexInspector and the skirmish setup's SkirmishMapInspector.

import 'package:flutter/material.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../../app_theme.dart';
import '../hud.dart';

/// Square-cornered button shape used across the map screens.
const mapButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(2)),
);

const mapButtonText = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
);

/// Style for the woods segmented button.
final inspectorSegmentStyle = SegmentedButton.styleFrom(
  shape: mapButtonShape,
  selectedBackgroundColor: AppColors.accent,
  selectedForegroundColor: AppColors.background,
  foregroundColor: AppColors.textSecondary,
  side: const BorderSide(color: AppColors.borderStrong),
  visualDensity: VisualDensity.compact,
);

/// Woods choice for the selected hexes. [value] is null when they differ;
/// a null [onChanged] disables it.
class WoodsSelector extends StatelessWidget {
  const WoodsSelector({super.key, required this.value, this.onChanged});

  final Woods? value;
  final ValueChanged<Woods>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return SegmentedButton<Woods>(
      segments: const [
        ButtonSegment(value: Woods.none, label: Text('None')),
        ButtonSegment(value: Woods.light, label: Text('Light')),
        ButtonSegment(value: Woods.heavy, label: Text('Heavy')),
        ButtonSegment(value: Woods.ultraHeavy, label: Text('Ultra')),
      ],
      selected: {?value},
      emptySelectionAllowed: true,
      onSelectionChanged: onChanged == null
          ? null
          : (s) {
              if (s.isNotEmpty) onChanged(s.first);
            },
      showSelectedIcon: false,
      style: inspectorSegmentStyle,
    );
  }
}

class InspectorLabel extends StatelessWidget {
  const InspectorLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(), style: HudText.sectionLabel),
  );
}

/// A feature toggle for the selected hexes. [all] means every hex has it;
/// [some] that at least one does.
class FeatureChip extends StatelessWidget {
  const FeatureChip({
    super.key,
    required this.feature,
    required this.all,
    required this.some,
    required this.onToggle,
  });

  final TerrainFeature feature;
  final bool all;
  final bool some;

  /// Called with [all]: true removes the feature, false adds it. Null
  /// disables the chip.
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final name = feature.name[0].toUpperCase() + feature.name.substring(1);
    final onToggle = this.onToggle;
    return FilterChip(
      label: Text(some && !all ? '$name (some)' : name),
      selected: all,
      showCheckmark: false,
      onSelected: onToggle == null ? null : (_) => onToggle(all),
      shape: mapButtonShape,
      side: BorderSide(color: all ? AppColors.accent : AppColors.chipBorder),
      backgroundColor: AppColors.panelRaised,
      selectedColor: AppColors.accent.withAlpha(48),
      labelStyle: TextStyle(
        fontSize: 13,
        color: all ? AppColors.accent : AppColors.textSecondary,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// A labelled − value + stepper. With [mixed] the value shows as a dash and
/// the buttons step from [value]. A null [onChanged] disables it.
class InspectorStepper extends StatelessWidget {
  const InspectorStepper({
    super.key,
    required this.label,
    required this.value,
    required this.mixed,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool mixed;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Row(
      children: [
        Expanded(
          child: Text(
            (mixed ? '$label (mixed)' : label).toUpperCase(),
            style: HudText.sectionLabel,
          ),
        ),
        IconButton(
          tooltip: 'Decrease $label',
          onPressed: onChanged != null && value > min
              ? () => onChanged(value - 1)
              : null,
          icon: const Icon(Icons.remove),
        ),
        Container(
          width: 40,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.panelRaised,
            border: Border.all(color: AppColors.cellBorder),
          ),
          child: Text(
            mixed ? '–' : '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: onChanged == null ? AppColors.iconDim : AppColors.text,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Increase $label',
          onPressed: onChanged != null && value < max
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

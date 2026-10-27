// File: lib/widgets/mech_list_panel.dart
// Searchable, filterable, sortable mech list for the Lance Builder. The era,
// faction, and tech base filters start from the lance parameters. Sort,
// filters, and visible columns live here; the selection lives in the screen.

import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../era.dart';
import '../lance.dart';
import '../mech_columns.dart';
import '../mech_data.dart';
import '../mech_labels.dart';
import '../mech_library.dart';
import 'hud.dart';

class MechListPanel extends StatefulWidget {
  const MechListPanel({
    super.key,
    required this.library,
    required this.defaults,
    required this.selectedId,
    required this.onSelect,
    required this.isInLance,
    required this.remainingBattleValue,
  });

  final MechLibrary library;

  /// The lance parameters. Era, faction, and tech base are the default filters.
  final LanceParameters defaults;
  final String? selectedId;
  final ValueChanged<Mech> onSelect;
  final bool Function(String mechId) isInLance;
  final int remainingBattleValue;

  @override
  State<MechListPanel> createState() => _MechListPanelState();
}

class _MechListPanelState extends State<MechListPanel> {
  static const double _nameMinWidth = 220;
  static const double _rowHeight = 40;

  final _query = TextEditingController();
  Era? _era;
  String? _faction;
  TechBase? _techBase;
  WeightClass? _weightClass;

  /// Null sorts by name.
  MechColumn? _sortColumn = MechColumn.battleValue;
  bool _ascending = false;
  List<MechColumn> _columns = List.of(MechColumn.defaults);

  @override
  void initState() {
    super.initState();
    _resetFilters();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _query.clear();
    _era = widget.defaults.era;
    _faction = widget.defaults.faction;
    _techBase = widget.defaults.techBase;
    _weightClass = null;
  }

  void _sortBy(MechColumn? column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = column == null || !column.numeric;
      }
    });
  }

  void _setEra(Era? era) {
    setState(() {
      _era = era;
      if (_faction != null &&
          !widget.library.factions(era: era).contains(_faction)) {
        _faction = null;
      }
    });
  }

  Future<void> _chooseColumns() async {
    final chosen = await showDialog<List<MechColumn>>(
      context: context,
      builder: (context) => _ColumnDialog(selected: _columns),
    );
    if (chosen != null) setState(() => _columns = chosen);
  }

  List<Mech> _visibleMechs(String? faction) {
    final list = filterMechs(
      widget.library.mechs,
      query: _query.text,
      era: _era,
      faction: faction,
      techBase: _techBase,
      weightClass: _weightClass,
    );
    final column = _sortColumn;
    int compare(Mech a, Mech b) {
      final result = column == null
          ? '${a.name} ${a.variant}'.compareTo('${b.name} ${b.variant}')
          : column.sortValue(a).compareTo(column.sortValue(b));
      return _ascending ? result : -result;
    }

    return list..sort(compare);
  }

  @override
  Widget build(BuildContext context) {
    final factions = widget.library.factions(era: _era);
    // A lance faction with no mechs in the chosen era cannot be selected.
    final faction = factions.contains(_faction) ? _faction : null;
    final mechs = _visibleMechs(faction);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _query,
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration('Search', false).copyWith(
                        hintText: 'Name or variant',
                        prefixIcon: const Icon(Icons.search, size: 18),
                      ),
                    ),
                  ),
                  _FilterDropdown<Era?>(
                    label: 'Era',
                    width: 230,
                    value: _era,
                    isDefault: _era != null && _era == widget.defaults.era,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any era'),
                      ),
                      for (final e in widget.library.eras())
                        DropdownMenuItem(value: e, child: Text(e.label)),
                    ],
                    onChanged: _setEra,
                  ),
                  _FilterDropdown<String?>(
                    label: 'Faction',
                    width: 230,
                    value: faction,
                    isDefault:
                        faction != null && faction == widget.defaults.faction,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any faction'),
                      ),
                      for (final f in factions)
                        DropdownMenuItem(value: f, child: Text(f)),
                    ],
                    onChanged: (f) => setState(() => _faction = f),
                  ),
                  _FilterDropdown<TechBase?>(
                    label: 'Tech',
                    width: 150,
                    value: _techBase,
                    isDefault:
                        _techBase != null &&
                        _techBase == widget.defaults.techBase,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any tech'),
                      ),
                      for (final t in const [
                        TechBase.innerSphere,
                        TechBase.clan,
                        TechBase.mixed,
                      ])
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (t) => setState(() => _techBase = t),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final wc in const <WeightClass?>[
                    null,
                    WeightClass.light,
                    WeightClass.medium,
                    WeightClass.heavy,
                    WeightClass.assault,
                  ])
                    ChoiceChip(
                      label: Text(wc == null ? 'All classes' : _wcLabel(wc)),
                      selected: _weightClass == wc,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _weightClass = wc),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(_resetFilters),
                    child: const Text('Reset filters'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _chooseColumns,
                    icon: const Icon(Icons.view_column_outlined, size: 18),
                    label: const Text('Columns'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${mechs.length} of ${widget.library.mechs.length} mechs'
                '  ·  Orange outline: lance default',
                style: const TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fixed = _columns.fold<double>(0, (s, c) => s + c.width);
              final width = math.max(
                constraints.maxWidth,
                fixed + _nameMinWidth + 16,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      _header(),
                      Expanded(
                        child: mechs.isEmpty
                            ? const Center(
                                child: Text(
                                  'No mechs match these filters.',
                                  style: TextStyle(color: AppColors.textDim),
                                ),
                              )
                            : ListView.builder(
                                itemCount: mechs.length,
                                itemExtent: _rowHeight,
                                itemBuilder: (context, i) => _row(mechs[i]),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    Widget cell(
      String label,
      MechColumn? column, {
      double? width,
      bool right = false,
    }) {
      final active = _sortColumn == column;
      final child = InkWell(
        onTap: () => _sortBy(column),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                    color: active ? AppColors.accent : AppColors.textDim,
                  ),
                ),
              ),
              if (active)
                Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      );
      final labelled = Semantics(
        label: 'Sort by $label',
        button: true,
        excludeSemantics: true,
        child: child,
      );
      return width == null
          ? Expanded(child: labelled)
          : SizedBox(width: width, child: labelled);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          cell('Mech', null),
          for (final c in _columns)
            cell(c.label, c, width: c.width, right: c.numeric),
        ],
      ),
    );
  }

  Widget _row(Mech m) {
    final selected = m.id == widget.selectedId;
    final inLance = widget.isInLance(m.id);
    final overBudget = !inLance && m.bv > widget.remainingBattleValue;

    return Material(
      color: selected ? AppColors.panelActive : Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelect(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: Color(0xFF1E242B)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m.variant,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDim,
                        ),
                      ),
                      if (inLance) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          color: const Color(0xFF5FB35A),
                          child: const Text(
                            'IN LANCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              for (final c in _columns)
                SizedBox(
                  width: c.width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      c.text(m),
                      textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: c == MechColumn.battleValue && overBudget
                            ? const Color(0xFFFF7A6A)
                            : AppColors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _wcLabel(WeightClass wc) => switch (wc) {
    WeightClass.light => 'Light',
    WeightClass.medium => 'Medium',
    WeightClass.heavy => 'Heavy',
    WeightClass.assault => 'Assault',
    WeightClass.unknown => 'Unknown',
  };
}

InputDecoration _fieldDecoration(String label, bool isDefault) =>
    InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: AppColors.panelRaised,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(
          color: isDefault ? AppColors.accent : AppColors.borderStrong,
        ),
      ),
    );

/// Labelled dropdown. An orange outline marks a value that matches the lance
/// default.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.width,
    required this.value,
    required this.isDefault,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final double width;
  final T value;
  final bool isDefault;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: _fieldDecoration(label, isDefault),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Checklist of optional columns, with a reset to the defaults.
class _ColumnDialog extends StatefulWidget {
  const _ColumnDialog({required this.selected});

  final List<MechColumn> selected;

  @override
  State<_ColumnDialog> createState() => _ColumnDialogState();
}

class _ColumnDialogState extends State<_ColumnDialog> {
  late Set<MechColumn> _on = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Columns'),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CheckboxListTile(
                value: true,
                onChanged: null,
                title: Text('Mech (always shown)'),
                dense: true,
              ),
              for (final c in MechColumn.values)
                CheckboxListTile(
                  value: _on.contains(c),
                  title: Text(c.label),
                  dense: true,
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _on.add(c);
                    } else {
                      _on.remove(c);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _on = MechColumn.defaults.toSet()),
          child: const Text('Reset to default'),
        ),
        FilledButton(
          // Keep the enum order so columns do not jump around.
          onPressed: () => Navigator.of(
            context,
          ).pop(MechColumn.values.where(_on.contains).toList()),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Section label used by the builder panels.
class PanelLabel extends StatelessWidget {
  const PanelLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: HudText.sectionLabel);
}

// File: lib/widgets/mech_list_panel.dart
// Searchable, filterable, sortable mech list for the Lance Builder. The era,
// faction, and tech base filters start from the lance parameters, and each
// one's choices narrow to what the other two still allow. Weight class
// chips pick any mix of classes. Each filterable column also takes its own
// filter (number ranges, or a checklist for Role) from its header's
// right-click menu or the More filters menu, which also reaches hidden
// columns and the weapons and equipment filter.
// Active column filters show as chips. Sort, filters, and visible columns
// live here; the selection lives in the screen.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../era.dart';
import '../lance.dart';
import '../mech_columns.dart';
import '../mech_data.dart';
import '../mech_gear.dart';
import '../mech_labels.dart';
import '../mech_library.dart';
import 'era_label.dart';
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

  /// Empty means every class.
  final Set<WeightClass> _weightClasses = {};
  final Map<MechColumn, ColumnFilter> _columnFilters = {};
  GearFilter _gear = GearFilter.none;

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
    _weightClasses.clear();
    _columnFilters.clear();
    _gear = GearFilter.none;
  }

  Future<void> _editGear() async {
    final result = await showDialog<GearFilter>(
      context: context,
      builder: (context) =>
          _GearFilterDialog(initial: _gear, mechs: widget.library.mechs),
    );
    if (result != null) setState(() => _gear = result);
  }

  Future<void> _editFilter(MechColumn column) async {
    final result = await showDialog<ColumnFilter>(
      context: context,
      builder: (context) => _ColumnFilterDialog(
        column: column,
        initial: _columnFilters[column] ?? ColumnFilter.none,
        mechs: widget.library.mechs,
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.isEmpty) {
        _columnFilters.remove(column);
      } else {
        _columnFilters[column] = result;
      }
    });
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

  Future<void> _chooseColumns() async {
    final chosen = await showDialog<List<MechColumn>>(
      context: context,
      builder: (context) => _ColumnDialog(selected: _columns),
    );
    if (chosen != null) setState(() => _columns = chosen);
  }

  List<Mech> _visibleMechs(Era? era, String? faction, TechBase? techBase) {
    final list = filterMechs(
      widget.library.mechs,
      query: _query.text,
      era: era,
      faction: faction,
      techBase: techBase,
      weightClasses: _weightClasses,
      columnFilters: _columnFilters,
      gear: _gear,
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
    final library = widget.library;
    final eras = library.eras(faction: _faction, techBase: _techBase);
    final factions = library.factions(era: _era, techBase: _techBase);
    final techBases = library.techBases(era: _era, faction: _faction);
    // Lance defaults that match no mechs alongside the other filters cannot be
    // selected; they act as "any".
    final era = eras.contains(_era) ? _era : null;
    final faction = factions.contains(_faction) ? _faction : null;
    final techBase = techBases.contains(_techBase) ? _techBase : null;
    final mechs = _visibleMechs(era, faction, techBase);

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
                    value: era,
                    isDefault: era != null && era == widget.defaults.era,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any era'),
                      ),
                      for (final e in eras)
                        DropdownMenuItem(value: e, child: EraLabel(e)),
                    ],
                    onChanged: (e) => setState(() => _era = e),
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
                    value: techBase,
                    isDefault:
                        techBase != null &&
                        techBase == widget.defaults.techBase,
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
                        if (techBases.contains(t))
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
                    FilterChip(
                      label: Text(wc == null ? 'All classes' : _wcLabel(wc)),
                      selected: wc == null
                          ? _weightClasses.isEmpty
                          : _weightClasses.contains(wc),
                      showCheckmark: false,
                      onSelected: (on) => setState(() {
                        if (wc == null) {
                          _weightClasses.clear();
                        } else if (on) {
                          _weightClasses.add(wc);
                        } else {
                          _weightClasses.remove(wc);
                        }
                      }),
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
                  MenuAnchor(
                    menuChildren: [
                      for (final c in MechColumn.filterableColumns)
                        MenuItemButton(
                          onPressed: () => _editFilter(c),
                          leadingIcon: Icon(
                            _columnFilters.containsKey(c)
                                ? Icons.filter_alt
                                : Icons.filter_alt_outlined,
                            size: 18,
                            color: _columnFilters.containsKey(c)
                                ? AppColors.accent
                                : AppColors.textDim,
                          ),
                          child: Text(c.label),
                        ),
                      const Divider(height: 1),
                      MenuItemButton(
                        onPressed: _editGear,
                        leadingIcon: Icon(
                          Icons.build_outlined,
                          size: 18,
                          color: _gear.isEmpty
                              ? AppColors.textDim
                              : AppColors.accent,
                        ),
                        child: const Text('Weapons & equipment…'),
                      ),
                    ],
                    builder: (context, controller, _) => OutlinedButton.icon(
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                      icon: const Icon(Icons.filter_alt_outlined, size: 18),
                      label: const Text('More filters'),
                    ),
                  ),
                ],
              ),
              if (_columnFilters.isNotEmpty || !_gear.isEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in MechColumn.filterableColumns)
                      if (_columnFilters[c] case final f?)
                        InputChip(
                          avatar: const Icon(
                            Icons.filter_alt,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          label: Text(f.describe(c)),
                          tooltip: 'Edit ${c.label} filter',
                          onPressed: () => _editFilter(c),
                          deleteButtonTooltipMessage:
                              'Remove ${c.label} filter',
                          onDeleted: () =>
                              setState(() => _columnFilters.remove(c)),
                        ),
                    if (!_gear.isEmpty)
                      InputChip(
                        avatar: const Icon(
                          Icons.build_outlined,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        label: Text(_gear.describe()),
                        tooltip: 'Edit weapons & equipment filter',
                        onPressed: _editGear,
                        deleteButtonTooltipMessage:
                            'Remove weapons & equipment filter',
                        onDeleted: () =>
                            setState(() => _gear = GearFilter.none),
                      ),
                  ],
                ),
              ],
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

  /// Right-click menu on a column header: sort either way, and filter.
  Future<void> _showHeaderMenu(
    MechColumn? column,
    Offset globalPosition,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final filtered = column != null && _columnFilters.containsKey(column);
    final action = await showMenu<_HeaderAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: _HeaderAction.sortAscending,
          child: _MenuRow(Icons.arrow_upward, 'Sort ascending'),
        ),
        const PopupMenuItem(
          value: _HeaderAction.sortDescending,
          child: _MenuRow(Icons.arrow_downward, 'Sort descending'),
        ),
        if (column != null && column.filterable) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _HeaderAction.filter,
            child: _MenuRow(Icons.filter_alt_outlined, 'Filter…'),
          ),
          if (filtered)
            const PopupMenuItem(
              value: _HeaderAction.clearFilter,
              child: _MenuRow(Icons.filter_alt_off_outlined, 'Clear filter'),
            ),
        ],
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _HeaderAction.sortAscending:
        setState(() {
          _sortColumn = column;
          _ascending = true;
        });
      case _HeaderAction.sortDescending:
        setState(() {
          _sortColumn = column;
          _ascending = false;
        });
      case _HeaderAction.filter:
        await _editFilter(column!);
      case _HeaderAction.clearFilter:
        setState(() => _columnFilters.remove(column));
    }
  }

  Widget _header() {
    Widget cell(
      String label,
      MechColumn? column, {
      double? width,
      bool right = false,
    }) {
      final active = _sortColumn == column;
      final filtered = column != null && _columnFilters.containsKey(column);
      final child = GestureDetector(
        onSecondaryTapUp: (d) => _showHeaderMenu(column, d.globalPosition),
        child: InkWell(
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
                // Marks a filtered column; the chip above says how.
                if (filtered)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final labelled = Semantics(
        label: filtered ? 'Sort by $label, filtered' : 'Sort by $label',
        button: true,
        excludeSemantics: true,
        child: Tooltip(
          message: 'Right-click for sort and filter options',
          waitDuration: const Duration(seconds: 1),
          child: child,
        ),
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

enum _HeaderAction { sortAscending, sortDescending, filter, clearFilter }

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.textDim),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
}

/// Edits one column's filter: a checklist for Role, min and max fields for
/// each number of a numeric column. Pops the new filter (empty from Clear),
/// or null on Cancel.
class _ColumnFilterDialog extends StatefulWidget {
  const _ColumnFilterDialog({
    required this.column,
    required this.initial,
    required this.mechs,
  });

  final MechColumn column;
  final ColumnFilter initial;
  final List<Mech> mechs;

  @override
  State<_ColumnFilterDialog> createState() => _ColumnFilterDialogState();
}

class _ColumnFilterDialogState extends State<_ColumnFilterDialog> {
  late final Set<String> _values = Set.of(widget.initial.values);
  late final Map<String, (TextEditingController, TextEditingController)>
  _fields = {
    for (final f in widget.column.numericFields)
      f.label: (
        TextEditingController(
          text: widget.initial.ranges[f.label]?.min?.toString() ?? '',
        ),
        TextEditingController(
          text: widget.initial.ranges[f.label]?.max?.toString() ?? '',
        ),
      ),
  };

  /// Checklist choices: the values present in the catalog, in name order.
  late final List<String> _choices = {
    for (final m in widget.mechs) ?widget.column.category(m),
  }.toList()..sort();

  @override
  void dispose() {
    for (final (min, max) in _fields.values) {
      min.dispose();
      max.dispose();
    }
    super.dispose();
  }

  NumRange _range(String label) {
    final (min, max) = _fields[label]!;
    return (min: int.tryParse(min.text), max: int.tryParse(max.text));
  }

  bool get _valid => _fields.keys.every((label) {
    final r = _range(label);
    return r.min == null || r.max == null || r.min! <= r.max!;
  });

  void _apply() {
    if (!_valid) return;
    Navigator.of(context).pop(
      ColumnFilter(
        values: _values,
        ranges: {
          for (final label in _fields.keys)
            if (_range(label) case final r when r.min != null || r.max != null)
              label: r,
        },
      ),
    );
  }

  /// The lowest and highest value in the catalog, as a hint. An intro year
  /// of 0 means unknown, so it is left out.
  String _catalogSpan(NumericField f) {
    final unknownZero = widget.column == MechColumn.intro;
    final vs = [
      for (final m in widget.mechs) f.value(m),
    ].where((v) => !unknownZero || v > 0).toList();
    if (vs.isEmpty) return '';
    final lo = vs.reduce(math.min).round();
    final hi = vs.reduce(math.max).round();
    return 'Catalog: $lo–$hi';
  }

  @override
  Widget build(BuildContext context) {
    final column = widget.column;
    return AlertDialog(
      title: Text('Filter ${column.label}'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (column.hasCategories) ...[
                const Text(
                  'Show mechs with any of the checked values. None checked '
                  'shows all.',
                  style: TextStyle(fontSize: 13, color: AppColors.textDim),
                ),
                const SizedBox(height: 8),
                for (final v in _choices)
                  CheckboxListTile(
                    value: _values.contains(v),
                    title: Text(v),
                    dense: true,
                    onChanged: (on) => setState(() {
                      if (on ?? false) {
                        _values.add(v);
                      } else {
                        _values.remove(v);
                      }
                    }),
                  ),
              ],
              for (final f in column.numericFields) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _catalogSpan(f),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: _numberField('Min', _fields[f.label]!.$1)),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField('Max', _fields[f.label]!.$2)),
                  ],
                ),
              ],
              if (!_valid)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Min must not be above Max.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ColumnFilter.none),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _apply : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _numberField(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _fieldDecoration(label, false),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _apply(),
      );
}

/// Searchable checklist of every weapon and equipment name in the catalog,
/// grouped, with how many mechs carry each, and an all/any switch. Pops
/// the new filter (empty from Clear), or null on Cancel.
class _GearFilterDialog extends StatefulWidget {
  const _GearFilterDialog({required this.initial, required this.mechs});

  final GearFilter initial;
  final List<Mech> mechs;

  @override
  State<_GearFilterDialog> createState() => _GearFilterDialogState();
}

class _GearFilterDialogState extends State<_GearFilterDialog> {
  late final Set<String> _items = Set.of(widget.initial.items);
  late GearMatch _match = widget.initial.match;
  final _search = TextEditingController();
  late final _catalog = gearCatalog(widget.mechs);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Widget> _group(String label, Map<String, int> counts) {
    final q = _search.text.trim().toLowerCase();
    final names = [
      for (final n in counts.keys)
        if (q.isEmpty || n.toLowerCase().contains(q)) n,
    ];
    if (names.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(label, style: HudText.sectionLabel),
      ),
      for (final n in names)
        CheckboxListTile(
          value: _items.contains(n),
          dense: true,
          title: Text(n),
          secondary: Text(
            '${counts[n]}',
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
          onChanged: (on) => setState(() {
            if (on ?? false) {
              _items.add(n);
            } else {
              _items.remove(n);
            }
          }),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final list = [
      ..._group('WEAPONS', _catalog.weapons),
      ..._group('EQUIPMENT', _catalog.equipment),
    ];
    return AlertDialog(
      title: const Text('Weapons & equipment'),
      content: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      'Search',
                      false,
                    ).copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<GearMatch>(
                  segments: [
                    for (final m in GearMatch.values)
                      ButtonSegment(value: m, label: Text(m.label)),
                  ],
                  selected: {_match},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _match = s.first),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _items.isEmpty
                  ? 'Check items to show only mechs that carry them. The '
                        'number is how many mechs in the catalog do.'
                  : '${_items.length} checked',
              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text(
                        'Nothing matches the search.',
                        style: TextStyle(color: AppColors.textDim),
                      ),
                    )
                  : ListView(children: list),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(GearFilter.none),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(GearFilter(items: _items, match: _match)),
          child: const Text('Apply'),
        ),
      ],
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

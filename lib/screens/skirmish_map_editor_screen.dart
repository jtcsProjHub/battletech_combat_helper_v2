// File: lib/screens/skirmish_map_editor_screen.dart
// Full-screen editor for one skirmish's map overlay, opened from the New
// Skirmish overview: the map | hex inspector, with undo and redo in the top
// bar. It edits a copy; Done returns the new overlay and Back asks before
// dropping changes. The printed sheet is never changed.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../maps/map_model.dart';

import '../app_theme.dart';
import '../history/change_history.dart';
import '../maps/hex_selection.dart';
import '../skirmish/skirmish_map.dart';
import '../widgets/map/inspector_controls.dart';
import '../widgets/skirmish/skirmish_map_inspector.dart';
import '../widgets/skirmish/skirmish_map_view.dart';

typedef _Overlay = Map<HexCoord, HexOverlay>;

class SkirmishMapEditorScreen extends StatefulWidget {
  const SkirmishMapEditorScreen({super.key, required this.map});

  /// The skirmish's map. Not changed here; Done pops the edited overlay.
  final SkirmishMap map;

  /// Opens the editor. Returns the edited overlay, or null when the user
  /// leaves without Done.
  static Future<Map<HexCoord, HexOverlay>?> open(
    BuildContext context,
    SkirmishMap map,
  ) => Navigator.of(context).push<Map<HexCoord, HexOverlay>>(
    MaterialPageRoute(builder: (_) => SkirmishMapEditorScreen(map: map)),
  );

  @override
  State<SkirmishMapEditorScreen> createState() =>
      _SkirmishMapEditorScreenState();
}

class _SkirmishMapEditorScreenState extends State<SkirmishMapEditorScreen> {
  late final SkirmishMap _map = widget.map.copy();
  late final _Overlay _original = widget.map.overlay;
  final _selection = HexSelection();
  final _history = ChangeHistory<_Overlay>();
  CanvasTool _tool = CanvasTool.box;

  bool get _hasChanges => !mapEquals(_map.overlay, _original);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  /// Applies [change] and records it, unless it changed nothing.
  void _edit(String label, void Function(SkirmishMap map) change) {
    final before = _map.overlay;
    change(_map);
    final after = _map.overlay;
    if (mapEquals(before, after)) return;
    setState(
      () => _history.record(Change(label: label, before: before, after: after)),
    );
  }

  void _undo() {
    final c = _history.undo();
    if (c != null) setState(() => _map.restoreOverlay(c.before));
  }

  void _redo() {
    final c = _history.redo();
    if (c != null) setState(() => _map.restoreOverlay(c.after));
  }

  /// Steps the selection's level by [delta] from the primary hex, as the
  /// inspector's stepper does: every selected hex gets the same level.
  /// When every selected hex is a building, steps the building height
  /// the same way instead.
  void _stepLevel(int delta) {
    final hexes = _selection.hexes;
    final primary = _selection.primary;
    if (hexes.isEmpty || primary == null) return;
    if (hexes.every((h) => _map.overlayAt(h).building)) {
      final heights = {for (final h in hexes) _map.buildingHeightAt(h)!};
      final from = heights.length == 1
          ? heights.single
          : _map.buildingHeightAt(primary)!;
      final to = (from + delta).clamp(
        1,
        SkirmishMapInspector.maxBuildingHeight,
      );
      final where = hexes.length > 1 ? '${hexes.length} buildings' : primary.id;
      _edit('Height $to · $where', (m) => m.setBuildingHeight(hexes, to));
      return;
    }
    final levels = {
      for (final h in hexes) SkirmishMapInspector.levelOf(_map, h),
    };
    final from = levels.length == 1
        ? levels.single
        : SkirmishMapInspector.levelOf(_map, primary);
    final to = (from + delta).clamp(-6, 10);
    final where = hexes.length > 1 ? '${hexes.length} hexes' : primary.id;
    _edit('Level $to · $where', (m) => m.setLevel(hexes, to));
  }

  void _resetSelection() {
    final hexes = _selection.hexes;
    if (hexes.isEmpty) return;
    final where = hexes.length > 1
        ? '${hexes.length} hexes'
        : _selection.primary!.id;
    _edit('Reset to printed · $where', (m) => m.clear(hexes));
  }

  void _setTool(CanvasTool t) {
    if (t != _tool) setState(() => _tool = t);
  }

  void _done() => Navigator.of(context).pop(_map.overlay);

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final kb = HardwareKeyboard.instance;
    final ctrl = kb.isControlPressed || kb.isMetaPressed;
    final shift = kb.isShiftPressed;
    final key = event.logicalKey;
    if (ctrl) {
      if (key == LogicalKeyboardKey.keyZ) {
        shift ? _redo() : _undo();
      } else if (key == LogicalKeyboardKey.keyY) {
        _redo();
      } else if (key == LogicalKeyboardKey.keyA) {
        _selection.selectAll(_map.grid);
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    if (kb.isAltPressed) return KeyEventResult.ignored;
    // + is Shift+= on most layouts, so these accept Shift.
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      _stepLevel(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _stepLevel(-1);
      return KeyEventResult.handled;
    }
    if (shift) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape) {
      _selection.clear();
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _resetSelection();
    } else if (key == LogicalKeyboardKey.keyH) {
      _setTool(CanvasTool.pan);
    } else if (key == LogicalKeyboardKey.keyB) {
      _setTool(CanvasTool.box);
    } else if (key == LogicalKeyboardKey.keyP) {
      _setTool(CanvasTool.brush);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _onBack() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard map changes?'),
        content: const Text(
          'The changes made to this skirmish map since opening it are lost. '
          'Use Done to keep them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => PopScope(
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) => _onKey(event),
          child: Scaffold(
            appBar: _TopBar(
              map: _map,
              history: _history,
              onUndo: _undo,
              onRedo: _redo,
              onDone: _done,
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColoredBox(
                    color: AppColors.background,
                    child: ClipRect(
                      child: SkirmishMapView(
                        map: _map,
                        selection: _selection,
                        tool: _tool,
                        onToolChanged: _setTool,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 360,
                  child: ColoredBox(
                    color: const Color(0xFF12161A),
                    child: SkirmishMapInspector(
                      map: _map,
                      selection: _selection,
                      onEdit: _edit,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.map,
    required this.history,
    required this.onUndo,
    required this.onRedo,
    required this.onDone,
  });

  final SkirmishMap map;
  final ChangeHistory<_Overlay> history;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDone;

  static const double _barHeight = 76;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    final overlay = map.overlay.values;
    final changed = overlay.length;
    final buildings = overlay.where((o) => o.building).length;
    const statStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
    final undo = history.nextUndo?.label;
    final redo = history.nextRedo?.label;

    return AppBar(
      toolbarHeight: _barHeight,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NEW SKIRMISH · MAP SETUP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: AppColors.accent,
            ),
          ),
          Text(
            map.name.isEmpty ? 'UNTITLED MAP' : map.name.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        _Stat(
          label: 'CHANGED HEXES',
          value: Text(
            '$changed',
            style: statStyle.copyWith(
              color: changed > 0 ? overlayMarkColorLight : null,
            ),
          ),
        ),
        _Stat(
          label: 'BUILDINGS',
          value: Text('$buildings', style: statStyle),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: undo == null ? 'Undo (Ctrl+Z)' : 'Undo $undo (Ctrl+Z)',
          onPressed: undo == null ? null : onUndo,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: redo == null
              ? 'Redo (Ctrl+Shift+Z)'
              : 'Redo $redo (Ctrl+Shift+Z)',
          onPressed: redo == null ? null : onRedo,
          icon: const Icon(Icons.redo),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Tooltip(
            message: 'Keep these changes for the skirmish',
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 44),
                shape: mapButtonShape,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              child: const Text('DONE'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppColors.textDim,
            ),
          ),
          value,
        ],
      ),
    );
  }
}

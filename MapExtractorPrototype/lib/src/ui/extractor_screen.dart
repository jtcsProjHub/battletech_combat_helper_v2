import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../model/map_sheet.dart';
import 'extractor_controller.dart';
import 'hex_selection.dart';
import 'hex_inspector.dart';
import 'hex_map_view.dart';
import 'source_overlay_view.dart';

/// Three-column layout: sources and map settings, the map or a photo, and
/// the hex inspector.
class ExtractorScreen extends StatefulWidget {
  const ExtractorScreen({super.key});

  @override
  State<ExtractorScreen> createState() => _ExtractorScreenState();
}

class _ExtractorScreenState extends State<ExtractorScreen> {
  final controller = ExtractorController();

  /// True while a text field has focus, so N and Enter go to the field.
  bool get _typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (_typing || event is KeyUpEvent) return KeyEventResult.ignored;
    final kb = HardwareKeyboard.instance;
    final ctrl = kb.isControlPressed || kb.isMetaPressed;
    final key = event.logicalKey;
    final grid = controller.draft.grid;
    if (ctrl && key == LogicalKeyboardKey.keyA) {
      controller.selection.selectAll(grid);
      return KeyEventResult.handled;
    }
    if (ctrl || kb.isAltPressed || kb.isShiftPressed) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape) {
      controller.selection.clear();
    } else if (key == LogicalKeyboardKey.keyN) {
      controller.selectNextToReview();
    } else if (key == LogicalKeyboardKey.enter) {
      controller.acceptSelection();
    } else if (key == LogicalKeyboardKey.keyH) {
      controller.setTool(CanvasTool.pan);
    } else if (key == LogicalKeyboardKey.keyB) {
      controller.setTool(CanvasTool.box);
    } else if (key == LogicalKeyboardKey.keyP) {
      controller.setTool(CanvasTool.brush);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListenableBuilder(
        listenable: controller.draft,
        // A Focus handler instead of CallbackShortcuts: shortcuts report the
        // key as handled, and on desktop a handled key never reaches the
        // focused text field. Returning `ignored` while typing lets N and
        // Enter through.
        builder: (context, _) => ListenableBuilder(
          listenable: controller.selection,
          builder: (context, _) => Focus(
            autofocus: true,
            onKeyEvent: (node, event) => _onKey(event),
            child: Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 320, child: _LeftPanel(controller)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _CenterPanel(controller)),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 340,
                    child: HexInspector(
                      draft: controller.draft,
                      selection: controller.selection,
                      sources: controller.sources,
                      onNextToReview: controller.selectNextToReview,
                      onAccept: controller.acceptSelection,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel(this.c);
  final ExtractorController c;

  /// Picks a btmap file and, when photos or map data are loaded, asks the
  /// user to confirm that opening it clears them.
  Future<void> _openJson(BuildContext context) async {
    final path = await c.pickJson();
    if (path == null || !context.mounted) return;
    if (c.hasLoadedData) {
      final n = c.sources.length;
      final what = [
        if (n > 0) '$n loaded ${n == 1 ? 'photo' : 'photos'} and their extraction results',
        'the current map and all edits that are not saved',
      ].join(', and ');
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear the current data?'),
          content: Text('Opening ${p.basename(path)} clears $what.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear and open'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await c.openJson(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = c.draft;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Map extractor', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(c.status, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Text('Sources', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('One full photo, four quadrant photos, or a scanned PDF of the same sheet.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (var i = 0; i < c.sources.length; i++) _SourceTile(c, i),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: c.busy ? null : c.pickSources,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: c.busy ||
                        c.sources.every((s) => s.status == SourceStatus.done)
                    ? null
                    : c.extractAll,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Extract'),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        Text('Map', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('name-${identityHashCode(draft)}'),
          initialValue: draft.name,
          decoration: const InputDecoration(
              labelText: 'Name', hintText: 'Foothills #1', isDense: true),
          onChanged: (v) => draft.name = v,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _IntField(
                key: ValueKey('cols-${draft.grid.columns}-${identityHashCode(draft)}'),
                label: 'Columns',
                value: draft.grid.columns,
                onChanged: (v) =>
                    c.setGrid(GridSpec(columns: v, rows: draft.grid.rows)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IntField(
                key: ValueKey('rows-${draft.grid.rows}-${identityHashCode(draft)}'),
                label: 'Rows',
                value: draft.grid.rows,
                onChanged: (v) =>
                    c.setGrid(GridSpec(columns: draft.grid.columns, rows: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('The extractor sets the size from the highest hex numbers it reads. '
            'Standard sheets are 15 x 17.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Text('${draft.terrainCount} hexes with terrain, '
            '${draft.unverified.length} to review'),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: c.busy ? null : () => _openJson(context),
                  child: const Text('Open JSON')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                  onPressed: c.busy ? null : c.saveJson, child: const Text('Save JSON')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
            'Keys: N = next hex to review. Enter = accept the selection and go to '
            'the next. Esc = clear selection. Ctrl+A = select all. '
            'H, B, P = pan, box and brush tools.',
            style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile(this.c, this.i);
  final ExtractorController c;
  final int i;

  @override
  Widget build(BuildContext context) {
    final s = c.sources[i];
    final theme = Theme.of(context);
    final subtitle = switch (s.status) {
      SourceStatus.waiting => 'Waiting',
      SourceStatus.running => s.stage,
      SourceStatus.done => s.stage,
      SourceStatus.failed => s.error ?? 'Failed',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (s.status) {
                    SourceStatus.done => Icons.check_circle,
                    SourceStatus.failed => Icons.error,
                    SourceStatus.running => Icons.hourglass_top,
                    SourceStatus.waiting => Icons.image_outlined,
                  },
                  size: 18,
                  color: s.status == SourceStatus.failed ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: c.busy ? null : () => c.removeSource(i),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            Text(subtitle, style: theme.textTheme.bodySmall),
            if (s.status == SourceStatus.running)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: LinearProgressIndicator(value: s.fraction),
              ),
          ],
        ),
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onFieldSubmitted: (v) {
          final n = int.tryParse(v);
          if (n != null && n >= 1 && n <= 99) onChanged(n);
        },
      );
}

class _CenterPanel extends StatelessWidget {
  const _CenterPanel(this.c);
  final ExtractorController c;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (c.view < 0 || c.view >= c.sources.length) {
      body = HexMapView(
        key: const ValueKey('map'),
        draft: c.draft,
        selection: c.selection,
        tool: c.tool,
        onToolChanged: c.setTool,
      );
    } else {
      body = SourceOverlayView(
        key: ValueKey(c.sources[c.view].path),
        source: c.sources[c.view],
        draft: c.draft,
        selection: c.selection,
        showOcrBoxes: c.showOcrBoxes,
        tool: c.tool,
        onToolChanged: c.setTool,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Map'),
                selected: c.view < 0,
                onSelected: (_) => c.setView(-1),
              ),
              for (var i = 0; i < c.sources.length; i++)
                ChoiceChip(
                  label: Text('Photo ${i + 1}'),
                  selected: c.view == i,
                  onSelected: c.sources[i].result == null ? null : (_) => c.setView(i),
                ),
              if (c.view >= 0)
                FilterChip(
                  label: const Text('OCR boxes'),
                  selected: c.showOcrBoxes,
                  onSelected: (_) => c.toggleOcrBoxes(),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: ClipRect(child: body)),
      ],
    );
  }
}

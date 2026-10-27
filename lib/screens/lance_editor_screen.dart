// File: lib/screens/lance_editor_screen.dart
// Full-screen Lance Builder: mech list | preview | roster, with the lance
// budget in the top bar. Pops with a LanceEditorResult: saved from the Save
// button, not saved from the back arrow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../lance.dart';
import '../lance_draft.dart';
import '../mech_data.dart';
import '../mech_library.dart';
import '../widgets/lance_roster_panel.dart';
import '../widgets/mech_list_panel.dart';
import '../widgets/mech_preview_panel.dart';

class LanceEditorResult {
  const LanceEditorResult(this.lance, {required this.saved});

  final Lance lance;
  final bool saved;
}

class LanceEditorScreen extends StatefulWidget {
  const LanceEditorScreen({
    super.key,
    required this.lance,
    required this.library,
  });

  final Lance lance;
  final MechLibrary library;

  @override
  State<LanceEditorScreen> createState() => _LanceEditorScreenState();
}

class _LanceEditorScreenState extends State<LanceEditorScreen> {
  late final LanceDraft _draft = LanceDraft(widget.lance, widget.library);
  String? _selectedId;

  /// Below this width the three panels become tabs.
  static const double _wideBreakpoint = 1200;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _select(Mech mech) => setState(() => _selectedId = mech.id);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final selected = _selectedId == null
            ? null
            : widget.library.byId(_selectedId!);

        final list = MechListPanel(
          library: widget.library,
          defaults: _draft.parameters,
          selectedId: _selectedId,
          onSelect: _select,
          isInLance: _draft.contains,
          remainingBattleValue: _draft.remainingBattleValue,
        );
        final preview = MechPreviewPanel(
          mech: selected,
          inLance: selected != null && _draft.contains(selected.id),
          lanceFull: _draft.isFull,
          remainingBattleValue: _draft.remainingBattleValue,
          openSlots: _draft.openSlots,
          onAdd: () {
            if (selected != null) _draft.add(selected);
          },
        );
        final roster = LanceRosterPanel(
          draft: _draft,
          selectedId: _selectedId,
          onSelect: _select,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            final scaffold = Scaffold(
              appBar: _TopBar(
                draft: _draft,
                onSave: () => Navigator.of(
                  context,
                ).pop(LanceEditorResult(_draft.toLance(), saved: true)),
                tabs: wide
                    ? null
                    : const TabBar(
                        tabs: [
                          Tab(text: 'MECHS'),
                          Tab(text: 'PREVIEW'),
                          Tab(text: 'ROSTER'),
                        ],
                      ),
              ),
              body: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: list),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 480,
                          child: ColoredBox(
                            color: const Color(0xFF12161A),
                            child: preview,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        SizedBox(width: 340, child: roster),
                      ],
                    )
                  : TabBarView(children: [list, preview, roster]),
            );
            // Back still returns the draft so the hub can keep the mechs.
            return PopScope<LanceEditorResult>(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                Navigator.of(
                  context,
                ).pop(LanceEditorResult(_draft.toLance(), saved: false));
              },
              child: wide
                  ? scaffold
                  : DefaultTabController(length: 3, child: scaffold),
            );
          },
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.draft, required this.onSave, this.tabs});

  final LanceDraft draft;
  final VoidCallback onSave;
  final PreferredSizeWidget? tabs;

  static const double _barHeight = 76;

  @override
  Size get preferredSize =>
      Size.fromHeight(_barHeight + (tabs?.preferredSize.height ?? 0));

  Future<void> _editTarget(BuildContext context) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) =>
          _TargetBattleValueDialog(initial: draft.parameters.targetBattleValue),
    );
    if (value != null) draft.setTargetBattleValue(value);
  }

  @override
  Widget build(BuildContext context) {
    final over = draft.isOverBudget;
    final bvColor = over ? const Color(0xFFFF7A6A) : AppColors.accent;
    final target = draft.parameters.targetBattleValue;
    final fraction = target > 0
        ? (draft.usedBattleValue / target).clamp(0.0, 1.0)
        : 0.0;

    return AppBar(
      toolbarHeight: _barHeight,
      titleSpacing: 0,
      bottom: tabs,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LANCE BUILDER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: AppColors.accent,
            ),
          ),
          Text(
            draft.lance.name.toUpperCase(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        _Stat(
          label: 'BATTLE VALUE',
          width: 180,
          onTap: () => _editTarget(context),
          tooltip: 'Change target Battle Value',
          value: Text.rich(
            TextSpan(
              text: '${draft.usedBattleValue}',
              style: TextStyle(color: bvColor),
              children: [
                TextSpan(
                  text: ' / $target',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDim,
                  ),
                ),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.edit, size: 14, color: AppColors.textDim),
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          bar: LinearProgressIndicator(
            value: fraction.toDouble(),
            minHeight: 4,
            color: bvColor,
            backgroundColor: const Color(0xFF262D34),
            semanticsLabel: 'Battle value used',
          ),
        ),
        _Stat(
          label: 'TONNAGE',
          value: Text(
            '${draft.tonnage.round()} t',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        _Stat(
          label: 'MECHS',
          value: Text(
            '${draft.mechs.length} / ${draft.parameters.maxMechs}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size(140, 44),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            child: const Text('SAVE LANCE'),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.bar,
    this.width,
    this.onTap,
    this.tooltip,
  });

  final String label;
  final Widget value;
  final Widget? bar;
  final double? width;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final stat = _content();
    if (onTap == null) return stat;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(onTap: onTap, child: stat),
    );
  }

  Widget _content() {
    return Container(
      width: width,
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
          if (bar != null) ...[const SizedBox(height: 4), bar!],
        ],
      ),
    );
  }
}

class _TargetBattleValueDialog extends StatefulWidget {
  const _TargetBattleValueDialog({required this.initial});

  final int initial;

  @override
  State<_TargetBattleValueDialog> createState() =>
      _TargetBattleValueDialogState();
}

class _TargetBattleValueDialogState extends State<_TargetBattleValueDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}')
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: '${widget.initial}'.length,
    );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text);
    if (n == null || n <= 0) {
      setState(() => _error = 'Enter a number above 0.');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Target Battle Value'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(onPressed: _submit, child: const Text('SET')),
      ],
    );
  }
}

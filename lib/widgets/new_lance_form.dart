// File: lib/widgets/new_lance_form.dart
// Form for starting a new lance: a required name and the starting
// parameters. Era and faction choices come from the loaded MechLibrary.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../era.dart';
import '../lance.dart';
import '../mech_data.dart' show TechBase;
import '../mech_library.dart';
import 'hud.dart';

const Map<TechBase, String> techBaseLabels = {
  TechBase.innerSphere: 'Inner Sphere',
  TechBase.clan: 'Clan',
  TechBase.mixed: 'Mixed',
};

class NewLanceForm extends StatefulWidget {
  const NewLanceForm({
    super.key,
    required this.library,
    required this.onCreate,
    required this.onCancel,
    this.inProgress,
  });

  final MechLibrary library;
  final ValueChanged<Lance> onCreate;
  final VoidCallback onCancel;

  /// The lance from the builder after its back arrow. Its target BV is
  /// copied into the form, and its mechs carry over on the next Create.
  final Lance? inProgress;

  static const minMechs = 1;
  static const maxMechsLimit = 12;

  @override
  State<NewLanceForm> createState() => _NewLanceFormState();
}

class _NewLanceFormState extends State<NewLanceForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bv = TextEditingController(
    text: '${LanceParameters.defaultTargetBattleValue}',
  );
  int _maxMechs = LanceParameters.defaultMaxMechs;
  Era? _era;
  String? _faction;
  TechBase? _techBase;

  @override
  void didUpdateWidget(NewLanceForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lance = widget.inProgress;
    if (lance != null && lance != oldWidget.inProgress) {
      _bv.text = '${lance.parameters.targetBattleValue}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bv.dispose();
    super.dispose();
  }

  void _setEra(Era? era) {
    setState(() {
      _era = era;
      // Drop a faction that has no mechs in the new era.
      if (_faction != null &&
          !widget.library.factions(era: era).contains(_faction)) {
        _faction = null;
      }
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onCreate(
      Lance.create(
        name: _name.text,
        parameters: LanceParameters(
          targetBattleValue: int.parse(_bv.text),
          maxMechs: _maxMechs,
          era: _era,
          faction: _faction,
          techBase: _techBase,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final factions = widget.library.factions(era: _era);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('NEW LANCE', style: HudText.panelTitle),
                  const SizedBox(height: 8),
                  const Text(
                    'Name the lance and set its starting limits. You pick '
                    'mechs in the next step.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (widget.inProgress case final lance?
                      when lance.slots.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      lance.slots.length == 1
                          ? '1 mech from the builder is kept.'
                          : '${lance.slots.length} mechs from the builder are '
                                'kept.',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('Lance name', required: true),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a name for the lance.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  const Text('PARAMETERS', style: HudText.sectionLabel),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          controller: _bv,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _decoration('Target Battle Value'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return (n == null || n <= 0)
                                ? 'Enter a number above 0.'
                                : null;
                          },
                        ),
                      ),
                      _MechCountStepper(
                        value: _maxMechs,
                        onChanged: (v) => setState(() => _maxMechs = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<Era?>(
                          initialValue: _era,
                          isExpanded: true,
                          decoration: _decoration('Target era'),
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
                      ),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String?>(
                          // A new key resets the field when the era change
                          // clears the faction.
                          key: ValueKey('faction-${_era?.name}'),
                          initialValue: _faction,
                          isExpanded: true,
                          decoration: _decoration('Target faction'),
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
                      ),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<TechBase?>(
                          initialValue: _techBase,
                          isExpanded: true,
                          decoration: _decoration('Target tech base'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Any tech base'),
                            ),
                            for (final entry in techBaseLabels.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: (t) => setState(() => _techBase = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: widget.onCancel,
                style: _buttonStyle(outlined: true),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: _submit,
                style: _buttonStyle(outlined: false),
                child: const Text('CREATE LANCE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static InputDecoration _decoration(String label, {bool required = false}) =>
      InputDecoration(
        labelText: required ? '$label *' : label,
        filled: true,
        fillColor: AppColors.panelRaised,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          borderSide: BorderSide(color: AppColors.borderStrong),
        ),
      );

  static ButtonStyle _buttonStyle({required bool outlined}) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(2)),
    );
    const text = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    );
    return outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size(120, 48),
            side: const BorderSide(color: AppColors.borderStrong),
            shape: shape,
            textStyle: text,
          )
        : FilledButton.styleFrom(
            minimumSize: const Size(160, 48),
            shape: shape,
            textStyle: text,
          );
  }
}

/// Minus / value / plus control for the maximum number of mechs.
class _MechCountStepper extends StatelessWidget {
  const _MechCountStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDown = value > NewLanceForm.minMechs;
    final canUp = value < NewLanceForm.maxMechsLimit;
    return Semantics(
      label: 'Max number of mechs',
      value: '$value',
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.panelRaised,
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 8),
              child: Text(
                'Max mechs',
                style: TextStyle(fontSize: 14, color: AppColors.textDim),
              ),
            ),
            IconButton(
              tooltip: 'Fewer mechs',
              onPressed: canDown ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            IconButton(
              tooltip: 'More mechs',
              onPressed: canUp ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

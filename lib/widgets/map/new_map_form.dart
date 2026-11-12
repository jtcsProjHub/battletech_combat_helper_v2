// File: lib/widgets/map/new_map_form.dart
// Form for starting a new map sheet: a required name and the grid size.
// Terrain is entered in the editor, by hand or from photos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../../app_theme.dart';
import '../hud.dart';

/// The name and size from the form.
typedef NewMapRequest = ({String name, GridSpec grid});

class NewMapForm extends StatefulWidget {
  const NewMapForm({super.key, required this.onCreate, required this.onCancel});

  final ValueChanged<NewMapRequest> onCreate;
  final VoidCallback onCancel;

  static const maxGridSide = 99;

  @override
  State<NewMapForm> createState() => _NewMapFormState();
}

class _NewMapFormState extends State<NewMapForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _columns = TextEditingController(text: '${GridSpec.standard.columns}');
  final _rows = TextEditingController(text: '${GridSpec.standard.rows}');

  static final _buttonShape = const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(2)),
  );
  static const _buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  @override
  void dispose() {
    _name.dispose();
    _columns.dispose();
    _rows.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onCreate((
      name: _name.text.trim(),
      grid: GridSpec(
        columns: int.parse(_columns.text),
        rows: int.parse(_rows.text),
      ),
    ));
  }

  String? _validateSide(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n < 1 || n > NewMapForm.maxGridSide)
        ? 'Enter 1 to ${NewMapForm.maxGridSide}.'
        : null;
  }

  Widget _sideField(TextEditingController controller, String label) => SizedBox(
    width: 160,
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: hudInputDecoration(label),
      validator: _validateSide,
      onFieldSubmitted: (_) => _submit(),
    ),
  );

  @override
  Widget build(BuildContext context) {
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
                  const Text('NEW MAP', style: HudText.panelTitle),
                  const SizedBox(height: 8),
                  const Text(
                    'Name the map sheet and set its size. In the next step '
                    'you enter the terrain by hand, or extract it from '
                    'photos of the printed sheet.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: hudInputDecoration(
                      'Map name',
                      required: true,
                      hint: 'Foothills #1',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a name for the map.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  const Text('GRID SIZE', style: HudText.sectionLabel),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _sideField(_columns, 'Columns'),
                      _sideField(_rows, 'Rows'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Standard sheets are 15 × 17. Extraction from photos '
                    'sets the size from the hex numbers it reads.',
                    style: TextStyle(fontSize: 14, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(120, 48),
                  side: const BorderSide(color: AppColors.borderStrong),
                  shape: _buttonShape,
                ),
                child: const Text('CANCEL', style: _buttonText),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  shape: _buttonShape,
                ),
                child: const Text('CREATE MAP', style: _buttonText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

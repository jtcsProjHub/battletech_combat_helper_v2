// File: lib/widgets/pilot_widgets.dart
// The pilot row on the roster cards, the gunnery and piloting badges, and
// the dialog that assigns a pilot to a mech. The badges follow the Force
// Pack pilot cards: a red shield for gunnery, a yellow chevron for piloting.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../mech_data.dart';
import '../pilot_data.dart';

const _gunneryColor = Color(0xFFD23C2E);
const _pilotingColor = Color(0xFFF2C230);

enum PilotSkill { gunnery, piloting }

/// One skill value in its colored badge, e.g. a red shield with "3".
class PilotSkillBadge extends StatelessWidget {
  const PilotSkillBadge({super.key, required this.skill, required this.value});

  final PilotSkill skill;
  final int value;

  @override
  Widget build(BuildContext context) {
    final gunnery = skill == PilotSkill.gunnery;
    final label = '${gunnery ? 'Gunnery' : 'Piloting'} $value';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: ClipPath(
          clipper: gunnery ? const _ShieldClipper() : const _ChevronClipper(),
          child: Container(
            width: gunnery ? 24 : 28,
            height: 22,
            color: gunnery ? _gunneryColor : _pilotingColor,
            alignment: gunnery ? const Alignment(0, -0.4) : Alignment.center,
            padding: gunnery ? null : const EdgeInsets.only(right: 3),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1,
                color: gunnery ? Colors.white : AppColors.background,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat top, sides that taper to a point at the bottom.
class _ShieldClipper extends CustomClipper<Path> {
  const _ShieldClipper();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height * 0.55)
    ..lineTo(s.width / 2, s.height)
    ..lineTo(0, s.height * 0.55)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A block with a notch on the left and a point on the right.
class _ChevronClipper extends CustomClipper<Path> {
  const _ChevronClipper();

  @override
  Path getClip(Size s) {
    const notch = 6.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(s.width - notch, 0)
      ..lineTo(s.width, s.height / 2)
      ..lineTo(s.width - notch, s.height)
      ..lineTo(0, s.height)
      ..lineTo(notch, s.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Gunnery then piloting.
class PilotSkillBadges extends StatelessWidget {
  const PilotSkillBadges({super.key, required this.pilot});

  final Pilot pilot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PilotSkillBadge(skill: PilotSkill.gunnery, value: pilot.gunnery),
        const SizedBox(width: 4),
        PilotSkillBadge(skill: PilotSkill.piloting, value: pilot.piloting),
      ],
    );
  }
}

/// The bottom row of a roster card. With no pilot assigned it shows the
/// standard skills the mech plays at and, when [onEdit] is set, a
/// "+ PILOT" button. With a pilot it shows the name and skill badges; a tap
/// edits them.
class PilotRow extends StatelessWidget {
  const PilotRow({super.key, required this.pilot, this.onEdit});

  final Pilot pilot;
  final VoidCallback? onEdit;

  static const _nameStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const _dimStyle = TextStyle(fontSize: 13, color: AppColors.textDim);

  @override
  Widget build(BuildContext context) {
    final edit = onEdit;
    if (pilot.isDefault) {
      return Row(
        children: [
          if (edit != null)
            TextButton.icon(
              onPressed: edit,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text(
                'PILOT',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            )
          else
            const Text('No pilot', style: _dimStyle),
          const Spacer(),
          const Flexible(
            child: Text(
              'Standard ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _dimStyle,
            ),
          ),
          PilotSkillBadges(pilot: pilot),
        ],
      );
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.person, size: 18, color: AppColors.textDim),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              pilot.name.isEmpty ? 'Unnamed pilot' : pilot.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pilot.name.isEmpty ? _dimStyle : _nameStyle,
            ),
          ),
          PilotSkillBadges(pilot: pilot),
          if (edit != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 14, color: AppColors.textDim),
          ],
        ],
      ),
    );
    if (edit == null) return row;
    return Tooltip(
      message: 'Edit pilot',
      child: InkWell(onTap: edit, child: row),
    );
  }
}

/// Asks for the pilot of [mech]. Returns the new pilot, `const Pilot()` when
/// the pilot is removed, or null on Cancel.
Future<Pilot?> showPilotDialog(
  BuildContext context, {
  required Mech mech,
  required Pilot pilot,
}) => showDialog<Pilot>(
  context: context,
  builder: (_) => _PilotDialog(mech: mech, pilot: pilot),
);

class _PilotDialog extends StatefulWidget {
  const _PilotDialog({required this.mech, required this.pilot});

  final Mech mech;
  final Pilot pilot;

  @override
  State<_PilotDialog> createState() => _PilotDialogState();
}

class _PilotDialogState extends State<_PilotDialog> {
  late final _name = TextEditingController(text: widget.pilot.name);
  late int _gunnery = widget.pilot.gunnery;
  late int _piloting = widget.pilot.piloting;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(
    context,
  ).pop(Pilot(name: _name.text.trim(), gunnery: _gunnery, piloting: _piloting));

  @override
  Widget build(BuildContext context) {
    final m = widget.mech;
    return AlertDialog(
      title: Text('Pilot · ${m.name} ${m.variant}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            _SkillStepper(
              skill: PilotSkill.gunnery,
              value: _gunnery,
              onChanged: (v) => setState(() => _gunnery = v),
            ),
            const SizedBox(height: 12),
            _SkillStepper(
              skill: PilotSkill.piloting,
              value: _piloting,
              onChanged: (v) => setState(() => _piloting = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lower is better. The standard pilot is Gunnery '
              '${Pilot.defaultGunnery}, Piloting ${Pilot.defaultPiloting}.',
              style: TextStyle(fontSize: 13, color: AppColors.textDim),
            ),
          ],
        ),
      ),
      actions: [
        if (!widget.pilot.isDefault)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const Pilot()),
            child: const Text('REMOVE PILOT'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(onPressed: _save, child: const Text('SAVE')),
      ],
    );
  }
}

class _SkillStepper extends StatelessWidget {
  const _SkillStepper({
    required this.skill,
    required this.value,
    required this.onChanged,
  });

  final PilotSkill skill;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final name = skill == PilotSkill.gunnery ? 'Gunnery' : 'Piloting';
    return Row(
      children: [
        PilotSkillBadge(skill: skill, value: value),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 16, color: AppColors.text),
          ),
        ),
        IconButton(
          tooltip: 'Lower $name',
          onPressed: value > Pilot.minSkill ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Raise $name',
          onPressed: value < Pilot.maxSkill ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

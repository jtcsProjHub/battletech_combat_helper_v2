// File: lib/widgets/mech_preview_panel.dart
// Details of the selected mech: identity, armor and structure by location
// with each location's share of the totals, stat tiles, weapons, ammo, and
// the Add to Lance button.

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../location.dart';
import '../mech_data.dart';
import '../mech_labels.dart';
import 'mech_thumbnail.dart';

const _armorColor = Color(0xFF7BC977);
const _rearColor = Color(0xFF8DB58A);
const _structureColor = Color(0xFFE8B33C);
const _overColor = Color(0xFFFF7A6A);

class MechPreviewPanel extends StatelessWidget {
  const MechPreviewPanel({
    super.key,
    required this.mech,
    required this.inLance,
    required this.lanceFull,
    required this.remainingBattleValue,
    required this.openSlots,
    required this.onAdd,
  });

  final Mech? mech;
  final bool inLance;
  final bool lanceFull;
  final int remainingBattleValue;
  final int openSlots;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final m = mech;
    if (m == null) {
      return const Center(
        child: Text(
          'Select a mech in the list to preview it.',
          style: TextStyle(color: AppColors.textDim),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(mech: m),
                const SizedBox(height: 16),
                _LocationFigure(mech: m),
                const SizedBox(height: 14),
                _StatTiles(mech: m),
                const SizedBox(height: 16),
                _WeaponsTable(mech: m),
                const SizedBox(height: 16),
                _Ammo(mech: m),
              ],
            ),
          ),
        ),
        _AddBar(
          mech: m,
          inLance: inLance,
          lanceFull: lanceFull,
          remainingBattleValue: remainingBattleValue,
          openSlots: openSlots,
          onAdd: onAdd,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mech});

  final Mech mech;

  @override
  Widget build(BuildContext context) {
    final m = mech;
    final sub = [
      m.techBase.label,
      if (m.introYear > 0) 'Intro ${m.introYear}',
      if (m.engineType.isNotEmpty) m.engineType,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.textDim,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  text: '${m.name.toUpperCase()} ',
                  children: [
                    TextSpan(
                      text: m.variant.toUpperCase(),
                      style: const TextStyle(color: AppColors.accent),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${m.tonnage.round()} t, ${m.weightClassString}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: AppColors.textSecondary,
              child: Text(
                m.role.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.background,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${m.bv} BV',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One location's numbers and their share of the mech's totals.
class _LocationValues {
  _LocationValues(Mech m, this.location, [this.rearLocation])
    : armor = m.armorByLocation[location] ?? 0,
      structure = m.structureByLocation[location] ?? 0,
      rear = rearLocation == null ? 0 : m.armorByLocation[rearLocation] ?? 0;

  final Location location;
  final Location? rearLocation;
  final int armor;
  final int structure;
  final int rear;
}

/// Thumbnail with a box for each location around it, laid out like a body:
/// HD above, CT below, arms, torsos, and legs on the sides.
class _LocationFigure extends StatelessWidget {
  const _LocationFigure({required this.mech});

  final Mech mech;

  @override
  Widget build(BuildContext context) {
    final m = mech;
    _LocationValues v(Location l, [Location? rear]) =>
        _LocationValues(m, l, rear);
    Widget box(_LocationValues lv) => _LocationBox(
      values: lv,
      armorTotal: m.armorTotal,
      structureTotal: m.structureTotal,
    );

    return Semantics(
      label: '${m.name} ${m.variant} armor and structure by location',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                box(v(Location.leftArm)),
                const SizedBox(height: 8),
                box(v(Location.leftTorso, Location.rearLeftTorso)),
                const SizedBox(height: 8),
                box(v(Location.leftLeg)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                box(v(Location.head)),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  color: AppColors.panel,
                  alignment: Alignment.center,
                  child: MechThumbnail(mechId: m.id, width: 112, height: 144),
                ),
                const SizedBox(height: 8),
                box(v(Location.centerTorso, Location.rearCenterTorso)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                box(v(Location.rightArm)),
                const SizedBox(height: 8),
                box(v(Location.rightTorso, Location.rearRightTorso)),
                const SizedBox(height: 8),
                box(v(Location.rightLeg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationBox extends StatelessWidget {
  const _LocationBox({
    required this.values,
    required this.armorTotal,
    required this.structureTotal,
  });

  final _LocationValues values;
  final int armorTotal;
  final int structureTotal;

  static String _pct(int v, int total) =>
      total > 0 ? '${(v * 100 / total).round()}%' : '';

  @override
  Widget build(BuildContext context) {
    final lv = values;
    final rear = lv.rearLocation;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border.all(color: const Color(0xFF262D34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                lv.location.code,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lv.location.label,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _ValueRow('Armor', lv.armor, _pct(lv.armor, armorTotal), _armorColor),
          if (rear != null)
            _ValueRow(
              rear.code,
              lv.rear,
              _pct(lv.rear, armorTotal),
              _rearColor,
            ),
          _ValueRow(
            'Struct',
            lv.structure,
            _pct(lv.structure, structureTotal),
            _structureColor,
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value, this.share, this.color);

  final String label;
  final int value;
  final String share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
        ),
        Expanded(
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            share,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
        ),
      ],
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.mech});

  final Mech mech;

  @override
  Widget build(BuildContext context) {
    final m = mech;
    final rear = [
      Location.rearLeftTorso,
      Location.rearCenterTorso,
      Location.rearRightTorso,
    ].fold<int>(0, (s, l) => s + (m.armorByLocation[l] ?? 0));
    final front = m.armorTotal - rear;
    return Row(
      children: [
        _tile(
          'Armor',
          '${m.armorTotal}',
          '$front front · $rear rear',
          _armorColor,
        ),
        const SizedBox(width: 8),
        _tile('Structure', '${m.structureTotal}', 'internal', _structureColor),
        const SizedBox(width: 8),
        _tile(
          'Heat gen / sink',
          '${m.totalWeaponHeat} / ${m.heatDissipation}',
          '${m.heatSinks.count} ${m.heatSinkShort}',
          AppColors.text,
        ),
        const SizedBox(width: 8),
        _tile(
          'Move',
          '${m.walk} / ${m.run} / ${m.jump}',
          'walk / run / jump',
          AppColors.text,
        ),
      ],
    );
  }

  Widget _tile(String label, String value, String sub, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border.all(color: const Color(0xFF262D34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
        ],
      ),
    ),
  );
}

/// Weapons grouped by type: total quantity and every location they mount in.
class _WeaponLine {
  _WeaponLine(this.weapon);

  final Weapon weapon;
  int quantity = 0;
  final List<String> locations = [];
}

class _WeaponsTable extends StatelessWidget {
  const _WeaponsTable({required this.mech});

  final Mech mech;

  static String _damage(Weapon w) {
    final d = w.damage;
    if (d == null) return '—';
    return switch (w.damageType) {
      2 => '$d/msl',
      1 => '$d/shot',
      _ => '$d',
    };
  }

  static String _range(Weapon w) {
    if (w.shortRange == null) return '—';
    final min = (w.minRange ?? 0) > 0 ? ' min ${w.minRange}' : '';
    return '${w.shortRange}/${w.mediumRange}/${w.longRange}$min';
  }

  @override
  Widget build(BuildContext context) {
    final lines = <String, _WeaponLine>{};
    for (final w in mech.weapons) {
      final line = lines.putIfAbsent(w.type, () => _WeaponLine(w));
      line.quantity += w.quantity ?? 1;
      final loc = w.location;
      if (loc != null && loc.isNotEmpty && !line.locations.contains(loc)) {
        line.locations.add(loc);
      }
    }

    const head = TextStyle(fontSize: 11, color: AppColors.textDim);
    const cell = TextStyle(fontSize: 12, color: AppColors.text);
    TableRow row(List<String> cells, {required bool header, Color? bg}) =>
        TableRow(
          decoration: bg == null ? null : BoxDecoration(color: bg),
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  cells[i],
                  style: header
                      ? head
                      : i == 1
                      ? cell.copyWith(fontSize: 13, fontWeight: FontWeight.w600)
                      : cell,
                ),
              ),
          ],
        );

    final values = lines.values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'WEAPONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {
            0: FixedColumnWidth(34),
            1: FlexColumnWidth(),
            2: FixedColumnWidth(60),
            3: FixedColumnWidth(42),
            4: FixedColumnWidth(62),
            5: FixedColumnWidth(104),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            row([
              'Qty',
              'Weapon',
              'Loc',
              'Heat',
              'Dmg',
              'Range S/M/L',
            ], header: true),
            for (var i = 0; i < values.length; i++)
              row(
                [
                  '${values[i].quantity}',
                  values[i].weapon.type,
                  values[i].locations.join(', '),
                  values[i].weapon.heat?.toString() ?? '—',
                  _damage(values[i].weapon),
                  _range(values[i].weapon),
                ],
                header: false,
                bg: i.isEven ? AppColors.panelRaised : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _Ammo extends StatelessWidget {
  const _Ammo({required this.mech});

  final Mech mech;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'AMMO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 4),
        if (mech.ammo.isEmpty)
          const Text(
            'None',
            style: TextStyle(fontSize: 12, color: AppColors.textDim),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in mech.ammo.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panelRaised,
                    border: Border.all(color: const Color(0xFF262D34)),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: e.key,
                      children: [
                        TextSpan(
                          text: ' · ${e.value} shots',
                          style: const TextStyle(color: AppColors.textDim),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.mech,
    required this.inLance,
    required this.lanceFull,
    required this.remainingBattleValue,
    required this.openSlots,
    required this.onAdd,
  });

  final Mech mech;
  final bool inLance;
  final bool lanceFull;
  final int remainingBattleValue;
  final int openSlots;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    String label = 'ADD TO LANCE';
    String note;
    Color noteColor = AppColors.textSecondary;
    if (inLance) {
      label = 'IN LANCE';
      note = 'Already in this lance.';
    } else if (lanceFull) {
      label = 'LANCE FULL';
      note = 'Remove a mech to free a slot.';
    } else {
      final after = remainingBattleValue - mech.bv;
      final slotsAfter = openSlots - 1;
      if (after < 0) {
        note = 'Goes ${-after} BV over the target.';
        noteColor = _overColor;
      } else if (slotsAfter > 0) {
        note =
            'Leaves $after BV for $slotsAfter '
            '${slotsAfter == 1 ? 'slot' : 'slots'}.';
      } else {
        note = 'Leaves $after BV.';
      }
    }
    final enabled = !inLance && !lanceFull;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(note, style: TextStyle(fontSize: 13, color: noteColor)),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: enabled ? onAdd : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(150, 44),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

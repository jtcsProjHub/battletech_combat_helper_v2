// File: lib/widgets/era_label.dart
// An era's name with its start year trailing in smaller, dimmer text, for era
// dropdowns. The name truncates first so the year always stays visible.

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../era.dart';

class EraLabel extends StatelessWidget {
  const EraLabel(this.era, {super.key});

  final Era era;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(era.label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(
          '${era.startYear}',
          style: const TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
      ],
    );
  }
}

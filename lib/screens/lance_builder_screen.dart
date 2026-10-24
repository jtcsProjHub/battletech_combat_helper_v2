import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Lance Builder route. The body is a placeholder until the browser,
/// preview, and roster widgets exist.
class LanceBuilderScreen extends StatelessWidget {
  const LanceBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LANCE BUILDER')),
      body: const Center(
        child: Text(
          'Lance Builder goes here.',
          style: TextStyle(color: AppColors.textDim, fontSize: 16),
        ),
      ),
    );
  }
}

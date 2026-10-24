import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Stand-in for a route that is not built yet. The back button returns to
/// the main menu.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title.toUpperCase())),
      body: const Center(
        child: Text(
          'Not built yet.',
          style: TextStyle(color: AppColors.textDim, fontSize: 16),
        ),
      ),
    );
  }
}

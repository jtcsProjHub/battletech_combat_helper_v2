import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../mech_library.dart';

/// Lance Builder route. The body is a placeholder until the browser,
/// preview, and roster widgets exist.
class LanceBuilderScreen extends ConsumerWidget {
  const LanceBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(mechLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('LANCE BUILDER')),
      body: Center(
        child: library.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Text(
            'Could not load mech data: $error',
            style: const TextStyle(color: AppColors.textDim, fontSize: 16),
          ),
          data: (library) => Text(
            'Lance Builder goes here (${library.mechs.length} mechs loaded).',
            style: const TextStyle(color: AppColors.textDim, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

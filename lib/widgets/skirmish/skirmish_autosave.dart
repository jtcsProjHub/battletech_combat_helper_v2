// File: lib/widgets/skirmish/skirmish_autosave.dart
// Saves the skirmish a screen is showing when the app is closed.
// Back navigation saves through the screen's own PopScope
// handler, which calls saveSkirmish.

import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../skirmish/skirmish.dart';
import '../../skirmish/skirmish_repository.dart';

mixin SkirmishAutosave<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final AppLifecycleListener _lifecycle;

  /// The skirmish to save.
  Skirmish get skirmish;

  /// False skips the save, e.g. for a new skirmish with nothing picked yet.
  bool get worthSaving => true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await saveSkirmish();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Writes the skirmish. Returns the error, or null on success or when
  /// there was nothing worth saving.
  Future<Object?> saveSkirmish() async {
    if (!worthSaving) return null;
    try {
      await ref.read(savedSkirmishesProvider.notifier).save(skirmish);
      return null;
    } on Object catch (e) {
      debugPrint('Could not save skirmish ${skirmish.id}: $e');
      return e;
    }
  }
}

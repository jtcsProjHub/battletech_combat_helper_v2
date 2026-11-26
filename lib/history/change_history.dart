// File: lib/history/change_history.dart
// An undo/redo history of labeled changes. Generic and free of Flutter and
// skirmish types, so the same mechanism can back lance balancing in setup
// now and the game log during play later: the log is the [entries], and
// undo walks back along them.
//
// T is whatever is cheap to keep for a change. For immutable values (a
// Lance) that is the value itself; for mutable game state it can be a
// snapshot or an event that knows how to reverse itself.

/// One change: what it was called and the state before and after it.
class Change<T> {
  const Change({
    required this.label,
    required this.before,
    required this.after,
  });

  /// Short description, e.g. "Atlas AS7-D → AS7-K". Shown on the undo and
  /// redo buttons and, later, as the log line.
  final String label;

  final T before;
  final T after;

  @override
  String toString() => 'Change($label)';
}

class ChangeHistory<T> {
  ChangeHistory({this.limit}) : assert(limit == null || limit > 0);

  /// The most changes kept; the oldest are dropped past it. Null keeps all.
  final int? limit;

  final List<Change<T>> _done = [];
  final List<Change<T>> _undone = [];

  /// The changes in effect, oldest first.
  List<Change<T>> get entries => List.unmodifiable(_done);

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;

  /// What [undo] would revert, or null.
  Change<T>? get nextUndo => _done.isEmpty ? null : _done.last;

  /// What [redo] would reapply, or null.
  Change<T>? get nextRedo => _undone.isEmpty ? null : _undone.last;

  /// Adds a change that was just made. Anything undone is no longer
  /// redoable.
  void record(Change<T> change) {
    _done.add(change);
    _undone.clear();
    final max = limit;
    if (max != null && _done.length > max) _done.removeAt(0);
  }

  /// Takes back the latest change and returns it, so the caller can restore
  /// its [Change.before]. Null when there is nothing to undo.
  Change<T>? undo() {
    if (_done.isEmpty) return null;
    final change = _done.removeLast();
    _undone.add(change);
    return change;
  }

  /// Reapplies the latest undone change and returns it, so the caller can
  /// restore its [Change.after]. Null when there is nothing to redo.
  Change<T>? redo() {
    if (_undone.isEmpty) return null;
    final change = _undone.removeLast();
    _done.add(change);
    return change;
  }

  void clear() {
    _done.clear();
    _undone.clear();
  }
}

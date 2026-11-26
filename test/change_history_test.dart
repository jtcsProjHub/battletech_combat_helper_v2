import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/history/change_history.dart';

Change<int> _change(int from, int to) =>
    Change(label: '$from → $to', before: from, after: to);

void main() {
  test('undo and redo walk back and forth along the changes', () {
    final h = ChangeHistory<int>();
    expect(h.canUndo, isFalse);
    expect(h.undo(), isNull);

    h
      ..record(_change(0, 1))
      ..record(_change(1, 2));
    expect(h.nextUndo!.label, '1 → 2');
    expect(h.entries.map((c) => c.after), [1, 2]);

    expect(h.undo()!.before, 1);
    expect(h.undo()!.before, 0);
    expect(h.canUndo, isFalse);
    expect(h.nextRedo!.label, '0 → 1');

    expect(h.redo()!.after, 1);
    expect(h.entries.map((c) => c.after), [1]);
    expect(h.nextRedo!.label, '1 → 2');
  });

  test('a new change after an undo drops the redo', () {
    final h = ChangeHistory<int>()
      ..record(_change(0, 1))
      ..record(_change(1, 2));
    h.undo();
    h.record(_change(1, 5));
    expect(h.canRedo, isFalse);
    expect(h.entries.map((c) => c.after), [1, 5]);
  });

  test('the limit drops the oldest changes', () {
    final h = ChangeHistory<int>(limit: 2)
      ..record(_change(0, 1))
      ..record(_change(1, 2))
      ..record(_change(2, 3));
    expect(h.entries.map((c) => c.label), ['1 → 2', '2 → 3']);
  });

  test('clear forgets everything', () {
    final h = ChangeHistory<int>()..record(_change(0, 1));
    h.undo();
    h.clear();
    expect(h.canUndo || h.canRedo, isFalse);
  });
}

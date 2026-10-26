import 'package:flutter_test/flutter_test.dart';
import 'package:battletech_combat_helper_v2/location.dart';

void main() {
  group('Location', () {
    test('codes, crit keys, and labels are unique', () {
      expect(Location.values.map((l) => l.code).toSet(), hasLength(Location.values.length));
      expect(Location.values.map((l) => l.critKey).toSet(), hasLength(Location.values.length));
      expect(Location.values.map((l) => l.label).toSet(), hasLength(Location.values.length));
    });

    test('every location round-trips through each lookup', () {
      for (final location in Location.values) {
        expect(Location.fromCode(location.code), location);
        expect(Location.fromCritKey(location.critKey), location);
        expect(Location.fromLabel(location.label), location);
      }
    });

    test('fromCode ignores case and whitespace', () {
      expect(Location.fromCode(' la '), Location.leftArm);
    });

    test('lookups return null for unknown or empty input', () {
      expect(Location.fromCode('R'), Location.invalid);
      expect(Location.fromCode(null), Location.invalid);
      expect(Location.fromCritKey('crit_right_side'), Location.invalid);
      expect(Location.fromLabel(''), Location.invalid);
    });
  });
}

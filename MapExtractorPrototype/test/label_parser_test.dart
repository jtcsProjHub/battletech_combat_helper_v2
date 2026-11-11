import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

void main() {
  group('parseHexId', () {
    test('reads plain and confusable ids', () {
      expect(LabelParser.parseHexId('0412'), const HexCoord(4, 12));
      expect(LabelParser.parseHexId('O4I2'), const HexCoord(4, 12));
      expect(LabelParser.parseHexId('04 12'), const HexCoord(4, 12));
    });
    test('rejects other text', () {
      expect(LabelParser.parseHexId('LEVEL1'), isNull);
      expect(LabelParser.parseHexId('0400'), isNull);
      expect(LabelParser.parseHexId('041'), isNull);
    });
  });

  group('parseLabel', () {
    // These OCR strings came from the Foothills #1 test scans.
    final cases = <String, String>{
      'LIGHT': 'LIGHT',
      'LIGHI': 'LIGHT',
      'HEAVV': 'HEAVY',
      'ROUCH': 'ROUGH',
      'LEVEL1': 'LEVEL 1',
      'LEVEL 2': 'LEVEL 2',
      'LEVEI 3': 'LEVEL 3',
      'DEVEL1': 'LEVEL 1',
      'LEVEL1-': 'LEVEL 1',
    };
    cases.forEach((input, expected) {
      test('$input -> $expected (certain)', () {
        final t = LabelParser.parseLabel(input).single;
        expect(t.key, expected);
        expect(t.certain, isTrue);
      });
    });

    test('a letter in place of the digit is a guess', () {
      final t = LabelParser.parseLabel('LEVELB').single;
      expect(t.key, 'LEVEL 8');
      expect(t.certain, isFalse);
      expect(LabelParser.parseLabel('LEVELT').single.certain, isFalse);
    });

    test('a missing digit is unknown, not LEVEL 4', () {
      final t = LabelParser.parseLabel('LEVEL').single;
      expect(t.key, 'LEVEL ?');
      expect(t.isUnknownNumber, isTrue);
      expect(t.certain, isFalse);
    });

    test('negative levels are kept but flagged', () {
      final t = LabelParser.parseLabel('LEVEL -1').single;
      expect(t.number, -1);
      expect(t.certain, isFalse);
    });

    test('non-terrain text gives no tokens', () {
      expect(LabelParser.parseLabel('BATTLETECH'), isEmpty);
      expect(LabelParser.parseLabel('0412'), isEmpty);
      expect(LabelParser.parseLabel('A'), isEmpty);
    });
  });
}

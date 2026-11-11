import '../model/hex_coord.dart';

/// One terrain token read from the map, for example LEVEL 2 or LIGHT.
class LabelToken {
  const LabelToken(this.word, {this.number, this.certain = true});

  /// Canonical word from [LabelParser.words].
  final String word;

  /// Value for LEVEL and DEPTH. Null when the digit could not be read.
  final int? number;

  /// False when the value is a guess: the digit came from a letter
  /// substitution (B -> 8), is missing, or is negative.
  final bool certain;

  bool get isNumbered => LabelParser.numbered.contains(word);
  bool get isUnknownNumber => isNumbered && number == null;

  /// Voting key, for example "LEVEL 2", "LEVEL ?" or "LIGHT".
  String get key => isNumbered ? '$word ${number ?? '?'}' : word;

  @override
  bool operator ==(Object other) =>
      other is LabelToken && other.key == key && other.certain == certain;

  @override
  int get hashCode => Object.hash(key, certain);

  @override
  String toString() => certain ? key : '$key (uncertain)';
}

/// Parses OCR text into hex ids and terrain tokens.
///
/// The map vocabulary is small, so the parser matches each text against a
/// fixed word list with a Levenshtein ratio of at least 0.8.
abstract final class LabelParser {
  static const words = [
    'LIGHT', 'HEAVY', 'ULTRA', 'ROUGH', 'RUBBLE', 'LEVEL', 'DEPTH', 'WATER',
    'BUILDING', 'PAVEMENT', 'PAVED', 'ROAD', 'SWAMP', 'SAND', 'ICE', 'BRIDGE',
  ];
  static const numbered = {'LEVEL', 'DEPTH'};

  /// Letters that OCR returns in place of a digit after LEVEL or DEPTH.
  static const digitFix = {
    'I': '1', 'L': '1', 'T': '1', '|': '1', 'Z': '2', 'S': '5', 'O': '0',
    'B': '8', 'G': '6',
  };

  /// Letters that OCR returns in place of a digit inside a hex number.
  static const idFix = {
    'O': '0', 'D': '0', 'I': '1', 'L': '1', '|': '1', 'Z': '2', 'S': '5',
    'B': '8',
  };

  static final _space = RegExp(r'\s');
  static final _labelChars = RegExp(r'[^A-Z0-9|\-]');

  /// Parses a printed hex number such as "0412".
  static HexCoord? parseHexId(String text, {int maxCol = 99, int maxRow = 99}) {
    final t = text.toUpperCase().replaceAll(_space, '');
    if (t.length != 4) return null;
    final fixed = t.split('').map((c) => idFix[c] ?? c).join();
    if (!RegExp(r'^\d{4}$').hasMatch(fixed)) return null;
    final c = int.parse(fixed.substring(0, 2));
    final r = int.parse(fixed.substring(2));
    if (c < 1 || c > maxCol || r < 1 || r > maxRow) return null;
    return HexCoord(c, r);
  }

  /// Parses one OCR text into terrain tokens. Returns an empty list when
  /// the text is not a terrain label.
  static List<LabelToken> parseLabel(String text) {
    final compact = text.toUpperCase().replaceAll(_labelChars, '');
    for (final word in words) {
      for (final n in [word.length, word.length - 1, word.length + 1]) {
        final end = n < compact.length ? n : compact.length;
        final head = compact.substring(0, end);
        var tail = compact.substring(end);
        if (head.length < 3) continue;
        if (similarity(head, word) < 0.8) continue;
        if (!numbered.contains(word)) return [LabelToken(word)];
        final negative = tail.startsWith('-');
        while (tail.startsWith('-')) {
          tail = tail.substring(1);
        }
        final ch = tail.isEmpty ? '' : tail[0];
        final sign = negative ? -1 : 1;
        if (ch.isNotEmpty && _isDigit(ch)) {
          return [LabelToken(word, number: sign * int.parse(ch), certain: !negative)];
        }
        final sub = digitFix[ch];
        if (sub != null) {
          return [LabelToken(word, number: sign * int.parse(sub), certain: false)];
        }
        return [LabelToken(word, certain: false)];
      }
    }
    return const [];
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }

  /// Levenshtein ratio: 1 - distance / max(length).
  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    final longest = a.length > b.length ? a.length : b.length;
    return 1.0 - prev[b.length] / longest;
  }
}

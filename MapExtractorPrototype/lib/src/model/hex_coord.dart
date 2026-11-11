/// A hex on a BattleTech map sheet, in the printed CCRR numbering.
///
/// Columns and rows start at 1. Even-numbered columns sit half a hex lower
/// than odd-numbered columns, as on the printed sheets.
class HexCoord implements Comparable<HexCoord> {
  const HexCoord(this.col, this.row);

  final int col;
  final int row;

  /// Parses "0412" into column 4, row 12. Returns null for anything else.
  static HexCoord? tryParse(String id) {
    if (id.length != 4) return null;
    final c = int.tryParse(id.substring(0, 2));
    final r = int.tryParse(id.substring(2));
    if (c == null || r == null || c < 1 || r < 1) return null;
    return HexCoord(c, r);
  }

  /// The printed four-digit id, for example "0412".
  String get id =>
      '${col.toString().padLeft(2, '0')}${row.toString().padLeft(2, '0')}';

  bool get isEvenColumn => col.isEven;

  /// Position of the printed hex number in grid space.
  ///
  /// Grid space uses one unit per column and one unit per row. The
  /// extractor fits a homography from this space to image pixels.
  (double, double) get numberPoint =>
      (col.toDouble(), row + (isEvenColumn ? 0.5 : 0.0));

  bool isInside(int columns, int rows) =>
      col >= 1 && col <= columns && row >= 1 && row <= rows;

  @override
  int compareTo(HexCoord other) =>
      col != other.col ? col.compareTo(other.col) : row.compareTo(other.row);

  @override
  bool operator ==(Object other) =>
      other is HexCoord && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => id;
}

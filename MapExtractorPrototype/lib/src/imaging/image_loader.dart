import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'bgr_image.dart';

/// Loads a photo or a scanned PDF into a [BgrImage].
///
/// Photos: JPEG or PNG, with the EXIF orientation applied.
/// PDFs: the largest embedded JPEG (DCTDecode) image is used. Phone scanner
/// apps, including the ML Kit document scanner, write PDFs this way. Vector
/// PDFs are not supported yet. Rendering them needs a PDF engine such as
/// pdfrx.
class ImageLoader {
  static BgrImage load(Uint8List bytes) {
    final jpeg = isPdf(bytes) ? largestEmbeddedJpeg(bytes) : bytes;
    if (jpeg == null) {
      throw const FormatException(
          'The PDF has no embedded JPEG image. Export it as a photo or JPEG.');
    }
    var decoded = img.decodeImage(jpeg);
    if (decoded == null) {
      throw const FormatException('The file is not a supported image.');
    }
    decoded = img.bakeOrientation(decoded);
    if (decoded.hasPalette ||
        decoded.numChannels != 3 ||
        decoded.format != img.Format.uint8) {
      decoded = decoded.convert(format: img.Format.uint8, numChannels: 3);
    }
    final bgr = decoded.getBytes(order: img.ChannelOrder.bgr);
    return BgrImage(decoded.width, decoded.height, Uint8List.fromList(bgr));
  }

  static bool isPdf(Uint8List b) =>
      b.length > 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46;

  /// Returns the bytes of the largest DCTDecode stream, or null.
  static Uint8List? largestEmbeddedJpeg(Uint8List pdf) {
    const filter = '/DCTDecode';
    Uint8List? best;
    var from = 0;
    while (true) {
      final f = _indexOf(pdf, filter, from);
      if (f < 0) break;
      from = f + filter.length;
      var s = _indexOf(pdf, 'stream', from);
      if (s < 0) break;
      s += 'stream'.length;
      if (s + 1 < pdf.length && pdf[s] == 0x0D && pdf[s + 1] == 0x0A) {
        s += 2;
      } else if (s < pdf.length && (pdf[s] == 0x0A || pdf[s] == 0x0D)) {
        s += 1;
      }
      final e = _indexOf(pdf, 'endstream', s);
      if (e < 0) break;
      if (pdf[s] != 0xFF || pdf[s + 1] != 0xD8) continue;
      // Trim to the last end-of-image marker inside the stream.
      var end = e;
      for (var i = e - 2; i > s; i--) {
        if (pdf[i] == 0xFF && pdf[i + 1] == 0xD9) {
          end = i + 2;
          break;
        }
      }
      if (best == null || end - s > best.length) {
        best = Uint8List.sublistView(pdf, s, end);
      }
    }
    return best == null ? null : Uint8List.fromList(best);
  }

  static int _indexOf(Uint8List hay, String needle, int from) {
    final n = needle.codeUnits;
    final last = hay.length - n.length;
    outer:
    for (var i = from; i <= last; i++) {
      for (var j = 0; j < n.length; j++) {
        if (hay[i + j] != n[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}

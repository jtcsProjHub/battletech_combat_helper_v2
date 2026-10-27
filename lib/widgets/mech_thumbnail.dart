// File: lib/widgets/mech_thumbnail.dart
// A mech's line-art thumbnail from assets/thumbnails, drawn as light lines on
// a transparent background so it reads on the dark panels.

import 'package:flutter/material.dart';

class MechThumbnail extends StatelessWidget {
  const MechThumbnail({
    super.key,
    required this.mechId,
    required this.width,
    required this.height,
  });

  final String mechId;
  final double width;
  final double height;

  static String assetPath(String mechId) => 'assets/thumbnails/$mechId.png';

  /// The source art is black lines on white. This keeps a fixed light color
  /// and turns darkness into opacity: white becomes transparent, black opaque.
  static const _lineArt = ColorFilter.matrix(<double>[
    0, 0, 0, 0, 220, //
    0, 0, 0, 0, 226, //
    0, 0, 0, 0, 232, //
    -0.2126, -0.7152, -0.0722, 0, 255,
  ]);

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ColorFiltered(
          colorFilter: _lineArt,
          child: Image.asset(
            assetPath(mechId),
            width: width,
            height: height,
            fit: BoxFit.contain,
            // The source files are about 1800 x 2400; decode at display size.
            cacheHeight: (height * dpr).round(),
            // Black draws as the light line color through the filter above.
            errorBuilder: (context, error, stack) => Icon(
              Icons.smart_toy_outlined,
              size: height * 0.5,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

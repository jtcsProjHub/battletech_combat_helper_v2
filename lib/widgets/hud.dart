// File: lib/widgets/hud.dart
// Shared pieces of the HUD look used by the menu-style screens: the numbered
// menu button, the bracketed panel frame, the hazard stripe, and text styles.

import 'package:flutter/material.dart';

import '../app_theme.dart';

class HudText {
  HudText._();

  /// Small accent label above a screen title, e.g. "MAIN MENU".
  static const eyebrow = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.3,
    color: AppColors.accent,
  );

  /// Large screen title, e.g. "SELECT OPERATION".
  static const title = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.05,
    color: AppColors.text,
  );

  /// Dim section label inside a panel, e.g. "WORKFLOW".
  static const sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    color: AppColors.textDim,
  );

  /// Accent heading at the top of a panel.
  static const panelTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color: AppColors.accent,
  );
}

/// Eyebrow, title, and hazard stripe stacked at the top of a menu column.
class HudTitleBlock extends StatelessWidget {
  const HudTitleBlock({super.key, required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(eyebrow.toUpperCase(), style: HudText.eyebrow),
        const SizedBox(height: 6),
        Text(title.toUpperCase(), style: HudText.title),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: HazardStripe(width: 160, height: 6),
        ),
      ],
    );
  }
}

/// Numbered menu button with an accent bar on the left when [active].
/// [onActivate] runs on hover and focus. Leave it null when hover must not
/// change the selection.
class HudMenuButton extends StatelessWidget {
  const HudMenuButton({
    super.key,
    required this.number,
    required this.label,
    required this.active,
    required this.onTap,
    this.onActivate,
  });

  final int number;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final edge = active ? AppColors.borderStrong : AppColors.border;
    final activate = onActivate;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: active ? AppColors.panelActive : AppColors.panel,
        child: InkWell(
          onTap: onTap,
          onHover: activate == null
              ? null
              : (hovering) {
                  if (hovering) activate();
                },
          onFocusChange: activate == null
              ? null
              : (focused) {
                  if (focused) activate();
                },
          hoverColor: AppColors.panelActive,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: active ? AppColors.accent : edge,
                  width: 4,
                ),
                top: BorderSide(color: edge),
                right: BorderSide(color: edge),
                bottom: BorderSide(color: edge),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    number.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_double_arrow_right,
                  color: active ? AppColors.accent : AppColors.iconDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel with a thin border and accent brackets on the four corners.
/// The frame passes its constraints to [child], so it fills a fixed-height
/// slot or shrinks to its content in a scrolling column.
class HudFrame extends StatelessWidget {
  const HudFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(36, 32, 36, 32),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
        const Positioned(
          left: -1,
          top: -1,
          child: _Corner(left: true, top: true),
        ),
        const Positioned(
          right: -1,
          top: -1,
          child: _Corner(left: false, top: true),
        ),
        const Positioned(
          left: -1,
          bottom: -1,
          child: _Corner(left: true, top: false),
        ),
        const Positioned(
          right: -1,
          bottom: -1,
          child: _Corner(left: false, top: false),
        ),
      ],
    );
  }
}

/// L-shaped accent bracket drawn on one corner of a [HudFrame].
class _Corner extends StatelessWidget {
  const _Corner({required this.left, required this.top});

  final bool left;
  final bool top;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.accent, width: 2);
    return IgnorePointer(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          border: Border(
            left: left ? side : BorderSide.none,
            right: left ? BorderSide.none : side,
            top: top ? side : BorderSide.none,
            bottom: top ? BorderSide.none : side,
          ),
        ),
      ),
    );
  }
}

/// Diagonal accent stripes, used under screen titles.
class HazardStripe extends StatelessWidget {
  const HazardStripe({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const CustomPaint(painter: _HazardStripePainter()),
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  const _HazardStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accent;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    const stripe = 6.0;
    for (var x = -size.height; x < size.width + size.height; x += stripe * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + stripe, 0)
        ..lineTo(x + stripe, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

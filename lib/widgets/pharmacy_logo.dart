import 'package:flutter/material.dart';

/// Pharmacy logo: white "+" cross inside a rounded box.
/// Matches the universal pharmacy cross symbol used on Algerian pharmacy signs.
class PharmacyLogo extends StatelessWidget {
  final double size;
  final Color bgColor;
  final Color symbolColor;
  final bool showBackground;
  final double? borderRadius;

  const PharmacyLogo({
    super.key,
    this.size = 44,
    this.bgColor = const Color(0xFF2EB15B),
    this.symbolColor = Colors.white,
    this.showBackground = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? size * 0.22;
    final crossThickness = size * 0.18;
    final crossLength    = size * 0.54;

    return Container(
      width: size,
      height: size,
      decoration: showBackground
          ? BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(br),
            )
          : null,
      child: Center(
        child: SizedBox(
          width: crossLength,
          height: crossLength,
          child: CustomPaint(
            painter: _CrossPainter(
              color: symbolColor,
              thickness: crossThickness,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final Color color;
  final double thickness;
  const _CrossPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final r = thickness / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: size.width, height: thickness),
        Radius.circular(r),
      ),
      paint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: thickness, height: size.height),
        Radius.circular(r),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) => 
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}

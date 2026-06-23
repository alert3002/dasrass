import 'package:flutter/material.dart';

/// Лупа outline — мисли [Layout.jsx] header-search-cta-icon (viewBox 0 0 24 24).
class DastrassHeaderSearchIcon extends StatelessWidget {
  const DastrassHeaderSearchIcon({super.key, this.color = const Color(0xFF111111), this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SearchOutlinePainter(color: color),
    );
  }
}

class _SearchOutlinePainter extends CustomPainter {
  _SearchOutlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * (1.75 / 24)
      ..strokeCap = StrokeCap.round;

    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawCircle(const Offset(10.5, 10.5), 6.75, paint);
    canvas.drawLine(const Offset(15.8, 15.8), const Offset(20, 20), paint);
  }

  @override
  bool shouldRepaint(covariant _SearchOutlinePainter old) => old.color != color;
}

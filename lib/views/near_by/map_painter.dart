import 'package:flutter/material.dart';

import '../../theme.dart';

/// A lightweight stand-in "map" — colored blocks + pins — since there's no
/// maps SDK wired into this project yet.
class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFE8ECEE));
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6;
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.3), roadPaint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.55, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.8), roadPaint);

    final pins = [
      Offset(size.width * 0.3, size.height * 0.3),
      Offset(size.width * 0.55, size.height * 0.5),
      Offset(size.width * 0.7, size.height * 0.25),
      Offset(size.width * 0.2, size.height * 0.65),
      Offset(size.width * 0.8, size.height * 0.7),
    ];
    final colors = [Colors.redAccent, Colors.orange, Colors.blue, Colors.green, Colors.purple];
    for (var i = 0; i < pins.length; i++) {
      canvas.drawCircle(pins[i], 8, Paint()..color = colors[i % colors.length]);
      canvas.drawCircle(pins[i], 8, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      9,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

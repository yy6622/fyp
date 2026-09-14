import 'package:flutter/material.dart';

/// A simple two-color donut: [fraction] (0..1) of the circle is "settled"
/// (green), the rest "outstanding" (pink) — driven by real expense totals
/// from [ExpensesTabController], not a fixed split.
class PiePainter extends CustomPainter {
  final double fraction;
  const PiePainter({this.fraction = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paintGreen = Paint()..color = const Color(0xFF6FCF97);
    final paintPink = Paint()..color = const Color(0xFFE0708A);
    const total = 6.28318530718; // 2*pi
    final splitAt = fraction.clamp(0.0, 1.0) * total;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708, splitAt, true, paintGreen);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708 + splitAt, total - splitAt, true, paintPink);
  }

  @override
  bool shouldRepaint(covariant PiePainter oldDelegate) => oldDelegate.fraction != fraction;
}

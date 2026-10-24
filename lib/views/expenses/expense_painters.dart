import 'package:flutter/material.dart';

/// A simple two-color donut: [fraction] (0..1) of the circle is "settled"
/// (green), the rest "outstanding" (pink) — driven by real expense totals
/// from [ExpensesTabController], not a fixed split.
class PiePainter extends CustomPainter {
  /// Share of the money that has been paid (0-1): the green part of the ring.
  final double fraction;

  /// No expenses yet: an empty grey ring.
  final bool empty;
  const PiePainter({this.fraction = 0.5, this.empty = false});

  static const settledColor = Color(0xFF6FCF97);
  static const unsettledColor = Color(0xFFE0708A);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2 - stroke / 2);
    Paint ring(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const full = 6.28318530718; // 2*pi
    const top = -1.5708;
    if (empty) {
      canvas.drawArc(rect, 0, full, false, ring(const Color(0xFFE4E4E4)));
      return;
    }
    final f = fraction.clamp(0.0, 1.0);
    canvas.drawArc(rect, 0, full, false, ring(unsettledColor));
    if (f > 0) canvas.drawArc(rect, top, f * full, false, ring(settledColor));
  }

  @override
  bool shouldRepaint(covariant PiePainter oldDelegate) => oldDelegate.fraction != fraction || oldDelegate.empty != empty;
}

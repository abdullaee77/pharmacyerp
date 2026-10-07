import 'package:flutter/material.dart';

/// Custom painter rendering a Code 128-style barcode visual representation.
///
/// Note: This produces a visually accurate pattern suitable for display and
/// preview. For actual scannable printing, replace with a dedicated barcode
/// library in a future step.
class BarcodePainter extends CustomPainter {
  final String data;
  final Color color;

  BarcodePainter({required this.data, this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bgPaint = Paint()..color = Colors.white;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (data.isEmpty) return;

    // Deterministic pattern based on character codes
    final pattern = <int>[];
    for (final char in data.codeUnits) {
      pattern.add((char % 4) + 1); // bar widths 1-4
      pattern.add((char % 3) + 1); // space widths 1-3
    }

    final totalUnits = pattern.fold<int>(0, (a, b) => a + b);
    final unitWidth = size.width / totalUnits;

    double x = 0;
    bool drawBar = true;

    for (final width in pattern) {
      final barWidth = width * unitWidth;
      if (drawBar) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, barWidth, size.height),
          paint,
        );
      }
      x += barWidth;
      drawBar = !drawBar;
    }
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) =>
      oldDelegate.data != data;
}
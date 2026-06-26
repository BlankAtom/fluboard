import 'package:flutter/material.dart';

import 'board_models.dart';

/// Draws an "infinite" dotted/lined grid background. It only paints the cells
/// that fall inside the currently visible scene rectangle, so it stays cheap
/// no matter how far the user pans.
class GridPainter extends CustomPainter {
  GridPainter({
    required this.viewport,
    this.step = 48,
    this.color = const Color(0xFFE3E6EC),
  });

  /// Visible region in board (scene) coordinates.
  final Rect viewport;
  final double step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final startX = (viewport.left / step).floor() * step;
    final startY = (viewport.top / step).floor() * step;

    for (double x = startX; x <= viewport.right; x += step) {
      canvas.drawLine(
        Offset(x, viewport.top),
        Offset(x, viewport.bottom),
        paint,
      );
    }
    for (double y = startY; y <= viewport.bottom; y += step) {
      canvas.drawLine(
        Offset(viewport.left, y),
        Offset(viewport.right, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter old) =>
      old.viewport != viewport || old.step != step || old.color != color;
}

/// Renders every freehand [StrokeItem] on the board.
class StrokePainter extends CustomPainter {
  StrokePainter({required this.strokes, required this.repaint})
      : super(repaint: repaint);

  final List<StrokeItem> strokes;
  final Listenable repaint;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        final dot = Paint()
          ..color = stroke.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, dot);
        continue;
      }

      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter old) => false;
}

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Seçili Karoyu veya Binanın Footprint Tabanını Gösteren Vurgu Katmanı
class IsometricSelectionHighlight extends PositionComponent {
  final double tileW;
  final double tileH;
  bool isVisible = false;
  int footprintCols = 1;
  int footprintRows = 1;

  IsometricSelectionHighlight({required this.tileW, required this.tileH})
      : super(
          anchor: Anchor.center,
          priority: 99999, // Her zaman sahnedeki tüm öğelerin üstünde görünür
        );

  /// Seçim vurgusunu verilen merkez ve footprint boyutuna göre konumlandırır
  void updateHighlight({
    required Vector2 centerPos,
    int cols = 1,
    int rows = 1,
    bool visible = true,
  }) {
    position = centerPos;
    footprintCols = cols;
    footprintRows = rows;
    isVisible = visible;
  }

  void hide() {
    isVisible = false;
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;
    super.render(canvas);

    final hw = tileW / 2;
    final hh = tileH / 2;

    // footprintCols x footprintRows taban elması (merkeze göre yerel köşe noktaları)
    final north = Offset((-footprintCols + footprintRows) * (hw / 2), (-footprintCols - footprintRows) * (hh / 2));
    final east = Offset((footprintCols + footprintRows) * (hw / 2), (footprintCols - footprintRows) * (hh / 2));
    final south = Offset((footprintCols - footprintRows) * (hw / 2), (footprintCols + footprintRows) * (hh / 2));
    final west = Offset((-footprintCols - footprintRows) * (hw / 2), (-footprintCols + footprintRows) * (hh / 2));

    final path = Path()
      ..moveTo(north.dx, north.dy)
      ..lineTo(east.dx, east.dy)
      ..lineTo(south.dx, south.dy)
      ..lineTo(west.dx, west.dy)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFFE2B755).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFFFF0B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }
}

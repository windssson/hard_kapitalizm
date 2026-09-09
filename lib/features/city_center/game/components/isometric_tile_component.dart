import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 2:1 İzometrik Zemin Karo Bileşeni (Elmas Şeklinde Zemin Parçası)
class IsometricTileComponent extends PositionComponent {
  final int col;
  final int row;
  final double tileWidth;
  final double tileHeight;

  IsometricTileComponent({
    required this.col,
    required this.row,
    required Vector2 position,
    required this.tileWidth,
    required this.tileHeight,
    required int priority,
  }) : super(
          position: position,
          size: Vector2(tileWidth, tileHeight),
          anchor: Anchor.center,
          priority: priority,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final hw = tileWidth / 2;
    final hh = tileHeight / 2;

    // 2:1 Tam Elmas Yolu (Diamond)
    final path = Path()
      ..moveTo(hw, 0)
      ..lineTo(tileWidth, hh)
      ..lineTo(hw, tileHeight)
      ..lineTo(0, hh)
      ..close();

    // Dama deseni ile derinlik algısı
    final isEven = (col + row) % 2 == 0;
    final baseColor = isEven ? const Color(0xFF15261F) : const Color(0xFF111E19);

    final fillPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF223C30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }
}

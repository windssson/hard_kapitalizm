import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/features/city_center/game/city_center_grid.dart';

/// 2:1 İzometrik Çoklu Karo (Footprint) Destekli 2.5D Bina Modeli (Sprite & Prosedürel)
class IsometricBuildingComponent extends PositionComponent {
  final int col;
  final int row;
  final int footprintCols;
  final int footprintRows;
  final String buildingName;
  final Sprite? sprite;
  final Color wallColor;
  final Color roofColor;
  final double wallHeight;
  final CityCenterGrid grid;

  // Taban ve çatı yerel poligon noktaları
  late Offset localSouth;
  late Offset localWest;
  late Offset localEast;
  late Offset localNorth;

  late Offset roofSouth;
  late Offset roofWest;
  late Offset roofEast;
  late Offset roofNorth;

  late Path _visualPolygon;
  Rect? _spriteDrawRect;

  /// Binanın sol-üst kök hücresi
  math.Point<int> get rootCell => math.Point<int>(col, row);

  /// Binanın kapladığı tüm grid hücreleri
  List<math.Point<int>> get coveredCells {
    final list = <math.Point<int>>[];
    for (int c = col; c < col + footprintCols; c++) {
      for (int r = row; r < row + footprintRows; r++) {
        list.add(math.Point<int>(c, r));
      }
    }
    return list;
  }

  /// Verilen hücrenin bu binanın footprint alanında olup olmadığını denetler
  bool coversCell(int c, int r) {
    return c >= col && c < col + footprintCols && r >= row && r < row + footprintRows;
  }

  /// Binanın footprint tabanının merkez dünya koordinatı
  Vector2 get baseCenterWorld {
    return grid.getFootprintCenterPos(col, row, footprintCols, footprintRows);
  }

  IsometricBuildingComponent({
    required this.col,
    required this.row,
    required this.footprintCols,
    required this.footprintRows,
    required Vector2 position,
    required this.buildingName,
    this.sprite,
    required int priority,
    this.wallColor = const Color(0xFF2C3E50),
    this.roofColor = const Color(0xFFE2B755),
    this.wallHeight = 28.0,
    this.grid = const CityCenterGrid(),
  }) : super(
          position: position,
          // Zemine basan alt-orta nokta: Anchor.bottomCenter
          anchor: Anchor.bottomCenter,
          priority: priority,
        ) {
    final double hw = grid.tileW / 2;
    final double hh = grid.tileH / 2;

    // Taban genişliği ve dikey yükseklik
    final totalW = (footprintCols + footprintRows) * hw;
    final totalH = (footprintCols + footprintRows) * hh + wallHeight;

    double compH = totalH;
    if (sprite != null) {
      final double ar = sprite!.srcSize.x / sprite!.srcSize.y;
      final double spriteW = totalW;
      final double spriteH = spriteW / ar;
      compH = math.max(compH, spriteH);
    }
    size = Vector2(totalW, compH);

    // Taban köşe noktaları (Anchor.bottomCenter = (footprintCols * hw, compH))
    localSouth = Offset(footprintCols * hw, compH);
    localWest = Offset(0, compH - footprintCols * hh);
    localEast = Offset(totalW, compH - footprintRows * hh);
    localNorth = Offset(footprintRows * hw, compH - (footprintCols + footprintRows) * hh);

    // Çatı köşe noktaları (duvar yüksekliği kadar yukarı ötelenmiş)
    roofSouth = localSouth.translate(0, -wallHeight);
    roofWest = localWest.translate(0, -wallHeight);
    roofEast = localEast.translate(0, -wallHeight);
    roofNorth = localNorth.translate(0, -wallHeight);

    // Görsel tıklama alanı (Çatı + Sol Duvar + Sağ Duvar birleşik poligonu)
    _visualPolygon = Path()
      ..moveTo(localWest.dx, localWest.dy)
      ..lineTo(localSouth.dx, localSouth.dy)
      ..lineTo(localEast.dx, localEast.dy)
      ..lineTo(roofEast.dx, roofEast.dy)
      ..lineTo(roofNorth.dx, roofNorth.dy)
      ..lineTo(roofWest.dx, roofWest.dy)
      ..close();

    // Sprite çizim alanı: tabanı tam localSouth (zemin güney ucu) hizasında
    if (sprite != null) {
      final double ar = sprite!.srcSize.x / sprite!.srcSize.y;
      final double spriteW = totalW;
      final double spriteH = spriteW / ar;
      final double drawX = localSouth.dx - (spriteW / 2);
      final double drawY = localSouth.dy - spriteH;
      _spriteDrawRect = Rect.fromLTWH(drawX, drawY, spriteW, spriteH);
    }
  }

  /// Dünya koordinatındaki bir noktanın binanın görsel gövdesine (çatı, duvar veya sprite) denk gelip gelmediğini denetler
  bool containsWorldPoint(Vector2 worldPos) {
    final local = parentToLocal(worldPos);

    if (sprite != null && _spriteDrawRect != null) {
      return _spriteDrawRect!.contains(Offset(local.x, local.y));
    }

    // Hızlı bounding box kontrolü
    if (local.x < 0 || local.x > size.x || local.y < 0 || local.y > size.y) {
      return false;
    }
    // Hassas görsel poligon kontrolü
    return _visualPolygon.contains(Offset(local.x, local.y));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1) Footprint Taban Elması (Zemin Kılavuz Çerçevesi)
    final footprintBase = Path()
      ..moveTo(localNorth.dx, localNorth.dy)
      ..lineTo(localEast.dx, localEast.dy)
      ..lineTo(localSouth.dx, localSouth.dy)
      ..lineTo(localWest.dx, localWest.dy)
      ..close();

    final baseFill = Paint()
      ..color = const Color(0xFFE2B755).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final baseStroke = Paint()
      ..color = const Color(0xFFE2B755).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(footprintBase, baseFill);
    canvas.drawPath(footprintBase, baseStroke);

    // 2) Gerçek PNG/WebP Sprite Çizimi (Varsa)
    if (sprite != null && _spriteDrawRect != null) {
      sprite!.render(
        canvas,
        position: Vector2(_spriteDrawRect!.left, _spriteDrawRect!.top),
        size: Vector2(_spriteDrawRect!.width, _spriteDrawRect!.height),
      );
      return;
    }

    // 3) Prosedürel 2.5D Çizim (Sprite yoksa)
    // Sol Duvar (Güneybatı Yüzü - Gölgeli)
    final leftWall = Path()
      ..moveTo(localWest.dx, localWest.dy)
      ..lineTo(localSouth.dx, localSouth.dy)
      ..lineTo(roofSouth.dx, roofSouth.dy)
      ..lineTo(roofWest.dx, roofWest.dy)
      ..close();

    final leftPaint = Paint()
      ..color = wallColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftWall, leftPaint);

    final leftBorder = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(leftWall, leftBorder);

    // 2) Sağ Duvar (Güneydoğu Yüzü - Aydınlık)
    final rightWall = Path()
      ..moveTo(localSouth.dx, localSouth.dy)
      ..lineTo(localEast.dx, localEast.dy)
      ..lineTo(roofEast.dx, roofEast.dy)
      ..lineTo(roofSouth.dx, roofSouth.dy)
      ..close();

    final rightPaint = Paint()
      ..color = wallColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightWall, rightPaint);

    final rightBorder = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(rightWall, rightBorder);

    // 3) Çatı Yüzeyi (2:1 İzometrik Elmas Tepe)
    final roof = Path()
      ..moveTo(roofNorth.dx, roofNorth.dy)
      ..lineTo(roofEast.dx, roofEast.dy)
      ..lineTo(roofSouth.dx, roofSouth.dy)
      ..lineTo(roofWest.dx, roofWest.dy)
      ..close();

    final roofPaint = Paint()
      ..color = roofColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(roof, roofPaint);

    // Çatı Kenarlık Vurgusu
    final roofBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(roof, roofBorder);

    // Çatı Üzeri Etiket (Bina Adı ve Boyutu)
    final textSpan = TextSpan(
      text: '$buildingName\n${footprintCols}x$footprintRows',
      style: TextStyle(
        color: Colors.white,
        fontSize: math.max(9.0, 7.0 + (footprintCols + footprintRows)),
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4),
        ],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final roofCenter = Offset(
      (roofNorth.dx + roofSouth.dx) / 2 - (textPainter.width / 2),
      (roofNorth.dy + roofSouth.dy) / 2 - (textPainter.height / 2),
    );
    textPainter.paint(canvas, roofCenter);
  }
}

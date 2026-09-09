import 'dart:math' as math;
import 'package:flame/components.dart';

/// 2:1 İzometrik Şehir Izgarası (Matematiksel Koordinat & Derinlik Dönüşümleri)
class CityCenterGrid {
  // 2:1 Standart İzometrik Oran
  final double tileW;
  final double tileH;
  final int gridSize;

  const CityCenterGrid({
    this.tileW = 64.0,
    this.tileH = 32.0,
    this.gridSize = 16,
  });

  /// Grid (col, row) ➔ 2:1 İzometrik Dünya Koordinatı (num destekli, merkez hesaplamaları için)
  Vector2 gridToIso(num col, num row) {
    final x = (col - row) * (tileW / 2);
    final y = (col + row) * (tileH / 2);
    return Vector2(x, y);
  }

  /// 2:1 İzometrik Dünya Koordinatı ➔ Grid (col, row) Ters Dönüşümü
  math.Point<int>? isoToGrid(Vector2 worldPos) {
    final double halfW = tileW / 2;
    final double halfH = tileH / 2;

    final double colFraction = (worldPos.y / halfH + worldPos.x / halfW) / 2;
    final double rowFraction = (worldPos.y / halfH - worldPos.x / halfW) / 2;

    final int col = (colFraction + 0.5).floor();
    final int row = (rowFraction + 0.5).floor();

    if (isWithinBounds(col, row)) {
      return math.Point<int>(col, row);
    }
    return null;
  }

  /// Tek bir hücrenin harita sınırları içinde olup olmadığını denetler
  bool isWithinBounds(int col, int row) {
    return col >= 0 && col < gridSize && row >= 0 && row < gridSize;
  }

  /// Çoklu footprint'e sahip bir binanın tüm hücreleriyle birlikte harita içinde olup olmadığını denetler
  bool isFootprintWithinBounds(int col, int row, int cols, int rows) {
    return col >= 0 &&
        row >= 0 &&
        col + cols <= gridSize &&
        row + rows <= gridSize;
  }

  /// Derinlik / Priority Kuralı (Tek Kural Standardı)
  int getBaseDepth(int col, int row) => (col + row) * 100;

  /// Zemin karosu derinliği (taban seviyesi)
  int getTilePriority(int col, int row) => getBaseDepth(col, row);

  /// Bina derinliği (zeminin üstü: en ön/güney hücreye göre + 50)
  int getBuildingPriority(int col, int row) => getBaseDepth(col, row) + 50;

  /// Footprint tabanının en alt güney ucunun dünya koordinatı (Anchor konumu)
  Vector2 getFootprintBottomAnchorPos(int col, int row, int cols, int rows) {
    final maxCol = col + cols - 1;
    final maxRow = row + rows - 1;
    final bottomX = (maxCol - maxRow) * (tileW / 2);
    final bottomY = (maxCol + maxRow) * (tileH / 2) + (tileH / 2);
    return Vector2(bottomX, bottomY);
  }

  /// Footprint güney köşesi (getFootprintBottomAnchorPos ile birebir aynı)
  Vector2 getFootprintSouthPos(int col, int row, int cols, int rows) =>
      getFootprintBottomAnchorPos(col, row, cols, rows);

  /// Footprint kuzey köşesi (en üst köşe)
  Vector2 getFootprintNorthPos(int col, int row, int cols, int rows) {
    final x = (col - row) * (tileW / 2);
    final y = (col + row) * (tileH / 2) - (tileH / 2);
    return Vector2(x, y);
  }

  /// Footprint doğu köşesi (en sağ köşe)
  Vector2 getFootprintEastPos(int col, int row, int cols, int rows) {
    final maxCol = col + cols - 1;
    final x = (maxCol + 1 - row) * (tileW / 2);
    final y = (maxCol + row) * (tileH / 2);
    return Vector2(x, y);
  }

  /// Footprint batı köşesi (en sol köşe)
  Vector2 getFootprintWestPos(int col, int row, int cols, int rows) {
    final maxRow = row + rows - 1;
    final x = (col - (maxRow + 1)) * (tileW / 2);
    final y = (col + maxRow) * (tileH / 2);
    return Vector2(x, y);
  }

  /// Footprint merkezinin dünya koordinatı (Seçim vurgusu için)
  Vector2 getFootprintCenterPos(int col, int row, int cols, int rows) {
    final centerCol = col + (cols - 1) / 2.0;
    final centerRow = row + (rows - 1) / 2.0;
    return gridToIso(centerCol, centerRow);
  }
}

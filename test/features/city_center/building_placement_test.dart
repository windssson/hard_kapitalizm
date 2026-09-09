import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/features/city_center/game/building_placement_service.dart';
import 'package:hard_kapitalizm/features/city_center/game/city_center_grid.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_building_component.dart';
import 'package:hard_kapitalizm/features/city_center/models/building_type.dart';

void main() {
  const grid = CityCenterGrid(tileW: 64.0, tileH: 32.0, gridSize: 16);

  group('1. Grid Sınır (Boundary) Testleri', () {
    const type3x2 = BuildingType(name: 'Fabrika', footprintCols: 3, footprintRows: 2);
    const type2x3 = BuildingType(name: 'Çiftlik', footprintCols: 2, footprintRows: 3);
    const type1x1 = BuildingType(name: 'Lojistik', footprintCols: 1, footprintRows: 1);
    const type2x2 = BuildingType(name: 'Tarla', footprintCols: 2, footprintRows: 2);
    const type4x3 = BuildingType(name: 'Maden', footprintCols: 4, footprintRows: 3);

    test('16x16 grid üzerinde 3x2 bina sınır kontrolü: 13,14 valid, 14,14 invalid', () {
      final service = BuildingPlacementService();

      // 13,14 konumu: cols 13..15, rows 14..15 -> sınırlar içinde (valid)
      expect(service.canPlace(col: 13, row: 14, type: type3x2, grid: grid), isTrue);

      // 14,14 konumu: cols 14..16 (16 dışarıda) -> geçersiz (invalid)
      expect(service.canPlace(col: 14, row: 14, type: type3x2, grid: grid), isFalse);

      // 13,15 konumu: rows 15..16 (16 dışarıda) -> geçersiz (invalid)
      expect(service.canPlace(col: 13, row: 15, type: type3x2, grid: grid), isFalse);
    });

    test('Negatif koordinatlar sınır dışı sayılmalı', () {
      final service = BuildingPlacementService();
      expect(service.canPlace(col: -1, row: 0, type: type1x1, grid: grid), isFalse);
      expect(service.canPlace(col: 0, row: -1, type: type1x1, grid: grid), isFalse);
    });

    test('Edge placement sınırları (1x1, 2x2, 3x2, 2x3, 4x3)', () {
      final service = BuildingPlacementService();

      // 1x1 -> 15,15 geçerli; 16,15 ve 15,16 geçersiz
      expect(service.canPlace(col: 15, row: 15, type: type1x1, grid: grid), isTrue);
      expect(service.canPlace(col: 16, row: 15, type: type1x1, grid: grid), isFalse);
      expect(service.canPlace(col: 15, row: 16, type: type1x1, grid: grid), isFalse);

      // 2x2 -> 14,14 geçerli; 15,14 ve 14,15 geçersiz
      expect(service.canPlace(col: 14, row: 14, type: type2x2, grid: grid), isTrue);
      expect(service.canPlace(col: 15, row: 14, type: type2x2, grid: grid), isFalse);
      expect(service.canPlace(col: 14, row: 15, type: type2x2, grid: grid), isFalse);

      // 3x2 -> 13,14 geçerli; 14,14 geçersiz
      expect(service.canPlace(col: 13, row: 14, type: type3x2, grid: grid), isTrue);
      expect(service.canPlace(col: 14, row: 14, type: type3x2, grid: grid), isFalse);

      // 2x3 -> 14,13 geçerli; 15,13 ve 14,14 geçersiz
      expect(service.canPlace(col: 14, row: 13, type: type2x3, grid: grid), isTrue);
      expect(service.canPlace(col: 15, row: 13, type: type2x3, grid: grid), isFalse);
      expect(service.canPlace(col: 14, row: 14, type: type2x3, grid: grid), isFalse);

      // 4x3 -> 12,13 geçerli; 13,13 ve 12,14 geçersiz
      expect(service.canPlace(col: 12, row: 13, type: type4x3, grid: grid), isTrue);
      expect(service.canPlace(col: 13, row: 13, type: type4x3, grid: grid), isFalse);
      expect(service.canPlace(col: 12, row: 14, type: type4x3, grid: grid), isFalse);
    });
  });

  group('2. Footprint Cells (Hücre Kapsama) Testleri', () {
    test('3x2 bina tam 6 hücre üretmeli ve doğru koordinatları içermeli', () {
      final building = IsometricBuildingComponent(
        col: 2,
        row: 5,
        footprintCols: 3,
        footprintRows: 2,
        position: Vector2.zero(),
        buildingName: 'Fabrika',
        priority: 100,
        grid: grid,
      );

      final cells = building.coveredCells;
      expect(cells.length, equals(6));

      final expected = [
        const math.Point(2, 5),
        const math.Point(2, 6),
        const math.Point(3, 5),
        const math.Point(3, 6),
        const math.Point(4, 5),
        const math.Point(4, 6),
      ];

      for (final pt in expected) {
        expect(cells.contains(pt), isTrue, reason: '$pt bulunmalı');
        expect(building.coversCell(pt.x, pt.y), isTrue);
      }

      // Kapsam dışı hücreler
      expect(building.coversCell(1, 5), isFalse);
      expect(building.coversCell(5, 5), isFalse);
      expect(building.coversCell(2, 7), isFalse);
    });

    test('2x3 bina tam 6 hücre üretmeli (ters oran)', () {
      final building = IsometricBuildingComponent(
        col: 4,
        row: 3,
        footprintCols: 2,
        footprintRows: 3,
        position: Vector2.zero(),
        buildingName: 'Çiftlik',
        priority: 100,
        grid: grid,
      );

      final cells = building.coveredCells;
      expect(cells.length, equals(6));

      final expected = [
        const math.Point(4, 3),
        const math.Point(4, 4),
        const math.Point(4, 5),
        const math.Point(5, 3),
        const math.Point(5, 4),
        const math.Point(5, 5),
      ];

      for (final pt in expected) {
        expect(cells.contains(pt), isTrue, reason: '$pt bulunmalı');
        expect(building.coversCell(pt.x, pt.y), isTrue);
      }

      expect(building.coversCell(6, 3), isFalse);
      expect(building.coversCell(4, 6), isFalse);
    });

    test('1x1, 2x2, 4x3 hücre adetleri doğrulaması', () {
      final b1x1 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 1,
        footprintRows: 1,
        position: Vector2.zero(),
        buildingName: 'Lojistik',
        priority: 100,
      );
      expect(b1x1.coveredCells.length, equals(1));

      final b2x2 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 2,
        footprintRows: 2,
        position: Vector2.zero(),
        buildingName: 'Tarla',
        priority: 100,
      );
      expect(b2x2.coveredCells.length, equals(4));

      final b4x3 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 4,
        footprintRows: 3,
        position: Vector2.zero(),
        buildingName: 'Maden',
        priority: 100,
      );
      expect(b4x3.coveredCells.length, equals(12));
    });
  });

  group('3. Occupancy (Çakışma & Rezervasyon) Testleri', () {
    test('Bir bina tarafından kullanılan hücrelere ikinci bina yerleşememeli', () {
      final service = BuildingPlacementService();
      const type3x2 = BuildingType(name: 'Fabrika', footprintCols: 3, footprintRows: 2);
      const type2x2 = BuildingType(name: 'Tarla', footprintCols: 2, footprintRows: 2);
      const type1x1 = BuildingType(name: 'Lojistik', footprintCols: 1, footprintRows: 1);

      final building = IsometricBuildingComponent(
        col: 4,
        row: 4,
        footprintCols: 3,
        footprintRows: 2,
        position: grid.getFootprintBottomAnchorPos(4, 4, 3, 2),
        buildingName: 'Fabrika',
        priority: 100,
        grid: grid,
      );

      service.registerBuilding(building);

      // 4,4'teki 3x2 bina şu hücreleri kapatır: (4,4), (5,4), (6,4), (4,5), (5,5), (6,5)
      expect(service.isCellOccupied(4, 4), isTrue);
      expect(service.isCellOccupied(5, 4), isTrue);
      expect(service.isCellOccupied(6, 4), isTrue);
      expect(service.isCellOccupied(4, 5), isTrue);
      expect(service.isCellOccupied(5, 5), isTrue);
      expect(service.isCellOccupied(6, 5), isTrue);

      // Kapsam dışı hücreler boş kalmalı
      expect(service.isCellOccupied(7, 4), isFalse);
      expect(service.isCellOccupied(4, 6), isFalse);
      expect(service.isCellOccupied(3, 4), isFalse);

      // Dolu hücrelerden herhangi birine 1x1 bina yerleşememeli
      expect(service.canPlace(col: 4, row: 4, type: type1x1, grid: grid), isFalse);
      expect(service.canPlace(col: 5, row: 5, type: type1x1, grid: grid), isFalse);
      expect(service.canPlace(col: 6, row: 4, type: type1x1, grid: grid), isFalse);

      // Kısmen çakışan 2x2 binalar yerleşememeli
      expect(service.canPlace(col: 3, row: 3, type: type2x2, grid: grid), isFalse); // (4,4) ile çakışır
      expect(service.canPlace(col: 6, row: 5, type: type2x2, grid: grid), isFalse); // (6,5) ile çakışır

      // Komşu ama çakışmayan binalar yerleşebilmeli
      expect(service.canPlace(col: 7, row: 4, type: type2x2, grid: grid), isTrue);
      expect(service.canPlace(col: 4, row: 6, type: type2x2, grid: grid), isTrue);

      // Bina kaldırıldığında tüm hücreler serbest kalmalı
      service.unregisterBuilding(building);
      expect(service.isCellOccupied(4, 4), isFalse);
      expect(service.isCellOccupied(5, 5), isFalse);
      expect(service.canPlace(col: 4, row: 4, type: type3x2, grid: grid), isTrue);
    });
  });

  group('4. Anchor & Projeksiyon Geometrisi Matematik Doğrulaması', () {
    test('IsometricBuildingComponent anchor değeri footprintCols / (footprintCols + footprintRows) olmalı', () {
      // 2x2 için Anchor(0.5, 1.0) -> Anchor.bottomCenter ile birebir aynı
      final b2x2 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 2,
        footprintRows: 2,
        position: Vector2.zero(),
        buildingName: 'Tarla',
        priority: 100,
        grid: grid,
      );
      expect(b2x2.anchor.x, equals(0.5));
      expect(b2x2.anchor.y, equals(1.0));

      // 1x1 için Anchor(0.5, 1.0)
      final b1x1 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 1,
        footprintRows: 1,
        position: Vector2.zero(),
        buildingName: 'Lojistik',
        priority: 100,
        grid: grid,
      );
      expect(b1x1.anchor.x, equals(0.5));
      expect(b1x1.anchor.y, equals(1.0));

      // 3x2 için Anchor(3/5 = 0.6, 1.0)
      final b3x2 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 3,
        footprintRows: 2,
        position: Vector2.zero(),
        buildingName: 'Fabrika',
        priority: 100,
        grid: grid,
      );
      expect(b3x2.anchor.x, closeTo(0.6, 1e-6));
      expect(b3x2.anchor.y, equals(1.0));

      // 2x3 için Anchor(2/5 = 0.4, 1.0)
      final b2x3 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 2,
        footprintRows: 3,
        position: Vector2.zero(),
        buildingName: 'Çiftlik',
        priority: 100,
        grid: grid,
      );
      expect(b2x3.anchor.x, closeTo(0.4, 1e-6));
      expect(b2x3.anchor.y, equals(1.0));

      // 4x3 için Anchor(4/7, 1.0)
      final b4x3 = IsometricBuildingComponent(
        col: 0,
        row: 0,
        footprintCols: 4,
        footprintRows: 3,
        position: Vector2.zero(),
        buildingName: 'Maden',
        priority: 100,
        grid: grid,
      );
      expect(b4x3.anchor.x, closeTo(4.0 / 7.0, 1e-6));
      expect(b4x3.anchor.y, equals(1.0));
    });

    test('Grid üzerinde binanın güney köşesi ile en güneydeki hücrenin alt köşesi tam eşleşmeli', () {
      final testCases = [
        {'cols': 1, 'rows': 1},
        {'cols': 2, 'rows': 2},
        {'cols': 3, 'rows': 2},
        {'cols': 2, 'rows': 3},
        {'cols': 4, 'rows': 3},
      ];

      const col = 3;
      const row = 4;

      for (final tc in testCases) {
        final c = tc['cols']!;
        final r = tc['rows']!;

        final southPos = grid.getFootprintSouthPos(col, row, c, r);
        final anchorPos = grid.getFootprintBottomAnchorPos(col, row, c, r);
        expect(southPos, equals(anchorPos));

        // En güney hücre: maxCol = col + c - 1, maxRow = row + r - 1
        final maxCol = col + c - 1;
        final maxRow = row + r - 1;
        final cellCenter = grid.gridToIso(maxCol, maxRow);
        final cellSouthApex = cellCenter + Vector2(0, grid.tileH / 2);

        expect(southPos.x, closeTo(cellSouthApex.x, 1e-6));
        expect(southPos.y, closeTo(cellSouthApex.y, 1e-6));
      }
    });

    test('Footprint 4 köşe geometrisi tutarlılığı (West, East, North, South parallelogram)', () {
      const col = 2;
      const row = 3;
      const cols = 3;
      const rows = 2;

      final north = grid.getFootprintNorthPos(col, row, cols, rows);
      final east = grid.getFootprintEastPos(col, row, cols, rows);
      final south = grid.getFootprintSouthPos(col, row, cols, rows);
      final west = grid.getFootprintWestPos(col, row, cols, rows);

      final hw = grid.tileW / 2;

      // 1. Yatay genişlik West ile East arasındaki mesafedir = (cols + rows) * hw
      expect(east.x - west.x, closeTo((cols + rows) * hw, 1e-6));

      // 2. South noktasının West'e göre yatay mesafesi = cols * hw
      expect(south.x - west.x, closeTo(cols * hw, 1e-6));

      // 3. East noktasının South'a göre yatay mesafesi = rows * hw
      expect(east.x - south.x, closeTo(rows * hw, 1e-6));

      // 4. Parallelogram vektör eşitlikleri: (East - North) == (South - West)
      final vecNorthToEast = east - north;
      final vecWestToSouth = south - west;
      expect(vecNorthToEast.x, closeTo(vecWestToSouth.x, 1e-6));
      expect(vecNorthToEast.y, closeTo(vecWestToSouth.y, 1e-6));

      // (West - North) == (South - East)
      final vecNorthToWest = west - north;
      final vecEastToSouth = south - east;
      expect(vecNorthToWest.x, closeTo(vecEastToSouth.x, 1e-6));
      expect(vecNorthToWest.y, closeTo(vecEastToSouth.y, 1e-6));

      // 5. Footprint merkezinin köşe noktalarının ortalamasıyla tam uyuşması
      final center = grid.getFootprintCenterPos(col, row, cols, rows);
      final avgX = (north.x + south.x) / 2;
      final avgY = (north.y + south.y) / 2;
      expect(center.x, closeTo(avgX, 1e-6));
      expect(center.y, closeTo(avgY, 1e-6));
    });

    test('IsometricBuildingComponent localSouth konumu anchor ile birebir örtüşür', () {
      // Component localSouth: (cols * hw, compH)
      // Component size: ((cols + rows) * hw, compH)
      // Component anchor: (cols / (cols + rows), 1.0)
      // Flame local anchor position: (anchor.x * size.x, anchor.y * size.y)
      // Bu ikisi tamamen özdeş olmalıdır.
      final b3x2 = IsometricBuildingComponent(
        col: 1,
        row: 1,
        footprintCols: 3,
        footprintRows: 2,
        position: grid.getFootprintBottomAnchorPos(1, 1, 3, 2),
        buildingName: 'Fabrika',
        priority: 100,
        grid: grid,
      );

      final anchorLocalX = b3x2.anchor.x * b3x2.size.x;
      final anchorLocalY = b3x2.anchor.y * b3x2.size.y;

      expect(anchorLocalX, closeTo(b3x2.localSouth.dx, 1e-6));
      expect(anchorLocalY, closeTo(b3x2.localSouth.dy, 1e-6));
    });
  });
}

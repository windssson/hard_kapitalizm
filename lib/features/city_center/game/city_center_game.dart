import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart' hide PointerMoveEvent;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/features/city_center/camera/city_center_camera_controller.dart';
import 'package:hard_kapitalizm/features/city_center/data/building_catalog.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_building_component.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_selection_highlight.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_tile_component.dart';
import 'package:hard_kapitalizm/features/city_center/models/building_type.dart';

/// 26° Ortografik İzometrik Flame Şehir Merkezi Oyunu
class CityCenterGame extends FlameGame with ScrollDetector {
  final void Function(int col, int row, String type) onTileSelected;

  CityCenterGame({required this.onTileSelected});

  // 2:1 Standart İzometrik Oran
  static const double tileW = 64.0;
  static const double tileH = 32.0;
  static const int gridSize = 16;

  late final World gameWorld;
  late final CameraComponent cameraComp;
  late final CityCenterCameraController cameraController;

  // Başlangıç Bina Kataloğu
  final List<BuildingType> buildingCatalog = List.from(CityCenterData.defaultCatalog);

  int selectedCatalogIndex = 0;
  BuildingType get activeBuildingType => buildingCatalog[selectedCatalogIndex];

  bool isPlacingBuilding = false;
  // Haritadaki dolu karolar (Grid key "col,row" -> Bina Referansı)
  final Map<String, IsometricBuildingComponent> occupiedTiles = {};
  
  // Seçili Karo Göstergesi
  math.Point<int>? selectedTile;
  late final IsometricSelectionHighlight selectionHighlight;

  // tarlatest.png Sprite Referansı
  Sprite? tarlaSprite;

  @override
  Color backgroundColor() => const Color(0xFF090D12);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gameWorld = World();
    // Ortografik kamera: Cihazın tam çözünürlüğünde paralel projeksiyon
    cameraComp = CameraComponent(world: gameWorld);
    cameraController = CityCenterCameraController(
      cameraComp: cameraComp,
      gridSize: gridSize,
      tileW: tileW,
      tileH: tileH,
    );

    await add(gameWorld);
    await add(cameraComp);

    // Katalogtaki asset tanımlı bina görsellerini (örn. isometric/tarlayeni.png) yükle
    images.prefix = 'assets/';
    for (int i = 0; i < buildingCatalog.length; i++) {
      final bType = buildingCatalog[i];
      if (bType.assetPath != null) {
        try {
          final sp = await loadSprite(bType.assetPath!);
          buildingCatalog[i] = bType.copyWith(sprite: sp);
          if (bType.name == 'Tarla') {
            tarlaSprite = sp;
          }
          debugPrint('${bType.name} görseli başarıyla yüklendi: ${bType.assetPath} (${sp.srcSize})');
        } catch (e) {
          debugPrint('${bType.assetPath} yüklenirken hata oluştu: $e');
        }
      }
    }

    // 2:1 İzometrik Grid'i inşa et
    await _buildIsometricGrid();

    // Seçim Vurgusu Bileşeni
    selectionHighlight = IsometricSelectionHighlight(tileW: tileW, tileH: tileH);
    await gameWorld.add(selectionHighlight);

    // Haritanın merkezine test için doğrudan Tarla (tarlatest.png) yerleştir
    final tarlaType = buildingCatalog.firstWhere((b) => b.name == 'Tarla');
    placeBuilding(6, 6, tarlaType);

    // Kalan alanlara rastgele binalar serpiştir
    spawnRandomBuildings(count: 5, clearExisting: false);

    // Kamerayı haritanın tam merkezine odakla
    cameraController.centerMap();
  }

  /// Haritaya 2x2 rastgele binaları çakışmayacak şekilde yerleştirir
  void spawnRandomBuildings({int count = 6, bool clearExisting = true}) {
    if (clearExisting) {
      clearAllBuildings();
      // Temizleme sonrası merkezi Tarla binasını yeniden koy
      final tarlaType = buildingCatalog.firstWhere((b) => b.name == 'Tarla');
      placeBuilding(6, 6, tarlaType);
    }

    final random = math.Random();
    int placedCount = 0;
    int attempts = 0;

    final available = List<BuildingType>.from(buildingCatalog)..shuffle(random);

    while (placedCount < count && attempts < 250) {
      attempts++;
      final baseType = available[placedCount % available.length];

      // Bütün binalar 2x2 footprint
      const int fCols = 2;
      const int fRows = 2;

      final runtimeType = baseType.copyWith(
        footprintCols: fCols,
        footprintRows: fRows,
      );

      final maxC = gridSize - fCols;
      final maxR = gridSize - fRows;
      if (maxC <= 0 || maxR <= 0) continue;

      final col = random.nextInt(maxC);
      final row = random.nextInt(maxR);

      if (canPlaceBuilding(col, row, runtimeType)) {
        placeBuilding(col, row, runtimeType);
        placedCount++;
      }
    }
  }

  void clearAllBuildings() {
    occupiedTiles.clear();
    final buildings = gameWorld.children.whereType<IsometricBuildingComponent>().toList();
    for (final b in buildings) {
      b.removeFromParent();
    }
  }

  /// Derinlik / Priority Hesaplama Sistemi:
  /// Ortak taban derinliği kuralı: baseDepth = (col + row) * 100
  static int getBaseDepth(int col, int row) => (col + row) * 100;

  /// Zemin karosu derinliği (taban seviyesi: baseDepth)
  static int getTilePriority(int col, int row) => getBaseDepth(col, row);

  /// Bina derinliği (zeminin üstü: baseDepth + 50)
  static int getBuildingPriority(int col, int row) => getBaseDepth(col, row) + 50;

  /// Ekrandaki dokunma noktasını kamera dünyasındaki koordinata çevirir
  Vector2 screenToWorld(Offset screenPoint) {
    return cameraController.screenToWorld(screenPoint);
  }

  /// 2:1 İzometrik Grid İnşası
  Future<void> _buildIsometricGrid() async {
    for (int col = 0; col < gridSize; col++) {
      for (int row = 0; row < gridSize; row++) {
        final pos = gridToIso(col, row);
        final tile = IsometricTileComponent(
          col: col,
          row: row,
          position: pos,
          tileWidth: tileW,
          tileHeight: tileH,
          // Ortak derinlik kuralı: zemin = baseDepth
          priority: getTilePriority(col, row),
        );
        await gameWorld.add(tile);
      }
    }
  }

  /// Grid (col, row) ➔ 2:1 İzometrik Dünya Koordinatı (num destekli, merkez hesaplamaları için)
  static Vector2 gridToIso(num col, num row) {
    final x = (col - row) * (tileW / 2);
    final y = (col + row) * (tileH / 2);
    return Vector2(x, y);
  }

  /// 2:1 İzometrik Dünya Koordinatı ➔ Grid (col, row) Ters Dönüşümü
  static math.Point<int>? isoToGrid(Vector2 worldPos) {
    // 2:1 dimetrik izdüşümün ters formülü
    final double halfW = tileW / 2;
    final double halfH = tileH / 2;

    final double colFraction = (worldPos.y / halfH + worldPos.x / halfW) / 2;
    final double rowFraction = (worldPos.y / halfH - worldPos.x / halfW) / 2;

    final int col = (colFraction + 0.5).floor();
    final int row = (rowFraction + 0.5).floor();

    if (col >= 0 && col < gridSize && row >= 0 && row < gridSize) {
      return math.Point<int>(col, row);
    }
    return null;
  }

  /// Ekrandan dokunulan noktayı dünya koordinatına çevirip karo işlemini yürütür
  void handleTapAtScreenPoint(Offset screenPoint) {
    final worldPos = screenToWorld(screenPoint);

    // 1. AŞAMA: Görsel Hitbox Kontrolü (Bina Çatısı, Duvarı veya Sprite'ı)
    final candidateBuildings = gameWorld.children
        .whereType<IsometricBuildingComponent>()
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    IsometricBuildingComponent? clickedBuilding;
    for (final b in candidateBuildings) {
      if (b.containsWorldPoint(worldPos)) {
        clickedBuilding = b;
        break;
      }
    }

    if (clickedBuilding != null) {
      _selectOrRemoveBuilding(clickedBuilding);
      return;
    }

    // 2. AŞAMA: Zemin Grid Rezervasyonu Kontrolü (Footprint Hitbox)
    final cell = isoToGrid(worldPos);

    if (cell != null) {
      final key = '${cell.x},${cell.y}';
      final existingBuilding = occupiedTiles[key];

      if (existingBuilding != null) {
        _selectOrRemoveBuilding(existingBuilding);
      } else {
        if (isPlacingBuilding) {
          if (canPlaceBuilding(cell.x, cell.y, activeBuildingType)) {
            placeBuilding(cell.x, cell.y, activeBuildingType);
            final centerPos = gridToIso(
              cell.x + (activeBuildingType.footprintCols - 1) / 2.0,
              cell.y + (activeBuildingType.footprintRows - 1) / 2.0,
            );
            selectionHighlight.updateHighlight(
              centerPos: centerPos,
              cols: activeBuildingType.footprintCols,
              rows: activeBuildingType.footprintRows,
              visible: true,
            );
            onTileSelected(
              cell.x,
              cell.y,
              '${activeBuildingType.name} (${activeBuildingType.footprintCols}x${activeBuildingType.footprintRows}) inşa edildi! [Kök: (${cell.x}, ${cell.y})]',
            );
          } else {
            selectedTile = cell;
            final centerPos = gridToIso(cell.x, cell.y);
            selectionHighlight.updateHighlight(centerPos: centerPos, cols: 1, rows: 1, visible: true);
            onTileSelected(
              cell.x,
              cell.y,
              'Yetersiz alan! (${activeBuildingType.footprintCols}x${activeBuildingType.footprintRows} sığmıyor veya dolu)',
            );
          }
        } else {
          selectedTile = cell;
          final centerPos = gridToIso(cell.x, cell.y);
          selectionHighlight.updateHighlight(centerPos: centerPos, cols: 1, rows: 1, visible: true);
          onTileSelected(cell.x, cell.y, 'Boş Arsa: (${cell.x}, ${cell.y})');
        }
      }
    } else {
      selectedTile = null;
      selectionHighlight.hide();
    }
  }

  /// Bir binayı seçer veya inşa modundaysa haritadan kaldırır
  void _selectOrRemoveBuilding(IsometricBuildingComponent b) {
    if (isPlacingBuilding) {
      final name = b.buildingName;
      final rootC = b.col;
      final rootR = b.row;
      removeBuilding(b);
      selectionHighlight.hide();
      onTileSelected(rootC, rootR, '$name (${b.footprintCols}x${b.footprintRows}) kaldırıldı (Arsa Boş)');
    } else {
      selectedTile = math.Point<int>(b.col, b.row);
      selectionHighlight.updateHighlight(
        centerPos: b.baseCenterWorld,
        cols: b.footprintCols,
        rows: b.footprintRows,
        visible: true,
      );
      final cellsStr = b.coveredCells.map((p) => '(${p.x},${p.y})').join(', ');
      final spriteBadge = b.sprite != null ? ' [PNG Sprite Aktif]' : '';
      onTileSelected(
        b.col,
        b.row,
        '${b.buildingName}$spriteBadge [${b.footprintCols}x${b.footprintRows}] — Kök: (${b.col}, ${b.row})\nAlanı: $cellsStr',
      );
    }
  }

  /// Binanın sığıp sığmadığını denetler
  bool canPlaceBuilding(int col, int row, BuildingType type) {
    if (col + type.footprintCols > gridSize || row + type.footprintRows > gridSize) {
      return false;
    }
    for (int c = col; c < col + type.footprintCols; c++) {
      for (int r = row; r < row + type.footprintRows; r++) {
        if (occupiedTiles.containsKey('$c,$r')) {
          return false;
        }
      }
    }
    return true;
  }

  /// Çoklu footprint destekli bina inşası
  void placeBuilding(int col, int row, BuildingType type) {
    final maxCol = col + type.footprintCols - 1;
    final maxRow = row + type.footprintRows - 1;
    final priority = getBuildingPriority(maxCol, maxRow);

    final bottomX = (maxCol - maxRow) * (tileW / 2);
    final bottomY = (maxCol + maxRow) * (tileH / 2) + (tileH / 2);
    final anchorBottomPos = Vector2(bottomX, bottomY);

    final spriteToUse = type.sprite ?? (type.name == 'Tarla' ? tarlaSprite : null);

    final building = IsometricBuildingComponent(
      col: col,
      row: row,
      footprintCols: type.footprintCols,
      footprintRows: type.footprintRows,
      position: anchorBottomPos,
      buildingName: type.name,
      sprite: spriteToUse,
      wallColor: type.wallColor,
      roofColor: type.roofColor,
      wallHeight: type.wallHeight,
      priority: priority,
    );

    for (int c = col; c <= maxCol; c++) {
      for (int r = row; r <= maxRow; r++) {
        occupiedTiles['$c,$r'] = building;
      }
    }

    gameWorld.add(building);
  }

  /// Binayı ve kapladığı tüm footprint alanını temizler
  void removeBuilding(IsometricBuildingComponent building) {
    occupiedTiles.removeWhere((key, val) => val == building);
    building.removeFromParent();
  }

  /// Sonraki bina türüne geçiş yapar
  void cycleBuildingType() {
    selectedCatalogIndex = (selectedCatalogIndex + 1) % buildingCatalog.length;
  }

  /// Masaüstü / Web için fare tekerleğiyle zoom
  @override
  void onScroll(PointerScrollInfo info) {
    final scrollDelta = info.scrollDelta.global.y;
    if (scrollDelta < 0) {
      cameraController.zoomByStep(0.15);
    } else if (scrollDelta > 0) {
      cameraController.zoomByStep(-0.15);
    }
  }

  void toggleBuildingPlacement() {
    isPlacingBuilding = !isPlacingBuilding;
  }
}

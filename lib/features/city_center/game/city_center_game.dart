import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart' hide PointerMoveEvent;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/features/city_center/camera/city_center_camera_controller.dart';
import 'package:hard_kapitalizm/features/city_center/data/building_catalog.dart';
import 'package:hard_kapitalizm/features/city_center/data/city_center_asset_registry.dart';
import 'package:hard_kapitalizm/features/city_center/game/building_placement_service.dart';
import 'package:hard_kapitalizm/features/city_center/game/city_center_grid.dart';
import 'package:hard_kapitalizm/features/city_center/game/city_center_scene.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_building_component.dart';
import 'package:hard_kapitalizm/features/city_center/models/building_type.dart';

/// 26° Ortografik İzometrik Şehir Merkezi Flame Oyunu (Ana Orkestratör)
class CityCenterGame extends FlameGame with ScrollDetector {
  final void Function(int col, int row, String type) onTileSelected;

  CityCenterGame({required this.onTileSelected});

  // 1. Grid Katmanı (Matematiksel Koordinat & Derinlik Dönüşümleri)
  final CityCenterGrid grid = const CityCenterGrid();

  // 2. Varlık Katmanı (Sprite Cache & Ön Yükleme)
  final CityCenterAssetRegistry assetRegistry = CityCenterAssetRegistry();

  // 3. Yerleşim Servisi (Arsa Rezervasyonları & Çakışma Denetimi)
  final BuildingPlacementService placementService = BuildingPlacementService();

  // 4. Görsel Sahne Katmanı (World, Karolar, Binalar, Vurgular)
  late final CityCenterScene scene;

  // 5. Kamera Kontrolcüsü (Pan, Pinch Zoom, Sınır Clamping)
  late final CityCenterCameraController cameraController;

  late final World gameWorld;
  late final CameraComponent cameraComp;

  // Başlangıç Bina Kataloğu
  final List<BuildingType> buildingCatalog = List.from(CityCenterData.defaultCatalog);

  int selectedCatalogIndex = 0;
  BuildingType get activeBuildingType => buildingCatalog[selectedCatalogIndex];

  bool isPlacingBuilding = false;
  math.Point<int>? selectedTile;

  @override
  Color backgroundColor() => const Color(0xFF090D12);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gameWorld = World();
    cameraComp = CameraComponent(world: gameWorld);

    await add(gameWorld);
    await add(cameraComp);

    // 1. Modül: Kamera Kontrolcüsü
    cameraController = CityCenterCameraController(
      cameraComp: cameraComp,
      grid: grid,
    );

    // 2. Modül: Görsel Sahne
    scene = CityCenterScene(
      gameWorld: gameWorld,
      grid: grid,
    );

    // 3. Modül: Varlık Kayıt Defteri (Sprite Preload)
    await assetRegistry.preloadCatalog(images, buildingCatalog);

    // 4. Sahneyi Başlat (Zemin Karoları & Seçim Vurgusu)
    await scene.initScene();

    // 5. Haritanın merkezine test için doğrudan Tarla (tarlayeni.png) yerleştir
    final tarlaType = buildingCatalog.firstWhere((b) => b.name == 'Tarla');
    placeBuilding(6, 6, tarlaType);

    // 6. Kalan alanlara rastgele binalar serpiştir
    spawnRandomBuildings(count: 5, clearExisting: false);

    // 7. Kamerayı harita merkezine odakla
    cameraController.centerMap();
  }

  /// Çoklu footprint destekli bina inşası
  void placeBuilding(int col, int row, BuildingType type) {
    final maxCol = col + type.footprintCols - 1;
    final maxRow = row + type.footprintRows - 1;
    final priority = grid.getBuildingPriority(maxCol, maxRow);
    final anchorBottomPos = grid.getFootprintBottomAnchorPos(
      col,
      row,
      type.footprintCols,
      type.footprintRows,
    );

    final spriteToUse = assetRegistry.getBuildingSprite(type);

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
      grid: grid,
    );

    // Yerleşim servisine kaydet
    placementService.registerBuilding(building);

    // Görsel sahneye ekle
    scene.addBuilding(building);
  }

  /// Binayı hem sahneden hem de arsa rezervasyonundan kaldırır
  void removeBuilding(IsometricBuildingComponent building) {
    placementService.unregisterBuilding(building);
    scene.removeBuilding(building);
  }

  /// Sahnedeki ve rezervasyondaki tüm binaları temizler
  void clearAllBuildings() {
    placementService.clear();
    scene.clearBuildings();
  }

  /// Haritaya rastgele binaları çakışmayacak şekilde yerleştirir
  void spawnRandomBuildings({int count = 6, bool clearExisting = true}) {
    if (clearExisting) {
      clearAllBuildings();
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
      final fCols = baseType.footprintCols;
      final fRows = baseType.footprintRows;

      final maxValidCol = grid.gridSize - fCols;
      final maxValidRow = grid.gridSize - fRows;
      if (maxValidCol < 0 || maxValidRow < 0) continue;

      final col = random.nextInt(maxValidCol + 1);
      final row = random.nextInt(maxValidRow + 1);

      if (placementService.canPlace(col: col, row: row, type: baseType, grid: grid)) {
        placeBuilding(col, row, baseType);
        placedCount++;
      }
    }
  }

  /// Ekrandan dokunulan noktayı dünya koordinatına çevirip karo & bina işlemini yürütür
  void handleTapAtScreenPoint(Offset screenPoint) {
    final worldPos = cameraController.screenToWorld(screenPoint);

    // 1. AŞAMA: Görsel Hitbox Kontrolü (Bina Çatısı, Duvarı veya Sprite'ı)
    final clickedBuilding = scene.findBuildingAtWorldPoint(worldPos);

    if (clickedBuilding != null) {
      _selectOrRemoveBuilding(clickedBuilding);
      return;
    }

    // 2. AŞAMA: Zemin Grid Rezervasyonu Kontrolü (Footprint Hitbox)
    final cell = grid.isoToGrid(worldPos);

    if (cell != null) {
      final existingBuilding = placementService.getBuildingAt(cell.x, cell.y);

      if (existingBuilding != null) {
        _selectOrRemoveBuilding(existingBuilding);
      } else {
        if (isPlacingBuilding) {
          if (placementService.canPlace(col: cell.x, row: cell.y, type: activeBuildingType, grid: grid)) {
            placeBuilding(cell.x, cell.y, activeBuildingType);
            final centerPos = grid.getFootprintCenterPos(
              cell.x,
              cell.y,
              activeBuildingType.footprintCols,
              activeBuildingType.footprintRows,
            );
            scene.updateHighlight(
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
            final centerPos = grid.gridToIso(cell.x, cell.y);
            scene.updateHighlight(centerPos: centerPos, cols: 1, rows: 1, visible: true);
            onTileSelected(
              cell.x,
              cell.y,
              'Yetersiz alan! (${activeBuildingType.footprintCols}x${activeBuildingType.footprintRows} sığmıyor veya dolu)',
            );
          }
        } else {
          selectedTile = cell;
          final centerPos = grid.gridToIso(cell.x, cell.y);
          scene.updateHighlight(centerPos: centerPos, cols: 1, rows: 1, visible: true);
          onTileSelected(cell.x, cell.y, 'Boş Arsa: (${cell.x}, ${cell.y})');
        }
      }
    } else {
      selectedTile = null;
      scene.hideHighlight();
    }
  }

  /// Bir binayı seçer veya inşa modundaysa haritadan kaldırır
  void _selectOrRemoveBuilding(IsometricBuildingComponent b) {
    if (isPlacingBuilding) {
      final name = b.buildingName;
      final rootC = b.col;
      final rootR = b.row;
      removeBuilding(b);
      scene.hideHighlight();
      onTileSelected(rootC, rootR, '$name (${b.footprintCols}x${b.footprintRows}) kaldırıldı (Arsa Boş)');
    } else {
      selectedTile = math.Point<int>(b.col, b.row);
      scene.updateHighlight(
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

import 'package:flame/components.dart';
import 'package:hard_kapitalizm/features/city_center/game/city_center_grid.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_building_component.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_selection_highlight.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_tile_component.dart';

/// Şehir Merkezi Görsel Sahnesi (World, Karolar, Binalar ve Seçim Vurgusu Yönetimi)
class CityCenterScene {
  final World gameWorld;
  final CityCenterGrid grid;
  late final IsometricSelectionHighlight selectionHighlight;

  CityCenterScene({
    required this.gameWorld,
    required this.grid,
  }) {
    selectionHighlight = IsometricSelectionHighlight(
      tileW: grid.tileW,
      tileH: grid.tileH,
    );
  }

  /// Sahneye seçim vurgusunu ve 2:1 izometrik zemin karolarını ekler
  Future<void> initScene() async {
    await gameWorld.add(selectionHighlight);

    // Grid taban karolarını inşa et
    for (int col = 0; col < grid.gridSize; col++) {
      for (int row = 0; row < grid.gridSize; row++) {
        final pos = grid.gridToIso(col, row);
        final tile = IsometricTileComponent(
          col: col,
          row: row,
          position: pos,
          tileWidth: grid.tileW,
          tileHeight: grid.tileH,
          priority: grid.getTilePriority(col, row),
        );
        await gameWorld.add(tile);
      }
    }
  }

  /// Sahnedeki mevcut tüm binalar
  Iterable<IsometricBuildingComponent> get buildings =>
      gameWorld.children.whereType<IsometricBuildingComponent>();

  /// Sahneye yeni bir bina ekler
  void addBuilding(IsometricBuildingComponent building) {
    gameWorld.add(building);
  }

  /// Sahneden bir binayı kaldırır
  void removeBuilding(IsometricBuildingComponent building) {
    building.removeFromParent();
  }

  /// Sahnedeki tüm binaları temizler
  void clearBuildings() {
    final toRemove = buildings.toList();
    for (final b in toRemove) {
      b.removeFromParent();
    }
  }

  /// Tıklanan dünya koordinatında görsel olarak (gövde/çatı/sprite) yer alan en öndeki binayı bulur
  IsometricBuildingComponent? findBuildingAtWorldPoint(Vector2 worldPos) {
    // Öndeki binalar arkadakileri kapattığı için yüksek priority'den başlanır
    final candidates = buildings.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final b in candidates) {
      if (b.containsWorldPoint(worldPos)) {
        return b;
      }
    }
    return null;
  }

  /// Seçim kutusunu belirtilen merkez ve boyuta taşır
  void updateHighlight({
    required Vector2 centerPos,
    int cols = 1,
    int rows = 1,
    bool visible = true,
  }) {
    selectionHighlight.updateHighlight(
      centerPos: centerPos,
      cols: cols,
      rows: rows,
      visible: visible,
    );
  }

  /// Seçim vurgusunu gizler
  void hideHighlight() {
    selectionHighlight.hide();
  }
}

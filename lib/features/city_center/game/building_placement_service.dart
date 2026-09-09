import 'package:hard_kapitalizm/features/city_center/game/city_center_grid.dart';
import 'package:hard_kapitalizm/features/city_center/game/components/isometric_building_component.dart';
import 'package:hard_kapitalizm/features/city_center/models/building_type.dart';

/// Şehir Merkezi Bina Yerleşim & Arsa Rezervasyon Servisi
class BuildingPlacementService {
  // Grid hücresi ("col,row") ➔ O hücreyi kaplayan bina bileşeni referansı
  final Map<String, IsometricBuildingComponent> _occupiedCells = {};

  /// Dolu hücrelerin haritası (Read-only erişim)
  Map<String, IsometricBuildingComponent> get occupiedCells =>
      Map.unmodifiable(_occupiedCells);

  /// Verilen koordinat ve footprint için arsanın inşaata uygun olup olmadığını denetler
  bool canPlace({
    required int col,
    required int row,
    required BuildingType type,
    required CityCenterGrid grid,
  }) {
    // 1. Sınır kontrolü: Bina harita dışına taşıyor mu?
    if (!grid.isFootprintWithinBounds(col, row, type.footprintCols, type.footprintRows)) {
      return false;
    }

    // 2. Çakışma kontrolü: Kaplayacağı hücrelerden herhangi biri dolu mu?
    for (int c = col; c < col + type.footprintCols; c++) {
      for (int r = row; r < row + type.footprintRows; r++) {
        if (_occupiedCells.containsKey('$c,$r')) {
          return false;
        }
      }
    }

    return true;
  }

  /// Bir binanın kapladığı tüm hücreleri rezerve eder
  void registerBuilding(IsometricBuildingComponent building) {
    for (int c = building.col; c < building.col + building.footprintCols; c++) {
      for (int r = building.row; r < building.row + building.footprintRows; r++) {
        _occupiedCells['$c,$r'] = building;
      }
    }
  }

  /// Bir binayı ve kapladığı tüm arsa rezervasyonlarını kaldırır
  void unregisterBuilding(IsometricBuildingComponent building) {
    _occupiedCells.removeWhere((key, val) => val == building);
  }

  /// Verilen grid hücresinde bulunan binayı döndürür (varsa)
  IsometricBuildingComponent? getBuildingAt(int col, int row) {
    return _occupiedCells['$col,$row'];
  }

  /// Verilen hücrenin dolu olup olmadığını kontrol eder
  bool isCellOccupied(int col, int row) {
    return _occupiedCells.containsKey('$col,$row');
  }

  /// Tüm arsa rezervasyonlarını temizler
  void clear() {
    _occupiedCells.clear();
  }
}

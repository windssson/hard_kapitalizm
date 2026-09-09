import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/features/city_center/models/building_type.dart';

/// Şehir Merkezi Başlangıç Veri Kataloğu
class CityCenterData {
  static const List<BuildingType> defaultCatalog = [
    BuildingType(
      name: 'Tarla',
      footprintCols: 2,
      footprintRows: 2,
      wallColor: Color(0xFF3B2F1F),
      roofColor: Color(0xFFC49A45),
      wallHeight: 16.0,
      assetPath: 'isometric/tarlayeni.png',
    ),
    BuildingType(name: 'Fabrika', footprintCols: 3, footprintRows: 2, wallColor: Color(0xFF243342), roofColor: Color(0xFFE67E22), wallHeight: 32.0),
    BuildingType(name: 'Çiftlik', footprintCols: 2, footprintRows: 3, wallColor: Color(0xFF1E392A), roofColor: Color(0xFF82B366), wallHeight: 24.0),
    BuildingType(name: 'Maden', footprintCols: 4, footprintRows: 3, wallColor: Color(0xFF2A2A2A), roofColor: Color(0xFF9E7C57), wallHeight: 28.0),
    BuildingType(name: 'Lojistik', footprintCols: 1, footprintRows: 1, wallColor: Color(0xFF1C3144), roofColor: Color(0xFF2E86C1), wallHeight: 20.0),
    BuildingType(name: 'Depo', footprintCols: 3, footprintRows: 2, wallColor: Color(0xFF2B3A42), roofColor: Color(0xFF5D6D7E), wallHeight: 26.0),
    BuildingType(
      name: 'Mağaza',
      footprintCols: 2,
      footprintRows: 2,
      wallColor: Color(0xFF3E2723),
      roofColor: Color(0xFFE2B755),
      wallHeight: 25.0,
      assetPath: 'isometric/magazayeni.png',
    ),
  ];
}

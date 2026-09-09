// City Center (Şehir Merkezi) Modülü Giriş ve Dışa Aktarım Dosyası
export 'package:hard_kapitalizm/features/city_center/camera/city_center_camera_controller.dart';
export 'package:hard_kapitalizm/features/city_center/data/building_catalog.dart';
export 'package:hard_kapitalizm/features/city_center/data/city_center_asset_registry.dart';
export 'package:hard_kapitalizm/features/city_center/game/building_placement_service.dart';
export 'package:hard_kapitalizm/features/city_center/game/city_center_game.dart';
export 'package:hard_kapitalizm/features/city_center/game/city_center_grid.dart';
export 'package:hard_kapitalizm/features/city_center/game/city_center_scene.dart';
export 'package:hard_kapitalizm/features/city_center/game/components/isometric_building_component.dart';
export 'package:hard_kapitalizm/features/city_center/game/components/isometric_selection_highlight.dart';
export 'package:hard_kapitalizm/features/city_center/game/components/isometric_tile_component.dart';
export 'package:hard_kapitalizm/features/city_center/models/building_type.dart';
export 'package:hard_kapitalizm/features/city_center/ui/city_center_screen.dart';

import 'package:hard_kapitalizm/features/city_center/game/city_center_game.dart';
import 'package:hard_kapitalizm/features/city_center/ui/city_center_screen.dart';

// Geriye dönük uyumluluk alias'ları
typedef FlameTestScreen = CityCenterScreen;
typedef IsometricMapGame = CityCenterGame;

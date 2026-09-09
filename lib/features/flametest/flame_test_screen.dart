import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart' hide PointerMoveEvent;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

/// 2D İzometrik Test Ekranı (İzole Test Alanı)
class FlameTestScreen extends StatefulWidget {
  const FlameTestScreen({super.key});

  @override
  State<FlameTestScreen> createState() => _FlameTestScreenState();
}

class _FlameTestScreenState extends State<FlameTestScreen> {
  late final IsometricMapGame _game;
  String _selectedTileInfo = 'Herhangi bir karoya dokunun';
  String _currentMode = 'Seçim Modu';

  // Ham Dokunma (Listener) Takibi: 1 parmakla pan, 2 parmakla zoom
  final Map<int, Offset> _activePointers = {};
  double _initialPinchDistance = 0.0;
  double _initialPinchZoom = 1.0;
  Offset _lastPanPoint = Offset.zero;
  double _totalMovement = 0.0;
  static const double _tapMovementThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    _game = IsometricMapGame(
      onTileSelected: (col, row, type) {
        setState(() {
          _selectedTileInfo = 'Karo: ($col, $row) — Tür: $type';
        });
      },
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 1) {
      // Tek parmak başladı -> Kaydırma (Pan) başlangıcı
      _lastPanPoint = event.localPosition;
      _totalMovement = 0.0;
    } else if (_activePointers.length == 2) {
      // Çift parmak başladı -> Pinch to Zoom başlangıcı
      final points = _activePointers.values.toList();
      _initialPinchDistance = (points[0] - points[1]).distance;
      _initialPinchZoom = _game.cameraComp.viewfinder.zoom;
      _lastPanPoint = (points[0] + points[1]) / 2;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;

    if (_activePointers.length == 1) {
      // 1 Dokunma: Anında ve Kesintisiz Kaydırma (Pan)
      final currentPoint = event.localPosition;
      final delta = currentPoint - _lastPanPoint;
      _lastPanPoint = currentPoint;
      _totalMovement += delta.distance;

      if (delta.dx != 0 || delta.dy != 0) {
        _game.panCamera(delta.dx, delta.dy);
      }
    } else if (_activePointers.length >= 2) {
      // 2 Dokunma: Pinch Zoom + Çift parmakla kaydırma
      final points = _activePointers.values.toList();
      final currentDistance = (points[0] - points[1]).distance;
      if (_initialPinchDistance > 10) {
        final scale = currentDistance / _initialPinchDistance;
        _game.applyPinchZoom(_initialPinchZoom * scale);
      }

      final midPoint = (points[0] + points[1]) / 2;
      final delta = midPoint - _lastPanPoint;
      _lastPanPoint = midPoint;
      _totalMovement += delta.distance;
      if (delta.dx != 0 || delta.dy != 0) {
        _game.panCamera(delta.dx, delta.dy);
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final releasedPoint = event.localPosition;
    final wasSinglePointer = _activePointers.length == 1;

    _activePointers.remove(event.pointer);

    if (_activePointers.length == 1) {
      _lastPanPoint = _activePointers.values.first;
    } else if (_activePointers.isEmpty) {
      // Dokunma bitti: Sürükleme eşiği aşılmadıysa tıklandı kabul et
      if (wasSinglePointer && _totalMovement < _tapMovementThreshold) {
        _game.handleTapAtScreenPoint(releasedPoint);
      }
      _totalMovement = 0.0;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D12),
      body: Stack(
        children: [
          // Oyun Alanı & Ham Dokunmatik Kontroller (Listener: Sıfır gecikme, tam tepki)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: GameWidget(game: _game),
            ),
          ),

          // Üst Bilgi Barı
          Positioned(
            top: MediaQuery.of(context).padding.top + 10.h,
            left: 16.w,
            right: 16.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.cardBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold),
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '2D İzometrik (26° Ortografik)',
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.gold,
                            fontSize: AppTypography.titleLarge,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _selectedTileInfo,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _currentMode,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Alt Kontrol Butonları
          Positioned(
            bottom: 24.h,
            left: 16.w,
            right: 16.w,
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.cardBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.zoom_in_rounded,
                    label: 'Yakınlaş',
                    onTap: () => _game.zoomByStep(0.2),
                  ),
                  _buildActionButton(
                    icon: Icons.zoom_out_rounded,
                    label: 'Uzaklaş',
                    onTap: () => _game.zoomByStep(-0.2),
                  ),
                  _buildActionButton(
                    icon: Icons.center_focus_strong_rounded,
                    label: 'Merkezle',
                    onTap: () => _game.centerMap(),
                  ),
                  _buildActionButton(
                    icon: Icons.shuffle_rounded,
                    label: 'Rastgele',
                    onTap: () {
                      _game.spawnRandomBuildings(count: 6);
                      setState(() {
                        _selectedTileInfo = 'Rastgele 2x2 ve 3x3 binalar serpiştirildi';
                      });
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.swap_horiz_rounded,
                    label: '${_game.activeBuildingType.name} (${_game.activeBuildingType.footprintCols}x${_game.activeBuildingType.footprintRows})',
                    onTap: () {
                      _game.cycleBuildingType();
                      setState(() {
                        if (_game.isPlacingBuilding) {
                          _currentMode = '${_game.activeBuildingType.name} (${_game.activeBuildingType.footprintCols}x${_game.activeBuildingType.footprintRows})';
                        }
                      });
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.add_business_rounded,
                    label: _game.isPlacingBuilding ? 'İnşa Açık' : 'Bina Modu',
                    accent: _game.isPlacingBuilding,
                    onTap: () {
                      _game.toggleBuildingPlacement();
                      setState(() {
                        _currentMode = _game.isPlacingBuilding
                            ? '${_game.activeBuildingType.name} (${_game.activeBuildingType.footprintCols}x${_game.activeBuildingType.footprintRows})'
                            : 'Seçim Modu';
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: accent
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.cardBgLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent ? AppColors.gold : AppColors.border,
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              size: 20.sp,
              color: accent ? AppColors.gold : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: accent ? AppColors.gold : AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: accent ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 26° Ortografik İzometrik Flame Oyunu
class IsometricMapGame extends FlameGame with ScrollDetector {
  final void Function(int col, int row, String type) onTileSelected;

  IsometricMapGame({required this.onTileSelected});

  // 2:1 Standart İzometrik Oran
  static const double tileW = 64.0;
  static const double tileH = 32.0;
  static const int gridSize = 16;

  // Zoom Limitleri
  static const double minZoom = 0.4;
  static const double maxZoom = 2.6;

  late final World gameWorld;
  late final CameraComponent cameraComp;

  // Ön Tanımlı Bina Kataloğu (assets/flametest altındaki görseller)
  static const List<BuildingType> buildingCatalog = [
    BuildingType(name: 'Fabrika', assetName: 'fabrikaizometrik.png', footprintCols: 3, footprintRows: 3),
    BuildingType(name: 'Çiftlik', assetName: 'ciftlikizometrik.png', footprintCols: 3, footprintRows: 3),
    BuildingType(name: 'Maden', assetName: 'madenizometrik.png', footprintCols: 3, footprintRows: 3),
    BuildingType(name: 'Tarla', assetName: 'tarlaizometrik.png', footprintCols: 2, footprintRows: 2),
    BuildingType(name: 'Lojistik', assetName: 'lojistikizometrik.png', footprintCols: 3, footprintRows: 2),
    BuildingType(name: 'Depo', assetName: 'depoizometrik.png', footprintCols: 2, footprintRows: 2),
    BuildingType(name: 'Mağaza', assetName: 'magazaizometrik.png', footprintCols: 2, footprintRows: 2),
  ];

  int selectedCatalogIndex = 0;
  BuildingType get activeBuildingType => buildingCatalog[selectedCatalogIndex];

  // Yüklenen Sprite Önbelleği
  final Map<String, Sprite> loadedSprites = {};

  bool isPlacingBuilding = false;
  // Haritadaki dolu karolar (Grid key "col,row" -> Bina Referansı)
  final Map<String, IsometricBuildingComponent> occupiedTiles = {};
  
  // Seçili Karo Göstergesi
  math.Point<int>? selectedTile;
  late final IsometricSelectionHighlight selectionHighlight;

  @override
  Color backgroundColor() => const Color(0xFF090D12);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gameWorld = World();
    // Ortografik kamera: Cihazın tam çözünürlüğünde paralel projeksiyon
    cameraComp = CameraComponent(world: gameWorld);

    await add(gameWorld);
    await add(cameraComp);

    // 2:1 İzometrik Grid'i inşa et
    await _buildIsometricGrid();

    // Seçim Vurgusu Bileşeni
    selectionHighlight = IsometricSelectionHighlight(tileW: tileW, tileH: tileH);
    await gameWorld.add(selectionHighlight);

    // assets/flametest altındaki görselleri önbelleğe al
    await _loadAssetSprites();

    // Haritaya 2x2 ve 3x3 rastgele binalar yerleştir
    spawnRandomBuildings(count: 6);

    // Kamerayı haritanın tam merkezine odakla
    centerMap();
  }

  /// assets/flametest altındaki izometrik PNG görsellerini yükler
  Future<void> _loadAssetSprites() async {
    images.prefix = '';
    for (final item in buildingCatalog) {
      try {
        final sprite = await loadSprite('assets/flametest/${item.assetName}');
        loadedSprites[item.assetName] = sprite;
      } catch (e) {
        debugPrint('Sprite yüklenemedi: ${item.assetName} - $e');
      }
    }
  }

  /// Haritaya 2x2 ve 3x3 rastgele binaları çakışmayacak şekilde yerleştirir
  void spawnRandomBuildings({int count = 6}) {
    clearAllBuildings();

    final random = math.Random();
    int placedCount = 0;
    int attempts = 0;

    final available = List<BuildingType>.from(buildingCatalog)..shuffle(random);

    while (placedCount < count && attempts < 250) {
      attempts++;
      final baseType = available[placedCount % available.length];

      // 2x2 veya 3x3 rastgele footprint
      final int fCols = random.nextBool() ? 3 : 2;
      final int fRows = random.nextBool() ? 3 : 2;

      final runtimeType = BuildingType(
        name: baseType.name,
        assetName: baseType.assetName,
        footprintCols: fCols,
        footprintRows: fRows,
        wallColor: baseType.wallColor,
        roofColor: baseType.roofColor,
        wallHeight: baseType.wallHeight,
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

  /// Ekrandaki (local) dokunma koordinatını kamera dünyasındaki koordinata çevirir
  Vector2 screenToWorld(Offset screenPoint) {
    return cameraComp.viewfinder.parentToLocal(Vector2(screenPoint.dx, screenPoint.dy));
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

  /// Grid (col, row) ➔ 2:1 İzometrik Dünya Koordinatı (Karo Merkezi)
  static Vector2 gridToIso(int col, int row) {
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

    // 1. AŞAMA: Görsel Hitbox Kontrolü (Bina Çatısı veya Gövdesine Tıklama)
    // Öndeki binalar arkadakileri kapattığı için yüksek priority'den başlanır
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
      // Oyuncu doğrudan binanın 2.5D görseline (çatısına/duvarına) dokundu
      if (isPlacingBuilding) {
        final name = clickedBuilding.buildingName;
        removeBuilding(clickedBuilding);
        selectionHighlight.hide();
        onTileSelected(clickedBuilding.col, clickedBuilding.row, '$name kaldırıldı (Arsa Boş)');
      } else {
        selectedTile = math.Point<int>(clickedBuilding.col, clickedBuilding.row);
        final centerPos = gridToIso(clickedBuilding.col, clickedBuilding.row);
        selectionHighlight.updatePosition(centerPos, true);
        onTileSelected(
          clickedBuilding.col,
          clickedBuilding.row,
          '${clickedBuilding.buildingName} (${clickedBuilding.footprintCols}x${clickedBuilding.footprintRows}) — Kök: (${clickedBuilding.col}, ${clickedBuilding.row})',
        );
      }
      return;
    }

    // 2. AŞAMA: Zemin Grid Rezervasyonu Kontrolü (Footprint Hitbox)
    final cell = isoToGrid(worldPos);

    if (cell != null) {
      selectedTile = cell;
      final centerPos = gridToIso(cell.x, cell.y);
      selectionHighlight.updatePosition(centerPos, true);

      final key = '${cell.x},${cell.y}';
      final existingBuilding = occupiedTiles[key];

      if (isPlacingBuilding) {
        if (existingBuilding != null) {
          // Tıklanan arsa rezervli -> binayı kaldır
          final name = existingBuilding.buildingName;
          removeBuilding(existingBuilding);
          onTileSelected(cell.x, cell.y, '$name kaldırıldı (Arsa Boş)');
        } else {
          // Seçili bina tipini bu karodan başlayarak yerleştirmeyi dene
          if (canPlaceBuilding(cell.x, cell.y, activeBuildingType)) {
            placeBuilding(cell.x, cell.y, activeBuildingType);
            onTileSelected(
              cell.x,
              cell.y,
              '${activeBuildingType.name} (${activeBuildingType.footprintCols}x${activeBuildingType.footprintRows}) inşa edildi!',
            );
          } else {
            onTileSelected(
              cell.x,
              cell.y,
              'Yetersiz alan! (${activeBuildingType.footprintCols}x${activeBuildingType.footprintRows} sığmıyor veya dolu)',
            );
          }
        }
      } else {
        if (existingBuilding != null) {
          final b = existingBuilding;
          onTileSelected(
            cell.x,
            cell.y,
            '${b.buildingName} (${b.footprintCols}x${b.footprintRows}) — Kök: (${b.col}, ${b.row})',
          );
        } else {
          onTileSelected(cell.x, cell.y, 'Boş Arsa');
        }
      }
    } else {
      selectedTile = null;
      selectionHighlight.hide();
    }
  }

  /// Binanın haritaya ve mevcut yapılara göre sığıp sığmadığını denetler
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
    // İzometrik derinlik: Binanın en ön (alt) köşesindeki karoya göre
    final maxCol = col + type.footprintCols - 1;
    final maxRow = row + type.footprintRows - 1;
    final priority = getBuildingPriority(maxCol, maxRow);

    // Footprint tabanının en alt güney ucu (Zemine basan anchor: Anchor.bottomCenter)
    final bottomX = (maxCol - maxRow) * (tileW / 2);
    final bottomY = (maxCol + maxRow) * (tileH / 2) + (tileH / 2);
    final anchorBottomPos = Vector2(bottomX, bottomY);

    final building = IsometricBuildingComponent(
      col: col,
      row: row,
      footprintCols: type.footprintCols,
      footprintRows: type.footprintRows,
      position: anchorBottomPos,
      buildingName: type.name,
      sprite: loadedSprites[type.assetName],
      wallColor: type.wallColor,
      roofColor: type.roofColor,
      wallHeight: type.wallHeight,
      priority: priority,
    );

    // Kapladığı tüm hücreleri işaretle
    for (int c = col; c < col + type.footprintCols; c++) {
      for (int r = row; r < row + type.footprintRows; r++) {
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

  /// Tek parmakla kamerayı kaydırma (Pan)
  void panCamera(double dx, double dy) {
    final zoom = cameraComp.viewfinder.zoom;
    final currentPos = cameraComp.viewfinder.position;
    final nextX = currentPos.x - (dx / zoom);
    final nextY = currentPos.y - (dy / zoom);
    cameraComp.viewfinder.position = _clampPosition(Vector2(nextX, nextY));
  }

  /// 2 parmakla pinch zoom
  void applyPinchZoom(double targetZoom) {
    cameraComp.viewfinder.zoom = targetZoom.clamp(minZoom, maxZoom);
    cameraComp.viewfinder.position = _clampPosition(cameraComp.viewfinder.position);
  }

  /// Butonla adım adım zoom yapma
  void zoomByStep(double step) {
    final current = cameraComp.viewfinder.zoom;
    cameraComp.viewfinder.zoom = (current + step).clamp(minZoom, maxZoom);
    cameraComp.viewfinder.position = _clampPosition(cameraComp.viewfinder.position);
  }

  /// Masaüstü / Web için fare tekerleğiyle zoom
  @override
  void onScroll(PointerScrollInfo info) {
    final scrollDelta = info.scrollDelta.global.y;
    if (scrollDelta < 0) {
      zoomByStep(0.15);
    } else if (scrollDelta > 0) {
      zoomByStep(-0.15);
    }
  }

  /// Haritayı merkeze al
  void centerMap() {
    // 16x16 grid'in merkezi: col = 8, row = 8
    final centerCol = gridSize / 2;
    final centerRow = gridSize / 2;
    final centerPos = Vector2(0, (centerCol + centerRow) * (tileH / 2));
    cameraComp.viewfinder.position = centerPos;
    cameraComp.viewfinder.zoom = 1.0;
  }

  /// Haritanın dışına sınırsız kaymayı engelleyen sınırlar (Camera Clamping)
  Vector2 _clampPosition(Vector2 pos) {
    final halfMapWidth = (gridSize * tileW) / 2 + 800;
    final mapHeight = (gridSize * tileH) + 800;

    final clampedX = pos.x.clamp(-halfMapWidth, halfMapWidth);
    final clampedY = pos.y.clamp(-400.0, mapHeight);
    return Vector2(clampedX, clampedY);
  }

  void toggleBuildingPlacement() {
    isPlacingBuilding = !isPlacingBuilding;
  }
}

/// 2:1 İzometrik Karo Bileşeni (Elmas Şeklinde Zemin)
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

/// Seçili Karoyu Gösteren Vurgu Katmanı
class IsometricSelectionHighlight extends PositionComponent {
  final double tileW;
  final double tileH;
  bool isVisible = false;

  IsometricSelectionHighlight({required this.tileW, required this.tileH})
      : super(
          size: Vector2(tileW, tileH),
          anchor: Anchor.center,
          priority: 99999, // Her zaman en üstte görünsün
        );

  void updatePosition(Vector2 pos, bool visible) {
    position = pos;
    isVisible = visible;
  }

  void hide() {
    isVisible = false;
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;
    super.render(canvas);

    final hw = tileW / 2;
    final hh = tileH / 2;

    final path = Path()
      ..moveTo(hw, 0)
      ..lineTo(tileW, hh)
      ..lineTo(hw, tileH)
      ..lineTo(0, hh)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFFE2B755).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFFFF0B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }
}

/// Bina Türü Tanımı (Footprint ve Görsel Özellikler)
class BuildingType {
  final String name;
  final String assetName;
  final int footprintCols;
  final int footprintRows;
  final Color wallColor;
  final Color roofColor;
  final double wallHeight;

  const BuildingType({
    required this.name,
    required this.assetName,
    required this.footprintCols,
    required this.footprintRows,
    this.wallColor = const Color(0xFF2C3E50),
    this.roofColor = const Color(0xFFE2B755),
    this.wallHeight = 28.0,
  });
}

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
  }) : super(
          position: position,
          // Zemine basan alt-orta nokta
          anchor: Anchor.bottomCenter,
          priority: priority,
        ) {
    const double hw = IsometricMapGame.tileW / 2;
    const double hh = IsometricMapGame.tileH / 2;

    // Sprite / Bounding Box boyutu (Genişlik ve dikey çatı yüksekliği)
    final totalW = (footprintCols + footprintRows) * hw;
    final totalH = (footprintCols + footprintRows) * hh + wallHeight;
    size = Vector2(totalW, totalH);

    // Taban köşe noktaları (Anchor.bottomCenter = (footprintCols * hw, totalH))
    localSouth = Offset(footprintCols * hw, totalH);
    localWest = Offset(0, totalH - footprintCols * hh);
    localEast = Offset(totalW, totalH - footprintRows * hh);
    localNorth = Offset(footprintRows * hw, totalH - (footprintCols + footprintRows) * hh);

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

    // Eğer Sprite görseli varsa render dikdörtgenini hesapla
    if (sprite != null) {
      final double spriteW = totalW * 1.15;
      final double ar = sprite!.srcSize.x / sprite!.srcSize.y;
      final double spriteH = spriteW / ar;
      final double drawX = localSouth.dx - (spriteW / 2);
      final double drawY = localSouth.dy - spriteH;
      _spriteDrawRect = Rect.fromLTWH(drawX, drawY, spriteW, spriteH);
    }
  }

  /// Dünya koordinatındaki bir noktanın binanın görsel gövdesine (çatı veya duvar) denk gelip gelmediğini denetler
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

    // 2) Gerçek PNG/WebP Sprite Çizimi
    if (sprite != null && _spriteDrawRect != null) {
      sprite!.render(
        canvas,
        position: Vector2(_spriteDrawRect!.left, _spriteDrawRect!.top),
        size: Vector2(_spriteDrawRect!.width, _spriteDrawRect!.height),
      );
      return;
    }

    // 3) Prosedürel 2.5D Çizim (Yedek Mod)
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

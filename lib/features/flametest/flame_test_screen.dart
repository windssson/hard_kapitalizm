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
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 1) {
      // Tek parmak başladı -> Kaydırma (Pan) başlangıcı
      _lastPanPoint = event.position;
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
    _activePointers[event.pointer] = event.position;

    if (_activePointers.length == 1) {
      // 1 Dokunma: Anında ve Kesintisiz Kaydırma (Pan)
      final currentPoint = event.position;
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
    final releasedScreenPoint = event.localPosition;
    final wasSinglePointer = _activePointers.length == 1;

    _activePointers.remove(event.pointer);

    if (_activePointers.length == 1) {
      _lastPanPoint = _activePointers.values.first;
    } else if (_activePointers.isEmpty) {
      // Dokunma bitti: Sürükleme eşiği aşılmadıysa tıklandı kabul et
      if (wasSinglePointer && _totalMovement < _tapMovementThreshold) {
        _game.handleTapAtScreenPoint(releasedScreenPoint);
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
                    icon: Icons.add_business_rounded,
                    label: 'Bina Ekle',
                    accent: true,
                    onTap: () {
                      _game.toggleBuildingPlacement();
                      setState(() {
                        _currentMode = _game.isPlacingBuilding ? 'Bina Yerleştir' : 'Seçim Modu';
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

  // Kamera Açısı: Tam 26 Derece İzometrik Eğim
  static const double angleDegrees = 26.0;
  static const double tileW = 64.0;
  // tan(26°) ≈ 0.48773 -> 26 derecelik ortografik projeksiyon yüksekliği
  static final double tileH = tileW * math.tan(angleDegrees * math.pi / 180.0);
  static const int gridSize = 16;

  // Zoom Limitleri
  static const double minZoom = 0.4;
  static const double maxZoom = 2.6;

  late final World gameWorld;
  late final CameraComponent cameraComp;

  bool isPlacingBuilding = false;
  final Map<String, String> placedBuildings = {};
  
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

    // Kamerayı haritanın tam merkezine odakla
    centerMap();
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
          // Derinlik sıralaması: Arkadan öne (row + col)
          priority: (col + row),
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
    final worldPos = cameraComp.viewfinder.parentToLocal(Vector2(screenPoint.dx, screenPoint.dy));
    final cell = isoToGrid(worldPos);

    if (cell != null) {
      selectedTile = cell;
      final centerPos = gridToIso(cell.x, cell.y);
      selectionHighlight.updatePosition(centerPos, true);

      final key = '${cell.x},${cell.y}';
      if (isPlacingBuilding) {
        if (placedBuildings.containsKey(key)) {
          placedBuildings.remove(key);
          _removeBuildingAt(cell.x, cell.y);
          onTileSelected(cell.x, cell.y, 'Boş Arsa');
        } else {
          placedBuildings[key] = 'Endüstri Tesisi';
          _addBuildingAt(cell.x, cell.y, 'Endüstri Tesisi');
          onTileSelected(cell.x, cell.y, 'Endüstri Tesisi Kuruldu');
        }
      } else {
        final building = placedBuildings[key] ?? 'Çim/Arsa';
        onTileSelected(cell.x, cell.y, building);
      }
    } else {
      selectedTile = null;
      selectionHighlight.hide();
    }
  }

  void _addBuildingAt(int col, int row, String name) {
    final pos = gridToIso(col, row);
    final building = IsometricBuildingComponent(
      col: col,
      row: row,
      position: pos,
      buildingWidth: tileW,
      buildingHeight: tileH,
      buildingName: name,
      // Derinlik sıralaması: Karodan hemen sonra ön planda olması için
      priority: (col + row) * 10 + 5,
    );
    gameWorld.add(building);
  }

  void _removeBuildingAt(int col, int row) {
    final toRemove = gameWorld.children
        .whereType<IsometricBuildingComponent>()
        .where((b) => b.col == col && b.row == row)
        .toList();
    for (final b in toRemove) {
      b.removeFromParent();
    }
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

/// 2:1 İzometrik 2.5D Bina Modeli
class IsometricBuildingComponent extends PositionComponent {
  final int col;
  final int row;
  final double buildingWidth;
  final double buildingHeight;
  final String buildingName;

  IsometricBuildingComponent({
    required this.col,
    required this.row,
    required Vector2 position,
    required this.buildingWidth,
    required this.buildingHeight,
    required this.buildingName,
    required int priority,
  }) : super(
          position: Vector2(position.x, position.y - 14),
          size: Vector2(buildingWidth, buildingHeight + 28),
          anchor: Anchor.center,
          priority: priority,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    const bHeight = 24.0;
    final hw = buildingWidth / 2;
    final hh = buildingHeight / 2;

    // Sol Yüz
    final leftWall = Path()
      ..moveTo(0, hh)
      ..lineTo(hw, buildingHeight)
      ..lineTo(hw, buildingHeight - bHeight)
      ..lineTo(0, hh - bHeight)
      ..close();

    final leftPaint = Paint()
      ..color = const Color(0xFF202E3D)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftWall, leftPaint);

    // Sağ Yüz
    final rightWall = Path()
      ..moveTo(hw, buildingHeight)
      ..lineTo(buildingWidth, hh)
      ..lineTo(buildingWidth, hh - bHeight)
      ..lineTo(hw, buildingHeight - bHeight)
      ..close();

    final rightPaint = Paint()
      ..color = const Color(0xFF2C3E52)
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightWall, rightPaint);

    // Çatı (İzometrik Tepe - 2:1 elmas formu)
    final roof = Path()
      ..moveTo(hw, 0 - (bHeight - hh))
      ..lineTo(buildingWidth, hh - bHeight)
      ..lineTo(hw, buildingHeight - bHeight)
      ..lineTo(0, hh - bHeight)
      ..close();

    final roofPaint = Paint()
      ..color = const Color(0xFFD4A034)
      ..style = PaintingStyle.fill;
    canvas.drawPath(roof, roofPaint);

    // Çatı Kenarlık Vurgusu
    final borderPaint = Paint()
      ..color = const Color(0xFFFFDF7D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(roof, borderPaint);
  }
}

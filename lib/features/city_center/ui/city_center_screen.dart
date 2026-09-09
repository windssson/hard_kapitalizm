import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/city_center/game/city_center_game.dart';

/// Şehir Merkezi Ekranı (City Center - Zorunlu Yatay / Landscape Mod)
class CityCenterScreen extends StatefulWidget {
  const CityCenterScreen({super.key});

  @override
  State<CityCenterScreen> createState() => _CityCenterScreenState();
}

class _CityCenterScreenState extends State<CityCenterScreen> {
  late final CityCenterGame _game;
  String _selectedTileInfo = 'Tarla (tarlayeni.png) [6,6] hazır. Bir karoya dokunun';
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

    // 1. ADIM: Ekranı YATAY (Landscape) Moduna Kilitle
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 2. ADIM: Oyun Motorunu Başlat
    _game = CityCenterGame(
      onTileSelected: (col, row, type) {
        if (!mounted) return;
        setState(() {
          _selectedTileInfo = 'Karo: ($col, $row) — $type';
        });
      },
    );
  }

  @override
  void dispose() {
    // Ekrandan çıkıldığında DİKEY (Portrait) Moduna geri dön
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
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
        _game.cameraController.pan(delta.dx, delta.dy);
      }
    } else if (_activePointers.length >= 2) {
      // 2 Dokunma: Pinch Zoom + Çift parmakla kaydırma
      final points = _activePointers.values.toList();
      final currentDistance = (points[0] - points[1]).distance;
      if (_initialPinchDistance > 10) {
        final scale = currentDistance / _initialPinchDistance;
        _game.cameraController.applyPinchZoom(_initialPinchZoom * scale);
      }

      final midPoint = (points[0] + points[1]) / 2;
      final delta = midPoint - _lastPanPoint;
      _lastPanPoint = midPoint;
      _totalMovement += delta.distance;
      if (delta.dx != 0 || delta.dy != 0) {
        _game.cameraController.pan(delta.dx, delta.dy);
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

  void _handleBack() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Cihazın fiziksel geri tuşuna basıldığında da dikey moda dön
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
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

            // Üst Bilgi Barı (Yatay moda optimize, kompakt Safe-Area)
            Positioned(
              top: MediaQuery.of(context).padding.top + 6.h,
              left: math.max(16.0, MediaQuery.of(context).padding.left + 8.0),
              right: math.max(16.0, MediaQuery.of(context).padding.right + 8.0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14.r),
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 18.sp),
                      onPressed: _handleBack,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Şehir Merkezi',
                                style: AppTextStyles.title.copyWith(
                                  color: AppColors.gold,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  'YATAY MOD (2.5D)',
                                  style: TextStyle(
                                    color: AppColors.goldLight,
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            _selectedTileInfo,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
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

            // Alt Kontrol Butonları (Yatay mod için altta kompakt dock)
            Positioned(
              bottom: 12.h,
              left: math.max(20.0, MediaQuery.of(context).padding.left + 12.0),
              right: math.max(20.0, MediaQuery.of(context).padding.right + 12.0),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 620.w),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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
                        onTap: () => _game.cameraController.zoomByStep(0.2),
                      ),
                      _buildActionButton(
                        icon: Icons.zoom_out_rounded,
                        label: 'Uzaklaş',
                        onTap: () => _game.cameraController.zoomByStep(-0.2),
                      ),
                      _buildActionButton(
                        icon: Icons.center_focus_strong_rounded,
                        label: 'Merkezle',
                        onTap: () => _game.cameraController.centerMap(),
                      ),
                      _buildActionButton(
                        icon: Icons.shuffle_rounded,
                        label: 'Rastgele',
                        onTap: () {
                          _game.spawnRandomBuildings(count: 6);
                          setState(() {
                            _selectedTileInfo = 'Rastgele 2x2 binalar serpiştirildi';
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
            ),
          ],
        ),
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(7.w),
              decoration: BoxDecoration(
                color: accent
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : AppColors.cardBgLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent ? AppColors.gold : AppColors.border,
                  width: 1.1,
                ),
              ),
              child: Icon(
                icon,
                size: 17.sp,
                color: accent ? AppColors.gold : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                color: accent ? AppColors.gold : AppColors.textSecondary,
                fontSize: 9.sp,
                fontWeight: accent ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

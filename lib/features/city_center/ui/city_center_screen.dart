import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/features/city_center/game/city_center_game.dart';

/// Şehir Merkezi Ekranı (City Center - Zorunlu Yatay / Landscape Mod)
/// Sol: Bilgi, Mod ve Navigasyon Dikey Paneli
/// Sağ: Eylem ve İnşa Dikey Çubuğu
/// Orta: Kesintisiz ve Geniş 2.5D İzometrik Şehir Haritası
class CityCenterScreen extends StatefulWidget {
  const CityCenterScreen({super.key});

  @override
  State<CityCenterScreen> createState() => _CityCenterScreenState();
}

class _CityCenterScreenState extends State<CityCenterScreen> {
  late final CityCenterGame _game;
  String _selectedTileInfo = 'Tarla (tarlayeni.png) [6,6] hazır.\nBir karoya dokunun.';
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
          _selectedTileInfo = 'Karo: ($col, $row)\n$type';
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
      _lastPanPoint = event.localPosition;
      _totalMovement = 0.0;
    } else if (_activePointers.length == 2) {
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
      final currentPoint = event.localPosition;
      final delta = currentPoint - _lastPanPoint;
      _lastPanPoint = currentPoint;
      _totalMovement += delta.distance;

      if (delta.dx != 0 || delta.dy != 0) {
        _game.cameraController.pan(delta.dx, delta.dy);
      }
    } else if (_activePointers.length >= 2) {
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
    final padding = MediaQuery.of(context).padding;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090D12),
        body: Stack(
          children: [
            // 1. Zemin: 2.5D İzometrik Oyun Alanı & Ham Dokunmatik Kontroller
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

            // 2. DİKEY SOL PANEL: Navigasyon, Mod ve Durum Bilgisi
            Positioned(
              top: math.max(10.0, padding.top + 4.0),
              bottom: math.max(10.0, padding.bottom + 4.0),
              left: math.max(12.0, padding.left + 4.0),
              width: 210,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 14,
                      offset: const Offset(3, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Geri Dönüş ve Başlık
                    Row(
                      children: [
                        InkWell(
                          onTap: _handleBack,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.gold,
                              size: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Şehir Merkezi',
                                style: AppTextStyles.title.copyWith(
                                  color: AppColors.gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '2.5D İzometrik',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 8),

                    // Aktif Mod Rozeti (Seçim / İnşa)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _game.isPlacingBuilding
                            ? AppColors.gold.withValues(alpha: 0.2)
                            : AppColors.cardBgLight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _game.isPlacingBuilding ? AppColors.gold : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _game.isPlacingBuilding
                                ? Icons.add_business_rounded
                                : Icons.touch_app_rounded,
                            size: 14,
                            color: _game.isPlacingBuilding
                                ? AppColors.gold
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _currentMode,
                              style: TextStyle(
                                color: _game.isPlacingBuilding
                                    ? AppColors.gold
                                    : AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Durum / Seçili Karo Bilgi Alanı
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DURUM & DETAY',
                                style: TextStyle(
                                  color: AppColors.goldLight.withValues(alpha: 0.7),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedTileInfo,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 10,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. DİKEY SAĞ PANEL: Eylem, Kamera ve İnşa Buton Çubuğu (Toolbar)
            Positioned(
              top: math.max(10.0, padding.top + 4.0),
              bottom: math.max(10.0, padding.bottom + 4.0),
              right: math.max(12.0, padding.right + 4.0),
              width: 72,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 14,
                      offset: const Offset(-3, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildVerticalActionButton(
                        icon: Icons.zoom_in_rounded,
                        label: 'Yakınlaş',
                        onTap: () => _game.cameraController.zoomByStep(0.2),
                      ),
                      const SizedBox(height: 5),
                      _buildVerticalActionButton(
                        icon: Icons.zoom_out_rounded,
                        label: 'Uzaklaş',
                        onTap: () => _game.cameraController.zoomByStep(-0.2),
                      ),
                      const SizedBox(height: 5),
                      _buildVerticalActionButton(
                        icon: Icons.center_focus_strong_rounded,
                        label: 'Merkezle',
                        onTap: () => _game.cameraController.centerMap(),
                      ),
                      const SizedBox(height: 5),
                      _buildVerticalActionButton(
                        icon: Icons.shuffle_rounded,
                        label: 'Rastgele',
                        onTap: () {
                          _game.spawnRandomBuildings(count: 6);
                          setState(() {
                            _selectedTileInfo = 'Rastgele 2x2 binalar serpiştirildi.';
                          });
                        },
                      ),
                      const SizedBox(height: 5),
                      _buildVerticalActionButton(
                        icon: Icons.swap_horiz_rounded,
                        label: _game.activeBuildingType.name,
                        onTap: () {
                          _game.cycleBuildingType();
                          setState(() {
                            if (_game.isPlacingBuilding) {
                              _currentMode = '${_game.activeBuildingType.name} (${_game.activeBuildingType.footprintCols}x${_game.activeBuildingType.footprintRows})';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 5),
                      _buildVerticalActionButton(
                        icon: Icons.add_business_rounded,
                        label: _game.isPlacingBuilding ? 'İnşa Açık' : 'İnşa Et',
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

  Widget _buildVerticalActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.gold.withValues(alpha: 0.22)
              : AppColors.cardBgLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent ? AppColors.gold : AppColors.border,
            width: 1.1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accent
                    ? AppColors.gold.withValues(alpha: 0.25)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: accent ? AppColors.gold : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent ? AppColors.gold : AppColors.textSecondary,
                fontSize: 8.5,
                fontWeight: accent ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

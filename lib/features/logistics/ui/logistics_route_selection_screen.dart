import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';

class LogisticsRouteSelectionScreen extends ConsumerStatefulWidget {
  final LogisticsVehicleModel vehicle;
  final List<CityModel> cities;

  const LogisticsRouteSelectionScreen({
    super.key,
    required this.vehicle,
    required this.cities,
  });

  @override
  ConsumerState<LogisticsRouteSelectionScreen> createState() =>
      _LogisticsRouteSelectionScreenState();
}

class _LogisticsRouteSelectionScreenState
    extends ConsumerState<LogisticsRouteSelectionScreen> {
  static const double _minLat = 35.9;
  static const double _maxLat = 42.7;
  static const double _minLon = 25.7;
  static const double _maxLon = 47.0;

  String? _cityAId;
  String? _cityBId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cityAId = widget.cities.any(
      (city) => city.id == widget.vehicle.routeCityAId,
    )
        ? widget.vehicle.routeCityAId
        : null;
    _cityBId = widget.cities.any(
      (city) => city.id == widget.vehicle.routeCityBId,
    )
        ? widget.vehicle.routeCityBId
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final cityA = _findCity(_cityAId);
    final cityB = _findCity(_cityBId);
    final canSave = cityA != null && cityB != null && cityA.id != cityB.id;

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Rota Secimi'),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
                child: Column(
                  children: [
                    _buildHeader(cityA, cityB),
                    SizedBox(height: 12.h),
                    Expanded(child: _buildMap(cityA, cityB)),
                    SizedBox(height: 12.h),
                    _buildFooter(canSave, cityA, cityB),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CityModel? cityA, CityModel? cityB) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.vehicle.hasAssignedRoute
                ? 'Mevcut rotayi guncelle'
                : 'Arac icin sehir cifti sec',
            style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.titleLarge),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildSelectedCityChip(
                  label: 'Baslangic',
                  city: cityA,
                  color: AppColors.gold,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(AppIcons.syncAlt, color: AppColors.textMuted, size: AppIconSizes.regular),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSelectedCityChip(
                  label: 'Hedef',
                  city: cityB,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Haritadan iki farkli sehir sec. Rota cift yonludur.',
            style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCityChip({
    required String label,
    required CityModel? city,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            city?.name ?? 'Secilmedi',
            style: AppTextStyles.body.standardCopyWith(
              color: city == null ? AppColors.textMuted : AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMap(CityModel? cityA, CityModel? cityB) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 2.2,
        boundaryMargin: EdgeInsets.all(24.w),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            Offset project(CityModel city) {
              final normalizedX =
                  (city.mapPositionY - _minLon) / (_maxLon - _minLon);
              final normalizedY =
                  (_maxLat - city.mapPositionX) / (_maxLat - _minLat);
              return Offset(normalizedX * width, normalizedY * height);
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/backmap.webp',
                    fit: BoxFit.fill,
                    color: AppFx.panelWash(0.38),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RouteSelectionPainter(
                      start: cityA == null ? null : project(cityA),
                      end: cityB == null ? null : project(cityB),
                    ),
                  ),
                ),
                ...widget.cities.map((city) {
                  final position = project(city);
                  return _buildCityMarker(city, position, width, height);
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCityMarker(
    CityModel city,
    Offset position,
    double mapWidth,
    double mapHeight,
  ) {
    final isStart = city.id == _cityAId;
    final isEnd = city.id == _cityBId;
    final isSelected = isStart || isEnd;
    final color = isStart
        ? AppColors.gold
        : isEnd
        ? AppColors.blue
        : AppColors.textPrimary;
    const markerWidth = 82.0;
    const markerHeight = 48.0;
    final left = (position.dx - markerWidth / 2)
        .clamp(0.0, mapWidth - markerWidth)
        .toDouble();
    final top = (position.dy - 10.h)
        .clamp(0.0, mapHeight - markerHeight)
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: markerWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectCity(city),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 18.w : 13.w,
              height: isSelected ? 18.w : 13.w,
              decoration: BoxDecoration(
                color: isSelected ? color : AppFx.panelWash(0.87),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.textPrimary : AppColors.gold,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isSelected ? 0.65 : 0.24),
                    blurRadius: isSelected ? 12 : 6,
                    spreadRadius: isSelected ? 3 : 1,
                  ),
                ],
              ),
              child: isSelected
                  ? Center(
                      child: Text(
                        isStart ? '1' : '2',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textOnAccent,
                          fontSize: AppTypography.micro,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppFx.panelWash(isSelected ? 0.88 : 0.7),
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(
                  color: color.withValues(alpha: isSelected ? 0.75 : 0.25),
                ),
              ),
              child: Text(
                city.name,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.micro,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool canSave, CityModel? cityA, CityModel? cityB) {
    final distance = cityA != null && cityB != null
        ? _calculateDistanceKm(cityA, cityB)
        : null;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              distance == null
                  ? 'Rota icin iki sehir sec.'
                  : 'Mesafe: ${distance.toStringAsFixed(0)} km',
              style: AppTextStyles.body.standardCopyWith(
                color: distance == null ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: AppTypography.body,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _isSaving
                ? null
                : () => setState(() {
                      _cityAId = null;
                      _cityBId = null;
                    }),
            child: const Text('Sifirla'),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: canSave && !_isSaving ? _saveRoute : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              disabledBackgroundColor: AppColors.border,
              foregroundColor: AppColors.textOnAccent,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: AppLoadingIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnAccent,
                    ),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _selectCity(CityModel city) {
    setState(() {
      if (_cityAId == null || (_cityAId != null && _cityBId != null)) {
        _cityAId = city.id;
        _cityBId = null;
        return;
      }

      if (_cityAId == city.id) return;
      _cityBId = city.id;
    });
  }

  Future<void> _saveRoute() async {
    if (_cityAId == null || _cityBId == null || _cityAId == _cityBId) return;

    setState(() => _isSaving = true);
    final result = await ref.read(logisticsActionProvider).setVehicleRoute(
          vehicleId: widget.vehicle.id,
          cityAId: _cityAId!,
          cityBId: _cityBId!,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Rota Kaydedildi',
        message: result['message']?.toString() ?? 'Arac rotasi guncellendi.',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message']?.toString() ?? 'Rota kaydedilemedi.',
      type: SnackbarType.error,
    );
  }

  CityModel? _findCity(String? cityId) {
    if (cityId == null || cityId.isEmpty) return null;
    for (final city in widget.cities) {
      if (city.id == cityId) return city;
    }
    return null;
  }

  double _calculateDistanceKm(CityModel cityA, CityModel cityB) {
    const earthRadiusKm = 6371.0;
    final lat1 = _degreesToRadians(cityA.mapPositionX);
    final lat2 = _degreesToRadians(cityB.mapPositionX);
    final dLat = _degreesToRadians(cityB.mapPositionX - cityA.mapPositionX);
    final dLon = _degreesToRadians(cityB.mapPositionY - cityA.mapPositionY);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return earthRadiusKm * 2 * math.asin(math.sqrt(a));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
}

class _RouteSelectionPainter extends CustomPainter {
  final Offset? start;
  final Offset? end;

  const _RouteSelectionPainter({
    required this.start,
    required this.end,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (start == null || end == null) return;

    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.75)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start!, end!, paint);
  }

  @override
  bool shouldRepaint(covariant _RouteSelectionPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}

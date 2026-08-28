import 'dart:math' as math;

import 'package:city_picker_from_map/city_picker_from_map.dart';
// ignore: implementation_imports
import 'package:city_picker_from_map/src/parser.dart';
// ignore: implementation_imports
import 'package:city_picker_from_map/src/size_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
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
  List<City> _cityList = [];
  bool _isLoadingMap = true;
  late TransformationController _transformationController;
  bool _hasCenteredMap = false;

  String? _cityAId;
  String? _cityBId;
  bool _isSaving = false;

  String _normalizeString(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  Future<void> _loadCityList() async {
    try {
      final list = await Parser.instance.svgToCityList(Maps.TURKEY);
      if (!mounted) return;
      setState(() {
        _cityList = list;
        _isLoadingMap = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMap = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
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
    _loadCityList();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  City? _findSvgCity(CityModel? cityModel) {
    if (cityModel == null || _cityList.isEmpty) return null;
    final normName = _normalizeString(cityModel.name);
    return _cityList.cast<City?>().firstWhere(
      (c) => c != null && _normalizeString(c.title) == normName,
      orElse: () => null,
    );
  }

  void _centerMap(double viewportWidth, double viewportHeight) {
    if (_cityList.isEmpty) return;
    final childWidth = SizeController.instance.mapSize.width;
    final childHeight = SizeController.instance.mapSize.height;
    final scale = (viewportWidth / childWidth) * 1.12;
    final tx = (viewportWidth - childWidth * scale) / 2;
    final ty = (viewportHeight - childHeight * scale) / 2;

    // ignore: deprecated_member_use
    _transformationController.value = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(tx, ty)
      // ignore: deprecated_member_use
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final cityA = _findCity(_cityAId);
    final cityB = _findCity(_cityBId);
    final canSave = cityA != null && cityB != null && cityA.id != cityB.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Rota Belirleme'),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 14.h),
                child: Column(
                  children: [
                    _buildHeader(cityA, cityB),
                    SizedBox(height: 10.h),
                    Expanded(child: _buildMapContainer(cityA, cityB)),
                    SizedBox(height: 10.h),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.vehicle.hasAssignedRoute
                    ? 'Mevcut Rotayı Güncelle'
                    : 'Çift Yönlü Rota Belirle',
                style: AppTextStyles.h2.standardCopyWith(
                  fontSize: AppTypography.titleLarge,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AppColors.borderGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 13.sp,
                      color: AppColors.gold,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${widget.vehicle.speedKmh} km/s',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.goldLight,
                        fontSize: AppTypography.micro,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildSelectedCityChip(
                  label: '1. Başlangıç',
                  city: cityA,
                  color: AppColors.gold,
                  isStart: true,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: InkWell(
                  onTap: (cityA != null || cityB != null) ? _swapCities : null,
                  borderRadius: BorderRadius.circular(999.r),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.borderGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      AppIcons.syncAlt,
                      color: (cityA != null || cityB != null)
                          ? AppColors.gold
                          : AppColors.textMuted,
                      size: 16.sp,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildSelectedCityChip(
                  label: '2. Hedef',
                  city: cityB,
                  color: AppColors.blue,
                  isStart: false,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Haritadaki illere dokunun veya büyütece basarak listeden seçin. Rota otomatik çift yönlüdür.',
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.micro,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCityChip({
    required String label,
    required CityModel? city,
    required Color color,
    required bool isStart,
  }) {
    return InkWell(
      onTap: () => _showCitySearchSheet(context, isStart),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.standardCopyWith(
                      color: color,
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    city?.name ?? 'Şehir Seçin',
                    style: AppTextStyles.body.standardCopyWith(
                      color: city == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.search_rounded,
              color: color.withValues(alpha: 0.7),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapContainer(CityModel? cityA, CityModel? cityB) {
    if (_isLoadingMap) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLoadingIndicator(color: AppColors.gold),
            SizedBox(height: 12.h),
            Text(
              'Türkiye Haritası Yükleniyor...',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final svgCityA = _findSvgCity(cityA);
    final svgCityB = _findSvgCity(cityB);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final childWidth = SizeController.instance.mapSize.width;
          final childHeight = SizeController.instance.mapSize.height;

          if (!_hasCenteredMap) {
            _hasCenteredMap = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _centerMap(width, height);
              }
            });
          }

          Offset? posA = svgCityA?.path.getBounds().center;
          Offset? posB = svgCityB?.path.getBounds().center;

          return Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.3,
                maxScale: 4.5,
                boundaryMargin: EdgeInsets.symmetric(
                  horizontal: childWidth * 0.8,
                  vertical: childHeight * 0.8,
                ),
                constrained: false,
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: childWidth,
                  height: childHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _handleMapTap(details.localPosition),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            size: Size(childWidth, childHeight),
                            painter: _TurkeyRouteMapPainter(
                              cities: _cityList,
                              cityA: svgCityA,
                              cityB: svgCityB,
                              normalizeFn: _normalizeString,
                            ),
                          ),
                        ),
                        if (posA != null && cityA != null)
                          _buildSvgMarker(
                            position: posA,
                            label: '1',
                            cityName: cityA.name,
                            color: AppColors.gold,
                          ),
                        if (posB != null && cityB != null)
                          _buildSvgMarker(
                            position: posB,
                            label: '2',
                            cityName: cityB.name,
                            color: AppColors.blue,
                          ),
                        if (posA != null && posB != null && cityA != null && cityB != null)
                          _buildMidpointDistanceTag(
                            midpoint: (posA + posB) / 2,
                            distanceKm: _calculateDistanceKm(cityA, cityB),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12.h,
                right: 12.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        final val = _transformationController.value;
                        // ignore: deprecated_member_use
                        _transformationController.value = val.clone()..scale(1.25);
                      },
                    ),
                    SizedBox(height: 6.h),
                    _buildZoomButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        final val = _transformationController.value;
                        // ignore: deprecated_member_use
                        _transformationController.value = val.clone()..scale(0.8);
                      },
                    ),
                    SizedBox(height: 6.h),
                    _buildZoomButton(
                      icon: Icons.center_focus_strong_rounded,
                      onTap: () => _centerMap(width, height),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: 32.w,
        height: 32.w,
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.gold, size: 18.sp),
      ),
    );
  }

  Widget _buildSvgMarker({
    required Offset position,
    required String label,
    required String cityName,
    required Color color,
  }) {
    const markerWidth = 90.0;
    return Positioned(
      left: position.dx - markerWidth / 2,
      top: position.dy - 38.0,
      width: markerWidth,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.cardBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: color, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                cityName,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.7),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMidpointDistanceTag({
    required Offset midpoint,
    required double distanceKm,
  }) {
    const tagWidth = 100.0;
    return Positioned(
      left: midpoint.dx - tagWidth / 2,
      top: midpoint.dy - 12.0,
      width: tagWidth,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: AppColors.cardBg.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.straighten_rounded,
                  size: 12.sp,
                  color: AppColors.gold,
                ),
                SizedBox(width: 4.w),
                Text(
                  '${distanceKm.toStringAsFixed(0)} km',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.goldLight,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMapTap(Offset tapPos) {
    for (final city in _cityList) {
      if (city.path.contains(tapPos)) {
        final normName = _normalizeString(city.title);
        final matchedCity = widget.cities.cast<CityModel?>().firstWhere(
          (c) => c != null && _normalizeString(c.name) == normName,
          orElse: () => null,
        );
        if (matchedCity != null) {
          _selectCity(matchedCity);
          AppHaptic.selection();
        }
        break;
      }
    }
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

  void _swapCities() {
    AppHaptic.medium();
    setState(() {
      final temp = _cityAId;
      _cityAId = _cityBId;
      _cityBId = temp;
    });
  }

  Widget _buildFooter(bool canSave, CityModel? cityA, CityModel? cityB) {
    final distance = cityA != null && cityB != null
        ? _calculateDistanceKm(cityA, cityB)
        : null;

    final durationHours = (distance != null && widget.vehicle.speedKmh > 0)
        ? (distance / widget.vehicle.speedKmh)
        : null;

    final durationText = durationHours != null
        ? '${durationHours.floor()} sa ${(durationHours.remainder(1.0) * 60).round()} dk'
        : null;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distance == null
                      ? 'Haritadan 2 şehir seçin'
                      : 'Mesafe: ${distance.toStringAsFixed(0)} km',
                  style: AppTextStyles.body.standardCopyWith(
                    color: distance == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (durationText != null) ...[
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12.sp,
                        color: AppColors.gold,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Tahmini Sefer: $durationText',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.goldLight,
                          fontSize: AppTypography.micro,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: _isSaving
                ? null
                : () => setState(() {
                      _cityAId = null;
                      _cityBId = null;
                    }),
            child: Text(
              'Sıfırla',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: canSave && !_isSaving ? _saveRoute : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              disabledBackgroundColor: AppColors.cardBgLight,
              foregroundColor: AppColors.background,
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: AppLoadingIndicator(
                      strokeWidth: 2,
                      color: AppColors.background,
                    ),
                  )
                : const Text(
                    'Kaydet',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }

  void _showCitySearchSheet(BuildContext context, bool isStart) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
      ),
      builder: (sheetCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = widget.cities.where((c) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: (isStart ? AppColors.gold : AppColors.blue)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isStart
                              ? Icons.trip_origin_rounded
                              : Icons.location_on_rounded,
                          color: isStart ? AppColors.gold : AppColors.blue,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        isStart
                            ? '1. Başlangıç Şehrini Seçin'
                            : '2. Hedef Şehrini Seçin',
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    onChanged: (val) => setSheetState(() => searchQuery = val),
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Şehir ara...',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.gold,
                        size: 20.sp,
                      ),
                      filled: true,
                      fillColor: AppColors.cardBgLight,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        color: AppColors.border.withValues(alpha: 0.25),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final city = filtered[index];
                        final isSelected = isStart
                            ? _cityAId == city.id
                            : _cityBId == city.id;

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? (isStart ? AppColors.gold : AppColors.blue)
                                : AppColors.cardBgLight,
                            radius: 16.r,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.background
                                    : AppColors.textMuted,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            city.name,
                            style: TextStyle(
                              color: isSelected
                                  ? (isStart ? AppColors.gold : AppColors.blue)
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14.sp,
                            ),
                          ),
                          subtitle: Text(
                            'Nüfus: ${AppMoney.full(city.population, withSymbol: false)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: isStart
                                      ? AppColors.gold
                                      : AppColors.blue,
                                  size: 18.sp,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            setState(() {
                              if (isStart) {
                                _cityAId = city.id;
                              } else {
                                _cityBId = city.id;
                              }
                            });
                            AppHaptic.selection();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        message: result['message']?.toString() ?? 'Araç rotası güncellendi.',
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

class _TurkeyRouteMapPainter extends CustomPainter {
  final List<City> cities;
  final City? cityA;
  final City? cityB;
  final String Function(String) normalizeFn;

  _TurkeyRouteMapPainter({
    required this.cities,
    required this.cityA,
    required this.cityB,
    required this.normalizeFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final defaultFillPaint = Paint()
      ..color = AppColors.cardBg.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final cityAFillPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final cityAStrokePaint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final cityBFillPaint = Paint()
      ..color = AppColors.blue.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final cityBStrokePaint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw all provinces
    for (final city in cities) {
      final isA = cityA != null && city.id == cityA!.id;
      final isB = cityB != null && city.id == cityB!.id;

      if (isA) {
        canvas.drawPath(city.path, cityAFillPaint);
        canvas.drawPath(city.path, cityAStrokePaint);
      } else if (isB) {
        canvas.drawPath(city.path, cityBFillPaint);
        canvas.drawPath(city.path, cityBStrokePaint);
      } else {
        canvas.drawPath(city.path, defaultFillPaint);
        canvas.drawPath(city.path, strokePaint);
      }
    }

    // Draw Route connection line between City A and City B
    if (cityA != null && cityB != null) {
      final p1 = cityA!.path.getBounds().center;
      final p2 = cityB!.path.getBounds().center;

      // Glow line
      final glowPaint = Paint()
        ..color = AppColors.gold.withValues(alpha: 0.25)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, glowPaint);

      // Dashed main route line
      final routePaint = Paint()
        ..color = AppColors.gold
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, p1, p2, routePaint);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dashWidth = 8,
    double dashSpace = 5,
  }) {
    var distance = (p2 - p1).distance;
    if (distance <= 0) return;
    var direction = (p2 - p1) / distance;

    var start = p1;
    while (distance >= 0) {
      var next = start + direction * dashWidth;
      if (distance < dashWidth) {
        next = p1 + direction * (p2 - p1).distance;
      }
      canvas.drawLine(start, next, paint);
      start = next + direction * (dashWidth + dashSpace);
      distance -= (dashWidth + dashSpace);
    }
  }

  @override
  bool shouldRepaint(covariant _TurkeyRouteMapPainter oldDelegate) {
    return oldDelegate.cityA?.id != cityA?.id ||
        oldDelegate.cityB?.id != cityB?.id ||
        oldDelegate.cities != cities;
  }
}

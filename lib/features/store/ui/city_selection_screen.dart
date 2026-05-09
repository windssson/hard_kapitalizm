import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';

class CitySelectionScreen extends ConsumerStatefulWidget {
  final String buildingKind; // 'store' veya 'warehouse'

  const CitySelectionScreen({
    super.key,
    this.buildingKind = 'store',
  });

  @override
  ConsumerState<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends ConsumerState<CitySelectionScreen> {
  CityModel? _selectedCity;

  static const double _minLat = 35.8;
  static const double _maxLat = 42.5;
  static const double _minLon = 25.7;
  static const double _maxLon = 47.0;

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(
              title: widget.buildingKind == 'warehouse' 
                  ? 'Depo Lokasyonu Seç' 
                  : widget.buildingKind == 'field'
                      ? 'Tarla Lokasyonu Seç'
                      : widget.buildingKind == 'farm'
                          ? 'Çiftlik Lokasyonu Seç'
                          : widget.buildingKind == 'factory'
                              ? 'Fabrika Lokasyonu Seç'
                              : widget.buildingKind == 'mine'
                                  ? 'Maden Lokasyonu Seç'
                                  : 'Mağaza Lokasyonu Seç',
            ),
            Expanded(
              child: citiesAsync.when(
                data: (cities) => cities.isEmpty ? _buildEmptyState() : _buildMap(cities),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                error: (error, stack) => Center(child: Text('Hata: $error', style: TextStyle(color: AppColors.red))),
              ),
            ),
            _buildSelectionPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, color: AppColors.textMuted, size: 64.sp),
          SizedBox(height: 16.h),
          Text('Aktif şehir bulunamadı.', style: AppTextStyles.h2),
        ],
      ),
    );
  }

  Widget _buildMap(List<CityModel> cities) {
    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapWidth = constraints.maxWidth;
            final mapHeight = constraints.maxHeight;
            return InteractiveViewer(
              maxScale: 5.0,
              minScale: 1.0,
              boundaryMargin: EdgeInsets.all(20.w),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: CustomPaint(painter: MapGridPainter())),
                  ...cities.map((city) => _buildCityMarker(city, mapWidth, mapHeight)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCityMarker(CityModel city, double mapWidth, double mapHeight) {
    final bool isSelected = _selectedCity?.id == city.id;
    final double normX = (city.mapPositionY - _minLon) / (_maxLon - _minLon);
    final double normY = (_maxLat - city.mapPositionX) / (_maxLat - _minLat);

    const markerWidth = 50.0;
    const markerHeight = 50.0;
    final double left = (normX * mapWidth) - markerWidth / 2;
    final double top = (normY * mapHeight) - markerHeight / 2;

    return Positioned(
      left: left.clamp(0, mapWidth - markerWidth),
      top: top.clamp(0, mapHeight - markerHeight),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCity = city),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(isSelected ? 10.w : 8.w),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : AppColors.navBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: isSelected ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: isSelected ? 0.8 : 0.4),
                    blurRadius: isSelected ? 15 : 8,
                    spreadRadius: isSelected ? 4 : 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.location_city,
                color: isSelected ? Colors.black : AppColors.gold,
                size: isSelected ? 22.sp : 18.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                city.name,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionPanel() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(color: _selectedCity != null ? AppColors.gold : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedCity != null ? Icons.location_on : Icons.location_off,
                  color: _selectedCity != null ? AppColors.gold : AppColors.textMuted,
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seçilen Şehir',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
                    ),
                    Text(
                      _selectedCity?.name ?? 'Lütfen Şehir Seçiniz',
                      style: TextStyle(
                        color: _selectedCity != null ? Colors.white : AppColors.textMuted,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            height: 55.h,
            child: ElevatedButton(
              onPressed: _selectedCity != null ? _handleContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: _selectedCity != null ? 8 : 0,
              ),
              child: Text(
                'Devam Et',
                style: TextStyle(
                  color: _selectedCity != null ? Colors.black : Colors.white.withValues(alpha: 0.3),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue() {
    if (_selectedCity == null) return;
    
    final String targetRoute = widget.buildingKind == 'warehouse' 
        ? '/warehouses/new/type' 
        : widget.buildingKind == 'field'
            ? '/fields/new/type'
            : widget.buildingKind == 'farm'
                ? '/farms/new/type'
                : widget.buildingKind == 'factory'
                    ? '/factories/new/type'
                    : widget.buildingKind == 'mine'
                        ? '/mines/new/type'
                        : '/store/new/type';
        
    context.push(targetRoute, extra: _selectedCity);
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderGold.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

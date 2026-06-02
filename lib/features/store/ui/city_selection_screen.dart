import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';

class CitySelectionScreen extends ConsumerStatefulWidget {
  final String buildingKind; // 'store' veya 'warehouse'

  const CitySelectionScreen({super.key, this.buildingKind = 'store'});

  @override
  ConsumerState<CitySelectionScreen> createState() =>
      _CitySelectionScreenState();
}

class _CitySelectionScreenState extends ConsumerState<CitySelectionScreen> {
  CityModel? _selectedCity;

  static const double _minLat =
      35.9; // Alt kenara daha yakın oturması için ayarlandı
  static const double _maxLat =
      42.7; // Üst kenardan boşluk bırakmak için büyütüldü (42.5'ti)
  static const double _minLon = 25.7;
  static const double _maxLon = 47;

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Veritabanındaki güncel koordinatları tekrar çekmek için:
          ref.read(staticCatalogControllerProvider).refresh();
        },
        backgroundColor: AppColors.gold,
        mini: true, // Çok yer kaplamasın
        tooltip: 'Koordinatları Yenile',
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(
              title: widget.buildingKind == 'warehouse'
                  ? 'Depo Lokasyonu Seç'
                  : widget.buildingKind == 'field'
                  ? 'Çiftlik Lokasyonu Seç'
                  : widget.buildingKind == 'farm'
                  ? 'Tarla Lokasyonu Seç'
                  : widget.buildingKind == 'factory'
                  ? 'Fabrika Lokasyonu Seç'
                  : widget.buildingKind == 'mine'
                  ? 'Maden Lokasyonu Seç'
                  : 'Mağaza Lokasyonu Seç',
            ),
            Expanded(
              child: citiesAsync.when(
                data: (cities) => cities.isEmpty
                    ? _buildEmptyState()
                    : Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio:
                                1.35, // Haritayı basık (yüksekliği az) hale getirir
                            child: _buildMap(cities),
                          ),
                        ),
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    'Hata: $error',
                    style: TextStyle(color: AppColors.red),
                  ),
                ),
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
      margin: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        image: DecorationImage(
          image: const AssetImage('assets/backmap.webp'),
          fit: BoxFit.fill,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(
              alpha: 0.5,
            ), // Görünürlük için çok hafif karartma
            BlendMode.darken,
          ),
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapWidth = constraints.maxWidth;
            final mapHeight = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: CustomPaint(painter: MapGridPainter())),
                ...cities.map(
                  (city) => _buildCityMarker(city, mapWidth, mapHeight),
                ),
              ],
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

    const markerWidth = 80.0;
    const markerHeight = 60.0;
    final double left = (normX * mapWidth) - markerWidth / 2;
    final double top = (normY * mapHeight) - markerHeight / 2;

    return Positioned(
      left: left.clamp(0.0, mapWidth - markerWidth),
      top: top.clamp(0.0, mapHeight - markerHeight),
      width: markerWidth,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 300 + (city.id.hashCode % 500)),
        curve: Curves.elasticOut,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: () => setState(() => _selectedCity = city),
          behavior: HitTestBehavior.opaque,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 20.w : 14.w,
              height: isSelected ? 20.w : 14.w,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.black87,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : AppColors.gold,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(
                      alpha: isSelected ? 0.9 : 0.5,
                    ),
                    blurRadius: isSelected ? 16 : 8,
                    spreadRadius: isSelected ? 6 : 2,
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold
                    : Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppColors.borderGold.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                city.name,
                style: TextStyle(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSelectionPanel() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(
                color: _selectedCity != null
                    ? AppColors.gold
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedCity != null
                      ? Icons.location_on
                      : Icons.location_off,
                  color: _selectedCity != null
                      ? AppColors.gold
                      : AppColors.textMuted,
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seçilen Şehir',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.sp,
                      ),
                    ),
                    Text(
                      _selectedCity?.name ?? 'Lütfen Şehir Seçiniz',
                      style: TextStyle(
                        color: _selectedCity != null
                            ? Colors.white
                            : AppColors.textMuted,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: _selectedCity != null ? 8 : 0,
              ),
              child: Text(
                'Devam Et',
                style: TextStyle(
                  color: _selectedCity != null
                      ? Colors.black
                      : Colors.white.withValues(alpha: 0.3),
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

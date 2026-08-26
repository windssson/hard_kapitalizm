import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:city_picker_from_map/city_picker_from_map.dart';
// ignore: implementation_imports
import 'package:city_picker_from_map/src/parser.dart';
// ignore: implementation_imports
import 'package:city_picker_from_map/src/size_controller.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';

class CitySelectionScreen extends ConsumerStatefulWidget {
  final String
  buildingKind; // 'store', 'warehouse', 'field', 'farm', 'factory', 'mine'

  const CitySelectionScreen({super.key, this.buildingKind = 'store'});

  @override
  ConsumerState<CitySelectionScreen> createState() =>
      _CitySelectionScreenState();
}

class _CitySelectionScreenState extends ConsumerState<CitySelectionScreen> {
  CityModel? _selectedCity;
  late TransformationController _transformationController;
  List<City> _cityList = [];
  bool _isLoadingMap = true;
  bool _hasCenteredMap = false;

  String _normalizeString(String input) {
    return input
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

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadCityList();
  }

  void _centerMap(Size viewportSize) {
    final double rawWidth = SizeController.instance.mapSize.width > 0
        ? SizeController.instance.mapSize.width
        : 1007.0;
    final double rawHeight = SizeController.instance.mapSize.height > 0
        ? SizeController.instance.mapSize.height
        : 450.0;

    // Haritayı %50 daha büyük ve ekranın tam merkezine odaklı başlatacak ölçek
    final double targetScale = (viewportSize.width * 3) / rawWidth;
    final double scaledWidth = rawWidth * targetScale;
    final double scaledHeight = rawHeight * targetScale;

    final double tx = (viewportSize.width - scaledWidth) / 5 + 50.w;
    final double ty = (viewportSize.height - scaledHeight) / 2 - 35.h;

    // ignore: deprecated_member_use
    _transformationController.value = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(tx, ty)
      // ignore: deprecated_member_use
      ..scale(targetScale);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadCityList() async {
    try {
      final list = await Parser.instance.svgToCityList(Maps.TURKEY);
      if (!mounted) return;
      setState(() {
        _cityList = list;
        _isLoadingMap = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hasCenteredMap = true;
          _centerMap(MediaQuery.of(context).size);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMap = false;
      });
    }
  }

  void _handleTapUp(
    TapUpDetails details,
    List<CityModel> activeCities,
    Size canvasSize,
  ) {
    final double scale = SizeController.instance.calculateScale(canvasSize);
    if (scale == 0.0) return;

    final double inverseScale = 1.0 / scale;
    final Offset localPos = details.localPosition;
    final Offset virtualPos = localPos * inverseScale;

    City? tappedCity;
    for (final city in _cityList) {
      if (city.path.contains(virtualPos)) {
        tappedCity = city;
        break;
      }
    }

    if (tappedCity != null) {
      final matched = activeCities.cast<CityModel?>().firstWhere(
        (c) =>
            c != null &&
            _normalizeString(c.name) == _normalizeString(tappedCity!.title),
        orElse: () => null,
      );

      if (matched == null) {
        AppSnackbar.show(
          context,
          message:
              '${tappedCity.title} şu anda yatırım yapılabilir durumda değil.',
          type: SnackbarType.warning,
        );
        setState(() {
          _selectedCity = null;
        });
      } else {
        setState(() {
          _selectedCity = matched;
        });
        if (ref.read(tutorialProvider).step == TutorialStep.selectCity) {
          ref.read(tutorialProvider.notifier).setStep(TutorialStep.confirmCity);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesProvider);

    // Harita tamamen yüklenip boyutu sıfırdan büyük olduğu an 1 kere merkezlemeyi tetikler
    if (citiesAsync.hasValue &&
        !_isLoadingMap &&
        !_hasCenteredMap &&
        _cityList.isNotEmpty) {
      _hasCenteredMap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _centerMap(MediaQuery.of(context).size);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: citiesAsync.when(
        data: (cities) => cities.isEmpty
            ? _buildEmptyState()
            : Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Özel Boyanmış İnteraktif SVG Harita (En altta ve tüm ekranı kaplar)
                  _buildInteractiveMap(cities),

                  // 2. Yüzen Üst Başlık Barı (Yarı şeffaf gradyanlı)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.background.withValues(alpha: 0.95),
                            AppColors.background.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: SecondaryTopBar(
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
                      ),
                    ),
                  ),

                  // 3. Haritayı Ortala ve Yenile Butonu
                  Positioned(
                    top: 75.h,
                    right: 16.w,
                    child: SafeArea(
                      child: FloatingActionButton(
                        onPressed: () {
                          _centerMap(MediaQuery.of(context).size);
                          ref.read(staticCatalogControllerProvider).refresh();
                        },
                        backgroundColor: AppColors.cardBg.withValues(
                          alpha: 0.90,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                        elevation: 4,
                        mini: true,
                        tooltip: 'Haritayı Ortala & Yenile',
                        child: Icon(
                          Icons.center_focus_strong_rounded,
                          color: AppColors.gold,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ),

                  // 4. Şehir Seçildiğinde Harita Üzerinde Yüzen Bilgi Penceresi (Popup)
                  if (_selectedCity != null)
                    Center(
                      child: SingleChildScrollView(
                        child: _buildFloatingSelectionPanel(),
                      ),
                    )
                  else ...[
                    if (ref.watch(tutorialProvider).step ==
                        TutorialStep.none) ...[
                      _buildInfoCard(),
                      _buildLegendCard(),
                    ],
                  ],
                ],
              ),
        loading: () =>
            Center(child: AppLoadingIndicator(color: AppColors.gold)),
        error: (error, stack) => Center(
          child: Text(
            'Hata: $error',
            style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final String kind = widget.buildingKind;
    final bool hasLegend = kind != 'warehouse';

    return Positioned(
      bottom: hasLegend ? 155.h : 24.h,
      left: 16.w,
      right: 16.w,
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.cardBg.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gesture_rounded, color: AppColors.gold, size: 20.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harita Kontrolleri',
                        style: AppTextStyles.body.standardCopyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '• Haritada gezinmek için tek parmakla kaydırın.\n'
                        '• Yakınlaştırmak için iki parmağınızı kıstırın.\n'
                        '• Yatırım detayları için bir şehre dokunun.',
                        style: AppTextStyles.caption
                            .standardCopyWith(color: AppColors.textMuted)
                            .copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendCard() {
    final String kind = widget.buildingKind;
    if (kind == 'warehouse') return const SizedBox.shrink();

    final List<MapEntry<String, Color>> legendItems = [];
    if (kind == 'store') {
      legendItems.addAll([
        const MapEntry('Yüksek Nüfus (>3M)', Colors.green),
        const MapEntry('Orta-Yüksek (1.5M - 3M)', Colors.lightGreen),
        const MapEntry('Orta Nüfus (750K - 1.5M)', Colors.amber),
        const MapEntry('Düşük-Orta (300K - 750K)', Colors.orange),
        const MapEntry('Düşük Nüfus (<300K)', Colors.redAccent),
      ]);
    } else if (kind == 'farm') {
      legendItems.addAll([
        const MapEntry('Meyve Bahçesi', Colors.red),
        const MapEntry('Tahıl Tarlası', Colors.amber),
        const MapEntry('Sebze Tarlası', Colors.green),
        const MapEntry('Endüstriyel Tarım', Colors.blue),
      ]);
    } else if (kind == 'field') {
      legendItems.addAll([
        const MapEntry('Mandıra/Besi', Colors.red),
        const MapEntry('Küçükbaş', Colors.brown),
        const MapEntry('Kümes', Colors.amber),
        const MapEntry('Arı/İpek', Colors.pink),
        const MapEntry('Su Ürünleri', Colors.cyan),
      ]);
    } else if (kind == 'mine') {
      legendItems.addAll([
        const MapEntry('Metal Madeni', Colors.blueGrey),
        const MapEntry('Taş/Mermer Ocağı', Colors.brown),
        const MapEntry('Enerji/Kimya', Colors.orange),
        const MapEntry('Değerli Madenler', Colors.purple),
      ]);
    } else if (kind == 'factory') {
      legendItems.addAll([
        const MapEntry('Gıda/Fırın', Colors.lightGreen),
        const MapEntry('Kimya/Kozmetik', Colors.teal),
        const MapEntry('Tekstil/Konfeksiyon', Colors.purple),
        const MapEntry('Ağır Sanayi/Metal', Colors.blueGrey),
        const MapEntry('Elektronik/Beyaz Eşya', Colors.blue),
        const MapEntry('Otomotiv/Ulaşım', Colors.red),
        const MapEntry('Lüks Atölyesi', Colors.deepOrange),
      ]);
    }

    if (legendItems.isEmpty) return const SizedBox.shrink();

    final isStore = kind == 'store';

    return Positioned(
      bottom: 20.h,
      left: 16.w,
      right: 16.w,
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.cardBg.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isStore ? Icons.people_alt_rounded : Icons.map_rounded,
                      color: AppColors.gold,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      isStore
                          ? 'Nüfus Dağılımı & Müşteri Potansiyeli'
                          : 'Katsayı Avantaj Renkleri (Parlaklık Oranına Göre)',
                      style: AppTextStyles.body.standardCopyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 12.w,
                  runSpacing: 6.h,
                  children: legendItems.map((item) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            color: item.value.withValues(alpha: 0.70),
                            shape: BoxShape.circle,
                            border: Border.all(color: item.value, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: item.value.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          item.key,
                          style: AppTextStyles.caption
                              .standardCopyWith(
                                color: AppColors.white.withValues(alpha: 0.95),
                              )
                              .copyWith(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                SizedBox(height: 8.h),
                Text(
                  isStore
                      ? '• Yeşil tonlar yüksek nüfus ve tüketici potansiyelini, kırmızı tonlar düşük nüfusu temsil eder.'
                      : '• Renkler Şehirlerin Üretim Avantajlarını temsil eder.',
                  style: AppTextStyles.caption
                      .standardCopyWith(color: AppColors.textMuted)
                      .copyWith(fontSize: 9.5.sp, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.mapOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.emptyState,
          ),
          SizedBox(height: 16.h),
          Text('Aktif şehir bulunamadı.', style: AppTextStyles.h2),
        ],
      ),
    );
  }

  Widget _buildInteractiveMap(List<CityModel> cities) {
    if (_isLoadingMap) {
      return Center(child: AppLoadingIndicator(color: AppColors.gold));
    }
    if (_cityList.isEmpty) {
      return Center(
        child: Text(
          'Harita verisi yüklenemedi.',
          style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
        ),
      );
    }

    final double rawWidth = SizeController.instance.mapSize.width;
    final double rawHeight = SizeController.instance.mapSize.height;
    final double childWidth = rawWidth > 0 ? rawWidth : 360.w;
    final double childHeight = rawHeight > 0 ? rawHeight : 220.h;

    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.9,
        vertical: MediaQuery.of(context).size.height * 0.9,
      ),
      minScale: 0.2,
      maxScale: 4.0,
      scaleEnabled: true,
      panEnabled: true,
      child: SizedBox(
        key: TutorialKeys.citySelectionMapKey,
        width: childWidth,
        height: childHeight,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return GestureDetector(
                onTapUp: (details) => _handleTapUp(details, cities, canvasSize),
                child: CustomPaint(
                  size: canvasSize,
                  painter: TurkeyMapPainter(
                    cities: _cityList,
                    activeCities: cities,
                    selectedCity: _selectedCity,
                    buildingKind: widget.buildingKind,
                    normalizeFn: _normalizeString,
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSelectionPanel() {
    if (_selectedCity == null) return const SizedBox.shrink();
    final city = _selectedCity!;

    return Container(
      key: ref.watch(tutorialProvider).step == TutorialStep.confirmCity
          ? TutorialKeys.citySelectionConfirmKey
          : null,
      width: 320.w,
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: AppFx.shadow(0.65), blurRadius: 35, spreadRadius: 8),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Başlık ve Kapatma Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(AppIcons.locationOn, color: AppColors.gold, size: 22.sp),
                  SizedBox(width: 10.w),
                  Text(
                    city.name,
                    style: AppTextStyles.h2.standardCopyWith(
                      color: AppColors.white,
                      fontSize: AppTypography.titleLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedCity = null;
                  });
                },
                icon: Icon(
                  AppIcons.closeRounded,
                  color: AppColors.textMuted,
                  size: 20.sp,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
          SizedBox(height: 12.h),

          // İstatistik Bilgileri (Nüfus & Vergi)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      color: AppColors.textMuted,
                      size: 16.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Nüfus: ',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.caption,
                      ),
                    ),
                    Text(
                      _formatPopulation(city.population),
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.white,
                        fontSize: AppTypography.caption,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.percent,
                      color: AppColors.textMuted,
                      size: 16.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Vergi Oranı: ',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.caption,
                      ),
                    ),
                    Text(
                      '%${(city.taxRate * 100).toStringAsFixed(1)}',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.white,
                        fontSize: AppTypography.caption,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Üretime Özel Stratejik Bonuslar
          if (_buildCategoryBonuses(city).isNotEmpty) ...[
            SizedBox(height: 16.h),
            Text(
              'Yatırım & Üretim Avantajları:',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _buildCategoryBonuses(city),
            ),
          ],

          SizedBox(height: 24.h),

          // Devam Et Butonu
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: _handleContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 6,
              ),
              child: Text(
                'Devam Et',
                style: AppTextStyles.button.standardCopyWith(
                  color: AppColors.textOnAccent,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryBonuses(CityModel city) {
    final bonuses = city.categoryBonuses;
    if (bonuses.isEmpty) return [];

    final filteredBonuses = <String, double>{};
    bonuses.forEach((key, value) {
      if (value > 1.0) {
        final bool isMatch = _isBonusMatchForBuildingKind(
          key,
          widget.buildingKind,
        );
        if (isMatch) {
          filteredBonuses[key] = value;
        }
      }
    });

    if (filteredBonuses.isEmpty) return [];

    return filteredBonuses.entries.map((entry) {
      final categoryName = _getCategoryDisplayName(entry.key);
      final percent = ((entry.value - 1.0) * 100).round();
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0.2),
              AppColors.gold.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCategoryIcon(entry.key),
              color: AppColors.gold,
              size: 14.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              '$categoryName: +%$percent',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.white,
                fontSize: AppTypography.caption,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  bool _isBonusMatchForBuildingKind(String bonusKey, String buildingKind) {
    if (buildingKind == 'farm') {
      return bonusKey.contains('bahcesi') ||
          bonusKey.contains('tarlasi') ||
          bonusKey.contains('tarim');
    }
    if (buildingKind == 'field') {
      return bonusKey.contains('ciftligi') ||
          bonusKey.contains('hayvanciligi') ||
          bonusKey.contains('ipekcilik') ||
          bonusKey.contains('tesisi');
    }
    if (buildingKind == 'mine') {
      return bonusKey.contains('maden') ||
          bonusKey.contains('ocagi') ||
          bonusKey.contains('kaynaklari');
    }
    if (buildingKind == 'factory') {
      return bonusKey.contains('fabrikasi') ||
          bonusKey.contains('sanayi') ||
          bonusKey.contains('atolyesi') ||
          bonusKey.contains('isleme');
    }
    return true;
  }

  String _getCategoryDisplayName(String bonusKey) {
    final cleanKey = bonusKey.replaceFirst('bonus_', '');
    switch (cleanKey) {
      case 'meyve_bahcesi':
        return 'Meyve Bahçesi';
      case 'sebze_tarlasi':
        return 'Sebze Tarlası';
      case 'tahil_tarlasi':
        return 'Tahıl Tarlası';
      case 'endustriyel_tarim_alani':
        return 'Endüstriyel Tarım';
      case 'mandira_ve_besi_ciftligi':
        return 'Mandıra & Besi';
      case 'kumes_hayvanciligi':
        return 'Kümes Hayvancılığı';
      case 'aricilik_ve_ipekcilik':
        return 'Arıcılık & İpek';
      case 'kucukbas_hayvan_ciftligi':
        return 'Küçükbaş Hayvan';
      case 'su_urunleri_tesisi':
        return 'Su Ürünleri';
      case 'insaat_ve_tas_ocagi':
        return 'İnşaat & Taş Ocağı';
      case 'enerji_ve_kimya_kaynaklari':
        return 'Enerji & Kimya';
      case 'metal_maden_ocagi':
        return 'Metal Maden Ocağı';
      case 'degerli_ve_stratejik_madenler':
        return 'Değerli Madenler';
      case 'firn_ve_atistirmalik_fabrikasi':
        return 'Fırın & Atıştırmalık';
      case 'gida_isleme_fabrikasi':
        return 'Gıda İşleme';
      case 'kimya_ve_kozmetik_fabrikasi':
        return 'Kimya & Kozmetik';
      case 'tekstil_ve_konfeksiyon_fabrikasi':
        return 'Tekstil & Konfeksiyon';
      case 'mobilya_ve_kagit_sanayi':
        return 'Mobilya & Kağıt';
      case 'agir_sanayi_ve_metal_isleme':
        return 'Ağır Sanayi & Metal';
      case 'elektronik_ve_yuksek_teknoloji':
        return 'Elektronik & Yüksek Teknoloji';
      case 'beyaz_esya_ve_ev_gerecleri':
        return 'Beyaz Eşya';
      case 'otomotiv_ve_ulasim_fabrikasi':
        return 'Otomotiv & Ulaşım';
      case 'luks_ve_aksesuar_atolyesi':
        return 'Lüks Aksesuar';
      default:
        return cleanKey.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getCategoryIcon(String bonusKey) {
    final cleanKey = bonusKey.replaceFirst('bonus_', '');
    if (cleanKey.contains('bahcesi') ||
        cleanKey.contains('tarlasi') ||
        cleanKey.contains('tarim')) {
      return AppIcons.agricultureOutlined;
    }
    if (cleanKey.contains('ciftligi') ||
        cleanKey.contains('hayvanciligi') ||
        cleanKey.contains('ipekcilik') ||
        cleanKey.contains('tesisi')) {
      return AppIcons.grass;
    }
    if (cleanKey.contains('maden') ||
        cleanKey.contains('ocagi') ||
        cleanKey.contains('kaynaklari')) {
      return AppIcons.landscapeRounded;
    }
    return AppIcons.factoryOutlined;
  }

  String _formatPopulation(int population) {
    if (population >= 1000000) {
      return '${(population / 1000000).toStringAsFixed(1)}M';
    }
    if (population >= 1000) {
      return '${(population / 1000).toStringAsFixed(0)}K';
    }
    return population.toString();
  }

  void _handleContinue() {
    if (_selectedCity == null) return;

    if (ref.read(tutorialProvider).step == TutorialStep.selectCity ||
        ref.read(tutorialProvider).step == TutorialStep.confirmCity) {
      ref.read(tutorialProvider.notifier).setStep(TutorialStep.selectManav);
    }

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

// 5. Haritayı Boyayan Yüksek Performanslı CustomPainter
class TurkeyMapPainter extends CustomPainter {
  final List<City> cities;
  final List<CityModel> activeCities;
  final CityModel? selectedCity;
  final String buildingKind;
  final String Function(String) normalizeFn;

  // Performans Optimizasyonu: TextPainter.layout() her karede 81 kez çağrılmasın diye static cache'liyoruz.
  static final Map<String, TextPainter> _staticTextPainterCache = {};

  TurkeyMapPainter({
    required this.cities,
    required this.activeCities,
    required this.selectedCity,
    required this.buildingKind,
    required this.normalizeFn,
  }) {
    _initTextPainterCache();
  }

  void _initTextPainterCache() {
    if (_staticTextPainterCache.isNotEmpty) return;
    for (final city in cities) {
      final activeCity = activeCities.cast<CityModel?>().firstWhere(
        (c) => c != null && normalizeFn(c.name) == normalizeFn(city.title),
        orElse: () => null,
      );
      final bool isActive = activeCity != null;
      final textSpan = TextSpan(
        text: city.title.toUpperCase(),
        style: TextStyle(
          color: isActive
              ? AppColors.white.withValues(alpha: 0.95)
              : AppColors.white.withValues(alpha: 0.18),
          fontSize: isActive ? 7.5 : 5.0,
          fontWeight: isActive ? FontWeight.w500 : FontWeight.w100,
          fontFamily: AppTypography.fontFamily,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(1, 1),
              blurRadius: 1.5,
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      _staticTextPainterCache[city.id] = textPainter;
    }
  }

  final sizeController = SizeController.instance;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = sizeController.calculateScale(size);
    canvas.save();
    canvas.scale(scale);

    // Çizgi ve Dolgu Fırçaları
    final strokePaint = Paint()
      ..color = AppColors.borderGold.withValues(alpha: 0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final defaultFillPaint = Paint()
      ..color = AppColors.cardBg.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    for (final city in cities) {
      // Veritabanındaki aktif yatırım şehirlerinden biri mi?
      final activeCity = activeCities.cast<CityModel?>().firstWhere(
        (c) => c != null && normalizeFn(c.name) == normalizeFn(city.title),
        orElse: () => null,
      );

      Paint fillPaint = defaultFillPaint;

      if (activeCity != null) {
        // Eğer bu il seçilmişse altın parlaması ile boya
        if (selectedCity?.id == activeCity.id) {
          fillPaint = Paint()
            ..color = AppColors.gold.withValues(alpha: 0.65)
            ..style = PaintingStyle.fill;
        } else if (buildingKind == 'store') {
          // Mağaza için nüfusa göre ısı haritası renklendirmesi (Yeşil -> Sarı -> Kırmızı)
          final pop = activeCity.population;
          Color popColor;
          double opacity = 0.50;

          if (pop >= 3000000) {
            popColor = Colors.green;
            opacity = 0.65;
          } else if (pop >= 1500000) {
            popColor = Colors.lightGreen;
            opacity = 0.55;
          } else if (pop >= 750000) {
            popColor = Colors.amber;
            opacity = 0.45;
          } else if (pop >= 300000) {
            popColor = Colors.orange;
            opacity = 0.40;
          } else {
            popColor = Colors.redAccent;
            opacity = 0.45;
          }

          fillPaint = Paint()
            ..color = popColor.withValues(alpha: opacity)
            ..style = PaintingStyle.fill;
        } else {
          // Kurulan birim türüne göre (tarla, maden vb.) bu ilin katsayı bonusunu kontrol et (depo hariç)
          final bool shouldColor = buildingKind != 'warehouse';
          final MapEntry<Color, double>? colorAndBonus = shouldColor
              ? _getSpecificCategoryColorAndBonus(activeCity, buildingKind)
              : null;
          if (colorAndBonus != null) {
            final Color baseColor = colorAndBonus.key;
            final double bonusValue = colorAndBonus.value;

            // Katsayı değerine göre dinamik opaklık (ısı haritası etkisi)
            double opacity = 0.15;
            if (bonusValue >= 1.30) {
              opacity = 0.70;
            } else if (bonusValue >= 1.25) {
              opacity = 0.45;
            } else if (bonusValue >= 1.20) {
              opacity = 0.25;
            }

            fillPaint = Paint()
              ..color = baseColor.withValues(alpha: opacity)
              ..style = PaintingStyle.fill;
          } else {
            // Aktif şehir ama özel katsayı bonusu yok
            fillPaint = Paint()
              ..color = AppColors.white.withValues(alpha: 0.12)
              ..style = PaintingStyle.fill;
          }
        }
      } else {
        // Yatırım yapılamayan inaktif il
        if (selectedCity != null &&
            normalizeFn(selectedCity!.name) == normalizeFn(city.title)) {
          fillPaint = Paint()
            ..color = AppColors.gold.withValues(alpha: 0.65)
            ..style = PaintingStyle.fill;
        }
      }

      // İli ve sınır çizgisini boya
      canvas.drawPath(city.path, fillPaint);
      canvas.drawPath(city.path, strokePaint);

      // Aktif şehirlere harita üzerinde şık bir merkez pini (yuvarlak) çiz
      final bounds = city.path.getBounds();
      if (activeCity != null) {
        final dotColor = selectedCity?.id == activeCity.id
            ? AppColors.white
            : AppColors.gold;

        final dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

        final dotBorderPaint = Paint()
          ..color = AppColors.background
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(bounds.center, 3.5, dotPaint);
        canvas.drawCircle(bounds.center, 3.5, dotBorderPaint);
      }

      // Şehir adını (il sınırları içinde) küçük ve şık şekilde yaz
      final tp = _staticTextPainterCache[city.id];
      if (tp != null) {
        final bool isActive = activeCity != null;
        // Pin ile çakışmayı önlemek için aktif şehirlerin yazısını 11 birim aşağı kaydırırız
        final double offsetY = isActive ? 11.0 : 0.0;
        final textOffset = Offset(
          bounds.center.dx - (tp.width / 2),
          bounds.center.dy - (tp.height / 2) + offsetY,
        );

        tp.paint(canvas, textOffset);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TurkeyMapPainter oldDelegate) {
    return oldDelegate.cities != cities ||
        oldDelegate.activeCities != activeCities ||
        oldDelegate.selectedCity != selectedCity ||
        oldDelegate.buildingKind != buildingKind;
  }

  bool _isBonusMatchForBuildingKind(String bonusKey, String buildingKind) {
    if (buildingKind == 'farm') {
      return bonusKey.contains('bahcesi') ||
          bonusKey.contains('tarlasi') ||
          bonusKey.contains('tarim');
    }
    if (buildingKind == 'field') {
      return bonusKey.contains('ciftligi') ||
          bonusKey.contains('hayvanciligi') ||
          bonusKey.contains('ipekcilik') ||
          bonusKey.contains('tesisi');
    }
    if (buildingKind == 'mine') {
      return bonusKey.contains('maden') ||
          bonusKey.contains('ocagi') ||
          bonusKey.contains('kaynaklari');
    }
    if (buildingKind == 'factory') {
      return bonusKey.contains('fabrikasi') ||
          bonusKey.contains('sanayi') ||
          bonusKey.contains('atolyesi') ||
          bonusKey.contains('isleme');
    }
    return true;
  }

  MapEntry<Color, double>? _getSpecificCategoryColorAndBonus(
    CityModel city,
    String buildingKind,
  ) {
    final bonuses = city.categoryBonuses;
    double maxBonus = 1.0;
    String? maxBonusKey;

    bonuses.forEach((key, value) {
      if (_isBonusMatchForBuildingKind(key, buildingKind)) {
        if (value > maxBonus) {
          maxBonus = value;
          maxBonusKey = key;
        }
      }
    });

    if (maxBonusKey == null) return null;

    final cleanKey = maxBonusKey!.replaceFirst('bonus_', '');
    Color color;
    switch (cleanKey) {
      // 1. Tarla (farm) Kategorileri
      case 'meyve_bahcesi':
        color = Colors.red;
        break;
      case 'tahil_tarlasi':
        color = Colors.amber;
        break;
      case 'sebze_tarlasi':
        color = Colors.green;
        break;
      case 'endustriyel_tarim_alani':
        color = Colors.blue;
        break;

      // 2. Çiftlik (field) Kategorileri
      case 'mandira_ve_besi_ciftligi':
        color = Colors.red;
        break;
      case 'kucukbas_hayvan_ciftligi':
        color = Colors.brown;
        break;
      case 'kumes_hayvanciligi':
        color = Colors.amber;
        break;
      case 'aricilik_ve_ipekcilik':
        color = Colors.pink;
        break;
      case 'su_urunleri_tesisi':
        color = Colors.cyan;
        break;

      // 3. Maden (mine) Kategorileri
      case 'metal_maden_ocagi':
        color = Colors.blueGrey;
        break;
      case 'insaat_ve_tas_ocagi':
        color = Colors.brown;
        break;
      case 'enerji_ve_kimya_kaynaklari':
        color = Colors.orange;
        break;
      case 'degerli_ve_stratejik_madenler':
        color = Colors.purple;
        break;

      // 4. Fabrika (factory) Kategorileri
      case 'gida_isleme_fabrikasi':
        color = Colors.lightGreen;
        break;
      case 'firn_ve_atistirmalik_fabrikasi':
        color = Colors.amber;
        break;
      case 'kimya_ve_kozmetik_fabrikasi':
        color = Colors.teal;
        break;
      case 'tekstil_ve_konfeksiyon_fabrikasi':
        color = Colors.purple;
        break;
      case 'mobilya_ve_kagit_sanayi':
        color = Colors.brown;
        break;
      case 'agir_sanayi_ve_metal_isleme':
        color = Colors.blueGrey;
        break;
      case 'elektronik_ve_yuksek_teknoloji':
        color = Colors.blue;
        break;
      case 'beyaz_esya_ve_ev_gerecleri':
        color = Colors.indigo;
        break;
      case 'otomotiv_ve_ulasim_fabrikasi':
        color = Colors.red;
        break;
      case 'luks_ve_aksesuar_atolyesi':
        color = Colors.deepOrange;
        break;

      default:
        return null;
    }
    return MapEntry(color, maxBonus);
  }
}

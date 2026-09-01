import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/consolidated_transfer_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';

class ConsolidatedTransferSheet extends ConsumerStatefulWidget {
  final String? initialCityId;
  final String? initialCityName;

  const ConsolidatedTransferSheet({
    super.key,
    this.initialCityId,
    this.initialCityName,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialCityId,
    String? initialCityName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConsolidatedTransferSheet(
        initialCityId: initialCityId,
        initialCityName: initialCityName,
      ),
    );
  }

  @override
  ConsumerState<ConsolidatedTransferSheet> createState() =>
      _ConsolidatedTransferSheetState();
}

class _ConsolidatedTransferSheetState
    extends ConsumerState<ConsolidatedTransferSheet> {
  // 0: Kaynak Şehir, 1: Ürün Seçimi, 2: Hedef Seçimi, 3: Araç/Onay
  int _currentStep = 0;

  ConsolidatedSourceCityModel? _selectedCity;
  ConsolidatedTargetModel? _selectedTarget;

  @override
  void initState() {
    super.initState();
    if (widget.initialCityId != null && widget.initialCityName != null) {
      _selectedCity = ConsolidatedSourceCityModel(
        cityId: widget.initialCityId!,
        cityName: widget.initialCityName!,
        facilityCount: 1,
        totalStock: 0,
      );
      _currentStep = 1;
    }
  }

  // itemId -> selected quantity
  final Map<String, int> _selectedQuantities = {};

  // Step 3 Hedef Filtresi
  String _targetFilter = 'all'; // 'all', 'warehouse', 'factory', 'store'

  // Step 4 Araç Seçenekleri
  bool _isLoadingVehicles = false;
  List<MarketTransferVehicleOptionModel> _vehicleOptions = [];
  MarketTransferVehicleOptionModel? _selectedVehicle;
  String? _vehiclesUnavailableReason;

  bool _isSubmitting = false;

  double _computeSelectedVolume(List<ConsolidatedCandidateItemModel> candidates) {
    double vol = 0;
    for (final item in candidates) {
      final qty = _selectedQuantities[item.itemId] ?? 0;
      if (qty > 0) {
        vol += qty * item.birimHacim;
      }
    }
    return vol;
  }

  int _computeTotalQuantity() {
    int total = 0;
    for (final q in _selectedQuantities.values) {
      total += q;
    }
    return total;
  }

  Set<String> _computeSelectedProductIds(
    List<ConsolidatedCandidateItemModel> candidates,
  ) {
    final ids = <String>{};
    for (final item in candidates) {
      final qty = _selectedQuantities[item.itemId] ?? 0;
      if (qty > 0) {
        ids.add(item.productId);
      }
    }
    return ids;
  }

  Future<void> _loadVehicles(double totalVolume) async {
    if (_selectedCity == null || _selectedTarget == null) return;
    if (_selectedCity!.cityId == _selectedTarget!.cityId) return; // Aynı şehir

    setState(() {
      _isLoadingVehicles = true;
      _vehiclesUnavailableReason = null;
    });

    try {
      final result = await ref
          .read(consolidatedTransferActionProvider)
          .getRouteOptions(
            sourceCityId: _selectedCity!.cityId,
            targetCityId: _selectedTarget!.cityId,
            totalVolume: totalVolume,
          );

      if (!mounted) return;
      setState(() {
        _isLoadingVehicles = false;
        _vehicleOptions = result.options;
        _vehiclesUnavailableReason = result.unavailableReason;
        _selectedVehicle = result.options.isNotEmpty
            ? result.options.firstWhere(
                (v) => v.canSelect,
                orElse: () => result.options.first,
              )
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingVehicles = false;
        _vehiclesUnavailableReason = 'Araç seçenekleri yüklenemedi.';
      });
    }
  }

  Future<void> _handleStartTransfer(
    List<ConsolidatedCandidateItemModel> candidates,
  ) async {
    if (_selectedCity == null || _selectedTarget == null) return;
    final isSameCity = _selectedCity!.cityId == _selectedTarget!.cityId;

    if (!isSameCity && _selectedVehicle == null) {
      AppSnackbar.show(
        context,
        title: 'Araç Seçimi',
        message: 'Lütfen sevkiyat için bir araç seçin.',
        type: SnackbarType.warning,
      );
      return;
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final item in candidates) {
      final qty = _selectedQuantities[item.itemId] ?? 0;
      if (qty > 0) {
        itemsPayload.add({
          'source_kind': item.sourceKind,
          'source_id': item.sourceId,
          'item_id': item.itemId,
          'product_id': item.productId,
          'quantity': qty,
          'quality_level': item.qualityLevel,
          'brand_id': item.brandId,
        });
      }
    }

    if (itemsPayload.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Ürün Seçimi',
        message: 'Lütfen taşınacak en az bir ürün seçin.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await ref
          .read(consolidatedTransferActionProvider)
          .startCityConsolidatedTransfer(
            sourceCityId: _selectedCity!.cityId,
            targetEntityKind: _selectedTarget!.entityKind,
            targetEntityId: _selectedTarget!.id,
            items: itemsPayload,
            vehicleId: isSameCity ? null : _selectedVehicle?.vehicleId,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res['success'] == true) {
        AppHaptic.medium();
        // Lojistik ve transfer verilerini yenile
        ref.invalidate(buyerTransferMapProvider);
        ref.invalidate(consolidatedTransferTargetsProvider);
        ref.invalidate(consolidatedTransferSourceCitiesProvider);

        Navigator.pop(context);
        AppSnackbar.show(
          context,
          title: 'Başarılı',
          message: res['message'] ?? 'Konsolide transfer başlatıldı.',
          type: SnackbarType.success,
        );
      } else {
        AppHaptic.heavy();
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: res['message'] ?? 'Transfer başlatılamadı.',
          type: SnackbarType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppHaptic.heavy();
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.90.sh,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          _buildStepIndicator(),
          Expanded(child: _buildCurrentStepContent()),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.h),
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(AppIcons.localShipping, color: AppColors.gold, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konsolide Şehir Sevkiyatı',
                  style: AppTextStyles.h2.standardCopyWith(
                    fontSize: AppTypography.title,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _currentStep == 0
                      ? 'Adım 1: Kaynak Şehri Seçin'
                      : _currentStep == 1
                          ? 'Adım 2: Gönderilecek Ürünleri Seçin'
                          : _currentStep == 2
                              ? 'Adım 3: Hedef Tesisi Seçin'
                              : 'Adım 4: Araç & Gönderim Onayı',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.gold,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.textMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      child: Row(
        children: [
          _buildStepChip(0, 'Nereden?'),
          _buildStepDivider(0),
          _buildStepChip(1, 'Ürünler'),
          _buildStepDivider(1),
          _buildStepChip(2, 'Nereye?'),
          _buildStepDivider(2),
          _buildStepChip(3, 'Sevkiyat'),
        ],
      ),
    );
  }

  Widget _buildStepChip(int step, String label) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return GestureDetector(
      onTap: () {
        if (isDone) {
          setState(() => _currentStep = step);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22.w,
            height: 22.w,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.green
                  : isActive
                      ? AppColors.gold
                      : AppColors.cardBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isDone ? AppColors.transparent : AppColors.textMuted,
              ),
            ),
            child: Center(
              child: isDone
                  ? Icon(Icons.check, size: 12.sp, color: AppColors.textOnAccent)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? AppColors.textOnAccent
                            : AppColors.textMuted,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive
                  ? AppColors.gold
                  : isDone
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int step) {
    final isPassed = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2.h,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        color: isPassed ? AppColors.green : AppColors.borderGold.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1SourceCitySelection();
      case 1:
        return _buildStep2ProductsSelection();
      case 2:
        return _buildStep3TargetSelection();
      case 3:
        return _buildStep4VehicleAndConfirm();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================================
  // ADIM 1: KAYNAK ŞEHİR SEÇİMİ (Nereden Çıkacak?)
  // ==========================================================================
  Widget _buildStep1SourceCitySelection() {
    final citiesAsync = ref.watch(consolidatedTransferSourceCitiesProvider);

    return citiesAsync.when(
      data: (cities) {
        if (cities.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 40.sp),
                  SizedBox(height: 12.h),
                  Text(
                    'Stok Bulunan Şehir Yok',
                    style: AppTextStyles.title,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Depo, maden, tarla veya fabrikalarınızda aktarılacak ürün stoğu bulunmuyor.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          itemCount: cities.length,
          itemBuilder: (context, index) {
            final city = cities[index];
            final isSelected = _selectedCity?.cityId == city.cityId;

            return GestureDetector(
              onTap: () {
                AppHaptic.selection();
                setState(() {
                  _selectedCity = city;
                  _selectedQuantities.clear();
                  _selectedTarget = null;
                  _currentStep = 1; // Ürün seçimine geç
                });
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.12)
                      : AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.borderGold.withValues(alpha: 0.2),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_city_rounded,
                        color: AppColors.gold,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city.cityName,
                            style: AppTextStyles.title.standardCopyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.business_rounded, size: 13.sp, color: AppColors.textMuted),
                              SizedBox(width: 4.w),
                              Text(
                                '${city.facilityCount} İşletme / Depo',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                              Icon(Icons.layers_rounded, size: 13.sp, color: AppColors.gold),
                              SizedBox(width: 4.w),
                              Text(
                                '${city.totalStock} Adet Stok',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14.sp,
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  // ==========================================================================
  // ADIM 2: ÜRÜN TOPLAMA (Neleri Göndereceksin?)
  // ==========================================================================
  Widget _buildStep2ProductsSelection() {
    if (_selectedCity == null) {
      return const SizedBox.shrink();
    }

    final candidatesAsync = ref.watch(
      consolidatedTransferCityCandidatesProvider(_selectedCity!.cityId),
    );

    return candidatesAsync.when(
      data: (candidates) {
        if (candidates.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 40.sp),
                  SizedBox(height: 12.h),
                  Text(
                    'Bu Şehirde Stok Bulunamadı',
                    style: AppTextStyles.title,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${_selectedCity!.cityName} şehrindeki tesislerde aktarılabilir ürün kalmamış.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final selectedVolume = _computeSelectedVolume(candidates);
        final totalSelectedQuantity = _computeTotalQuantity();

        // Ürünleri tesise göre grupla
        final groupedCandidates = <String, List<ConsolidatedCandidateItemModel>>{};
        for (final item in candidates) {
          final groupKey = '${item.sourceKindDisplay} • ${item.sourceName}';
          groupedCandidates.putIfAbsent(groupKey, () => []).add(item);
        }

        return Column(
          children: [
            // Canlı Özet Barı
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.borderGold.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_city_rounded, color: AppColors.gold, size: 16.sp),
                      SizedBox(width: 6.w),
                      Text(
                        _selectedCity!.cityName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Seçilen: $totalSelectedQuantity Adet • ${selectedVolume.toStringAsFixed(1)} m³',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Ürün Listesi
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 80.h),
                itemCount: groupedCandidates.length,
                itemBuilder: (context, groupIndex) {
                  final groupKey = groupedCandidates.keys.elementAt(groupIndex);
                  final itemsInGroup = groupedCandidates[groupKey]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Row(
                          children: [
                            Icon(Icons.business_rounded, size: 14.sp, color: AppColors.gold),
                            SizedBox(width: 6.w),
                            Text(
                              groupKey,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...itemsInGroup.map((item) {
                        final currentQty = _selectedQuantities[item.itemId] ?? 0;

                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: currentQty > 0
                                ? AppColors.gold.withValues(alpha: 0.08)
                                : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: currentQty > 0
                                  ? AppColors.gold.withValues(alpha: 0.4)
                                  : AppColors.borderGold.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 42.w,
                                height: 42.w,
                                child: BrandedProductImage(
                                  fileName: item.productIcon ?? '',
                                  productId: item.productId,
                                  brandId: item.brandId,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Row(
                                      children: [
                                        Text(
                                          'Stok: ${item.availableQuantity} • Q${item.qualityLevel}',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        if (item.brandName != 'Standart') ...[
                                          SizedBox(width: 6.w),
                                          Text(
                                            item.brandName,
                                            style: TextStyle(
                                              fontSize: 9.5.sp,
                                              color: AppColors.gold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      'Birim Hacim: ${item.birimHacim} m³',
                                      style: TextStyle(
                                        fontSize: 9.5.sp,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Adet Stepper
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    iconSize: 22.sp,
                                    color: currentQty > 0
                                        ? AppColors.gold
                                        : AppColors.textMuted,
                                    onPressed: currentQty > 0
                                        ? () {
                                            AppHaptic.selection();
                                            setState(() {
                                              _selectedQuantities[item.itemId] =
                                                  currentQty - 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  Text(
                                    '$currentQty',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      color: currentQty > 0
                                          ? AppColors.gold
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    iconSize: 22.sp,
                                    color: currentQty < item.availableQuantity
                                        ? AppColors.gold
                                        : AppColors.textMuted,
                                    onPressed: currentQty < item.availableQuantity
                                        ? () {
                                            AppHaptic.selection();
                                            setState(() {
                                              _selectedQuantities[item.itemId] =
                                                  currentQty + 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      AppHaptic.selection();
                                      setState(() {
                                        _selectedQuantities[item.itemId] =
                                            item.availableQuantity;
                                      });
                                    },
                                    child: Text(
                                      'Tümü',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),

            // Hedef Seçimine İlerle Butonu
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderGold.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.3),
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: totalSelectedQuantity > 0
                      ? () {
                          AppHaptic.light();
                          setState(() => _currentStep = 2);
                        }
                      : null,
                  child: Text(
                    'Hedef Seçimine İlerle ($totalSelectedQuantity Adet • ${selectedVolume.toStringAsFixed(1)} m³)',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  // ==========================================================================
  // ADIM 3: AKILLI HEDEF TESİS SEÇİMİ (Nereye Gidecek?)
  // ==========================================================================
  Widget _buildStep3TargetSelection() {
    final targetsAsync = ref.watch(consolidatedTransferTargetsProvider);
    final candidates = ref
            .read(consolidatedTransferCityCandidatesProvider(_selectedCity!.cityId))
            .value ??
        [];
    final selectedVolume = _computeSelectedVolume(candidates);
    final selectedProductIds = _computeSelectedProductIds(candidates);

    return targetsAsync.when(
      data: (targets) {
        if (targets.isEmpty) {
          return Center(
            child: Text(
              'Aktif bir hedef tesisiniz bulunmuyor.',
              style: AppTextStyles.body,
            ),
          );
        }

        final filteredTargets = _targetFilter == 'all'
            ? targets
            : targets.where((t) => t.entityKind == _targetFilter).toList();

        final warehouseCount =
            targets.where((t) => t.entityKind == 'warehouse').length;
        final factoryCount =
            targets.where((t) => t.entityKind == 'factory').length;
        final storeCount =
            targets.where((t) => t.entityKind == 'store').length;

        return Column(
          children: [
            // Yük Bilgi Rozeti
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 6.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Taşınacak Yük Hacmi:',
                    style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
                  ),
                  Text(
                    '${selectedVolume.toStringAsFixed(1)} m³',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),

            // Kategori Filtre Butonları
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: Row(
                children: [
                  _buildFilterChip('all', 'Hepsi (${targets.length})'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('warehouse', '🏬 Depolar ($warehouseCount)'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('factory', '🏭 Fabrikalar ($factoryCount)'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('store', '🏪 Mağazalar ($storeCount)'),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 24.h),
                itemCount: filteredTargets.length,
                itemBuilder: (context, index) {
                  final target = filteredTargets[index];
                  final isSelected = _selectedTarget?.id == target.id;
                  final isSameCity = _selectedCity?.cityId == target.cityId;
                  final acceptsProducts =
                      target.acceptsAllProducts(selectedProductIds);
                  final hasEnoughCapacity = target.emptyCapacity >= selectedVolume;
                  final canSelect = acceptsProducts && hasEnoughCapacity;

                  final fullnessRatio = target.totalCapacity > 0
                      ? (target.usedCapacity / target.totalCapacity).clamp(0.0, 1.0)
                      : 0.0;

                  return GestureDetector(
                    onTap: canSelect
                        ? () {
                            AppHaptic.selection();
                            setState(() {
                              _selectedTarget = target;
                              _loadVehicles(selectedVolume);
                              _currentStep = 3; // Sevkiyat adımına geç
                            });
                          }
                        : () {
                            AppHaptic.heavy();
                            if (!acceptsProducts) {
                              AppSnackbar.show(
                                context,
                                title: 'Ürün Uyuşmazlığı',
                                message:
                                    '${target.name} seçtiğiniz ürünleri kabul etmiyor.',
                                type: SnackbarType.warning,
                              );
                            } else if (!hasEnoughCapacity) {
                              AppSnackbar.show(
                                context,
                                title: 'Kapasite Yetersiz',
                                message:
                                    '${target.name} tesisinde yeterli boş alan yok. Gerekli: ${selectedVolume.toStringAsFixed(1)} m³, Boş: ${target.emptyCapacity.toStringAsFixed(1)} m³',
                                type: SnackbarType.warning,
                              );
                            }
                          },
                    child: Opacity(
                      opacity: canSelect ? 1.0 : 0.45,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold.withValues(alpha: 0.12)
                              : AppColors.cardBgLight,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gold
                                : isSameCity
                                    ? AppColors.green.withValues(alpha: 0.5)
                                    : AppColors.borderGold.withValues(alpha: 0.2),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getKindBadgeColor(target.entityKind),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    target.entityKindDisplay,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    target.name,
                                    style: AppTextStyles.body.standardCopyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSameCity) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4.r),
                                      border: Border.all(color: AppColors.green),
                                    ),
                                    child: Text(
                                      '🟢 Şehir İçi',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.green,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                ],
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 13.sp,
                                  color: AppColors.gold,
                                ),
                                Text(
                                  target.cityName,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Boş Kapasite: ${target.emptyCapacity.toStringAsFixed(1)} m³',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: hasEnoughCapacity
                                        ? AppColors.green
                                        : AppColors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!acceptsProducts)
                                  Text(
                                    'Ürün Kabul Etmiyor',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppColors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else if (!hasEnoughCapacity)
                                  Text(
                                    'Kapasite Yetersiz',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppColors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                  Text(
                                    'Kabul Ediyor ✅',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppColors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: LinearProgressIndicator(
                                value: fullnessRatio,
                                minHeight: 6.h,
                                backgroundColor:
                                    AppColors.borderGold.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation(
                                  fullnessRatio > 0.9
                                      ? AppColors.red
                                      : AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _targetFilter == key;
    return GestureDetector(
      onTap: () {
        AppHaptic.selection();
        setState(() => _targetFilter = key);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.2)
              : AppColors.cardBgLight,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.borderGold.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.gold : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Color _getKindBadgeColor(String kind) {
    switch (kind) {
      case 'factory':
        return Colors.deepOrange.shade700;
      case 'store':
        return Colors.purple.shade700;
      case 'farm':
        return Colors.green.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  // ==========================================================================
  // ADIM 4: ARAÇ & GÖNDERİM ONAYI (Sevkiyat)
  // ==========================================================================
  Widget _buildStep4VehicleAndConfirm() {
    if (_selectedCity == null || _selectedTarget == null) {
      return const SizedBox.shrink();
    }

    final candidates = ref
            .read(consolidatedTransferCityCandidatesProvider(_selectedCity!.cityId))
            .value ??
        [];
    final selectedVolume = _computeSelectedVolume(candidates);
    final totalQuantity = _computeTotalQuantity();
    final isSameCity = _selectedCity!.cityId == _selectedTarget!.cityId;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      children: [
        // Rota ve Hedef Kartı
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBgLight,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.route_rounded, color: AppColors.gold, size: 18.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'SEVKİYAT PLANI',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Çıkış Şehri', style: AppTextStyles.caption),
                      Text(
                        _selectedCity!.cityName,
                        style: AppTextStyles.title.standardCopyWith(fontSize: 14.sp),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 20.sp),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Hedef Tesis', style: AppTextStyles.caption),
                      Text(
                        _selectedTarget!.name,
                        style: AppTextStyles.title.standardCopyWith(fontSize: 14.sp),
                      ),
                      Text(
                        '(${_selectedTarget!.cityName})',
                        style: TextStyle(fontSize: 10.sp, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(color: AppColors.borderGold.withValues(alpha: 0.2), height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryMiniStat('Kalem Sayısı', '${_selectedQuantities.length} Çeşit'),
                  _buildSummaryMiniStat('Toplam Adet', '$totalQuantity Adet'),
                  _buildSummaryMiniStat('Toplam Hacim', '${selectedVolume.toStringAsFixed(1)} m³'),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Şehir İçi ise:
        if (isSameCity) ...[
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flash_on_rounded, color: AppColors.green, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Şehir İçi Anlık Teslimat',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Tüm işletmeler aynı şehirde olduğu için araç tahsisine gerek yoktur. Mallar anında hedef tesise aktarılacaktır.',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: 10.5.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Şehirler arası ise: Araç Seçimi
          Text(
            'SEVKİYAT ARACI SEÇİN',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          SizedBox(height: 8.h),
          if (_isLoadingVehicles)
            const Center(child: AppLoadingIndicator())
          else if (_vehiclesUnavailableReason != null && _vehicleOptions.isEmpty)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _vehiclesUnavailableReason!,
                style: TextStyle(color: AppColors.red, fontSize: 11.sp),
              ),
            )
          else ...[
            ..._vehicleOptions.map((v) {
              final isSelected = _selectedVehicle?.vehicleId == v.vehicleId;
              final canSelect = v.canSelect;

              return GestureDetector(
                onTap: canSelect
                    ? () {
                        AppHaptic.selection();
                        setState(() => _selectedVehicle = v);
                      }
                    : null,
                child: Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.12)
                        : AppColors.cardBgLight,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.borderGold.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.localShipping,
                        color: isSelected ? AppColors.gold : AppColors.textMuted,
                        size: 22.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  v.vehicleName,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: canSelect
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                  ),
                                ),
                                if (v.isRental) ...[
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'Kiralık',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Kapasite: ${v.capacity} m³ • Hız: ${v.speedKmh} km/h • Süre: ${(v.estimatedDurationSeconds / 60).ceil()} dk',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (!canSelect && v.disabledReason != null)
                              Text(
                                v.disabledReason!,
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  color: AppColors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppMoney.compact(v.transportCost),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          ),
                          Text(
                            '${v.distanceKm.toStringAsFixed(0)} km',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],

        SizedBox(height: 24.h),

        // Aksiyon Butonu
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSameCity ? AppColors.green : AppColors.gold,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            onPressed: !_isSubmitting
                ? () => _handleStartTransfer(candidates)
                : null,
            child: _isSubmitting
                ? const AppLoadingIndicator()
                : Text(
                    isSameCity
                        ? 'Transferi Hemen Tamamla'
                        : 'Konsolide Sevkiyatı Başlat',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: isSameCity
                          ? Colors.white
                          : AppColors.textOnAccent,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMiniStat(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 10.sp, color: AppColors.textMuted)),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/consolidated_transfer_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';

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
  // 0: Kaynak Şehir, 1: Hedef Tesis, 2: Ürün Seçimi, 3: Araç/Onay
  int _currentStep = 0;

  ConsolidatedSourceCityModel? _selectedCity;
  ConsolidatedTargetModel? _selectedTarget;
  bool _onlyAcceptedProducts = true;
  bool _isAcceptedProductsExpanded = false;

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
      _currentStep = 1; // Şehir zaten belli olduğu için doğrudan Hedef Tesis seçimine geç
    }
  }

  // itemId -> selected quantity
  final Map<String, int> _selectedQuantities = {};

  // itemId -> ConsolidatedCandidateItemModel
  final Map<String, ConsolidatedCandidateItemModel> _candidatesMap = {};

  // Step 3 Hedef Filtresi
  String _targetFilter = 'all'; // 'all', 'warehouse', 'factory', 'store'

  // Step 4 Araç Seçenekleri
  bool _isLoadingVehicles = false;
  List<MarketTransferVehicleOptionModel> _vehicleOptions = [];
  MarketTransferVehicleOptionModel? _selectedVehicle;
  String? _vehiclesUnavailableReason;

  bool _isSubmitting = false;

  ConsolidatedCandidateItemModel? _findCandidate(
    String itemId, [
    List<ConsolidatedCandidateItemModel>? fallbackList,
  ]) {
    final cached = _candidatesMap[itemId];
    if (cached != null) return cached;
    if (fallbackList != null) {
      for (final item in fallbackList) {
        if (item.itemId == itemId) return item;
      }
    }
    return null;
  }

  double _computeSelectedVolume([List<ConsolidatedCandidateItemModel>? candidates]) {
    double vol = 0;
    for (final entry in _selectedQuantities.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = _findCandidate(entry.key, candidates);
      if (item != null) {
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
    for (final entry in _selectedQuantities.entries) {
      final qty = entry.value;
      if (qty <= 0) continue;
      final item = _findCandidate(entry.key, candidates);
      if (item != null) {
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
        ref.invalidate(consolidatedTransferCityCandidatesProvider);

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
    if (_selectedCity != null) {
      final candidatesAsync = ref.watch(
        consolidatedTransferCityCandidatesProvider(_selectedCity!.cityId),
      );
      if (candidatesAsync.hasValue && candidatesAsync.value != null) {
        for (final item in candidatesAsync.value!) {
          _candidatesMap[item.itemId] = item;
        }
      }
    }

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
                          ? 'Adım 2: Hedef Tesisi Seçin'
                          : _currentStep == 2
                              ? 'Adım 3: Gönderilecek Ürünleri Seçin'
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
          _buildStepChip(1, 'Nereye?'),
          _buildStepDivider(1),
          _buildStepChip(2, 'Ürünler'),
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
        return _buildStep2TargetSelection();
      case 2:
        return _buildStep3ProductsSelection();
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
                  Icon(Icons.location_off_rounded, color: AppColors.gold, size: 40.sp),
                  SizedBox(height: 12.h),
                  Text(
                    'Aktif Kaynak Şehir Bulunamadı',
                    style: AppTextStyles.title,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Stoğu veya işletmesi olan bir şehriniz bulunmuyor.',
                    style: AppTextStyles.caption,
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
                  _currentStep = 1; // Hedef tesis seçimine geç
                });
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.12)
                      : AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.borderGold.withValues(alpha: 0.2),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _build2TierBadge(
                      label: 'Şehir',
                      icon: Icons.location_city_rounded,
                      color: AppColors.gold,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  city.cityName,
                                  style: AppTextStyles.body.standardCopyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontSize: 13.5.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.location_on_outlined,
                                size: 13.sp,
                                color: AppColors.gold,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                '${city.facilityCount} Tesis',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Toplam Stok: ${city.totalStock} Adet',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'Kaynak Seç ➔',
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: LinearProgressIndicator(
                              value: 1.0,
                              minHeight: 3.5.h,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(AppColors.gold),
                            ),
                          ),
                        ],
                      ),
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
  // ADIM 2: HEDEF TESİS SEÇİMİ (Nereye Gidecek?)
  // ==========================================================================
  Widget _buildStep2TargetSelection() {
    if (_selectedCity == null) return const SizedBox.shrink();
    final targetsAsync = ref.watch(consolidatedTransferTargetsProvider);

    return targetsAsync.when(
      data: (targets) {
        if (targets.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, color: AppColors.gold, size: 40.sp),
                  SizedBox(height: 12.h),
                  Text(
                    'Aktif Bir Hedef Tesis Bulunamadı',
                    style: AppTextStyles.title,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Sevkiyat yapabileceğiniz aktif bir depo, fabrika veya mağazanız bulunmuyor.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
        final farmCount =
            targets.where((t) => t.entityKind == 'farm').length;
        final fieldCount =
            targets.where((t) => t.entityKind == 'field').length;
        final storeCount =
            targets.where((t) => t.entityKind == 'store').length;

        return Column(
          children: [
            // Kaynak Şehir Bilgi Barı
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.borderGold.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_city_rounded, color: AppColors.gold, size: 16.sp),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Kaynak: ${_selectedCity!.cityName} ➔ Hedef Tesisi Seçin',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _currentStep = 0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: AppColors.gold, size: 11.sp),
                          SizedBox(width: 3.w),
                          Text(
                            'Değiştir',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Kategori Filtre Butonları (İkonlu & Renkli)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  _buildFilterChipWithIcon('all', 'Hepsi (${targets.length})', Icons.grid_view_rounded, AppColors.gold),
                  SizedBox(width: 8.w),
                  _buildFilterChipWithIcon('warehouse', 'Depolar ($warehouseCount)', Icons.warehouse_rounded, const Color(0xFF2196F3)),
                  SizedBox(width: 8.w),
                  _buildFilterChipWithIcon('factory', 'Fabrikalar ($factoryCount)', Icons.factory_rounded, const Color(0xFFF44336)),
                  SizedBox(width: 8.w),
                  _buildFilterChipWithIcon('farm', 'Tarlalar ($farmCount)', Icons.eco_rounded, const Color(0xFF8BC34A)),
                  SizedBox(width: 8.w),
                  _buildFilterChipWithIcon('field', 'Çiftlikler ($fieldCount)', Icons.agriculture_rounded, const Color(0xFF4CAF50)),
                  SizedBox(width: 8.w),
                  _buildFilterChipWithIcon('store', 'Mağazalar ($storeCount)', Icons.storefront_rounded, const Color(0xFF9C27B0)),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                itemCount: filteredTargets.length,
                itemBuilder: (context, index) {
                  final target = filteredTargets[index];
                  final isSelected = _selectedTarget?.id == target.id;
                  final isSameCity = _selectedCity?.cityId == target.cityId;
                  final hasEmptyCapacity = target.emptyCapacity > 0;
                  final canSelect = hasEmptyCapacity;

                  final freeRatio = target.totalCapacity > 0
                      ? (target.emptyCapacity / target.totalCapacity).clamp(0.0, 1.0)
                      : 0.0;

                  final unitColor = _getKindColor(target.entityKind);
                  final unitIcon = _getKindIcon(target.entityKind);
                  final unitLabel = _getKindLabel(target.entityKind);

                  return GestureDetector(
                    onTap: canSelect
                        ? () {
                            AppHaptic.selection();
                            setState(() {
                              _selectedTarget = target;
                              _selectedQuantities.clear();
                              _currentStep = 2; // Ürün seçimine geç
                            });
                          }
                        : () {
                            AppHaptic.heavy();
                            AppSnackbar.show(
                              context,
                              title: 'Kapasite Dolu',
                              message: '${target.name} tesisinde boş alan bulunmuyor.',
                              type: SnackbarType.warning,
                            );
                          },
                    child: Opacity(
                      opacity: canSelect ? 1.0 : 0.45,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold.withValues(alpha: 0.12)
                              : AppColors.cardBgLight,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gold
                                : isSameCity
                                    ? AppColors.green.withValues(alpha: 0.4)
                                    : AppColors.borderGold.withValues(alpha: 0.15),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Sol 2 Katmanlı Rozet (Label + İkon)
                            _build2TierBadge(
                              label: unitLabel,
                              icon: unitIcon,
                              color: unitColor,
                            ),
                            SizedBox(width: 10.w),

                            // Sağ İçerik
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Satır 1: İsim + Şehir İçi + Konum
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          target.name,
                                          style: AppTextStyles.body.standardCopyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                            fontSize: 13.sp,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSameCity) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5.w,
                                            vertical: 2.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.green.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4.r),
                                            border: Border.all(
                                              color: AppColors.green.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.business_rounded, size: 10.sp, color: AppColors.green),
                                              SizedBox(width: 2.w),
                                              Text(
                                                'Şehir İçi',
                                                style: TextStyle(
                                                  fontSize: 8.5.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 5.w),
                                      ],
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 13.sp,
                                        color: AppColors.gold,
                                      ),
                                      SizedBox(width: 2.w),
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
                                  SizedBox(height: 5.h),

                                  // Satır 2: Boş Kapasite + Kabul Şartı
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Boş Kapasite: ',
                                              style: TextStyle(
                                                fontSize: 10.5.sp,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '${target.emptyCapacity.toStringAsFixed(1)} m³',
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: hasEmptyCapacity
                                                    ? const Color(0xFF00E676)
                                                    : AppColors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildRequirementBadge(target),
                                    ],
                                  ),
                                  SizedBox(height: 6.h),

                                  // Satır 3: Renkli İlerleme Çubuğu (Zarif & Arkası Soluk)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4.r),
                                    child: LinearProgressIndicator(
                                      value: freeRatio,
                                      minHeight: 3.5.h,
                                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                                      valueColor: AlwaysStoppedAnimation(
                                        hasEmptyCapacity ? unitColor : AppColors.red,
                                      ),
                                    ),
                                  ),
                                ],
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

  // ==========================================================================
  // ADIM 3: ÜRÜN SEÇİMİ (Ne Taşınacak?)
  // ==========================================================================
  Widget _buildStep3ProductsSelection() {
    if (_selectedCity == null || _selectedTarget == null) {
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
        final isOverCapacity = selectedVolume > _selectedTarget!.emptyCapacity;

        final allProductsAsync = ref.watch(allProductsProvider);
        final allProductsList = allProductsAsync.value ?? const <ProductModel>[];
        final productMap = {for (final p in allProductsList) p.id.toUpperCase(): p};

        // Ürünleri tesise göre grupla (kalite ve ürün türü kontrolüyle)
        final groupedCandidates = <String, List<ConsolidatedCandidateItemModel>>{};
        for (final item in candidates) {
          final isProductAccepted = _selectedTarget!.acceptsProduct(item.productId);
          final isQualityAccepted = _selectedTarget!.acceptsQuality(item.productId, item.qualityLevel);
          final canSelect = isProductAccepted && isQualityAccepted;

          if (_onlyAcceptedProducts && !canSelect) {
            continue; // Sadece uygun ürün & kalite filtresi devredeyse gösterme
          }
          final groupKey = '${item.sourceKindDisplay} • ${item.sourceName}';
          groupedCandidates.putIfAbsent(groupKey, () => []).add(item);
        }

        final compatibleCount = candidates.where((c) => _selectedTarget!.acceptsItem(productId: c.productId, qualityLevel: c.qualityLevel)).length;
        final totalCandidatesCount = candidates.length;

        return Column(
          children: [
            // Canlı Güzergah & Hedef Kapasite Barı
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.borderGold.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_right_alt_rounded, color: AppColors.gold, size: 18.sp),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          '${_selectedCity!.cityName} ➔ ${_selectedTarget!.name} (${_selectedTarget!.cityName})',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _currentStep = 1),
                        child: Text(
                          'Hedefi Değiştir',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hedef Boş Alanı: ${_selectedTarget!.emptyCapacity.toStringAsFixed(1)} m³',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          color: isOverCapacity ? AppColors.red : AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: isOverCapacity
                              ? AppColors.red.withValues(alpha: 0.15)
                              : AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: isOverCapacity
                                ? AppColors.red
                                : AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Seçilen: $totalSelectedQuantity Adet • ${selectedVolume.toStringAsFixed(1)} m³',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.bold,
                            color: isOverCapacity ? AppColors.red : AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedTarget!.entityKindDisplay} için $compatibleCount/$totalCandidatesCount uygun stok var',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: compatibleCount > 0 ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          AppHaptic.selection();
                          setState(() => _onlyAcceptedProducts = !_onlyAcceptedProducts);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: _onlyAcceptedProducts
                                ? AppColors.gold.withValues(alpha: 0.2)
                                : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                              color: _onlyAcceptedProducts
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                            ),
                          ),
                          child: Text(
                            _onlyAcceptedProducts
                                ? 'Sadece Uygunları Göster ($compatibleCount) ✅'
                                : 'Tüm Stokları Göster ($totalCandidatesCount)',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: _onlyAcceptedProducts
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Hedefin Kabul Ettiği Ürünler Paneli
            _buildTargetAcceptedProductsBanner(_selectedTarget!, productMap),

            // Ürün Listesi
            Expanded(
              child: groupedCandidates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rule_folder_outlined, color: AppColors.gold, size: 36.sp),
                            SizedBox(height: 10.h),
                            Text(
                              'Bu hedefe uygun ürün veya kalite bulunamadı.',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _selectedTarget!.entityKind == 'factory'
                                  ? '${_selectedTarget!.name} sadece Q${_selectedTarget!.minQualityLevel} kalitesinde girdi hammadde kabul eder. Bu şehirde uygun stok kalemi bulunamadı.'
                                  : '${_selectedTarget!.name} (${_selectedTarget!.entityKindDisplay}) bu şehirdeki mevcut stokları kabul etmiyor.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12.h),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.gold),
                              ),
                              onPressed: () => setState(() => _currentStep = 1),
                              child: Text('Farklı Bir Hedef Seç', style: TextStyle(color: AppColors.gold)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                      itemCount: groupedCandidates.length,
                      itemBuilder: (context, groupIndex) {
                        final groupKey = groupedCandidates.keys.elementAt(groupIndex);
                        final itemsInGroup = groupedCandidates[groupKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 6.h),
                              child: Row(
                                children: [
                                  Icon(Icons.business_rounded, size: 13.sp, color: AppColors.gold),
                                  SizedBox(width: 6.w),
                                  Text(
                                    groupKey,
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...itemsInGroup.map((item) {
                              final currentQty = _selectedQuantities[item.itemId] ?? 0;
                              final isProductAccepted = _selectedTarget!.acceptsProduct(item.productId);
                              final isQualityAccepted = _selectedTarget!.acceptsQuality(item.productId, item.qualityLevel);
                              final reqQuality = _selectedTarget!.getRequiredQualityFor(item.productId);
                              final canSelect = isProductAccepted && isQualityAccepted;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: canSelect
                                    ? null
                                    : () {
                                        AppHaptic.heavy();
                                        if (!isProductAccepted) {
                                          AppSnackbar.show(
                                            context,
                                            title: 'Ürün Uyumsuz',
                                            message: '${_selectedTarget!.name} (${_selectedTarget!.entityKindDisplay}) ${item.productName} ürününü kabul etmiyor.',
                                            type: SnackbarType.warning,
                                          );
                                        } else {
                                          AppSnackbar.show(
                                            context,
                                            title: 'Kalite Uyuşmazlığı',
                                            message: '${_selectedTarget!.name} fabrikası bu girdi için Q$reqQuality kalite bekliyor. Bu stok ise Q${item.qualityLevel} kalitededir.',
                                            type: SnackbarType.warning,
                                          );
                                        }
                                      },
                                child: Opacity(
                                  opacity: canSelect ? 1.0 : 0.45,
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 8.h),
                                    padding: EdgeInsets.all(10.w),
                                    decoration: BoxDecoration(
                                      color: currentQty > 0
                                          ? AppColors.gold.withValues(alpha: 0.08)
                                          : AppColors.cardBgLight,
                                      borderRadius: BorderRadius.circular(14.r),
                                      border: Border.all(
                                        color: currentQty > 0
                                            ? AppColors.gold.withValues(alpha: 0.6)
                                            : canSelect
                                                ? AppColors.borderGold.withValues(alpha: 0.15)
                                                : AppColors.red.withValues(alpha: 0.25),
                                        width: currentQty > 0 ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Sol Ürün Görseli & 5 Yıldızlı Kalite Rozeti
                                        _buildProduct2TierBadge(
                                          iconFileName: item.productIcon ?? '',
                                          productId: item.productId,
                                          brandId: item.brandId,
                                          qualityLevel: item.qualityLevel,
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      item.productName,
                                                      style: TextStyle(
                                                        fontSize: 12.5.sp,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(width: 5.w),
                                                  // 5 Yıldızlı Kalite Sistemi
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: List.generate(5, (index) {
                                                      final filled = index < item.qualityLevel;
                                                      return Padding(
                                                        padding: EdgeInsets.only(right: 1.w),
                                                        child: Icon(
                                                          filled ? AppIcons.starRounded : AppIcons.starBorderRounded,
                                                          size: 11.sp,
                                                          color: filled
                                                              ? AppColors.gold
                                                              : Colors.white.withValues(alpha: 0.2),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 3.h),
                                              Text(
                                                'Stok: ${item.availableQuantity} • ${item.birimHacim} m³${item.brandName != 'Standart' ? ' • ${item.brandName}' : ''}',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: AppColors.textMuted,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Adet Stepper veya Uyumsuzluk Rozeti
                                        if (canSelect)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline),
                                                iconSize: 20.sp,
                                                padding: EdgeInsets.zero,
                                                constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
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
                                              Container(
                                                constraints: BoxConstraints(minWidth: 24.w),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '$currentQty',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: currentQty > 0
                                                        ? AppColors.gold
                                                        : AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline),
                                                iconSize: 20.sp,
                                                padding: EdgeInsets.zero,
                                                constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
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
                                              SizedBox(width: 2.w),
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
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
                                                    fontSize: 9.5.sp,
                                                    color: AppColors.gold,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                                            decoration: BoxDecoration(
                                              color: !isProductAccepted
                                                  ? AppColors.red.withValues(alpha: 0.12)
                                                  : Colors.amber.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6.r),
                                              border: Border.all(
                                                color: !isProductAccepted
                                                    ? AppColors.red.withValues(alpha: 0.35)
                                                    : Colors.amber.withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Text(
                                              !isProductAccepted ? 'Uyumsuz' : '$reqQuality⭐ Şartı',
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.bold,
                                                color: !isProductAccepted ? AppColors.red : Colors.amber,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),

            // Kapasite Aşım Uyarısı
            if (isOverCapacity)
              Container(
                margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 16.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Hedef tesis kapasitesi aşılıyor! (Maksimum Boş Alan: ${_selectedTarget!.emptyCapacity.toStringAsFixed(1)} m³)',
                        style: TextStyle(
                          color: AppColors.red,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // İlerle Butonu
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
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
                  onPressed: (totalSelectedQuantity > 0 && !isOverCapacity)
                      ? () {
                          AppHaptic.light();
                          _loadVehicles(selectedVolume);
                          setState(() => _currentStep = 3);
                        }
                      : null,
                  child: Text(
                    totalSelectedQuantity == 0
                        ? 'En Az Bir Ürün Seçin'
                        : isOverCapacity
                            ? 'Kapasite Aşımı (${selectedVolume.toStringAsFixed(1)} / ${_selectedTarget!.emptyCapacity.toStringAsFixed(1)} m³)'
                            : 'Araç & Sevkiyat Seçimine İlerle ($totalSelectedQuantity Adet • ${selectedVolume.toStringAsFixed(1)} m³)',
                    style: TextStyle(
                      fontSize: 12.5.sp,
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

  Widget _buildTargetAcceptedProductsBanner(
    ConsolidatedTargetModel target,
    Map<String, ProductModel> productMap,
  ) {
    if (target.acceptedProductIds == null) {
      return Container(
        margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 6.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.all_inclusive_rounded, size: 13.sp, color: AppColors.green),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                'Genel Depo: Tüm ürünler ve kaliteler kabul edilir.',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final acceptedList = target.acceptedProductIds ?? const [];
    final isFactory = target.entityKind == 'factory';
    final isFarm = target.entityKind == 'farm';
    final isField = target.entityKind == 'field';
    final isWarehouse = target.entityKind == 'warehouse';
    final isProductionUnit = target.isProductionUnit;

    if (acceptedList.isEmpty) {
      return Container(
        margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 6.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.cardBgLight,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14.sp, color: AppColors.gold),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                isFarm
                    ? 'Bu tarlada henüz aktif gübre/tohum girdisi tanımlı değil.'
                    : isField
                        ? 'Bu çiftlikte henüz aktif yem/hammadde girdisi tanımlı değil.'
                        : 'Bu tesiste tanımlı kabul edilen ürün bulunmuyor.',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final title = isFactory
        ? 'Kabul Edilen Hammaddeler (${acceptedList.length})'
        : isFarm
            ? 'Kabul Edilen Girdiler (${acceptedList.length})'
            : isField
                ? 'Kabul Edilen Yem & Girdiler (${acceptedList.length})'
                : isWarehouse
                    ? 'Özel Depo Ürünleri (${acceptedList.length})'
                    : 'Mağaza Ürünleri (${acceptedList.length})';

    final iconData = isFactory
        ? Icons.precision_manufacturing_rounded
        : isFarm
            ? Icons.agriculture_rounded
            : isField
                ? Icons.pets_rounded
                : isWarehouse
                    ? Icons.warehouse_rounded
                    : Icons.storefront_rounded;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 6.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              AppHaptic.selection();
              setState(() => _isAcceptedProductsExpanded = !_isAcceptedProductsExpanded);
            },
            borderRadius: BorderRadius.circular(10.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
              child: Row(
                children: [
                  Icon(iconData, size: 14.sp, color: AppColors.gold),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isProductionUnit) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Şart: ',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ...List.generate(5, (i) {
                            final filled = i < target.minQualityLevel;
                            return Icon(
                              filled ? AppIcons.starRounded : AppIcons.starBorderRounded,
                              size: 8.5.sp,
                              color: filled ? AppColors.gold : Colors.white.withValues(alpha: 0.2),
                            );
                          }),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                  ],
                  Icon(
                    _isAcceptedProductsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: AppColors.gold,
                  ),
                ],
              ),
            ),
          ),
          if (_isAcceptedProductsExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 8.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: acceptedList.map((productId) {
                    final prod = productMap[productId.toUpperCase()];
                    final name = prod?.urunAdi ?? productId;
                    final icon = prod?.urunIconu ?? '';
                    final reqQ = target.getRequiredQualityFor(productId);

                    return Container(
                      margin: EdgeInsets.only(right: 6.w),
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: AppColors.borderGold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon.isNotEmpty) ...[
                            SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: BrandedProductImage(
                                fileName: icon,
                                productId: productId,
                              ),
                            ),
                            SizedBox(width: 4.w),
                          ],
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isProductionUnit) ...[
                            SizedBox(width: 4.w),
                            Text(
                              '$reqQ⭐',
                              style: TextStyle(
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ADIM 4: ARAÇ & GÖNDERİM ONAYI (Sevkiyat)
  // ==========================================================================
  Widget _buildStep4VehicleAndConfirm() {
    if (_selectedCity == null || _selectedTarget == null) {
      return const SizedBox.shrink();
    }

    final candidatesAsync = ref.watch(
      consolidatedTransferCityCandidatesProvider(_selectedCity!.cityId),
    );
    final candidates = candidatesAsync.value ?? _candidatesMap.values.toList();
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
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.green, size: 22.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Şehir İçi Anlık Teslimat',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Aynı şehir içi transferlerde araç ve yakıt gerekmez, ürünler hemen teslim edilir.',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.textPrimary,
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
              final vehicleColor = _getVehicleColor(v.vehicleName);

              return GestureDetector(
                onTap: canSelect
                    ? () {
                        AppHaptic.selection();
                        setState(() => _selectedVehicle = v);
                      }
                    : null,
                child: Container(
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.12)
                        : AppColors.cardBgLight,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.borderGold.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Sol Araç 2 Katmanlı Rozet
                      _build2TierBadge(
                        label: v.isRental ? 'Kiralık' : 'Filo',
                        icon: _getVehicleIcon(v.vehicleName),
                        color: vehicleColor,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    v.vehicleName,
                                    style: TextStyle(
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: canSelect
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  AppMoney.compact(v.transportCost),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kapasite: ${v.capacity} m³ • ${(v.estimatedDurationSeconds / 60).ceil()} dk',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textMuted,
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
                            if (!canSelect && v.disabledReason != null) ...[
                              SizedBox(height: 2.h),
                              Text(
                                v.disabledReason!,
                                style: TextStyle(
                                  fontSize: 9.5.sp,
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
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

  // ==========================================================================
  // ORTAK YARDIMCI BİLEŞENLER (Tasarım Standartları)
  // ==========================================================================

  Widget _buildFilterChipWithIcon(String key, String label, IconData icon, Color color) {
    final isSelected = _targetFilter == key;
    return GestureDetector(
      onTap: () {
        AppHaptic.selection();
        setState(() => _targetFilter = key);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.18)
              : AppColors.cardBgLight,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.borderGold.withValues(alpha: 0.18),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.sp,
              color: isSelected ? AppColors.gold : color,
            ),
            SizedBox(width: 5.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.gold : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2 Katmanlı Rozet (Üstte Başlık Etiketi, Altta İkon)
  Widget _build2TierBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 2.h),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.vertical(top: Radius.circular(9.r)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8.5.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(icon, size: 20.sp, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // Ürün İçin 2 Katmanlı Rozet (Üstte 5 Yıldızlı Kalite, Ortada Ürün Görseli)
  Widget _buildProduct2TierBadge({
    required String iconFileName,
    required String productId,
    required String brandId,
    required int qualityLevel,
  }) {
    final qualityColor = qualityLevel >= 3
        ? const Color(0xFF9C27B0)
        : qualityLevel == 2
            ? const Color(0xFF2196F3)
            : AppColors.gold;

    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: qualityColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 2.h),
            decoration: BoxDecoration(
              color: qualityColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9.r)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < qualityLevel;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.4.w),
                  child: Icon(
                    filled ? AppIcons.starRounded : AppIcons.starBorderRounded,
                    size: 7.sp,
                    color: filled ? AppColors.gold : Colors.white.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 26.w,
                height: 26.w,
                child: BrandedProductImage(
                  fileName: iconFileName,
                  productId: productId,
                  brandId: brandId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Şart ve Durum Rozeti (Hedef Tesis Seçim Sayfası)
  Widget _buildRequirementBadge(ConsolidatedTargetModel target) {
    if (target.entityKind == 'warehouse') {
      if (target.acceptedProductIds == null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tüm Ürünler Kabul Edilir',
              style: TextStyle(fontSize: 9.5.sp, color: AppColors.textMuted),
            ),
            SizedBox(width: 3.w),
            const Icon(Icons.check_box_rounded, size: 12, color: Color(0xFF00E676)),
          ],
        );
      } else {
        return Text(
          'Özel Depo (${target.acceptedProductIds!.length}) 📦',
          style: TextStyle(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2196F3),
          ),
        );
      }
    } else if (target.entityKind == 'factory') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Girdi Hammaddeleri',
            style: TextStyle(fontSize: 9.5.sp, color: AppColors.textMuted),
          ),
          SizedBox(width: 3.w),
          Icon(Icons.science_rounded, size: 12.sp, color: const Color(0xFFF44336)),
        ],
      );
    } else if (target.entityKind == 'farm') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tarla Girdileri',
            style: TextStyle(fontSize: 9.5.sp, color: AppColors.textMuted),
          ),
          SizedBox(width: 3.w),
          Icon(Icons.eco_rounded, size: 12.sp, color: const Color(0xFF8BC34A)),
        ],
      );
    } else if (target.entityKind == 'field') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Yem & Girdiler',
            style: TextStyle(fontSize: 9.5.sp, color: AppColors.textMuted),
          ),
          SizedBox(width: 3.w),
          Icon(Icons.pets_rounded, size: 12.sp, color: const Color(0xFF4CAF50)),
        ],
      );
    } else {
      return Text(
        'Mağaza Ürünleri 🛍️',
        style: TextStyle(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF9C27B0),
        ),
      );
    }
  }

  Color _getKindColor(String kind) {
    switch (kind) {
      case 'factory':
        return const Color(0xFFF44336); // Mercan Kırmızı
      case 'store':
        return const Color(0xFF9C27B0); // Mor
      case 'farm':
        return const Color(0xFF8BC34A); // Açık Yeşil (Tarla)
      case 'field':
        return const Color(0xFF4CAF50); // Zümrüt Yeşili (Çiftlik)
      default:
        return const Color(0xFF2196F3); // Mavi (Depo)
    }
  }

  IconData _getKindIcon(String kind) {
    switch (kind) {
      case 'factory':
        return Icons.factory_rounded;
      case 'store':
        return Icons.storefront_rounded;
      case 'farm':
        return Icons.eco_rounded;
      case 'field':
        return Icons.agriculture_rounded;
      default:
        return Icons.warehouse_rounded;
    }
  }

  String _getKindLabel(String kind) {
    switch (kind) {
      case 'factory':
        return 'Fabrika';
      case 'store':
        return 'Mağaza';
      case 'farm':
        return 'Tarla';
      case 'field':
        return 'Çiftlik';
      default:
        return 'Depo';
    }
  }

  Color _getVehicleColor(String vehicleName) {
    final lower = vehicleName.toLowerCase();
    if (lower.contains('uçak') || lower.contains('hava')) {
      return const Color(0xFF9C27B0);
    } else if (lower.contains('tren') || lower.contains('ray')) {
      return const Color(0xFFFF9800);
    } else if (lower.contains('tır') || lower.contains('kamyon')) {
      return const Color(0xFF2196F3);
    }
    return AppColors.gold;
  }

  IconData _getVehicleIcon(String vehicleName) {
    final lower = vehicleName.toLowerCase();
    if (lower.contains('uçak') || lower.contains('hava')) {
      return Icons.flight_rounded;
    } else if (lower.contains('tren') || lower.contains('ray')) {
      return Icons.train_rounded;
    } else if (lower.contains('tır') || lower.contains('çekici')) {
      return Icons.local_shipping_rounded;
    }
    return Icons.fire_truck_rounded;
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

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
                    child: Text(
                      'Değiştir',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Kategori Filtre Butonları
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  _buildFilterChip('all', 'Hepsi (${targets.length})'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('warehouse', '🏬 Depolar ($warehouseCount)'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('factory', '🏭 Fabrikalar ($factoryCount)'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('farm', '🌾 Tarlalar ($farmCount)'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('field', '🐄 Çiftlikler ($fieldCount)'),
                  SizedBox(width: 8.w),
                  _buildFilterChip('store', '🏪 Mağazalar ($storeCount)'),
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

                  final fullnessRatio = target.totalCapacity > 0
                      ? (target.usedCapacity / target.totalCapacity).clamp(0.0, 1.0)
                      : 0.0;

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
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold.withValues(alpha: 0.12)
                              : AppColors.cardBgLight,
                          borderRadius: BorderRadius.circular(14.r),
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
                                    horizontal: 7.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getKindBadgeColor(target.entityKind),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    target.entityKindDisplay,
                                    style: TextStyle(
                                      fontSize: 9.5.sp,
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
                                      fontSize: 13.sp,
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
                                        fontSize: 8.5.sp,
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
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Boş Kapasite: ${target.emptyCapacity.toStringAsFixed(1)} m³',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: hasEmptyCapacity
                                        ? AppColors.green
                                        : AppColors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  target.entityKind == 'warehouse'
                                      ? (target.acceptedProductIds == null
                                          ? 'Tüm Ürünler Kabul Edilir ✅'
                                          : '${target.acceptedProductIds!.length} Özel Ürün Kabul Eder 🏬')
                                      : target.entityKind == 'factory'
                                          ? 'Girdi Şartı: Q${target.minQualityLevel} 🏭'
                                          : target.entityKind == 'farm'
                                              ? (target.acceptedProductIds == null || target.acceptedProductIds!.isEmpty
                                                  ? 'Tarla Girdisi Bulunmuyor 🌾'
                                                  : 'Girdi Şartı: Q${target.minQualityLevel} 🌾')
                                              : target.entityKind == 'field'
                                                  ? (target.acceptedProductIds == null || target.acceptedProductIds!.isEmpty
                                                      ? 'Yem/Girdi Bulunmuyor 🐄'
                                                      : 'Yem Şartı: Q${target.minQualityLevel} 🐄')
                                                  : 'Mağaza Ürünleri (${target.acceptedProductIds?.length ?? 0}) 🏪',
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    color: target.entityKind == 'warehouse'
                                        ? (target.acceptedProductIds == null ? AppColors.green : AppColors.gold)
                                        : target.entityKind == 'factory'
                                            ? Colors.amber
                                            : target.entityKind == 'farm'
                                                ? Colors.greenAccent
                                                : target.entityKind == 'field'
                                                    ? Colors.tealAccent
                                                    : AppColors.gold,
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
                                minHeight: 5.h,
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
                                          : AppColors.cardBg,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: currentQty > 0
                                            ? AppColors.gold.withValues(alpha: 0.4)
                                            : canSelect
                                                ? AppColors.borderGold.withValues(alpha: 0.15)
                                                : AppColors.red.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 38.w,
                                          height: 38.w,
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
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                                              SizedBox(height: 2.h),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Birim: ${item.birimHacim} m³',
                                                    style: TextStyle(
                                                      fontSize: 9.sp,
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (!isProductAccepted) ...[
                                                SizedBox(height: 2.h),
                                                Text(
                                                  '❌ ${_selectedTarget!.entityKindDisplay} bu ürünü kabul etmiyor',
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    color: AppColors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ] else if (!isQualityAccepted) ...[
                                                SizedBox(height: 2.h),
                                                Text(
                                                  '⚠️ Kalite Uyuşmazlığı: Hedef Q$reqQuality şart koşuyor (Mevcut: Q${item.qualityLevel})',
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    color: Colors.amber,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ] else if (_selectedTarget!.isProductionUnit) ...[
                                                SizedBox(height: 2.h),
                                                Text(
                                                  'Girdi Uyumlu (Q${item.qualityLevel}) ✅',
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    color: AppColors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Adet Stepper veya Uyumsuzluk Rozeti
                                        if (canSelect)
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline),
                                                iconSize: 20.sp,
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
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: currentQty > 0
                                                      ? AppColors.gold
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline),
                                                iconSize: 20.sp,
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
                                          )
                                        else
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: !isProductAccepted
                                                  ? AppColors.red.withValues(alpha: 0.12)
                                                  : Colors.amber.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6.r),
                                              border: Border.all(
                                                color: !isProductAccepted
                                                    ? AppColors.red.withValues(alpha: 0.4)
                                                    : Colors.amber.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Text(
                                              !isProductAccepted ? 'Kabul Edilmiyor' : 'Q$reqQuality Şartı',
                                              style: TextStyle(
                                                fontSize: 9.5.sp,
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
          color: AppColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.all_inclusive_rounded, size: 14.sp, color: AppColors.green),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                'Genel Depo: Tüm ürünler ve tüm kalite seviyeleri kabul edilir.',
                style: TextStyle(
                  fontSize: 10.5.sp,
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
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.cardBgLight,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 15.sp, color: AppColors.gold),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                isFarm
                    ? 'Bu tarlada henüz ekili ürün veya aktif hammadde/gübre girdisi bulunmuyor.'
                    : isField
                        ? 'Bu çiftlikte henüz aktif hayvan veya yem girdisi bulunmuyor.'
                        : 'Bu tesiste tanımlı kabul edilen ürün bulunmuyor.',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 6.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFactory
                    ? Icons.precision_manufacturing_rounded
                    : isFarm
                        ? Icons.agriculture_rounded
                        : isField
                            ? Icons.pets_rounded
                            : isWarehouse
                                ? Icons.warehouse_rounded
                                : Icons.storefront_rounded,
                size: 14.sp,
                color: AppColors.gold,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  isFactory
                      ? 'Hedef Fabrikanın Kabul Ettiği Hammaddeler:'
                      : isFarm
                          ? 'Hedef Tarlanın Kabul Ettiği Girdiler:'
                          : isField
                              ? 'Hedef Çiftliğin Kabul Ettiği Yem & Girdiler:'
                              : isWarehouse
                                  ? 'Hedef Özel Deponun Kabul Ettiği Ürünler:'
                                  : 'Hedef Mağazanın Sattığı Ürünler:',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6.w),
              if (isProductionUnit)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Girdi Şartı: Q${target.minQualityLevel}',
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                )
              else
                Text(
                  '${acceptedList.length} Ürün',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: acceptedList.map((productId) {
                final prod = productMap[productId.toUpperCase()];
                final name = prod?.urunAdi ?? productId;
                final icon = prod?.urunIconu ?? '';
                final reqQ = target.getRequiredQualityFor(productId);

                return Container(
                  margin: EdgeInsets.only(right: 6.w),
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon.isNotEmpty) ...[
                        SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: BrandedProductImage(
                            fileName: icon,
                            productId: productId,
                          ),
                        ),
                        SizedBox(width: 5.w),
                      ],
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isProductionUnit) ...[
                        SizedBox(width: 4.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'Q$reqQ',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
      case 'field':
        return Colors.teal.shade700;
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

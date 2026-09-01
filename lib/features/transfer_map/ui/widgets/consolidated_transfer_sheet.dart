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
  const ConsolidatedTransferSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConsolidatedTransferSheet(),
    );
  }

  @override
  ConsumerState<ConsolidatedTransferSheet> createState() =>
      _ConsolidatedTransferSheetState();
}

class _ConsolidatedTransferSheetState
    extends ConsumerState<ConsolidatedTransferSheet> {
  int _currentStep = 0; // 0: Hedef, 1: Şehir, 2: Ürünler, 3: Araç/Onay

  ConsolidatedTargetModel? _selectedTarget;
  ConsolidatedSourceCityModel? _selectedCity;
  String _targetFilter = 'all'; // 'all', 'warehouse', 'factory', 'store'

  // itemId -> selected quantity
  final Map<String, int> _selectedQuantities = {};

  // Step 4 Vehicle Options
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

  Future<void> _loadVehicles(double totalVolume) async {
    if (_selectedCity == null || _selectedTarget == null) return;
    if (_selectedCity!.cityId == _selectedTarget!.cityId) return; // Same city!

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
        // Refresh transfer map
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
                      ? 'Adım 1: Hedef Tesisi Seçin'
                      : _currentStep == 1
                          ? 'Adım 2: Kaynak Şehri Seçin'
                          : _currentStep == 2
                              ? 'Adım 3: Ürünleri Toplayın'
                              : 'Adım 4: Araç & Gönderim',
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
          _buildStepChip(0, 'Hedef'),
          _buildStepDivider(0),
          _buildStepChip(1, 'Şehir'),
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
        return _buildStep1TargetSelection();
      case 1:
        return _buildStep2SourceCitySelection();
      case 2:
        return _buildStep3ProductsSelection();
      case 3:
        return _buildStep4VehicleAndConfirm();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================================
  // ADIM 1: HEDEF TESİS SEÇİMİ
  // ==========================================================================
  Widget _buildStep1TargetSelection() {
    final targetsAsync = ref.watch(consolidatedTransferTargetsProvider);

    return targetsAsync.when(
      data: (targets) {
        if (targets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 40.sp),
                SizedBox(height: 12.h),
                Text(
                  'Kullanılabilir Hedef Tesis Bulunamadı',
                  style: AppTextStyles.title,
                ),
                SizedBox(height: 6.h),
                Text(
                  'Ürün kabul edecek aktif bir depo, fabrika veya mağazanız bulunmuyor.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
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
            // Kategori Filtre Butonları
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
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
              child: filteredTargets.isEmpty
                  ? Center(
                      child: Text(
                        'Bu kategoride hedef tesis bulunamadı.',
                        style: AppTextStyles.caption,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                      itemCount: filteredTargets.length,
                      itemBuilder: (context, index) {
                        final target = filteredTargets[index];
                        final isSelected = _selectedTarget?.id == target.id;
                        final fullnessRatio = target.totalCapacity > 0
                            ? (target.usedCapacity / target.totalCapacity)
                                .clamp(0.0, 1.0)
                            : 0.0;

                        return GestureDetector(
                          onTap: () {
                            AppHaptic.selection();
                            setState(() {
                              _selectedTarget = target;
                              _currentStep = 1; // Otomatik sonraki adıma geç
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Boş Kapasite: ${target.emptyCapacity.toStringAsFixed(1)} m³',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: target.emptyCapacity > 0
                                            ? AppColors.green
                                            : AppColors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Toplam: ${target.totalCapacity.toStringAsFixed(0)} m³',
                                      style: TextStyle(
                                        fontSize: 10.5.sp,
                                        color: AppColors.textMuted,
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
                                    backgroundColor: AppColors.borderGold
                                        .withValues(alpha: 0.15),
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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
  // ADIM 2: KAYNAK ŞEHİR SEÇİMİ
  // ==========================================================================
  Widget _buildStep2SourceCitySelection() {
    final citiesAsync = ref.watch(consolidatedTransferSourceCitiesProvider);

    return citiesAsync.when(
      data: (cities) {
        if (cities.isEmpty) {
          return Center(
            child: Text(
              'Stok bulunan hiçbir tesisiniz yok.',
              style: AppTextStyles.body,
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          itemCount: cities.length,
          itemBuilder: (context, index) {
            final city = cities[index];
            final isSelected = _selectedCity?.cityId == city.cityId;
            final isSameCity = _selectedTarget?.cityId == city.cityId;

            return GestureDetector(
              onTap: () {
                AppHaptic.selection();
                setState(() {
                  _selectedCity = city;
                  _selectedQuantities.clear();
                  _currentStep = 2; // Ürün seçimine geç
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
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_city_rounded,
                        color: AppColors.gold,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                city.cityName,
                                style: AppTextStyles.title.standardCopyWith(
                                  fontSize: AppTypography.title,
                                ),
                              ),
                              if (isSameCity) ...[
                                SizedBox(width: 8.w),
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
                                    'Hedef Şehir (Şehir İçi)',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${city.facilityCount} İşletme • Toplam ${city.totalStock} Stok',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14.sp,
                      color: AppColors.textMuted,
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
  // ADIM 3: ÜRÜN TOPLAMA & KAPASİTE KİLİDİ
  // ==========================================================================
  Widget _buildStep3ProductsSelection() {
    if (_selectedCity == null || _selectedTarget == null) {
      return const SizedBox.shrink();
    }

    final params = ConsolidatedCandidatesParams(
      sourceCityId: _selectedCity!.cityId,
      targetEntityKind: _selectedTarget!.entityKind,
      targetEntityId: _selectedTarget!.id,
    );

    final candidatesAsync = ref.watch(
      consolidatedTransferCandidatesProvider(params),
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
                    'Uygun Ürün Bulunamadı',
                    style: AppTextStyles.title,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${_selectedCity!.cityName} şehrindeki tesislerinizde, ${_selectedTarget!.name} tesisinin kabul edebileceği stok bulunmuyor.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final selectedVolume = _computeSelectedVolume(candidates);
        final emptyCapacity = _selectedTarget!.emptyCapacity;
        final isCapacityExceeded = selectedVolume > emptyCapacity;
        final totalSelectedQuantity = _computeTotalQuantity();

        // Ürünleri işletme bazında grupla
        final groupedCandidates = <String, List<ConsolidatedCandidateItemModel>>{};
        for (final item in candidates) {
          final groupKey = '${item.sourceKindDisplay} • ${item.sourceName}';
          groupedCandidates.putIfAbsent(groupKey, () => []).add(item);
        }

        return Column(
          children: [
            // Canlı Kapasite Barı (Sticky)
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hedef Kapasite Doluluğu:',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${selectedVolume.toStringAsFixed(1)} / ${emptyCapacity.toStringAsFixed(1)} m³',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: isCapacityExceeded
                              ? AppColors.red
                              : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: emptyCapacity > 0
                          ? (selectedVolume / emptyCapacity).clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 6.h,
                      backgroundColor: AppColors.borderGold.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(
                        isCapacityExceeded ? AppColors.red : AppColors.gold,
                      ),
                    ),
                  ),
                  if (isCapacityExceeded)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text(
                        'Hedefin boş kapasitesi aşıldı! Lütfen miktarı azaltın.',
                        style: TextStyle(
                          color: AppColors.red,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Ürün Listesi
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 80.h),
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
                                width: 44.w,
                                height: 44.w,
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
                              // Adet Seçim Butonları
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

            // Devam Et Butonu
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
                  onPressed: totalSelectedQuantity > 0 && !isCapacityExceeded
                      ? () {
                          AppHaptic.light();
                          _loadVehicles(selectedVolume);
                          setState(() => _currentStep = 3);
                        }
                      : null,
                  child: Text(
                    'İlerle ($totalSelectedQuantity Adet • ${selectedVolume.toStringAsFixed(1)} m³)',
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
  // ADIM 4: ARAÇ & GÖNDERİM ONAYI
  // ==========================================================================
  Widget _buildStep4VehicleAndConfirm() {
    if (_selectedCity == null || _selectedTarget == null) {
      return const SizedBox.shrink();
    }

    final params = ConsolidatedCandidatesParams(
      sourceCityId: _selectedCity!.cityId,
      targetEntityKind: _selectedTarget!.entityKind,
      targetEntityId: _selectedTarget!.id,
    );
    final candidates = ref.read(consolidatedTransferCandidatesProvider(params)).value ?? [];
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

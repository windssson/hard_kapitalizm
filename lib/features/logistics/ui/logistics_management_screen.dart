import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/rewarded_time_reduce_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_finance_summary_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_performance_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_type_model.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_route_selection_screen.dart';

class LogisticsManagementScreen extends ConsumerStatefulWidget {
  const LogisticsManagementScreen({super.key});

  @override
  ConsumerState<LogisticsManagementScreen> createState() =>
      _LogisticsManagementScreenState();
}

class _LogisticsManagementScreenState
    extends ConsumerState<LogisticsManagementScreen> {
  String? _expandedVehicleId;

  Future<void> _handleRefuelAction(
    BuildContext context,
    LogisticsVehicleModel vehicle,
  ) async {
    final result = await ref
        .read(logisticsActionProvider)
        .refuelVehicle(vehicle.id);
    if (!context.mounted) return;
    _handleOpResult(context, result, 'Yakıt ikmali yapıldı.');
  }

  Future<void> _handleRepairAction(
    BuildContext context,
    LogisticsVehicleModel vehicle,
    LogisticsVehicleTypeModel? type,
    double playerCash,
  ) async {
    final missingCondition = (100 - vehicle.condition).clamp(0, 100);
    final purchasePrice = type?.purchasePrice ?? 0;
    final missingConditionRatio = missingCondition / 100.0;
    final repairCost = missingConditionRatio * (purchasePrice / 2);

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Bakım Onayı', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type?.name ?? 'Araç',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Eksik kondisyon: $missingCondition (%${(missingConditionRatio * 100).toStringAsFixed(0)})',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 6.h),
            Text(
              'Araç ücreti: ${purchasePrice.toStringAsFixed(0)} TL',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 6.h),
            Text(
              'Bakım maliyeti: ${repairCost.toStringAsFixed(0)} TL',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.gold,
                fontSize: AppTypography.bodyLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Mevcut nakit: ${playerCash.toStringAsFixed(0)} TL',
              style: AppTextStyles.caption.standardCopyWith(
                color: playerCash >= repairCost
                    ? AppColors.textMuted
                    : AppColors.red,
                fontSize: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text(
              'Bakımı Yap',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textOnAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true) {
      return;
    }

    final result = await ref
        .read(logisticsActionProvider)
        .repairVehicle(vehicle.id);
    if (!context.mounted) return;
    _handleOpResult(
      context,
      result,
      'Bakım tamamlandı.',
      includeCompany: false,
    );
  }

  Future<void> _handleBatchRefuelAction(BuildContext context) async {
    final result = await ref
        .read(logisticsActionProvider)
        .refuelAllVehicles();
    if (!context.mounted) return;
    _handleOpResult(
      context,
      result,
      result['message'] ?? 'Tüm araçlara yakıt ikmali yapıldı.',
    );
  }

  Future<void> _handleBatchRepairAction(
    BuildContext context,
    double playerCash,
  ) async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Toplu Bakım Onayı', style: AppTextStyles.h2),
        content: Text(
          'Boşta olan ve bakım gerektiren tüm araçlar onarılacaktır. Bakiyeniz yettiği kadar araç onarımı tamamlanacaktır.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text(
              'Tümünü Onar',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textOnAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    final result = await ref
        .read(logisticsActionProvider)
        .repairAllVehicles();
    if (!context.mounted) return;
    _handleOpResult(
      context,
      result,
      result['message'] ?? 'Toplu bakım tamamlandı.',
      includeCompany: false,
    );
  }

  Future<void> _handleActiveToggle(
    BuildContext context,
    LogisticsVehicleModel vehicle,
  ) async {
    final result = await ref
        .read(logisticsActionProvider)
        .setVehicleActive(
          vehicleId: vehicle.id,
          isActive: vehicle.status == 'inactive',
        );
    if (!context.mounted) return;
    _handleOpResult(
      context,
      result,
      vehicle.status == 'inactive'
          ? 'Araç aktif edildi.'
          : 'Araç pasife alındı.',
      includeCompany: false,
      includePlayer: false,
    );
  }

  Future<void> _handleRentalAction(
    BuildContext context,
    LogisticsVehicleModel vehicle,
    LogisticsVehicleTypeModel? type,
  ) async {
    if (vehicle.isAvailableForRent) {
      final result = await ref
          .read(logisticsActionProvider)
          .setVehicleRental(
            vehicleId: vehicle.id,
            isAvailableForRent: false,
            rentalPrice: 0,
          );
      if (!context.mounted) return;
      _handleOpResult(
        context,
        result,
        'Kiralama kapatıldı.',
        includeCompany: false,
        includePlayer: false,
      );
      return;
    }

    final fuelCostPerKm = vehicle.fuelRate * vehicle.fuelCost;
    final purchasePrice = type?.purchasePrice ?? 0.0;
    // 200 km'de 1 kondisyon puanı düşer. 1 kondisyon tamiri = (purchasePrice * 0.15) / 100 TL.
    // Dolayısıyla 1 km başına bakım maliyeti = (purchasePrice * 0.15) / 20000 TL = purchasePrice / 133333 TL.
    final maintenanceCostPerKm = purchasePrice > 0 ? (purchasePrice / 133333.0) : 0.0;
    final totalCostPerKm = fuelCostPerKm + maintenanceCostPerKm;
    final suggestedMinPrice = (totalCostPerKm * 1.3).ceilToDouble();

    final controller = TextEditingController(
      text: vehicle.rentalPrice > 0 ? vehicle.rentalPrice.toStringAsFixed(0) : '',
    );

    final rentalPrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Row(
          children: [
            Icon(AppIcons.vpnKey, color: AppColors.gold, size: AppIconSizes.medium),
            SizedBox(width: 8.w),
            Text('Kiraya Verme Ayarı', style: AppTextStyles.h2),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type?.name ?? 'Araç',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.title,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: AppColors.borderGold.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yakıt Maliyeti:',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${fuelCostPerKm.toStringAsFixed(2)} TL / km',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bakım/Yıpranma Payı:',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${maintenanceCostPerKm.toStringAsFixed(2)} TL / km',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      color: AppColors.border.withValues(alpha: 0.3),
                      height: 12.h,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Net Toplam Maliyet:',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                        Text(
                          '${totalCostPerKm.toStringAsFixed(2)} TL / km',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: AppTypography.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                '💡 Tavsiye edilen kârlı kira bedeli: en az ${suggestedMinPrice.toStringAsFixed(0)} TL / km',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.green,
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: controller,
                readOnly: true,
                showCursor: true,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  labelText: 'KM Başına Kira Ücreti (TL/km)',
                  hintText: 'Örn: 25',
                ),
              ),
              SizedBox(height: 12.h),
              NumericKeyboard(controller: controller, allowDecimal: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, double.tryParse(controller.text)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text(
              'Kiraya Ver',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textOnAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted) return;

    if (rentalPrice != null && rentalPrice > 0) {
      final result = await ref
          .read(logisticsActionProvider)
          .setVehicleRental(
            vehicleId: vehicle.id,
            isAvailableForRent: true,
            rentalPrice: rentalPrice,
          );
      if (!context.mounted) return;
      _handleOpResult(
        context,
        result,
        'Araç kiraya açıldı.',
        includeCompany: false,
        includePlayer: false,
      );
    } else if (rentalPrice != null) {
      AppSnackbar.show(
        context,
        title: 'Geçersiz Fiyat',
        message: 'Kira fiyatı sıfırdan büyük olmalı.',
        type: SnackbarType.warning,
      );
    }
  }

  Future<void> _openRouteSelectionPage(
    BuildContext context,
    LogisticsVehicleModel vehicle,
    List<CityModel> cities,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LogisticsRouteSelectionScreen(vehicle: vehicle, cities: cities),
      ),
    );

    if (saved == true) {
      ref.read(logisticsVehicleListProvider.notifier).refresh();
    }
  }

  void _handleOpResult(
    BuildContext context,
    Map<String, dynamic> result,
    String message, {
    bool includeVehicleList = true,
    bool includeCompany = true,
    bool includePlayer = true,
  }) {
    if (result['success'] == true) {
      if (includeVehicleList) {
        ref.read(logisticsVehicleListProvider.notifier).refresh();
      }
      if (includeCompany) {
        ref.invalidate(playerLogisticsCompanyProvider);
      }
      if (includePlayer) {
      }
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: message,
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'İşlem başarısız.',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(playerLogisticsCompanyProvider);
    final constructionAsync = ref.watch(playerLogisticsConstructionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Lojistik Yönetimi'),
            Expanded(
              child: companyAsync.when(
                data: (company) => constructionAsync.when(
                  data: (construction) => Consumer(
                    builder: (context, ref, _) {
                      final vehiclesAsync = ref.watch(
                        logisticsVehicleListProvider,
                      );
                      final vehicleTypesAsync = ref.watch(
                        logisticsVehicleTypesProvider,
                      );
                      final citiesAsync = ref.watch(activeCitiesProvider);
                      final playerAsync = ref.watch(playerProvider);
                      final performanceAsync = ref.watch(
                        logisticsVehiclePerformanceProvider,
                      );
                      final financeSummaryAsync = ref.watch(
                        logisticsFinanceSummaryProvider,
                      );

                      return playerAsync.when(
                        data: (player) => vehicleTypesAsync.when(
                          data: (vehicleTypes) => citiesAsync.when(
                            data: (cities) => performanceAsync.when(
                              data: (performanceByVehicle) =>
                                  vehiclesAsync.when(
                                    data: (vehicles) => _buildContent(
                                      context: context,
                                      company: company,
                                      construction: construction,
                                      vehicles: vehicles,
                                      vehicleTypes: vehicleTypes,
                                      cities: cities,
                                      performanceByVehicle:
                                          performanceByVehicle,
                                      financeSummary:
                                          financeSummaryAsync.asData?.value,
                                      playerCash: player?.cash ?? 0,
                                    ),
                                    loading: _buildLoading,
                                    error: (error, stack) =>
                                        _buildError('Araçlar yüklenemedi.'),
                                  ),
                              loading: _buildLoading,
                              error: (error, stack) =>
                                  _buildError('Performans verisi yüklenemedi.'),
                            ),
                            loading: _buildLoading,
                            error: (error, stack) =>
                                _buildError('Şehirler yüklenemedi.'),
                          ),
                          loading: _buildLoading,
                          error: (error, stack) =>
                              _buildError('Araç tipleri yüklenemedi.'),
                        ),
                        loading: _buildLoading,
                        error: (error, stack) =>
                            _buildError('Oyuncu verisi yüklenemedi.'),
                      );
                    },
                  ),
                  loading: _buildLoading,
                  error: (error, stack) =>
                      _buildError('İnşaat durumu okunamadı.'),
                ),
                loading: _buildLoading,
                error: (error, stack) =>
                    _buildError('Firma verisi yüklenemedi.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required LogisticsCompanyModel? company,
    required Map<String, dynamic>? construction,
    required List<LogisticsVehicleModel> vehicles,
    required List<LogisticsVehicleTypeModel> vehicleTypes,
    required List<CityModel> cities,
    required Map<String, LogisticsVehiclePerformanceModel> performanceByVehicle,
    required LogisticsFinanceSummaryModel? financeSummary,
    required double playerCash,
  }) {
    if (company == null && construction == null) {
      return _buildNoCompanyState(context);
    }

    final vehicleTypeMap = {for (final t in vehicleTypes) t.id: t};
    final cityMap = {for (final city in cities) city.id: city};
    final rawConstructionParams = construction?['params'];
    final Map<String, dynamic>? constructionParams =
        rawConstructionParams is Map<String, dynamic>
        ? rawConstructionParams
        : rawConstructionParams is Map
        ? Map<String, dynamic>.from(rawConstructionParams)
        : null;
    final finishAt = construction?['finish_at'] != null
        ? DateTime.tryParse(construction!['finish_at'].toString())
        : null;
    final constructionDurationMinutes =
        (constructionParams?['construction_time_minutes'] as num?)?.toInt() ??
        0;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 80.h),
      children: [
        if (company != null) ...[
          _buildCompanyCard(context, company, playerCash),
          SizedBox(height: 16.h),
          _buildFleetOverview(
            context,
            vehicles,
            performanceByVehicle,
            financeSummary,
            playerCash,
          ),
          SizedBox(height: 16.h),
          _buildSectionHeader('FİLO YÖNETİMİ', '${vehicles.length} Araç'),
          SizedBox(height: 8.h),
          if (vehicles.isEmpty)
            _buildEmptyFleetCard()
          else
            ...vehicles.map(
              (vehicle) => _buildVehicleCard(
                context,
                vehicle,
                vehicleTypeMap[vehicle.logisticsVehicleTypeId],
                performanceByVehicle[vehicle.id] ??
                    LogisticsVehiclePerformanceModel.empty(vehicle.id),
                cities,
                cityMap,
                playerCash,
              ),
            ),
          _buildPurchaseVehicleEntry(context, company, playerCash),
        ],
        if (construction != null) ...[
          if (company != null) SizedBox(height: 16.h),
          _buildSectionHeader('KURULUM DEVAM EDİYOR', 'İnşaat'),
          SizedBox(height: 8.h),
          _buildConstructionCard(
            context,
            construction,
            constructionParams,
            finishAt,
            constructionDurationMinutes,
          ),
        ],
      ],
    );
  }

  Widget _buildNoCompanyState(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24.w),
        padding: EdgeInsets.all(30.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.localShippingOutlined,
              color: AppColors.gold,
              size: AppIconSizes.emptyState,
            ),
            SizedBox(height: 20.h),
            Text(
              'Lojistik Ağınızı Kurun',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Ürünlerinizi taşımak ve kiralama geliri elde etmek için bir lojistik firması kurmalısınız.',
              style: AppTextStyles.body.standardCopyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: () => context.go('/logistics/setup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
              child: Text(
                'FİRMAYI KUR',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.title,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    LogisticsCompanyModel company,
    double playerCash,
  ) {
    final fuelRatio = company.fuelCapacity == 0
        ? 0.0
        : (company.currentFuel / company.fuelCapacity).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: AppDecorations.premiumCard(AppColors.gold, 24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.2),
                      AppColors.cardBgLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  AppIcons.businessCenterRounded,
                  color: AppColors.gold,
                  size: AppIconSizes.large,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.headline,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'SEVİYE ${company.level}',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: AppTypography.caption,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Lojistik Genel Merkezi',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.label,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(company.isActive),
            ],
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _buildPremiumStatTile(
                  'FİLO DURUMU',
                  '${company.currentVehicleCount} / ${company.maxVehicleCount}',
                  AppIcons.localShippingRounded,
                  AppColors.blue,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildPremiumStatTile(
                  'MERKEZ YAKIT',
                  '${company.currentFuel} / ${company.fuelCapacity} L',
                  AppIcons.gasMeterRounded,
                  AppColors.gold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.bolt,
                    color: AppColors.gold,
                    size: AppIconSizes.xSmall,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'MERKEZ YAKIT REZERVİ',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '%${(fuelRatio * 100).toInt()}',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          _buildPremiumProgressBar(fuelRatio, AppColors.gold),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: company.currentFuel >= company.fuelCapacity
                      ? null
                      : () => _showFuelSupplySheet(context, company),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.textOnAccent,
                    disabledBackgroundColor: AppColors.cardBgLight.withValues(
                      alpha: 0.5,
                    ),
                    disabledForegroundColor: AppColors.textMuted,
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(
                    AppIcons.localGasStationRounded,
                    size: AppIconSizes.small,
                  ),
                  label: Text(
                    company.currentFuel >= company.fuelCapacity
                        ? 'REZERV DOLU'
                        : 'YAKIT AL',
                    style: AppTextStyles.caption.standardCopyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/logistics/finance'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(
                    AppIcons.analyticsOutlined,
                    size: AppIconSizes.small,
                  ),
                  label: Text(
                    'FİNANS RAPORU',
                    style: AppTextStyles.caption.standardCopyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.25),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color.withValues(alpha: 0.7),
                size: AppIconSizes.small,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetOverview(
    BuildContext context,
    List<LogisticsVehicleModel> vehicles,
    Map<String, LogisticsVehiclePerformanceModel> performanceByVehicle,
    LogisticsFinanceSummaryModel? financeSummary,
    double playerCash,
  ) {
    final onRouteCount = vehicles
        .where((vehicle) => vehicle.status == 'on_route')
        .length;
    final idleCount = vehicles
        .where((vehicle) => vehicle.status == 'idle')
        .length;
    final lowFuelCount = vehicles
        .where((v) => v.currentFuel < v.fuelCapacity && v.status == 'idle')
        .length;
    final damagedCount = vehicles
        .where((v) => v.condition < 100 && v.status == 'idle')
        .length;

    final totalTrips = performanceByVehicle.values.fold<int>(
      0,
      (sum, p) => sum + p.totalTrips,
    );
    final totalDistance = performanceByVehicle.values.fold<double>(
      0,
      (sum, p) => sum + p.totalDistanceKm,
    );
    final totalCargo = performanceByVehicle.values.fold<int>(
      0,
      (sum, p) => sum + p.totalCargoQuantity,
    );
    final totalRentalRevenue = performanceByVehicle.values.fold<double>(
      0,
      (sum, p) => sum + p.rentalRevenue,
    );

    final totalDistanceDisplay = totalDistance > 0
        ? totalDistance.toStringAsFixed(0)
        : (financeSummary?.totalDistanceKm.toStringAsFixed(0) ?? '0');
    final totalCargoDisplay = totalCargo > 0
        ? totalCargo
        : (financeSummary?.totalCargoDelivered ?? 0);
    final rentalRevenueDisplay = totalRentalRevenue > 0
        ? totalRentalRevenue
        : (financeSummary?.rentalIncome ?? 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: AppColors.borderGold.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.insightsRounded,
                        color: AppColors.gold,
                        size: AppIconSizes.small,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'FİLO PERFORMANS & KPI',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${vehicles.length} Araç • $totalTrips Sefer',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.gold,
                      fontSize: AppTypography.caption,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiBox(
                      'Aktif / Boşta',
                      '$onRouteCount / $idleCount',
                      AppIcons.localShippingOutlined,
                      AppColors.blue,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildKpiBox(
                      'Toplam Yol',
                      '$totalDistanceDisplay km',
                      AppIcons.altRoute,
                      AppColors.gold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiBox(
                      'Taşınan Yük',
                      '$totalCargoDisplay Adet',
                      AppIcons.inventory2Outlined,
                      AppColors.green,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildKpiBox(
                      'Kira Geliri',
                      '${_formatMoney(rentalRevenueDisplay)} TL',
                      AppIcons.paymentsOutlined,
                      AppColors.warning,
                    ),
                  ),
                ],
              ),
              if (lowFuelCount > 0 || damagedCount > 0) ...[
                SizedBox(height: 12.h),
                Divider(color: AppColors.border.withValues(alpha: 0.3), height: 1),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    if (lowFuelCount > 0)
                      Expanded(
                        child: InkWell(
                          onTap: () => _handleBatchRefuelAction(context),
                          borderRadius: BorderRadius.circular(10.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  AppIcons.localGasStationRounded,
                                  color: AppColors.gold,
                                  size: AppIconSizes.xSmall,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Toplu Yakıt ($lowFuelCount)',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: AppTypography.label,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (lowFuelCount > 0 && damagedCount > 0)
                      SizedBox(width: 8.w),
                    if (damagedCount > 0)
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _handleBatchRepairAction(context, playerCash),
                          borderRadius: BorderRadius.circular(10.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppColors.green.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  AppIcons.buildRounded,
                                  color: AppColors.green,
                                  size: AppIconSizes.xSmall,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Toplu Bakım ($damagedCount)',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: AppTypography.label,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: AppIconSizes.small),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    LogisticsVehicleModel vehicle,
    LogisticsVehicleTypeModel? type,
    LogisticsVehiclePerformanceModel performance,
    List<CityModel> cities,
    Map<String, CityModel> cityMap,
    double playerCash,
  ) {
    final isExpanded = _expandedVehicleId == vehicle.id;
    final fuelRatio = vehicle.fuelCapacity == 0
        ? 0.0
        : (vehicle.currentFuel / vehicle.fuelCapacity).clamp(0.0, 1.0);
    final conditionRatio = (vehicle.condition / 100).clamp(0.0, 1.0);
    final hasRoute = vehicle.hasAssignedRoute;
    final vehicleShortId = vehicle.id.length > 8
        ? vehicle.id.substring(0, 8).toUpperCase()
        : vehicle.id.toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isExpanded
              ? AppColors.gold.withValues(alpha: 0.45)
              : AppColors.borderGold.withValues(alpha: 0.15),
          width: isExpanded ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedVehicleId = isExpanded ? null : vehicle.id;
          });
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      _mapVehicleIcon(type?.icon),
                      color: isExpanded
                          ? AppColors.gold
                          : AppColors.textSecondary,
                      size: AppIconSizes.medium,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type?.name ?? 'Bilinmeyen Araç',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.bodyLarge,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        if (hasRoute)
                          Row(
                            children: [
                              Icon(
                                AppIcons.placeOutlined,
                                color: AppColors.gold,
                                size: AppIconSizes.xxSmall,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                '${cityMap[vehicle.routeCityAId]?.name ?? '?'} ➔ ${cityMap[vehicle.routeCityBId]?.name ?? '?'}',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: AppTypography.label,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'ID: $vehicleShortId • Rota Yok',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.label,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildVehicleStatusBadge(vehicle),
                      if (!isExpanded) ...[
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              AppIcons.bolt,
                              color: fuelRatio < 0.2
                                  ? AppColors.red
                                  : AppColors.gold,
                              size: AppIconSizes.xxSmall,
                            ),
                            Text(
                              ' %${(fuelRatio * 100).toInt()}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.caption,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              AppIcons.handymanOutlined,
                              color: conditionRatio < 0.3
                                  ? AppColors.red
                                  : AppColors.green,
                              size: AppIconSizes.xxSmall,
                            ),
                            Text(
                              ' %${(conditionRatio * 100).toInt()}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (isExpanded) ...[
                Divider(color: AppFx.softOverlay(0.08), height: 16.h),
                if (hasRoute) ...[
                  _buildRoutePanel(vehicle, cityMap),
                  SizedBox(height: 12.h),
                ],
                _buildMiniProgress(
                  'YAKIT REZERVİ',
                  fuelRatio,
                  fuelRatio < 0.2 ? AppColors.red : AppColors.gold,
                  AppIcons.bolt,
                  '${vehicle.currentFuel} / ${vehicle.fuelCapacity} L',
                ),
                SizedBox(height: 10.h),
                _buildMiniProgress(
                  'KONDİSYON',
                  conditionRatio,
                  conditionRatio < 0.3 ? AppColors.red : AppColors.green,
                  AppIcons.handymanOutlined,
                  '%${vehicle.condition}',
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppFx.panelWash(0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      _buildVehicleDetailItem(
                        AppIcons.speed,
                        '${vehicle.speedKmh} km/h',
                        'Hız',
                      ),
                      _buildVehicleDetailItem(
                        AppIcons.inventory2Outlined,
                        '${vehicle.capacity} t',
                        'Kapasite',
                      ),
                      _buildVehicleDetailItem(
                        AppIcons.localGasStationOutlined,
                        '${vehicle.fuelRate} L/km',
                        'Tüketim',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                _buildVehiclePerformancePanel(performance),
                SizedBox(height: 12.h),
                _buildActionButtonsRow(
                  context,
                  vehicle,
                  type,
                  playerCash,
                  fuelRatio,
                  conditionRatio,
                  cities,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonsRow(
    BuildContext context,
    LogisticsVehicleModel vehicle,
    LogisticsVehicleTypeModel? type,
    double playerCash,
    double fuelRatio,
    double conditionRatio,
    List<CityModel> cities,
  ) {
    final canRefuel = vehicle.currentFuel < vehicle.fuelCapacity;
    final canRepair = vehicle.condition < 100;
    final canChangeRoute = vehicle.status != 'on_route';
    final canToggleActive = vehicle.status != 'on_route';

    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      alignment: WrapAlignment.start,
      children: [
        if (canRefuel)
          _buildActionButton(
            icon: AppIcons.localGasStation,
            label: 'Yakıt Al',
            color: AppColors.gold,
            onTap: () => _handleRefuelAction(context, vehicle),
          ),
        if (canRepair)
          _buildActionButton(
            icon: AppIcons.build,
            label: 'Bakım',
            color: AppColors.green,
            onTap: () =>
                _handleRepairAction(context, vehicle, type, playerCash),
          ),
        _buildActionButton(
          icon: AppIcons.altRoute,
          label: 'Rota Belirle',
          color: canChangeRoute ? AppColors.blue : AppColors.textMuted,
          onTap: canChangeRoute
              ? () => _openRouteSelectionPage(context, vehicle, cities)
              : null,
        ),
        _buildActionButton(
          icon: vehicle.isAvailableForRent
              ? AppIcons.noMeetingRoom
              : AppIcons.vpnKey,
          label: vehicle.isAvailableForRent ? 'Kiralama Kapat' : 'Kiraya Ver',
          color: AppColors.warning,
          onTap: () => _handleRentalAction(context, vehicle, type),
        ),
        if (canToggleActive)
          _buildActionButton(
            icon: vehicle.status == 'inactive'
                ? AppIcons.playCircleFill
                : AppIcons.pauseCircleFilled,
            label: vehicle.status == 'inactive' ? 'Etkinleştir' : 'Pasife Al',
            color: vehicle.status == 'inactive'
                ? AppColors.green
                : AppColors.red,
            onTap: () => _handleActiveToggle(context, vehicle),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: AppIconSizes.xSmall),
              SizedBox(width: 4.w),
              Text(
                label,
                style: AppTextStyles.caption.standardCopyWith(
                  color: color,
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutePanel(
    LogisticsVehicleModel vehicle,
    Map<String, CityModel> cityMap,
  ) {
    final hasRoute = vehicle.hasAssignedRoute;
    if (!hasRoute) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.cardBgLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.altRoute,
              color: AppColors.textMuted,
              size: AppIconSizes.small,
            ),
            SizedBox(width: 8.w),
            Text(
              'Rota atanmadı',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final cityAName = cityMap[vehicle.routeCityAId]?.name ?? '?';
    final cityBName = cityMap[vehicle.routeCityBId]?.name ?? '?';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.place, color: AppColors.gold, size: AppIconSizes.small),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              cityAName,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.gold,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Icon(
              AppIcons.syncAlt,
              color: AppColors.blue.withValues(alpha: 0.7),
              size: AppIconSizes.small,
            ),
          ),
          Icon(AppIcons.place, color: AppColors.gold, size: AppIconSizes.small),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              cityBName,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.gold,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclePerformancePanel(
    LogisticsVehiclePerformanceModel performance,
  ) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.insightsRounded,
                color: AppColors.gold,
                size: AppIconSizes.xSmall,
              ),
              SizedBox(width: 4.w),
              Text(
                'ARAÇ PERFORMANS GEÇMİŞİ',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildVehicleKpiTile(
                  'Seferler',
                  '${performance.totalTrips} (${performance.completedTrips} Bitti)',
                  AppIcons.localShippingOutlined,
                  AppColors.blue,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: _buildVehicleKpiTile(
                  'Toplam Mesafe',
                  '${performance.totalDistanceKm.toStringAsFixed(0)} km',
                  AppIcons.altRoute,
                  AppColors.gold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: _buildVehicleKpiTile(
                  'Taşınan Yük',
                  '${performance.totalCargoQuantity} Adet',
                  AppIcons.inventory2Outlined,
                  AppColors.green,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: _buildVehicleKpiTile(
                  'Kira Geliri',
                  '${performance.rentalRevenue.toStringAsFixed(0)} TL',
                  AppIcons.paymentsOutlined,
                  AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleKpiTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppIconSizes.xSmall),
          SizedBox(width: 6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.label,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseVehicleEntry(
    BuildContext context,
    LogisticsCompanyModel company,
    double playerCash,
  ) {
    final isFull = company.currentVehicleCount >= company.maxVehicleCount;
    return InkWell(
      onTap: isFull
          ? null
          : () => _showPurchaseVehicleSheet(
              context: context,
              company: company,
              playerCash: playerCash,
            ),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBgLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isFull
                ? AppColors.border
                : AppColors.gold.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.addCircleOutline,
              color: isFull ? AppColors.textMuted : AppColors.gold,
            ),
            SizedBox(width: 12.w),
            Text(
              isFull ? 'FİLO KAPASİTESİ DOLU' : 'YENİ ARAÇ SATIN AL',
              style: AppTextStyles.body.standardCopyWith(
                color: isFull ? AppColors.textMuted : AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(
              AppIcons.chevronRight,
              color: isFull ? AppColors.textMuted : AppColors.gold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstructionCard(
    BuildContext context,
    Map<String, dynamic> construction,
    Map<String, dynamic>? params,
    DateTime? finishAt,
    int constructionDurationMinutes,
  ) {
    final constructionId = construction['id'].toString();
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppColors.borderGold.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.construction,
                    color: AppColors.gold,
                    size: AppIconSizes.xLarge,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      params?['name'] ?? 'Lojistik Firması',
                      style: AppTextStyles.h2,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (finishAt != null)
                _ConstructionCountdown(
                  constructionId: constructionId,
                  finishAt: finishAt,
                  totalDuration: Duration(
                    minutes: constructionDurationMinutes > 0
                        ? constructionDurationMinutes
                        : 1,
                  ),
                  onFinish: () =>
                      _handleConstructionFinished(context, constructionId),
                ),
            ],
          ),
        ),
        if (finishAt != null) ...[
          SizedBox(height: 10.h),
          _ConstructionFinishButton(
            constructionId: constructionId,
            finishAt: finishAt,
            onFinishWithGold: (id) => _handleFinishWithGold(context, id),
          ),
          SizedBox(height: 10.h),
          RewardedTimeReduceButton(
            onPressed: () => _handleReduceConstructionTimeWithAd(
              context,
              ref,
              constructionId,
            ),
            caption:
                'Bir reklam ödülü al ve lojistik firma inşaat süresini 10 dakika kısalt.',
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleGold),
        Text(
          count,
          style: AppTextStyles.body.standardCopyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFleetCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        'Henüz bir aracınız yok. İlk aracınızı satın alarak başlayın.',
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPremiumProgressBar(double ratio, Color color) {
    final clampedRatio = ratio.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 10.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                borderRadius: BorderRadius.circular(5.r),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 10.h,
              width: constraints.maxWidth * clampedRatio,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.7), color],
                ),
                borderRadius: BorderRadius.circular(5.r),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(bool isActive) {
    final color = isActive ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.w,
            height: 5.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            isActive ? 'AKTİF' : 'PASİF',
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleStatusBadge(LogisticsVehicleModel vehicle) {
    final color = _getVehicleOperationColor(vehicle);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _getVehicleOperationLabel(vehicle),
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getVehicleOperationColor(LogisticsVehicleModel vehicle) {
    final fuelRatio = vehicle.fuelCapacity == 0
        ? 0.0
        : (vehicle.currentFuel / vehicle.fuelCapacity).clamp(0.0, 1.0);

    if (fuelRatio <= 0.15) {
      return AppColors.red;
    }
    if (vehicle.condition <= 30) {
      return AppColors.warning;
    }
    if (vehicle.status != 'on_route' && !vehicle.hasAssignedRoute) {
      return AppColors.gold;
    }
    if (vehicle.status == 'inactive') {
      return AppColors.textMuted;
    }
    if (vehicle.status == 'on_route') {
      return AppColors.blue;
    }
    return AppColors.green;
  }

  String _getVehicleOperationLabel(LogisticsVehicleModel vehicle) {
    final fuelRatio = vehicle.fuelCapacity == 0
        ? 0.0
        : (vehicle.currentFuel / vehicle.fuelCapacity).clamp(0.0, 1.0);

    if (fuelRatio <= 0.15) {
      return 'YAKIT KRİTİK';
    }
    if (vehicle.condition <= 30) {
      return 'BAKIM GEREKLİ';
    }
    if (vehicle.status != 'on_route' && !vehicle.hasAssignedRoute) {
      return 'ROTA EKSİK';
    }
    if (vehicle.status == 'inactive') {
      return 'PASİF ARAÇ';
    }
    if (vehicle.status == 'on_route') {
      return 'SEVKİYATTA';
    }
    return 'OPERASYONA HAZIR';
  }

  Widget _buildVehicleDetailItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: AppIconSizes.small),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySmall,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(
    String label,
    double value,
    Color color,
    IconData icon,
    String detailText,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.textMuted,
                  size: AppIconSizes.xxSmall,
                ),
                SizedBox(width: 4.w),
                Text(
                  label,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              detailText,
              style: AppTextStyles.caption.standardCopyWith(
                color: color,
                fontSize: AppTypography.label,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        _buildPremiumProgressBar(value, color),
      ],
    );
  }

  IconData _mapVehicleIcon(String? icon) {
    switch (icon) {
      case 'local_shipping':
        return AppIcons.localShipping;
      case 'electric_truck':
        return AppIcons.electricBolt;
      default:
        return AppIcons.localShippingOutlined;
    }
  }

  Widget _buildLoading() =>
      Center(child: AppLoadingIndicator(color: AppColors.gold));

  Widget _buildError(String message) => Center(
    child: Text(
      message,
      style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
    ),
  );

  Future<void> _showFuelSupplySheet(
    BuildContext context,
    LogisticsCompanyModel company,
  ) async {
    final remainingCapacity = company.fuelCapacity - company.currentFuel;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final warehouseAsync = ref.watch(
            playerLogisticsFuelWarehouseSourcesProvider,
          );

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.navBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                Text('Merkez Yakıt Al', style: AppTextStyles.h2),
                SizedBox(height: 6.h),
                Text(
                  'Boş kapasite: $remainingCapacity L',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: warehouseAsync.when(
                    data: (sources) {
                      if (sources.isEmpty) {
                        return _buildEmptyInfoCard(
                          'Depolarınızda kullanılabilir yakıt bulunmuyor.',
                        );
                      }
                      return ListView.separated(
                        itemCount: sources.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final source = sources[index];
                          final quantity =
                              (source['quantity'] as num?)?.toInt() ?? 0;
                          final maxQty = quantity < remainingCapacity
                              ? quantity
                              : remainingCapacity;

                          return _buildFuelSourceCard(
                            title: (source['warehouse_name'] ?? 'Depo')
                                .toString(),
                            subtitle:
                                '${source['city_name'] ?? 'Bilinmeyen Şehir'} / $quantity L',
                            trailing:
                                'Maliyet ${(source['cost'] as num?)?.toStringAsFixed(1) ?? '0'}',
                            onTap: maxQty <= 0
                                ? null
                                : () async {
                                    final qty = await _askFuelQuantity(
                                      context,
                                      title: 'Depodan Yakıt Aktar',
                                      subtitle:
                                          '${source['warehouse_name']} -> ${company.name}',
                                      maxQuantity: maxQty,
                                    );
                                    if (qty == null) return;
                                    if (!context.mounted) return;

                                    final result = await ref
                                        .read(logisticsActionProvider)
                                        .transferWarehouseFuelToCompany(
                                          logisticsCompanyId: company.id,
                                          warehouseSlotId: source['slot_id']
                                              .toString(),
                                          quantity: qty,
                                        );
                                    if (!context.mounted) return;
                                    if (result['success'] == true) {
                                      ref.invalidate(
                                        playerLogisticsCompanyProvider,
                                      );
                                      ref.invalidate(
                                        playerLogisticsFuelWarehouseSourcesProvider,
                                      );
                                      ref.invalidate(warehouseListProvider);
                                      Navigator.pop(sheetContext);
                                      AppSnackbar.show(
                                        context,
                                        title: 'Başarılı',
                                        message:
                                            '$qty L yakıt merkeze aktarıldı.',
                                        type: SnackbarType.success,
                                      );
                                    } else {
                                      AppSnackbar.show(
                                        context,
                                        title: 'Hata',
                                        message:
                                            result['message'] ??
                                            'Yakıt aktarılamadı.',
                                        type: SnackbarType.error,
                                      );
                                    }
                                  },
                          );
                        },
                      );
                    },
                    loading: _buildLoading,
                    error: (error, stack) =>
                        _buildError('Depo yakıtları yüklenemedi.'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFuelSourceCard({
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(AppIcons.localGasStation, color: AppColors.gold),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodyLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(subtitle, style: AppTextStyles.body),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trailing,
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.gold,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Icon(AppIcons.chevronRight, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInfoCard(String message) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }

  Future<int?> _askFuelQuantity(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int maxQuantity,
  }) async {
    final controller = TextEditingController(text: '1');

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(title, style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: AppTextStyles.body),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              readOnly: true,
              showCursor: true,
              enableInteractiveSelection: false,
              decoration: InputDecoration(
                labelText: 'Miktar',
                helperText: 'Maksimum: $maxQuantity L',
              ),
            ),
            SizedBox(height: 12.h),
            NumericKeyboard(
              controller: controller,
              shortcuts: [
                NumericKeyboardShortcut(
                  label: '1/4',
                  value: (maxQuantity / 4)
                      .ceil()
                      .clamp(1, maxQuantity)
                      .toString(),
                ),
                NumericKeyboardShortcut(
                  label: 'Yarı',
                  value: (maxQuantity / 2)
                      .ceil()
                      .clamp(1, maxQuantity)
                      .toString(),
                ),
                NumericKeyboardShortcut(
                  label: 'Tamamı',
                  value: maxQuantity.toString(),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty <= 0 || qty > maxQuantity) {
                AppSnackbar.show(
                  context,
                  title: 'Geçersiz Miktar',
                  message: '1 ile $maxQuantity arasında bir miktar girin.',
                  type: SnackbarType.warning,
                );
                return;
              }
              Navigator.pop(dialogContext, qty);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: Text(
              'Devam Et',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textOnAccent,
              ),
            ),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _handleConstructionFinished(
    BuildContext context,
    String constructionId,
  ) async {
    final result = await ref
        .read(logisticsActionProvider)
        .completeConstruction(constructionId, syncProviders: false);
    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'Lojistik merkezi tamamlandı.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'İnşaat tamamlanamadı.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleFinishWithGold(
    BuildContext context,
    String constructionId,
  ) async {
    final result = await ref
        .read(logisticsActionProvider)
        .finishConstructionWithGold(constructionId, syncProviders: false);
    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'İnşaat tamamlandı!',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    }
  }

  Future<void> _handleReduceConstructionTimeWithAd(
    BuildContext context,
    WidgetRef ref,
    String constructionId,
  ) async {
    await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'construction_time_reduce',
      resourceId: constructionId,
      onApplyReduction: () => ref
          .read(logisticsActionProvider)
          .reduceConstructionTimeWithAd(constructionId, syncProviders: false),
      successMessage: 'İnşaat süresi 10 dakika kısaltıldı.',
    );

    if (!context.mounted) return;
    ref.invalidate(playerLogisticsCompanyProvider);
    ref.invalidate(playerLogisticsConstructionProvider);
  }

  Future<void> _showPurchaseVehicleSheet({
    required BuildContext context,
    required LogisticsCompanyModel company,
    required double playerCash,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final typesAsync = ref.watch(logisticsVehicleTypesProvider);
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.navBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Araç Satın Al', style: AppTextStyles.h2),
                    Text(
                      '${company.currentVehicleCount}/${company.maxVehicleCount}',
                      style: AppTextStyles.titleGold,
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Expanded(
                  child: typesAsync.when(
                    data: (types) => ListView.builder(
                      itemCount: types.length,
                      itemBuilder: (context, index) => _PurchaseVehicleTypeCard(
                        type: types[index],
                        canAfford: playerCash >= types[index].purchasePrice,
                        isFleetFull:
                            company.currentVehicleCount >=
                            company.maxVehicleCount,
                        onPurchase: () async {
                          final result = await ref
                              .read(logisticsActionProvider)
                              .purchaseVehicle(
                                logisticsCompanyId: company.id,
                                logisticsVehicleTypeId: types[index].id,
                                syncProviders: false,
                              );
                          if (result['success'] == true) {
                            ref.invalidate(playerLogisticsCompanyProvider);
                            ref.read(logisticsVehicleListProvider.notifier).refresh();
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppSnackbar.show(
                                context,
                                title: 'Hayırlı Olsun!',
                                message:
                                    '${types[index].name} filonuza katıldı.',
                                type: SnackbarType.success,
                              );
                            }
                          } else if (context.mounted) {
                            AppSnackbar.show(
                              context,
                              title: 'Hata',
                              message:
                                  result['message'] ?? 'Araç satın alınamadı.',
                              type: SnackbarType.error,
                            );
                          }
                        },
                      ),
                    ),
                    loading: () => const Center(child: AppLoadingIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Hata: $error')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatMoney(double amount) {
    return AppMoney.compact(amount);
  }
}

class _ConstructionCountdown extends ConsumerStatefulWidget {
  final String constructionId;
  final DateTime finishAt;
  final Duration totalDuration;
  final VoidCallback? onFinish;

  const _ConstructionCountdown({
    required this.constructionId,
    required this.finishAt,
    required this.totalDuration,
    this.onFinish,
  });

  @override
  ConsumerState<_ConstructionCountdown> createState() =>
      _ConstructionCountdownState();
}

class _ConstructionCountdownState
    extends ConsumerState<_ConstructionCountdown> {
  bool _triggered = false;
  late final Duration _totalDuration;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.totalDuration.inSeconds > 0
        ? widget.totalDuration
        : const Duration(seconds: 1);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final remaining = widget.finishAt.difference(now);
    if (remaining.inSeconds <= 0 && !_triggered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _triggered) return;
        _triggered = true;
        widget.onFinish?.call();
      });
    }
    final isDone = remaining.inSeconds <= 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isDone
                    ? 'Tamamlanmaya Hazır'
                    : 'Kalan Süre: ${_formatDuration(remaining)}',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        AppProgressBar(
          value: _buildProgressValue(remaining),
          backgroundColor: AppColors.cardBgLight,
          valueColor: AlwaysStoppedAnimation(AppColors.gold),
        ),
      ],
    );
  }

  double _buildProgressValue(Duration remaining) {
    final totalSeconds = _totalDuration.inSeconds <= 0
        ? 1
        : _totalDuration.inSeconds;
    final remainingSeconds = remaining.inSeconds.clamp(0, totalSeconds);
    return (1 - (remainingSeconds / totalSeconds)).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours.toString().padLeft(2, '0')}:'
        '${(duration.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

class _ConstructionFinishButton extends ConsumerWidget {
  final String constructionId;
  final DateTime finishAt;
  final Future<void> Function(String constructionId)? onFinishWithGold;

  const _ConstructionFinishButton({
    required this.constructionId,
    required this.finishAt,
    this.onFinishWithGold,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final remainingSeconds = finishAt.difference(now).inSeconds;
    if (remainingSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final starCost = (remainingSeconds / 600.0).ceil().clamp(1, 999999);
    return GoldFinishButton(
      starCost: starCost,
      onPressed: () => onFinishWithGold?.call(constructionId),
    );
  }
}

class _PurchaseVehicleTypeCard extends StatelessWidget {
  final LogisticsVehicleTypeModel type;
  final bool canAfford;
  final bool isFleetFull;
  final VoidCallback onPurchase;

  const _PurchaseVehicleTypeCard({
    required this.type,
    required this.canAfford,
    required this.isFleetFull,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(AppIcons.localShipping, color: AppColors.gold),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.titleLarge,
                      ),
                    ),
                    Text(type.type, style: AppTextStyles.body),
                  ],
                ),
              ),
              Text(
                _formatMoney(type.purchasePrice),
                style: AppTextStyles.body.standardCopyWith(
                  color: canAfford ? AppColors.green : AppColors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _spec(AppIcons.speed, '${type.speedKmh} km/h'),
              _spec(AppIcons.inventory, '${type.capacity} t'),
              _spec(AppIcons.gasMeter, '${type.fuelCapacity} L'),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (canAfford && !isFleetFull) ? onPurchase : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                disabledBackgroundColor: AppColors.border,
              ),
              child: Text(
                isFleetFull
                    ? 'FILO DOLU'
                    : (canAfford ? 'SATIN AL' : 'NAKİT YETERSİZ'),
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textOnAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spec(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: AppIconSizes.xSmall, color: AppColors.textMuted),
        SizedBox(width: 4.w),
        Text(
          value,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }

  String _formatMoney(double amount) {
    return AppMoney.compact(amount);
  }
}

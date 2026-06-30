import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
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
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
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
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Mevcut nakit: ${playerCash.toStringAsFixed(0)} TL',
              style: TextStyle(
                color: playerCash >= repairCost
                    ? AppColors.textMuted
                    : AppColors.red,
                fontSize: 11.sp,
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
            child: const Text(
              'Bakımı Yap',
              style: TextStyle(color: Colors.black),
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

    final controller = TextEditingController();
    final rentalPrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Kira Fiyatı Belirle', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              readOnly: true,
              showCursor: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(hintText: 'Günlük kira bedeli'),
            ),
            SizedBox(height: 12.h),
            NumericKeyboard(controller: controller, allowDecimal: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, double.tryParse(controller.text)),
            child: const Text('Tamam'),
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
      ref.invalidate(logisticsVehicleListProvider);
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
        ref.invalidate(logisticsVehicleListProvider);
      }
      if (includeCompany) {
        ref.invalidate(playerLogisticsCompanyProvider);
      }
      if (includePlayer) {
        ref.invalidate(playerProvider);
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
          _buildFleetOverview(vehicles, performanceByVehicle),
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
              Icons.local_shipping_outlined,
              color: AppColors.gold,
              size: 60.sp,
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
              style: AppTextStyles.body.copyWith(height: 1.5),
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
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
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
                  Icons.business_center_rounded,
                  color: AppColors.gold,
                  size: 26.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
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
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Lojistik Genel Merkezi',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.sp,
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
                  Icons.local_shipping_rounded,
                  AppColors.blue,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildPremiumStatTile(
                  'MERKEZ YAKIT',
                  '${company.currentFuel} / ${company.fuelCapacity} L',
                  Icons.gas_meter_rounded,
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
                  Icon(Icons.bolt, color: AppColors.gold, size: 12.sp),
                  SizedBox(width: 4.w),
                  Text(
                    'MERKEZ YAKIT REZERVİ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '%${(fuelRatio * 100).toInt()}',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
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
                    foregroundColor: Colors.black,
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
                  icon: Icon(Icons.local_gas_station_rounded, size: 14.sp),
                  label: Text(
                    company.currentFuel >= company.fuelCapacity
                        ? 'REZERV DOLU'
                        : 'YAKIT AL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/logistics/finance'),
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
                  icon: Icon(Icons.analytics_outlined, size: 14.sp),
                  label: Text(
                    'FİNANS RAPORU',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
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
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.7), size: 13.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetOverview(
    List<LogisticsVehicleModel> vehicles,
    Map<String, LogisticsVehiclePerformanceModel> performanceByVehicle,
  ) {
    final onRouteCount = vehicles
        .where((vehicle) => vehicle.status == 'on_route')
        .length;
    final totalTrips = performanceByVehicle.values.fold<int>(
      0,
      (sum, performance) => sum + performance.totalTrips,
    );
    final financeEntriesAsync = ref.watch(logisticsFinanceEntriesProvider);
    final now = DateTime.now();
    final todayEntries =
        financeEntriesAsync.asData?.value
            .where((entry) => _isSameDay(entry.createdAt.toLocal(), now))
            .toList() ??
        const [];
    final dailyIncome = todayEntries
        .where((entry) => entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final dailyExpense = todayEntries
        .where((entry) => entry.isExpense)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final netDaily = dailyIncome - dailyExpense;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildOverviewStat(
            'Aktif Filo',
            '$onRouteCount / ${vehicles.length}',
            Icons.local_shipping_outlined,
            AppColors.blue,
          ),
          _buildOverviewDivider(),
          _buildOverviewStat(
            'Toplam Sefer',
            '$totalTrips',
            Icons.route_outlined,
            AppColors.gold,
          ),
          _buildOverviewDivider(),
          _buildOverviewStat(
            'Günlük Kâr',
            '${netDaily >= 0 ? '+' : ''}${_formatMoney(netDaily)} TL',
            Icons.payments_outlined,
            netDaily >= 0 ? AppColors.green : AppColors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(
    String label,
    String value,
    IconData icon,
    Color valueColor,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 12.sp),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewDivider() {
    return Container(
      height: 24.h,
      width: 1,
      color: AppColors.border.withValues(alpha: 0.5),
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
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type?.name ?? 'Bilinmeyen Araç',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        if (hasRoute)
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                color: AppColors.gold,
                                size: 10.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                '${cityMap[vehicle.routeCityAId]?.name ?? '?'} ➔ ${cityMap[vehicle.routeCityBId]?.name ?? '?'}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'ID: $vehicleShortId • Rota Yok',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
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
                              Icons.bolt,
                              color: fuelRatio < 0.2
                                  ? AppColors.red
                                  : AppColors.gold,
                              size: 10.sp,
                            ),
                            Text(
                              ' %${(fuelRatio * 100).toInt()}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9.sp,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              Icons.handyman_outlined,
                              color: conditionRatio < 0.3
                                  ? AppColors.red
                                  : AppColors.green,
                              size: 10.sp,
                            ),
                            Text(
                              ' %${(conditionRatio * 100).toInt()}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9.sp,
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
                Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 16.h,
                ),
                if (hasRoute) ...[
                  _buildRoutePanel(vehicle, cityMap),
                  SizedBox(height: 12.h),
                ],
                _buildMiniProgress(
                  'YAKIT REZERVI',
                  fuelRatio,
                  fuelRatio < 0.2 ? AppColors.red : AppColors.gold,
                  Icons.bolt,
                  '${vehicle.currentFuel} / ${vehicle.fuelCapacity} L',
                ),
                SizedBox(height: 10.h),
                _buildMiniProgress(
                  'KONDİSYON',
                  conditionRatio,
                  conditionRatio < 0.3 ? AppColors.red : AppColors.green,
                  Icons.handyman_outlined,
                  '%${vehicle.condition}',
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      _buildVehicleDetailItem(
                        Icons.speed,
                        '${vehicle.speedKmh} km/h',
                        'Hız',
                      ),
                      _buildVehicleDetailItem(
                        Icons.inventory_2_outlined,
                        '${vehicle.capacity} t',
                        'Kapasite',
                      ),
                      _buildVehicleDetailItem(
                        Icons.local_gas_station_outlined,
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
            icon: Icons.local_gas_station,
            label: 'Yakıt Al',
            color: AppColors.gold,
            onTap: () => _handleRefuelAction(context, vehicle),
          ),
        if (canRepair)
          _buildActionButton(
            icon: Icons.build,
            label: 'Bakım',
            color: AppColors.green,
            onTap: () =>
                _handleRepairAction(context, vehicle, type, playerCash),
          ),
        _buildActionButton(
          icon: Icons.alt_route,
          label: 'Rota Belirle',
          color: canChangeRoute ? AppColors.blue : AppColors.textMuted,
          onTap: canChangeRoute
              ? () => _openRouteSelectionPage(context, vehicle, cities)
              : null,
        ),
        _buildActionButton(
          icon: vehicle.isAvailableForRent
              ? Icons.no_meeting_room
              : Icons.vpn_key,
          label: vehicle.isAvailableForRent ? 'Kiralama Kapat' : 'Kiraya Ver',
          color: Colors.orangeAccent,
          onTap: () => _handleRentalAction(context, vehicle),
        ),
        if (canToggleActive)
          _buildActionButton(
            icon: vehicle.status == 'inactive'
                ? Icons.play_circle_fill
                : Icons.pause_circle_filled,
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
              Icon(icon, color: color, size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
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
            Icon(Icons.alt_route, color: AppColors.textMuted, size: 14.sp),
            SizedBox(width: 8.w),
            Text(
              'Rota atanmadı',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
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
          Icon(Icons.place, color: AppColors.gold, size: 14.sp),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              cityAName,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Icon(
              Icons.sync_alt,
              color: AppColors.blue.withValues(alpha: 0.7),
              size: 14.sp,
            ),
          ),
          Icon(Icons.place, color: AppColors.gold, size: 14.sp),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              cityBName,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 11.sp,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMiniStat(
          'Sefer',
          '${performance.totalTrips}',
          Icons.local_shipping,
        ),
        _buildMiniStat('Aktif', '${performance.activeTrips}', Icons.route),
        _buildMiniStat(
          'Gelir',
          '${performance.rentalRevenue.toStringAsFixed(0)} TL',
          Icons.payments,
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 12.sp),
        SizedBox(width: 4.w),
        Text(
          '$value $label',
          style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
        ),
      ],
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
              Icons.add_circle_outline,
              color: isFull ? AppColors.textMuted : AppColors.gold,
            ),
            SizedBox(width: 12.w),
            Text(
              isFull ? 'FILO KAPASITESI DOLU' : 'YENI ARAC SATIN AL',
              style: TextStyle(
                color: isFull ? AppColors.textMuted : AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
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
                  Icon(Icons.construction, color: AppColors.gold, size: 30.sp),
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
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
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
            style: TextStyle(
              color: color,
              fontSize: 9.sp,
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
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
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
      return Colors.orange;
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
          Icon(icon, color: AppColors.textMuted, size: 14.sp),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
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
                Icon(icon, color: AppColors.textMuted, size: 10.sp),
                SizedBox(width: 4.w),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              detailText,
              style: TextStyle(
                color: color,
                fontSize: 10.sp,
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
        return Icons.local_shipping;
      case 'electric_truck':
        return Icons.electric_bolt;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  Widget _buildLoading() =>
      const Center(child: CircularProgressIndicator(color: AppColors.gold));

  Widget _buildError(String message) => Center(
    child: Text(message, style: TextStyle(color: AppColors.red)),
  );

  Future<void> _showFuelSupplySheet(
    BuildContext context,
    LogisticsCompanyModel company,
  ) async {
    final remainingCapacity = company.fuelCapacity - company.currentFuel;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                child: const Icon(
                  Icons.local_gas_station,
                  color: AppColors.gold,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
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
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
            child: const Text(
              'Devam Et',
              style: TextStyle(color: Colors.black),
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
      ref.invalidate(playerProvider);
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
      ref.invalidate(playerProvider);
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'İnşaat tamamlandı!',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    }
  }

  Future<void> _showPurchaseVehicleSheet({
    required BuildContext context,
    required LogisticsCompanyModel company,
    required double playerCash,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                            ref.invalidate(logisticsVehicleListProvider);
                            ref.invalidate(playerProvider);
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        LinearProgressIndicator(
          value: _buildProgressValue(remaining),
          backgroundColor: AppColors.cardBgLight,
          valueColor: const AlwaysStoppedAnimation(AppColors.gold),
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
                child: const Icon(Icons.local_shipping, color: AppColors.gold),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                      ),
                    ),
                    Text(type.type, style: AppTextStyles.body),
                  ],
                ),
              ),
              Text(
                _formatMoney(type.purchasePrice),
                style: TextStyle(
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
              _spec(Icons.speed, '${type.speedKmh} km/h'),
              _spec(Icons.inventory, '${type.capacity} t'),
              _spec(Icons.gas_meter, '${type.fuelCapacity} L'),
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
                    : (canAfford ? 'SATIN AL' : 'NAKIT YETERSIZ'),
                style: const TextStyle(
                  color: Colors.black,
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
        Icon(icon, size: 12.sp, color: AppColors.textMuted),
        SizedBox(width: 4.w),
        Text(
          value,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
        ),
      ],
    );
  }

  String _formatMoney(double amount) {
    return AppMoney.compact(amount);
  }
}

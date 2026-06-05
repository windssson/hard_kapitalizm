import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
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

class LogisticsManagementScreen extends ConsumerWidget {
  const LogisticsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(playerLogisticsCompanyProvider);
    final constructionAsync = ref.watch(playerLogisticsConstructionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Lojistik Yonetimi'),
            Expanded(
              child: companyAsync.when(
                data: (company) => constructionAsync.when(
                  data: (construction) => Consumer(
                    builder: (context, ref, _) {
                      final vehiclesAsync = ref.watch(logisticsVehicleListProvider);
                      final vehicleTypesAsync = ref.watch(logisticsVehicleTypesProvider);
                      final citiesAsync = ref.watch(activeCitiesProvider);
                      final playerAsync = ref.watch(playerProvider);
                      final performanceAsync = ref.watch(logisticsVehiclePerformanceProvider);

                      return playerAsync.when(
                        data: (player) => vehicleTypesAsync.when(
                          data: (vehicleTypes) => citiesAsync.when(
                            data: (cities) => performanceAsync.when(
                              data: (performanceByVehicle) => vehiclesAsync.when(
                                data: (vehicles) => _buildContent(
                                  context: context,
                                  ref: ref,
                                  company: company,
                                  construction: construction,
                                  vehicles: vehicles,
                                  vehicleTypes: vehicleTypes,
                                  cities: cities,
                                  performanceByVehicle: performanceByVehicle,
                                  playerCash: player?.cash ?? 0,
                                ),
                                loading: _buildLoading,
                                error: (error, stack) =>
                                    _buildError('Araclar yuklenemedi.'),
                              ),
                              loading: _buildLoading,
                              error: (error, stack) =>
                                  _buildError('Performans verisi yuklenemedi.'),
                            ),
                            loading: _buildLoading,
                            error: (error, stack) =>
                                _buildError('Sehirler yuklenemedi.'),
                          ),
                          loading: _buildLoading,
                          error: (error, stack) =>
                              _buildError('Arac tipleri yuklenemedi.'),
                        ),
                        loading: _buildLoading,
                        error: (error, stack) =>
                            _buildError('Oyuncu verisi yuklenemedi.'),
                      );
                    },
                  ),
                  loading: _buildLoading,
                  error: (error, stack) =>
                      _buildError('Insaat durumu okunamadi.'),
                ),
                loading: _buildLoading,
                error: (error, stack) => _buildError('Firma verisi yuklenemedi.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required WidgetRef ref,
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
        (constructionParams?['construction_time_minutes'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 80.h),
      children: [
        if (company != null) ...[
          _buildCompanyCard(context, ref, company, playerCash),
          SizedBox(height: 24.h),
          _buildFleetOverview(ref, vehicles, performanceByVehicle),
          SizedBox(height: 24.h),
          _buildSectionHeader('FILO YONETIMI', '${vehicles.length} Arac'),
          SizedBox(height: 12.h),
          if (vehicles.isEmpty)
            _buildEmptyFleetCard()
          else
            ...vehicles.map(
              (vehicle) => _buildVehicleCard(
                context,
                ref,
                vehicle,
                vehicleTypeMap[vehicle.logisticsVehicleTypeId],
                performanceByVehicle[vehicle.id] ??
                    LogisticsVehiclePerformanceModel.empty(vehicle.id),
                cities,
                cityMap,
                playerCash,
              ),
            ),
          _buildPurchaseVehicleEntry(context, ref, company, playerCash),
        ],
        if (construction != null) ...[
          if (company != null) SizedBox(height: 24.h),
          _buildSectionHeader('KURULUM DEVAM EDIYOR', 'Insaat'),
          SizedBox(height: 12.h),
          _buildConstructionCard(
            context,
            ref,
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
          border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
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
              'Lojistik Aginizi Kurun',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Urunlerinizi tasimak ve kiralama geliri elde etmek icin bir lojistik firmasi kurmalisiniz.',
              style: AppTextStyles.body.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: () => context.go('/logistics/setup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: EdgeInsets.symmetric(
                  horizontal: 40.w,
                  vertical: 15.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
              child: Text(
                'FIRMAYI KUR',
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
    WidgetRef ref,
    LogisticsCompanyModel company,
    double playerCash,
  ) {
    final fuelRatio = company.fuelCapacity == 0
        ? 0.0
        : (company.currentFuel / company.fuelCapacity).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.cardBgLight, AppColors.cardBg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.borderGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.business_center,
                  color: AppColors.gold,
                  size: 30.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: AppTextStyles.h1.copyWith(fontSize: 20.sp),
                    ),
                    Text(
                      'Global lojistik merkezi - Seviye ${company.level}',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              _buildStatusChip(company.isActive),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  'FILO DURUMU',
                  '${company.currentVehicleCount}/${company.maxVehicleCount}',
                  Icons.local_shipping_rounded,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildStatTile(
                  'MERKEZ YAKIT',
                  '${company.currentFuel}/${company.fuelCapacity} L',
                  Icons.gas_meter_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MERKEZ YAKIT REZERVI',
                style: AppTextStyles.titleGold.copyWith(fontSize: 11.sp),
              ),
              Text(
                '%${(fuelRatio * 100).toInt()}',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildPremiumProgressBar(fuelRatio, AppColors.gold),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: company.currentFuel >= company.fuelCapacity
                      ? null
                      : () => _showFuelSupplySheet(
                            context,
                            ref,
                            company,
                            playerCash,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardBgLight,
                    disabledBackgroundColor: AppColors.border,
                    foregroundColor: AppColors.gold,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.local_gas_station_outlined),
                  label: Text(
                    company.currentFuel >= company.fuelCapacity ? 'DOLU' : 'YAKIT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
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
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: const Icon(Icons.analytics_outlined),
                  label: Text(
                    'RAPOR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
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

  Widget _buildFleetOverview(
    WidgetRef ref,
    List<LogisticsVehicleModel> vehicles,
    Map<String, LogisticsVehiclePerformanceModel> performanceByVehicle,
  ) {
    final assignedRoutes = vehicles.where((vehicle) => vehicle.hasAssignedRoute).length;
    final onRouteCount = vehicles.where((vehicle) => vehicle.status == 'on_route').length;
    final totalTrips = performanceByVehicle.values.fold<int>(
      0,
      (sum, performance) => sum + performance.totalTrips,
    );
    final financeEntriesAsync = ref.watch(logisticsFinanceEntriesProvider);
    final now = DateTime.now();
    final todayEntries = financeEntriesAsync.asData?.value
            .where((entry) => _isSameDay(entry.createdAt.toLocal(), now))
            .toList() ??
        const [];
    final dailyIncome = todayEntries
        .where((entry) => entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final dailyExpense = todayEntries
        .where((entry) => entry.isExpense)
        .fold<double>(0, (sum, entry) => sum + entry.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('OPERASYON OZETI', '$totalTrips Sefer'),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBgLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStatItem(
                      'AKTIF SEVKIYAT',
                      '$onRouteCount',
                      Icons.route,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildCompactStatItem(
                      'ATANMIS ROTA',
                      '$assignedRoutes/${vehicles.length}',
                      Icons.alt_route,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Divider(color: AppColors.borderGold.withValues(alpha: 0.2), height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStatItem(
                      'GUNLUK GELIR',
                      '${dailyIncome.toStringAsFixed(0)} TL',
                      Icons.payments_outlined,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildCompactStatItem(
                      'GUNLUK GIDER',
                      '${dailyExpense.toStringAsFixed(0)} TL',
                      Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 20.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    WidgetRef ref,
    LogisticsVehicleModel vehicle,
    LogisticsVehicleTypeModel? type,
    LogisticsVehiclePerformanceModel performance,
    List<CityModel> cities,
    Map<String, CityModel> cityMap,
    double playerCash,
  ) {
    final fuelRatio = vehicle.fuelCapacity == 0
        ? 0.0
        : (vehicle.currentFuel / vehicle.fuelCapacity).clamp(0.0, 1.0);
    final conditionRatio = (vehicle.condition / 100).clamp(0.0, 1.0);
    final hasRoute = vehicle.hasAssignedRoute;
    final vehicleShortId = vehicle.id.length > 8
        ? vehicle.id.substring(0, 8).toUpperCase()
        : vehicle.id.toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 6.w,
              child: Container(
                color: _getStatusColor(vehicle.status),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 6.w),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: AppColors.cardBgLight,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              _mapVehicleIcon(type?.icon),
                              color: AppColors.gold,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type?.name ?? 'Bilinmeyen Arac',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'ID: $vehicleShortId',
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildVehicleStatusBadge(vehicle.status),
                          SizedBox(width: 4.w),
                          _buildVehicleActionMenu(
                            context,
                            ref,
                            vehicle,
                            type,
                            cities,
                            cityMap,
                            fuelRatio,
                            conditionRatio,
                            playerCash,
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          _buildVehicleDetailItem(
                            Icons.speed,
                            '${vehicle.speedKmh} km/h',
                            'Hiz',
                          ),
                          _buildVehicleDetailItem(
                            Icons.inventory_2_outlined,
                            '${vehicle.capacity} t',
                            'Kapasite',
                          ),
                          _buildVehicleDetailItem(
                            Icons.local_gas_station_outlined,
                            '${vehicle.fuelRate} L/km',
                            'Tuketim',
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      _buildRoutePanel(vehicle, cityMap),
                      SizedBox(height: 16.h),
                      _buildMiniProgress(
                        'YAKIT',
                        fuelRatio,
                        fuelRatio < 0.2 ? AppColors.red : AppColors.gold,
                        Icons.bolt,
                      ),
                      SizedBox(height: 10.h),
                      _buildMiniProgress(
                        'KONDISYON',
                        conditionRatio,
                        conditionRatio < 0.3 ? AppColors.red : AppColors.green,
                        Icons.handyman_outlined,
                      ),
                      SizedBox(height: 14.h),
                      _buildVehiclePerformancePanel(performance),
                      // Aksiyon butonlari sag ust popup menuye tasindi.
                      if (!hasRoute) ...[
                        SizedBox(height: 10.h),
                        Text(
                          'Not: Ayni sehir transferleri anliktir. Bu arac yalnizca sehirler arasi rotalarda kullanilir.',
                          style: AppTextStyles.body.copyWith(fontSize: 10.sp),
                        ),
                      ],
                    ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Widget _buildVehicleActionMenu(
    BuildContext context,
    WidgetRef ref,
    LogisticsVehicleModel vehicle,
    LogisticsVehicleTypeModel? type,
    List<CityModel> cities,
    Map<String, CityModel> cityMap,
    double fuelRatio,
    double conditionRatio,
    double playerCash,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppColors.gold, size: 24.sp),
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      onSelected: (value) {
        switch (value) {
          case 'refuel':
            _handleRefuelAction(context, ref, vehicle);
            break;
          case 'repair':
            _handleRepairAction(context, ref, vehicle, type, playerCash);
            break;
          case 'route':
            _openRouteSelectionPage(context, ref, vehicle, cities);
            break;
          case 'rent':
            _handleRentalAction(context, ref, vehicle);
            break;
          case 'toggle_active':
            _handleActiveToggle(context, ref, vehicle);
            break;
        }
      },
      itemBuilder: (context) => [
        if (vehicle.currentFuel < vehicle.fuelCapacity)
          PopupMenuItem(
            value: 'refuel',
            child: Row(
              children: [
                Icon(Icons.local_gas_station, color: AppColors.gold, size: 18.sp),
                SizedBox(width: 10.w),
                Text('Doldur', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
              ],
            ),
          ),
        if (vehicle.condition < 100)
          PopupMenuItem(
            value: 'repair',
            child: Row(
              children: [
                Icon(Icons.build, color: AppColors.gold, size: 18.sp),
                SizedBox(width: 10.w),
                Text('Bakim Yap', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
              ],
            ),
          ),
        if (vehicle.status != 'on_route')
          PopupMenuItem(
            value: 'route',
            child: Row(
              children: [
                Icon(Icons.alt_route, color: AppColors.gold, size: 18.sp),
                SizedBox(width: 10.w),
                Text('Rota Atamasi', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'rent',
          child: Row(
            children: [
              Icon(vehicle.isAvailableForRent ? Icons.no_meeting_room : Icons.vpn_key, color: AppColors.gold, size: 18.sp),
              SizedBox(width: 10.w),
              Text(vehicle.isAvailableForRent ? 'Kiralamayi Kapat' : 'Kiraya Ver', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
            ],
          ),
        ),
        if (vehicle.status != 'on_route')
          PopupMenuItem(
            value: 'toggle_active',
            child: Row(
              children: [
                Icon(vehicle.status == 'inactive' ? Icons.play_circle_fill : Icons.pause_circle_filled, color: AppColors.gold, size: 18.sp),
                SizedBox(width: 10.w),
                Text(vehicle.status == 'inactive' ? 'Aktif Et' : 'Pasife Al', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openRouteSelectionPage(
    BuildContext context,
    WidgetRef ref,
    LogisticsVehicleModel vehicle,
    List<CityModel> cities,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LogisticsRouteSelectionScreen(
          vehicle: vehicle,
          cities: cities,
        ),
      ),
    );

    if (saved == true) {
      ref.invalidate(logisticsVehicleListProvider);
    }
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
            Text('Rota atanmadi', style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp, fontWeight: FontWeight.bold)),
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
              style: TextStyle(color: AppColors.gold, fontSize: 11.sp, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Icon(Icons.sync_alt, color: AppColors.blue.withValues(alpha: 0.7), size: 14.sp),
          ),
          Icon(Icons.place, color: AppColors.gold, size: 14.sp),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              cityBName,
              style: TextStyle(color: AppColors.gold, fontSize: 11.sp, fontWeight: FontWeight.w800),
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
        _buildMiniStat('Sefer', '${performance.totalTrips}', Icons.local_shipping),
        _buildMiniStat('Aktif', '${performance.activeTrips}', Icons.route),
        _buildMiniStat('Gelir', '${performance.rentalRevenue.toStringAsFixed(0)}', Icons.payments),
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
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseVehicleEntry(
    BuildContext context,
    WidgetRef ref,
    LogisticsCompanyModel company,
    double playerCash,
  ) {
    final isFull = company.currentVehicleCount >= company.maxVehicleCount;
    return InkWell(
      onTap: isFull
          ? null
          : () => _showPurchaseVehicleSheet(
                context: context,
                ref: ref,
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
    WidgetRef ref,
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
                      params?['name'] ?? 'Lojistik Firmasi',
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
                  onFinish: () => _handleConstructionFinished(
                    context,
                    ref,
                    constructionId,
                  ),
                ),
            ],
          ),
        ),
        if (finishAt != null) ...[
          SizedBox(height: 10.h),
          _ConstructionFinishButton(
            constructionId: constructionId,
            finishAt: finishAt,
            onFinishWithGold: (id) => _handleFinishWithGold(context, ref, id),
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
        'Henuz bir araciniz yok. Ilk aracinizi satin alarak baslayin.',
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 14.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
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
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color, blurRadius: 4)],
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            isActive ? 'AKTIF' : 'PASIF',
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.green;
      case 'on_route':
        return AppColors.blue;
      case 'repairing':
        return AppColors.gold;
      case 'inactive':
        return AppColors.textMuted;
      default:
        return AppColors.red;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'HAZIR';
      case 'on_route':
        return 'YOLDA';
      case 'repairing':
        return 'BAKIMDA';
      case 'inactive':
        return 'PASIF';
      default:
        return status.toUpperCase();
    }
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
              '%${(value * 100).toInt()}',
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

  Widget _buildError(String message) =>
      Center(child: Text(message, style: TextStyle(color: AppColors.red)));

  Future<void> _handleRefuelAction(
    BuildContext context,
    WidgetRef ref,
    LogisticsVehicleModel vehicle,
  ) async {
    final result = await ref.read(logisticsActionProvider).refuelVehicle(
          vehicle.id,
        );
    _handleOpResult(context, ref, result, 'Yakit ikmali yapildi.');
  }

  Future<void> _showFuelSupplySheet(
    BuildContext context,
    WidgetRef ref,
    LogisticsCompanyModel company,
    double playerCash,
  ) async {
    var mode = 'warehouse';
    final remainingCapacity = company.fuelCapacity - company.currentFuel;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Consumer(
          builder: (context, ref, _) {
            final warehouseAsync = ref.watch(
              playerLogisticsFuelWarehouseSourcesProvider,
            );
            final marketAsync = ref.watch(logisticsFuelMarketListingsProvider);

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
                  Text('Merkez Yakit Al', style: AppTextStyles.h2),
                  SizedBox(height: 6.h),
                  Text(
                    'Bos kapasite: $remainingCapacity L',
                    style: AppTextStyles.body,
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFuelModeButton(
                          label: 'Depomdan',
                          selected: mode == 'warehouse',
                          onTap: () => setModalState(() => mode = 'warehouse'),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _buildFuelModeButton(
                          label: 'Pazardan',
                          selected: mode == 'market',
                          onTap: () => setModalState(() => mode = 'market'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: mode == 'warehouse'
                        ? warehouseAsync.when(
                            data: (sources) {
                              if (sources.isEmpty) {
                                return _buildEmptyInfoCard(
                                  'Depolarinizda kullanilabilir yakit bulunmuyor.',
                                );
                              }
                              return ListView.separated(
                                itemCount: sources.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 10.h),
                                itemBuilder: (context, index) {
                                  final source = sources[index];
                                  final quantity =
                                      (source['quantity'] as num?)?.toInt() ?? 0;
                                  final maxQty = quantity < remainingCapacity
                                      ? quantity
                                      : remainingCapacity;

                                  return _buildFuelSourceCard(
                                    title:
                                        (source['warehouse_name'] ?? 'Depo')
                                            .toString(),
                                    subtitle:
                                        '${source['city_name'] ?? 'Bilinmeyen Sehir'} / $quantity L',
                                    trailing:
                                        'Maliyet ${(source['cost'] as num?)?.toStringAsFixed(1) ?? '0'}',
                                    onTap: maxQty <= 0
                                        ? null
                                        : () async {
                                            final qty =
                                                await _askFuelQuantity(
                                              context,
                                              title: 'Depodan Yakit Aktar',
                                              subtitle:
                                                  '${source['warehouse_name']} -> ${company.name}',
                                              maxQuantity: maxQty,
                                            );
                                            if (qty == null) return;

                                            final result = await ref
                                                .read(logisticsActionProvider)
                                                .transferWarehouseFuelToCompany(
                                                  logisticsCompanyId: company.id,
                                                  warehouseSlotId:
                                                      source['slot_id']
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
                                              ref.invalidate(
                                                warehouseListProvider,
                                              );
                                              Navigator.pop(sheetContext);
                                              AppSnackbar.show(
                                                context,
                                                title: 'Basarili',
                                                message:
                                                    '$qty L yakit merkeze aktarildi.',
                                                type: SnackbarType.success,
                                              );
                                            } else {
                                              AppSnackbar.show(
                                                context,
                                                title: 'Hata',
                                                message:
                                                    result['message'] ??
                                                    'Yakit aktarilamadi.',
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
                                _buildError('Depo yakitlari yuklenemedi.'),
                          )
                        : marketAsync.when(
                            data: (listings) {
                              if (listings.isEmpty) {
                                return _buildEmptyInfoCard(
                                  'Pazarda satista yakit ilani bulunmuyor.',
                                );
                              }
                              return ListView.separated(
                                itemCount: listings.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 10.h),
                                itemBuilder: (context, index) {
                                  final listing = listings[index];
                                  final maxQty = listing.quantity < remainingCapacity
                                      ? listing.quantity
                                      : remainingCapacity;
                                  return _buildFuelSourceCard(
                                    title: listing.warehouseName,
                                    subtitle:
                                        '${listing.cityName} / ${listing.quantity} L / Q${listing.qualityLevel}',
                                    trailing:
                                        '${listing.price.toStringAsFixed(1)} TL/L',
                                    onTap: maxQty <= 0
                                        ? null
                                        : () async {
                                            final qty =
                                                await _askFuelQuantity(
                                              context,
                                              title: 'Pazardan Yakit Al',
                                              subtitle:
                                                  '${listing.warehouseName} -> ${company.name}',
                                              maxQuantity: maxQty,
                                            );
                                            if (qty == null) return;

                                            final totalCost = qty * listing.price;
                                            if (playerCash < totalCost) {
                                              AppSnackbar.show(
                                                context,
                                                title: 'Nakit Yetersiz',
                                                message:
                                                    'Gerekli: ${totalCost.toStringAsFixed(0)} TL',
                                                type: SnackbarType.error,
                                              );
                                              return;
                                            }

                                            final result = await ref
                                                .read(logisticsActionProvider)
                                                .buyMarketFuelForCompany(
                                                  logisticsCompanyId: company.id,
                                                  sellerSlotId: listing.slotId,
                                                  quantity: qty,
                                                );
                                            if (!context.mounted) return;
                                            if (result['success'] == true) {
                                              ref.invalidate(
                                                playerLogisticsCompanyProvider,
                                              );
                                              ref.invalidate(
                                                logisticsFuelMarketListingsProvider,
                                              );
                                              ref.invalidate(playerProvider);
                                              Navigator.pop(sheetContext);
                                              AppSnackbar.show(
                                                context,
                                                title: 'Basarili',
                                                message:
                                                    '$qty L yakit pazardan alindi.',
                                                type: SnackbarType.success,
                                              );
                                            } else {
                                              AppSnackbar.show(
                                                context,
                                                title: 'Hata',
                                                message:
                                                    result['message'] ??
                                                    'Yakit satin alinamadi.',
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
                                _buildError('Pazar yakit ilanlari yuklenemedi.'),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFuelModeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            selected ? AppColors.gold : AppColors.cardBgLight,
        foregroundColor: selected ? Colors.black : AppColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(
            color: selected ? AppColors.gold : AppColors.border,
          ),
        ),
      ),
      child: Text(label),
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
                child: Icon(Icons.local_gas_station, color: AppColors.gold),
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
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
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
                  label: 'Yari',
                  value: (maxQuantity / 2)
                      .ceil()
                      .clamp(1, maxQuantity)
                      .toString(),
                ),
                NumericKeyboardShortcut(
                  label: 'Tamami',
                  value: maxQuantity.toString(),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty <= 0 || qty > maxQuantity) {
                AppSnackbar.show(
                  context,
                  title: 'Gecersiz Miktar',
                  message: '1 ile $maxQuantity arasinda bir miktar girin.',
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

  Future<void> _handleRepairAction(
    BuildContext context,
    WidgetRef ref,
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
        title: Text('Bakim Onayi', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type?.name ?? 'Arac',
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
              'Arac ucreti: ${purchasePrice.toStringAsFixed(0)} TL',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 6.h),
            Text(
              'Bakim maliyeti: ${repairCost.toStringAsFixed(0)} TL',
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
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text(
              'Bakimi Yap',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true) {
      return;
    }

    final result = await ref.read(logisticsActionProvider).repairVehicle(
          vehicle.id,
        );
    _handleOpResult(
      context,
      ref,
      result,
      'Bakim tamamlandi.',
      includeCompany: false,
    );
  }

  Future<void> _handleActiveToggle(
    BuildContext context,
    WidgetRef ref,
    LogisticsVehicleModel vehicle,
  ) async {
    final result = await ref.read(logisticsActionProvider).setVehicleActive(
          vehicleId: vehicle.id,
          isActive: vehicle.status == 'inactive',
        );
    _handleOpResult(
      context,
      ref,
      result,
      vehicle.status == 'inactive'
          ? 'Arac aktif edildi.'
          : 'Arac pasife alindi.',
      includeCompany: false,
      includePlayer: false,
    );
  }

  void _handleOpResult(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> result,
    String message,
    {
    bool includeVehicleList = true,
    bool includeCompany = true,
    bool includePlayer = true,
  }
  ) {
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
        title: 'Basarili',
        message: message,
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Islem basarisiz.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleRentalAction(
    BuildContext context,
    WidgetRef ref,
    LogisticsVehicleModel vehicle,
  ) async {
    if (vehicle.isAvailableForRent) {
      final result = await ref.read(logisticsActionProvider).setVehicleRental(
            vehicleId: vehicle.id,
            isAvailableForRent: false,
            rentalPrice: 0,
          );
      _handleOpResult(
        context,
        ref,
        result,
        'Kiralama kapatildi.',
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
        title: Text('Kira Fiyati Belirle', style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              readOnly: true,
              showCursor: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                hintText: 'Gunluk kira bedeli',
              ),
            ),
            SizedBox(height: 12.h),
            NumericKeyboard(
              controller: controller,
              allowDecimal: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgec'),
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

    if (rentalPrice != null) {
      final result = await ref.read(logisticsActionProvider).setVehicleRental(
            vehicleId: vehicle.id,
            isAvailableForRent: true,
            rentalPrice: rentalPrice,
          );
      _handleOpResult(
        context,
        ref,
        result,
        'Arac kiraya acildi.',
        includeCompany: false,
        includePlayer: false,
      );
    }
  }

  Future<void> _handleConstructionFinished(
    BuildContext context,
    WidgetRef ref,
    String constructionId,
  ) async {
    final result = await ref
        .read(logisticsActionProvider)
        .completeConstruction(constructionId, syncProviders: false);
    if (result['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
      ref.invalidate(playerProvider);
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Lojistik merkezi tamamlandi.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Insaat tamamlanamadi.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleFinishWithGold(
    BuildContext context,
    WidgetRef ref,
    String constructionId,
  ) async {
    final result = await ref
        .read(logisticsActionProvider)
        .finishConstructionWithGold(constructionId, syncProviders: false);
    if (result['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
      ref.invalidate(playerProvider);
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Insaat tamamlandi!',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
    }
  }

  Future<void> _showPurchaseVehicleSheet({
    required BuildContext context,
    required WidgetRef ref,
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
                    Text('Arac Satin Al', style: AppTextStyles.h2),
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
                            company.currentVehicleCount >= company.maxVehicleCount,
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
                                title: 'Hayirli Olsun!',
                                message:
                                    '${types[index].name} filonuza katildi.',
                                type: SnackbarType.success,
                              );
                            }
                          } else if (context.mounted) {
                            AppSnackbar.show(
                              context,
                              title: 'Hata',
                              message:
                                  result['message'] ?? 'Arac satin alinamadi.',
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

  String _buildRouteLabel(
    LogisticsVehicleModel vehicle,
    Map<String, CityModel> cityMap,
  ) {
    if (!vehicle.hasAssignedRoute) {
      return 'Rota atanmadi';
    }

    final cityAName =
        cityMap[vehicle.routeCityAId]?.name ?? 'Bilinmeyen sehir';
    final cityBName =
        cityMap[vehicle.routeCityBId]?.name ?? 'Bilinmeyen sehir';
    return '$cityAName <-> $cityBName';
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
                    ? 'Tamamlanmaya Hazir'
                    : 'Kalan Sure: ${_formatDuration(remaining)}',
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
                child: Icon(Icons.local_shipping, color: AppColors.gold),
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
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

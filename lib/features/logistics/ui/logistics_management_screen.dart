import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_datetime.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_type_model.dart';

class LogisticsManagementScreen extends ConsumerWidget {
  const LogisticsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(playerLogisticsCompanyProvider);
    final constructionAsync = ref.watch(playerLogisticsConstructionProvider);
    final vehiclesAsync = ref.watch(logisticsVehicleListStreamProvider);
    final vehicleTypesAsync = ref.watch(logisticsVehicleTypesProvider);
    final playerAsync = ref.watch(playerStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Nakliye Yonetimi'),
            Expanded(
              child: companyAsync.when(
                data: (company) {
                  return playerAsync.when(
                    data: (player) => vehicleTypesAsync.when(
                      data: (vehicleTypes) => vehiclesAsync.when(
                        data: (vehicles) => constructionAsync.when(
                          data: (construction) => _buildContent(
                            context: context,
                            ref: ref,
                            company: company,
                            construction: construction,
                            vehicles: vehicles,
                            vehicleTypes: vehicleTypes,
                            playerCash: player?.cash ?? 0,
                          ),
                          loading: _buildLoading,
                          error: (error, stack) => _buildError('Insaat durumu okunamadi.'),
                        ),
                        loading: _buildLoading,
                        error: (error, stack) => _buildError('Araclar yuklenemedi.'),
                      ),
                      loading: _buildLoading,
                      error: (error, stack) => _buildError('Arac tipleri yuklenemedi.'),
                    ),
                    loading: _buildLoading,
                    error: (error, stack) => _buildError('Oyuncu verisi yuklenemedi.'),
                  );
                },
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
    required double playerCash,
  }) {
    final vehicleTypeMap = {
      for (final vehicleType in vehicleTypes) vehicleType.id: vehicleType,
    };

    if (company == null && construction == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Container(
            padding: EdgeInsets.all(22.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping_outlined, color: AppColors.gold, size: 44.sp),
                SizedBox(height: 12.h),
                Text('Henuz nakliye firman yok', style: AppTextStyles.h2, textAlign: TextAlign.center),
                SizedBox(height: 8.h),
                Text(
                  'Lojistik sistemini acmak icin once bir nakliye firmasi kurman gerekiyor.',
                  style: AppTextStyles.body.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/logistics/setup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'FIRMA KUR',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final constructionParams = construction?['params'] as Map<String, dynamic>?;
    final finishAt = construction?['finish_at'] != null
        ? DateTime.tryParse(construction!['finish_at'].toString())
        : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      children: [
        if (company != null) ...[
          _buildCompanyCard(company),
          SizedBox(height: 16.h),
          _buildSectionTitle('Filo Durumu'),
          SizedBox(height: 8.h),
          if (vehicles.isEmpty)
            _buildInfoCard(
              icon: Icons.no_transfer,
              title: 'Arac yok',
              body: 'Bu firmaya bagli henuz bir nakliye araci bulunmuyor.',
            )
          else
            ...vehicles.map(
              (vehicle) => _buildVehicleCard(
                vehicle,
                vehicleTypeMap[vehicle.logisticsVehicleTypeId],
              ),
            ),
          _buildPurchaseVehicleCard(
            context: context,
            ref: ref,
            company: company,
            playerCash: playerCash,
          ),
        ],
        if (construction != null) ...[
          if (company != null) SizedBox(height: 16.h),
          _buildSectionTitle('Kurulum Durumu'),
          SizedBox(height: 8.h),
          _buildInfoCard(
            icon: Icons.construction,
            title: (constructionParams?['name'] ?? 'Nakliye Firmasi').toString(),
            body: finishAt == null
                ? 'Nakliye firmasi insaati devam ediyor.'
                : 'Insaat devam ediyor. Tahmini bitis: ${_formatDate(finishAt)}',
            footer: finishAt == null
                ? null
                : _ConstructionCountdown(
                    constructionId: construction['id']?.toString() ?? '',
                    finishAt: finishAt,
                    onFinish: () => _handleConstructionFinished(
                      context,
                      ref,
                      construction['id']?.toString() ?? '',
                    ),
                    onFinishWithGold: (constructionId) => _handleFinishWithGold(
                      context,
                      ref,
                      constructionId,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompanyCard(LogisticsCompanyModel company) {
    final fuelRatio = company.fuelCapacity == 0
        ? 0.0
        : (company.currentFuel / company.fuelCapacity).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.local_shipping, color: AppColors.gold, size: 28.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company.name, style: AppTextStyles.h2),
                    SizedBox(height: 4.h),
                    Text('Global lojistik merkezi', style: AppTextStyles.body),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: company.isActive
                      ? AppColors.green.withValues(alpha: 0.12)
                      : AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: company.isActive ? AppColors.green : AppColors.red,
                  ),
                ),
                child: Text(
                  company.isActive ? 'AKTIF' : 'PASIF',
                  style: TextStyle(
                    color: company.isActive ? AppColors.green : AppColors.red,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildStatTile('Seviye', company.level.toString(), Icons.trending_up)),
              SizedBox(width: 10.w),
              Expanded(child: _buildStatTile('Arac', '${company.currentVehicleCount}/${company.maxVehicleCount}', Icons.local_shipping)),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(child: _buildStatTile('Yakit', '${company.currentFuel}/${company.fuelCapacity}', Icons.local_gas_station)),
              SizedBox(width: 10.w),
              Expanded(child: _buildStatTile('Yakit Maliyeti', company.fuelCost.toStringAsFixed(1), Icons.payments)),
            ],
          ),
          SizedBox(height: 14.h),
          Text('Yakit doluluk', style: AppTextStyles.body),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: fuelRatio,
              minHeight: 10.h,
              backgroundColor: AppColors.cardBgLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 18.sp),
          SizedBox(height: 8.h),
          Text(label, style: AppTextStyles.body),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(
    LogisticsVehicleModel vehicle,
    LogisticsVehicleTypeModel? vehicleType,
  ) {
    final fuelRatio = vehicle.fuelCapacity == 0
        ? 0.0
        : (vehicle.currentFuel / vehicle.fuelCapacity).clamp(0.0, 1.0);
    final conditionRatio = (vehicle.condition / 100).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              _mapVehicleIcon(vehicleType?.icon),
              color: AppColors.gold,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vehicleType?.name ?? 'Arac',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.cardBgLight,
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        vehicle.status.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '${vehicleType?.type ?? 'TIP YOK'} | ID: ${vehicle.id.substring(0, 8)}',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Kapasite ${vehicle.capacity} | Hiz ${vehicle.speedKmh} km/h | Yakit tuketim ${vehicle.fuelRate}',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Yakit ${vehicle.currentFuel}/${vehicle.fuelCapacity} | Kondisyon ${vehicle.condition}/100',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Kiraya uygun: ${vehicle.isAvailableForRent ? 'Evet' : 'Hayir'} | Kira fiyati: ${_formatMoney(vehicle.rentalPrice)}',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Olusturulma: ${_formatDate(vehicle.createdAt)} | Guncelleme: ${_formatDate(vehicle.updatedAt)}',
                  style: AppTextStyles.body,
                ),
                if (vehicleType != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Alis fiyati: ${_formatMoney(vehicleType.purchasePrice)} | Tip depo yakiti: ${vehicleType.fuelCapacity}',
                    style: AppTextStyles.body,
                  ),
                ],
                SizedBox(height: 10.h),
                _buildProgressLine(
                  label: 'Yakit doluluk',
                  value: fuelRatio,
                  color: AppColors.gold,
                  text: '${(fuelRatio * 100).round()}%',
                ),
                SizedBox(height: 8.h),
                _buildProgressLine(
                  label: 'Kondisyon',
                  value: conditionRatio,
                  color: conditionRatio > 0.5 ? AppColors.green : AppColors.red,
                  text: '${vehicle.condition}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseVehicleCard({
    required BuildContext context,
    required WidgetRef ref,
    required LogisticsCompanyModel company,
    required double playerCash,
  }) {
    final isFleetFull = company.currentVehicleCount >= company.maxVehicleCount;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isFleetFull
              ? null
              : () => _showPurchaseVehicleSheet(
                    context: context,
                    ref: ref,
                    company: company,
                    playerCash: playerCash,
                  ),
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isFleetFull ? AppColors.border : AppColors.borderGold.withValues(alpha: 0.45),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.add_road,
                    color: isFleetFull ? AppColors.textMuted : AppColors.gold,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arac Satin Al',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        isFleetFull
                            ? 'Filo kapasitesi dolu.'
                            : 'Filo sonuna yeni arac eklemek icin listeyi ac.',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isFleetFull ? AppColors.textMuted : AppColors.gold,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String body,
    Widget? footer,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: AppColors.gold, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16.sp)),
                SizedBox(height: 4.h),
                Text(body, style: AppTextStyles.body.copyWith(height: 1.45)),
                if (footer != null) ...[
                  SizedBox(height: 12.h),
                  footer,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleGold.copyWith(fontSize: 16.sp),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.gold),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          message,
          style: TextStyle(color: AppColors.red, fontSize: 14.sp),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return AppDateTime.formatTurkeyDateTime(date);
  }

  Widget _buildProgressLine({
    required String label,
    required double value,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 88.w,
          child: Text(label, style: AppTextStyles.body),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8.h,
              backgroundColor: AppColors.cardBgLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 40.w,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  IconData _mapVehicleIcon(String? iconName) {
    switch (iconName) {
      case 'local_shipping_outlined':
        return Icons.local_shipping_outlined;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'electric_truck':
        return Icons.electric_bolt;
      case 'speed':
        return Icons.speed;
      default:
        return Icons.fire_truck;
    }
  }

  Future<void> _handleConstructionFinished(
    BuildContext context,
    WidgetRef ref,
    String constructionId,
  ) async {
    if (constructionId.isEmpty) return;

    final result = await ref
        .read(logisticsActionProvider)
        .completeConstruction(constructionId);

    if (result['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
      ref.invalidate(logisticsCompanyListStreamProvider);
      ref.invalidate(logisticsVehicleListStreamProvider);
      return;
    }

    if (context.mounted) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: (result['message'] ?? 'Insaat tamamlanamadi.').toString(),
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleFinishWithGold(
    BuildContext context,
    WidgetRef ref,
    String constructionId,
  ) async {
    if (constructionId.isEmpty) return;

    final result = await ref
        .read(logisticsActionProvider)
        .finishConstructionWithGold(constructionId);

    if (result['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
      ref.invalidate(logisticsCompanyListStreamProvider);
      ref.invalidate(logisticsVehicleListStreamProvider);

      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Basarili',
          message: 'Insaat yildiz ile aninda tamamlandi.',
          type: SnackbarType.success,
        );
      }
      return;
    }

    if (context.mounted) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: (result['message'] ?? 'Insaat yildiz ile tamamlanamadi.').toString(),
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _showPurchaseVehicleSheet({
    required BuildContext context,
    required WidgetRef ref,
    required LogisticsCompanyModel company,
    required double playerCash,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final vehicleTypesAsync = ref.watch(logisticsVehicleTypesProvider);

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
              decoration: BoxDecoration(
                color: AppColors.navBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Arac Satin Al', style: AppTextStyles.h2),
                            SizedBox(height: 4.h),
                            Text(
                              'En ucuzdan pahaliya siralandi. Nakit: ${_formatMoney(playerCash)}',
                              style: AppTextStyles.body,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${company.currentVehicleCount}/${company.maxVehicleCount}',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: vehicleTypesAsync.when(
                      data: (vehicleTypes) => ListView.builder(
                        itemCount: vehicleTypes.length,
                        itemBuilder: (context, index) {
                          final type = vehicleTypes[index];
                          return _PurchaseVehicleTypeCard(
                            type: type,
                            canAfford: playerCash >= type.purchasePrice,
                            isFleetFull: company.currentVehicleCount >= company.maxVehicleCount,
                            onPurchase: () async {
                              final result = await ref
                                  .read(logisticsActionProvider)
                                  .purchaseVehicle(
                                    logisticsCompanyId: company.id,
                                    logisticsVehicleTypeId: type.id,
                                  );

                              if (context.mounted && result['success'] == true) {
                                ref.invalidate(playerStreamProvider);
                                ref.invalidate(playerLogisticsCompanyProvider);
                                ref.invalidate(logisticsVehicleListStreamProvider);
                                ref.invalidate(logisticsCompanyListStreamProvider);

                                AppSnackbar.show(
                                  context,
                                  title: 'Basarili',
                                  message: '${type.name} filoya eklendi.',
                                  type: SnackbarType.success,
                                );
                                Navigator.of(context).pop();
                                return;
                              }

                              if (context.mounted) {
                                AppSnackbar.show(
                                  context,
                                  title: 'Hata',
                                  message: (result['message'] ?? 'Arac satin alinamadi.').toString(),
                                  type: SnackbarType.error,
                                );
                              }
                            },
                          );
                        },
                      ),
                      loading: _buildLoading,
                      error: (error, stack) => _buildError('Arac tipleri yuklenemedi.'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ConstructionCountdown extends StatefulWidget {
  final String constructionId;
  final DateTime finishAt;
  final VoidCallback? onFinish;
  final Future<void> Function(String constructionId)? onFinishWithGold;

  const _ConstructionCountdown({
    required this.constructionId,
    required this.finishAt,
    this.onFinish,
    this.onFinishWithGold,
  });

  @override
  State<_ConstructionCountdown> createState() => _ConstructionCountdownState();
}

class _PurchaseVehicleTypeCard extends StatefulWidget {
  final LogisticsVehicleTypeModel type;
  final bool canAfford;
  final bool isFleetFull;
  final Future<void> Function() onPurchase;

  const _PurchaseVehicleTypeCard({
    required this.type,
    required this.canAfford,
    required this.isFleetFull,
    required this.onPurchase,
  });

  @override
  State<_PurchaseVehicleTypeCard> createState() => _PurchaseVehicleTypeCardState();
}

class _PurchaseVehicleTypeCardState extends State<_PurchaseVehicleTypeCard> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isFleetFull || !widget.canAfford || _isSubmitting;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              _mapVehicleIcon(widget.type.icon),
              color: AppColors.gold,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.type.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  widget.type.type,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Kapasite ${widget.type.capacity} | Hiz ${widget.type.speedKmh} km/h | Yakit ${widget.type.fuelCapacity}',
                  style: AppTextStyles.body,
                ),
                if (widget.type.description.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(widget.type.description, style: AppTextStyles.body),
                ],
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Text(
                      _formatStaticMoney(widget.type.purchasePrice),
                      style: TextStyle(
                        color: widget.canAfford ? AppColors.green : AppColors.red,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34.h,
                      child: ElevatedButton(
                        onPressed: disabled
                            ? null
                            : () async {
                                setState(() => _isSubmitting = true);
                                try {
                                  await widget.onPurchase();
                                } finally {
                                  if (mounted) {
                                    setState(() => _isSubmitting = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.15),
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 14.w,
                                height: 14.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                widget.isFleetFull
                                    ? 'Dolu'
                                    : (widget.canAfford ? 'Satin Al' : 'Nakit Yetmez'),
                                style: TextStyle(
                                  color: disabled && !widget.isFleetFull && !widget.canAfford
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _mapVehicleIcon(String? iconName) {
    switch (iconName) {
      case 'local_shipping_outlined':
        return Icons.local_shipping_outlined;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'electric_truck':
        return Icons.electric_bolt;
      case 'speed':
        return Icons.speed;
      default:
        return Icons.fire_truck;
    }
  }

  String _formatStaticMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _ConstructionCountdownState extends State<_ConstructionCountdown> {
  late Duration _remaining;
  bool _finishTriggered = false;
  bool _isFinishingWithGold = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.finishAt.difference(DateTime.now());
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    if (!mounted) return;

    if (_remaining.inSeconds <= 0) {
      _notifyFinishedOnce();
      return;
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _remaining = widget.finishAt.difference(DateTime.now());
      });

      if (_remaining.inSeconds <= 0) {
        _notifyFinishedOnce();
        return;
      }

      _scheduleNextTick();
    });
  }

  void _notifyFinishedOnce() {
    if (_finishTriggered) return;
    _finishTriggered = true;
    widget.onFinish?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _remaining.inSeconds <= 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDone ? AppColors.green : AppColors.borderGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.timer_outlined,
                  color: isDone ? AppColors.green : AppColors.gold,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    isDone ? 'Insaat tamamlanmaya hazir' : 'Kalan sure: ${_formatRemaining(_remaining)}',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isDone) ...[
            SizedBox(width: 10.w),
            _buildFinishWithGoldButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildFinishWithGoldButton() {
    final stars = _calculateRequiredStars(_remaining);

    return SizedBox(
      height: 34.h,
      child: ElevatedButton(
        onPressed: _isFinishingWithGold || stars <= 0
            ? null
            : () async {
                setState(() => _isFinishingWithGold = true);
                try {
                  await widget.onFinishWithGold?.call(widget.constructionId);
                } finally {
                  if (mounted) {
                    setState(() => _isFinishingWithGold = false);
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.2),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: _isFinishingWithGold
            ? SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.black, size: 14.sp),
                  SizedBox(width: 4.w),
                  Text(
                    '$stars yildiz ile bitir',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatRemaining(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  int _calculateRequiredStars(Duration duration) {
    if (duration.inSeconds <= 0) return 0;
    return ((duration.inMinutes + 9) ~/ 10).clamp(1, 999999);
  }
}

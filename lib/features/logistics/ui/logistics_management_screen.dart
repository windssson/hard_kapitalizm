import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
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
            const SecondaryTopBar(title: 'Lojistik Yönetimi'),
            Expanded(
              child: companyAsync.when(
                data: (company) => playerAsync.when(
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
                        error: (error, stack) => _buildError('İnşaat durumu okunamadı.'),
                      ),
                      loading: _buildLoading,
                      error: (error, stack) => _buildError('Araçlar yüklenemedi.'),
                    ),
                    loading: _buildLoading,
                    error: (error, stack) => _buildError('Araç tipleri yüklenemedi.'),
                  ),
                  loading: _buildLoading,
                  error: (error, stack) => _buildError('Oyuncu verisi yüklenemedi.'),
                ),
                loading: _buildLoading,
                error: (error, stack) => _buildError('Firma verisi yüklenemedi.'),
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
    if (company == null && construction == null) {
      return _buildNoCompanyState(context);
    }

    final vehicleTypeMap = {for (final t in vehicleTypes) t.id: t};
    final constructionParams = construction?['params'] as Map<String, dynamic>?;
    final finishAt = construction?['finish_at'] != null ? DateTime.tryParse(construction!['finish_at'].toString()) : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 80.h),
      children: [
        if (company != null) ...[
          _buildCompanyCard(context, company),
          SizedBox(height: 24.h),
          _buildSectionHeader('FİLO YÖNETİMİ', '${vehicles.length} Araç'),
          SizedBox(height: 12.h),
          if (vehicles.isEmpty)
            _buildEmptyFleetCard()
          else
            ...vehicles.map((v) => _buildVehicleCard(context, ref, v, vehicleTypeMap[v.logisticsVehicleTypeId])),
          _buildPurchaseVehicleEntry(context, ref, company, playerCash),
        ],
        if (construction != null) ...[
          if (company != null) SizedBox(height: 24.h),
          _buildSectionHeader('KURULUM DEVAM EDİYOR', 'İnşaat'),
          SizedBox(height: 12.h),
          _buildConstructionCard(context, ref, construction, constructionParams, finishAt),
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
            Icon(Icons.local_shipping_outlined, color: AppColors.gold, size: 60.sp),
            SizedBox(height: 20.h),
            Text('Lojistik Ağınızı Kurun', style: AppTextStyles.h2, textAlign: TextAlign.center),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
              ),
              child: Text('FİRMAYI KUR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(BuildContext context, LogisticsCompanyModel company) {
    final fuelRatio = company.fuelCapacity == 0 ? 0.0 : (company.currentFuel / company.fuelCapacity).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))],
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
                  gradient: LinearGradient(colors: [AppColors.cardBgLight, AppColors.cardBg], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.business_center, color: AppColors.gold, size: 30.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company.name, style: AppTextStyles.h1.copyWith(fontSize: 20.sp)),
                    Text('Global Lojistik Merkezi • Seviye ${company.level}', style: AppTextStyles.body),
                  ],
                ),
              ),
              _buildStatusChip(company.isActive),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(child: _buildStatTile('FİLO DURUMU', '${company.currentVehicleCount}/${company.maxVehicleCount}', Icons.local_shipping_rounded)),
              SizedBox(width: 12.w),
              Expanded(child: _buildStatTile('MERKEZ YAKIT', '${company.currentFuel} L', Icons.gas_meter_rounded)),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MERKEZ YAKIT REZERVİ', style: AppTextStyles.titleGold.copyWith(fontSize: 11.sp)),
              Text('%${(fuelRatio * 100).toInt()}', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.sp)),
            ],
          ),
          SizedBox(height: 8.h),
          _buildPremiumProgressBar(fuelRatio, AppColors.gold),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, WidgetRef ref, LogisticsVehicleModel vehicle, LogisticsVehicleTypeModel? type) {
    final fuelRatio = vehicle.fuelCapacity == 0 ? 0.0 : (vehicle.currentFuel / vehicle.fuelCapacity).clamp(0.0, 1.0);
    final conditionRatio = (vehicle.condition / 100).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6.w, decoration: BoxDecoration(color: _getStatusColor(vehicle.status))),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(color: AppColors.cardBgLight, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
                            child: Icon(_mapVehicleIcon(type?.icon), color: AppColors.gold, size: 22.sp),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type?.name ?? 'Bilinmeyen Araç', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
                                Text('ID: ${vehicle.id.substring(0, 8).toUpperCase()}', style: AppTextStyles.body.copyWith(fontSize: 10.sp)),
                              ],
                            ),
                          ),
                          _buildVehicleStatusBadge(vehicle.status),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          _buildVehicleDetailItem(Icons.speed, '${vehicle.speedKmh} km/s', 'Hız'),
                          _buildVehicleDetailItem(Icons.inventory_2_outlined, '${vehicle.capacity} t', 'Kapasite'),
                          _buildVehicleDetailItem(Icons.local_gas_station_outlined, '${vehicle.fuelRate} L/km', 'Tüketim'),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildMiniProgress('YAKIT', fuelRatio, fuelRatio < 0.2 ? AppColors.red : AppColors.gold, Icons.bolt),
                      SizedBox(height: 10.h),
                      _buildMiniProgress('KONDİSYON', conditionRatio, conditionRatio < 0.3 ? AppColors.red : AppColors.green, Icons.handyman_outlined),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          _buildCompactActionBtn(Icons.local_gas_station, 'DOLDUR', () => _handleRefuelAction(context, ref, vehicle), fuelRatio < 0.95),
                          SizedBox(width: 8.w),
                          _buildCompactActionBtn(Icons.build, 'BAKIM', () => _handleRepairAction(context, ref, vehicle), conditionRatio < 0.9),
                          SizedBox(width: 8.w),
                          _buildCompactActionBtn(vehicle.isAvailableForRent ? Icons.no_meeting_room : Icons.vpn_key, vehicle.isAvailableForRent ? 'KAPAT' : 'KİRALA', () => _handleRentalAction(context, ref, vehicle), true),
                          const Spacer(),
                          IconButton(
                            onPressed: vehicle.status == 'on_route' ? null : () => _handleActiveToggle(context, ref, vehicle),
                            icon: Icon(vehicle.status == 'inactive' ? Icons.play_circle_fill : Icons.pause_circle_filled, color: vehicle.status == 'on_route' ? AppColors.textMuted : AppColors.gold, size: 32.sp),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseVehicleEntry(BuildContext context, WidgetRef ref, LogisticsCompanyModel company, double playerCash) {
    final isFull = company.currentVehicleCount >= company.maxVehicleCount;
    return InkWell(
      onTap: isFull ? null : () => _showPurchaseVehicleSheet(context: context, ref: ref, company: company, playerCash: playerCash),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBgLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isFull ? AppColors.border : AppColors.gold.withValues(alpha: 0.4), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: isFull ? AppColors.textMuted : AppColors.gold),
            SizedBox(width: 12.w),
            Text(isFull ? 'FİLO KAPASİTESİ DOLU' : 'YENİ ARAÇ SATIN AL', style: TextStyle(color: isFull ? AppColors.textMuted : AppColors.gold, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.chevron_right, color: isFull ? AppColors.textMuted : AppColors.gold),
          ],
        ),
      ),
    );
  }

  Widget _buildConstructionCard(BuildContext context, WidgetRef ref, Map<String, dynamic> construction, Map<String, dynamic>? params, DateTime? finishAt) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3))),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.construction, color: AppColors.gold, size: 30.sp),
              SizedBox(width: 12.w),
              Expanded(child: Text(params?['name'] ?? 'Lojistik Firması', style: AppTextStyles.h2)),
            ],
          ),
          SizedBox(height: 16.h),
          if (finishAt != null)
            _ConstructionCountdown(
              constructionId: construction['id'].toString(),
              finishAt: finishAt,
              onFinish: () => _handleConstructionFinished(context, ref, construction['id'].toString()),
              onFinishWithGold: (id) => _handleFinishWithGold(context, ref, id),
            ),
        ],
      ),
    );
  }

  // --- Yardımcı Widgetlar ---
  Widget _buildSectionHeader(String title, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleGold),
        Text(count, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyFleetCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(color: AppColors.cardBgLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16.r)),
      child: Text('Henüz bir aracınız yok. İlk aracınızı satın alarak başlayın.', style: AppTextStyles.body, textAlign: TextAlign.center),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: AppColors.cardBgLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: AppColors.gold, size: 14.sp), SizedBox(width: 6.w), Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp, fontWeight: FontWeight.bold))]),
          SizedBox(height: 4.h),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildPremiumProgressBar(double ratio, Color color) {
    return Stack(
      children: [
        Container(height: 10.h, width: double.infinity, decoration: BoxDecoration(color: AppColors.cardBgLight, borderRadius: BorderRadius.circular(5.r))),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 10.h,
          width: 320.w * ratio, // Yaklaşık genişlik
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]), borderRadius: BorderRadius.circular(5.r), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)]),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isActive) {
    final color = isActive ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r), border: Border.all(color: color, width: 0.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6.w, height: 6.w, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 4)])),
          SizedBox(width: 6.w),
          Text(isActive ? 'AKTİF' : 'PASİF', style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildVehicleStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(_getStatusLabel(status), style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return AppColors.green;
      case 'on_route': return AppColors.blue;
      case 'repairing': return AppColors.gold;
      case 'inactive': return AppColors.textMuted;
      default: return AppColors.red;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active': return 'HAZIR';
      case 'on_route': return 'YOLDA';
      case 'repairing': return 'BAKIMDA';
      case 'inactive': return 'PASİF';
      default: return status.toUpperCase();
    }
  }

  Widget _buildVehicleDetailItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 14.sp),
          SizedBox(height: 4.h),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(String label, double value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Icon(icon, color: AppColors.textMuted, size: 10.sp), SizedBox(width: 4.w), Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp, fontWeight: FontWeight.bold))]),
            Text('%${(value * 100).toInt()}', style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 4.h),
        _buildPremiumProgressBar(value, color),
      ],
    );
  }

  Widget _buildCompactActionBtn(IconData icon, String label, VoidCallback onTap, bool active) {
    return InkWell(
      onTap: active ? onTap : null,
      borderRadius: BorderRadius.circular(8.r),
      child: Opacity(
        opacity: active ? 1.0 : 0.4,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          decoration: BoxDecoration(color: AppColors.cardBgLight, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: AppColors.border)),
          child: Row(children: [Icon(icon, color: AppColors.gold, size: 12.sp), SizedBox(width: 4.w), Text(label, style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold))]),
        ),
      ),
    );
  }

  // --- Handlers & Logic ---
  IconData _mapVehicleIcon(String? icon) {
    switch (icon) {
      case 'local_shipping': return Icons.local_shipping;
      case 'electric_truck': return Icons.electric_bolt;
      default: return Icons.local_shipping_outlined;
    }
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator(color: AppColors.gold));
  Widget _buildError(String m) => Center(child: Text(m, style: TextStyle(color: AppColors.red)));

  Future<void> _handleRefuelAction(BuildContext context, WidgetRef ref, LogisticsVehicleModel v) async {
    final res = await ref.read(logisticsActionProvider).refuelVehicle(v.id);
    _handleOpResult(context, ref, res, 'Yakıt ikmali yapıldı.');
  }

  Future<void> _handleRepairAction(BuildContext context, WidgetRef ref, LogisticsVehicleModel v) async {
    final res = await ref.read(logisticsActionProvider).repairVehicle(v.id);
    _handleOpResult(context, ref, res, 'Bakım tamamlandı.');
  }

  Future<void> _handleActiveToggle(BuildContext context, WidgetRef ref, LogisticsVehicleModel v) async {
    final res = await ref.read(logisticsActionProvider).setVehicleActive(vehicleId: v.id, isActive: v.status == 'inactive');
    _handleOpResult(context, ref, res, v.status == 'inactive' ? 'Araç aktif edildi.' : 'Araç pasife alındı.');
  }

  void _handleOpResult(BuildContext context, WidgetRef ref, Map<String, dynamic> res, String msg) {
    if (res['success'] == true) {
      ref.invalidate(logisticsVehicleListStreamProvider);
      ref.invalidate(playerLogisticsCompanyProvider);
      AppSnackbar.show(context, title: 'Başarılı', message: msg, type: SnackbarType.success);
    } else {
      AppSnackbar.show(context, title: 'Hata', message: res['message'] ?? 'İşlem başarısız.', type: SnackbarType.error);
    }
  }

  Future<void> _handleRentalAction(BuildContext context, WidgetRef ref, LogisticsVehicleModel v) async {
    if (v.isAvailableForRent) {
      final res = await ref.read(logisticsActionProvider).setVehicleRental(vehicleId: v.id, isAvailableForRent: false, rentalPrice: 0);
      _handleOpResult(context, ref, res, 'Kiralama kapatıldı.');
    } else {
      final controller = TextEditingController();
      final price = await showDialog<double>(context: context, builder: (c) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Kira Fiyatı Belirle', style: AppTextStyles.h2),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Günlük kira bedeli')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')), ElevatedButton(onPressed: () => Navigator.pop(c, double.tryParse(controller.text)), child: const Text('Tamam'))],
      ));
      if (price != null) {
        final res = await ref.read(logisticsActionProvider).setVehicleRental(vehicleId: v.id, isAvailableForRent: true, rentalPrice: price);
        _handleOpResult(context, ref, res, 'Araç kiraya açıldı.');
      }
    }
  }

  Future<void> _handleConstructionFinished(BuildContext context, WidgetRef ref, String id) async {
    final res = await ref.read(logisticsActionProvider).completeConstruction(id);
    if (res['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
    }
  }

  Future<void> _handleFinishWithGold(BuildContext context, WidgetRef ref, String id) async {
    final res = await ref.read(logisticsActionProvider).finishConstructionWithGold(id);
    if (res['success'] == true) {
      ref.invalidate(playerLogisticsCompanyProvider);
      ref.invalidate(playerLogisticsConstructionProvider);
      AppSnackbar.show(context, title: 'Başarılı', message: 'İnşaat tamamlandı!', type: SnackbarType.success);
    }
  }

  Future<void> _showPurchaseVehicleSheet({required BuildContext context, required WidgetRef ref, required LogisticsCompanyModel company, required double playerCash}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Consumer(builder: (context, ref, _) {
        final typesAsync = ref.watch(logisticsVehicleTypesProvider);
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(color: AppColors.navBg, borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)), border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2))),
          child: Column(
            children: [
              Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 20.h),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Araç Satın Al', style: AppTextStyles.h2), Text('${company.currentVehicleCount}/${company.maxVehicleCount}', style: AppTextStyles.titleGold)]),
              SizedBox(height: 20.h),
              Expanded(child: typesAsync.when(
                data: (types) => ListView.builder(
                  itemCount: types.length,
                  itemBuilder: (c, i) => _PurchaseVehicleTypeCard(
                    type: types[i],
                    canAfford: playerCash >= types[i].purchasePrice,
                    isFleetFull: company.currentVehicleCount >= company.maxVehicleCount,
                    onPurchase: () async {
                      final res = await ref.read(logisticsActionProvider).purchaseVehicle(logisticsCompanyId: company.id, logisticsVehicleTypeId: types[i].id);
                      if (res['success'] == true) {
                        ref.invalidate(playerLogisticsCompanyProvider);
                        ref.invalidate(logisticsVehicleListStreamProvider);
                        Navigator.pop(context);
                        AppSnackbar.show(context, title: 'Hayırlı Olsun!', message: '${types[i].name} filonuza katıldı.', type: SnackbarType.success);
                      }
                    },
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Hata: $e')),
              )),
            ],
          ),
        );
      }),
    );
  }
}

// --- Alt Bileşenler ---

class _ConstructionCountdown extends StatefulWidget {
  final String constructionId;
  final DateTime finishAt;
  final VoidCallback? onFinish;
  final Future<void> Function(String constructionId)? onFinishWithGold;
  const _ConstructionCountdown({required this.constructionId, required this.finishAt, this.onFinish, this.onFinishWithGold});
  @override
  State<_ConstructionCountdown> createState() => _ConstructionCountdownState();
}

class _ConstructionCountdownState extends State<_ConstructionCountdown> {
  late Duration _remaining;
  bool _triggered = false;
  @override
  void initState() { super.initState(); _remaining = widget.finishAt.difference(DateTime.now()); _tick(); }
  void _tick() {
    if (!mounted) return;
    setState(() { _remaining = widget.finishAt.difference(DateTime.now()); });
    if (_remaining.inSeconds <= 0) { if (!_triggered) { _triggered = true; widget.onFinish?.call(); } return; }
    Future.delayed(const Duration(seconds: 1), _tick);
  }
  @override
  Widget build(BuildContext context) {
    final isDone = _remaining.inSeconds <= 0;
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isDone ? 'Tamamlanmaya Hazır' : 'Kalan Süre: ${_formatDur(_remaining)}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (!isDone) InkWell(onTap: () => widget.onFinishWithGold?.call(widget.constructionId), child: Text('Yıldız ile Bitir', style: AppTextStyles.titleGold)),
        ]),
        SizedBox(height: 12.h),
        LinearProgressIndicator(value: 1 - (_remaining.inSeconds / 3600).clamp(0.0, 1.0), backgroundColor: AppColors.cardBgLight, valueColor: const AlwaysStoppedAnimation(AppColors.gold)),
      ],
    );
  }
  String _formatDur(Duration d) => '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _PurchaseVehicleTypeCard extends StatelessWidget {
  final LogisticsVehicleTypeModel type;
  final bool canAfford;
  final bool isFleetFull;
  final VoidCallback onPurchase;
  const _PurchaseVehicleTypeCard({required this.type, required this.canAfford, required this.isFleetFull, required this.onPurchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(children: [
            Container(padding: EdgeInsets.all(10.w), decoration: BoxDecoration(color: AppColors.cardBgLight, borderRadius: BorderRadius.circular(12.r)), child: Icon(Icons.local_shipping, color: AppColors.gold)),
            SizedBox(width: 12.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp)),
              Text(type.type, style: AppTextStyles.body),
            ])),
            Text(_formatMoney(type.purchasePrice), style: TextStyle(color: canAfford ? AppColors.green : AppColors.red, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 12.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _spec(Icons.speed, '${type.speedKmh} km/s'),
            _spec(Icons.inventory, '${type.capacity} t'),
            _spec(Icons.gas_meter, '${type.fuelCapacity} L'),
          ]),
          SizedBox(height: 12.h),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: (canAfford && !isFleetFull) ? onPurchase : null,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, disabledBackgroundColor: AppColors.border),
            child: Text(isFleetFull ? 'FİLO DOLU' : (canAfford ? 'SATIN AL' : 'NAKİT YETERSİZ'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }
  Widget _spec(IconData i, String v) => Row(children: [Icon(i, size: 12.sp, color: AppColors.textMuted), SizedBox(width: 4.w), Text(v, style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp))]);
  String _formatMoney(double a) => a >= 1000000 ? '${(a/1000000).toStringAsFixed(1)}M' : (a >= 1000 ? '${(a/1000).toStringAsFixed(1)}K' : a.toStringAsFixed(0));
}

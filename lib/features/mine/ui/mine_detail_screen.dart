import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';

class MineDetailScreen extends ConsumerStatefulWidget {
  final String mineId;

  const MineDetailScreen({super.key, required this.mineId});

  @override
  ConsumerState<MineDetailScreen> createState() => _MineDetailScreenState();
}

class _MineDetailScreenState extends ConsumerState<MineDetailScreen> {
  @override
  void initState() {
    super.initState();
    _refreshOnEntry();
  }

  void _refreshOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(mineDetailProvider(widget.mineId));
      ref.read(mineDetailProvider(widget.mineId).future);
    });
  }

  String _fmt(dynamic value) {
    if (value == null) return '0';
    double v = double.parse(value.toString());
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  int _calculateUsedCapacity(List<MineProductionInventoryModel> inventories) {
    var total = 0;
    for (final inventory in inventories) {
      total += inventory.quantity;
    }
    return total;
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(mineDetailProvider(widget.mineId));

    return Scaffold(
      backgroundColor: Colors.transparent, // ZORUNLU
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Maden Yönetimi'), // ZORUNLU ÜST MENÜ
            Expanded(
              child: detailAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      error.toString(),
                      style: AppTextStyles.body.copyWith(color: AppColors.red, fontSize: 13.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (detail) => RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.cardBg,
                  onRefresh: () async {
                    ref.invalidate(mineDetailProvider(widget.mineId));
                    await ref.read(mineDetailProvider(widget.mineId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _MineHeroCard(detail: detail),
                      SizedBox(height: 16.h),
                      _ProductionStatusCard(detail: detail),
                      SizedBox(height: 16.h),
                      _StockCapacityCard(
                        detail: detail,
                        usedCapacity: _calculateUsedCapacity(detail.outputInventories),
                        onTransferRequested: (inv) => _startInventoryToWarehouseFlow(context, ref, detail, inv),
                        fmt: _fmt,
                      ),
                      SizedBox(height: 16.h),
                      _MineActionsCard(
                        detail: detail,
                        usedCapacity: _calculateUsedCapacity(detail.outputInventories),
                        onTransferRequested: () {
                          if (detail.outputInventories.isNotEmpty) {
                            _startInventoryToWarehouseFlow(context, ref, detail, detail.outputInventories.first);
                          }
                        },
                        onChangeProduct: () => _showProductDialog(context, ref, detail),
                        onToggleActive: () => _toggleMineActive(context, ref, detail),
                      ),
                      SizedBox(height: 16.h),
                      _PerformanceSummaryCard(detail: detail, fmt: _fmt),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  İŞ MANTIĞI METOTLARI
  // ════════════════════════════════════════════════════════════

  Future<void> _showProductDialog(BuildContext context, WidgetRef ref, MineDetailModel detail) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref.read(mineActionProvider).getSelectableProducts(typeId: detail.mineType.id);
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, title: 'Hata', message: e.toString(), type: SnackbarType.error);
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kaynak Seç', style: AppTextStyles.h2),
            SizedBox(height: 16.h),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Text('Bu maden türü için uygun kaynak bulunamadı.',
                          style: AppTextStyles.body, textAlign: TextAlign.center))
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, b) => SizedBox(height: 10.h),
                      itemBuilder: (_, index) {
                        final selectableProduct = products[index];
                        final product = selectableProduct.product;
                        return ListTile(
                          tileColor: AppColors.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          leading: SizedBox(
                            width: 44.w,
                            height: 44.w,
                            child: CachedAssetImage(fileName: product.urunIconu, fit: BoxFit.contain),
                          ),
                          title: Text(product.urunAdi, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text('Kalite: ', style: AppTextStyles.body.copyWith(fontSize: 11.sp)),
                                  _QualityIndicator(quality: selectableProduct.maxQualityLevel, maxQuality: 5, size: 12.sp),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text('Üretim: ${product.uretimAdedi}/sa', style: AppTextStyles.body.copyWith(fontSize: 11.sp)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Icon(Icons.chevron_right, color: AppColors.gold, size: 20.sp),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _selectMineProduct(context, ref, detail, selectableProduct);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMineProduct(BuildContext context, WidgetRef ref, MineDetailModel detail, SelectableProductionProductModel selectableProduct) async {
    final product = selectableProduct.product;
    final result = await ref.read(mineActionProvider).setMineProduct(mineId: detail.mine.id, productId: product.id);
    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(mineDetailProvider(detail.mine.id));
      await ref.read(mineDetailProvider(detail.mine.id).future);
      if (!context.mounted) return;
      AppSnackbar.show(context, title: 'Başarılı', message: 'Kaynak başarıyla seçildi.', type: SnackbarType.success);
      return;
    }
    AppSnackbar.show(context, title: 'Hata', message: result['message'] ?? 'Kaynak seçilemedi.', type: SnackbarType.error);
  }

  Future<void> _toggleMineActive(BuildContext context, WidgetRef ref, MineDetailModel detail) async {
    final result = await ref.read(mineActionProvider).setMineActive(mineId: detail.mine.id, isActive: !detail.mine.isActive);
    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(mineDetailProvider(detail.mine.id));
      await ref.read(mineDetailProvider(detail.mine.id).future);
      if (!context.mounted) return;
      return;
    }
    AppSnackbar.show(context, title: 'Hata', message: result['message'] ?? 'Durum güncellenemedi.', type: SnackbarType.error);
  }

  Future<void> _startInventoryToWarehouseFlow(BuildContext context, WidgetRef ref, MineDetailModel detail, MineProductionInventoryModel inventory) async {
    final warehouses = await ref.read(mineActionProvider).getWarehousesForProductionLogistics(productionCityId: detail.mine.cityId);
    if (!context.mounted) return;
    if (warehouses.isEmpty) {
      AppSnackbar.show(context, title: 'Bilgi', message: 'Bu şehirde aktif depon yok.', type: SnackbarType.info);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
        child: ListView(
          children: [
            Text('Hedef Depo Seç', style: AppTextStyles.h2),
            SizedBox(height: 16.h),
            ...warehouses.map((warehouse) {
              final warehouseId = warehouse.id;
              final sameCity = warehouse.isSameCity;
              return Container(
                margin: EdgeInsets.only(bottom: 10.h),
                child: ListTile(
                  tileColor: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  title: Text(warehouse.name, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text('${warehouse.cityName} | ${sameCity ? 'Anlık Transfer' : 'Lojistik Transfer'}', style: AppTextStyles.body.copyWith(fontSize: 11.sp)),
                  trailing: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20.sp),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showQuantityDialog(
                      context: context,
                      maxQuantity: inventory.quantity,
                      title: 'Miktar Girin',
                      subtitle: '${inventory.product?.urunAdi ?? inventory.productId} depoya aktarılacak',
                      onConfirm: (quantity) async {
                        if (sameCity) {
                          final result = await ref.read(mineActionProvider).transferProductionInventoryToWarehouse(
                                productionInventoryId: inventory.id,
                                warehouseId: warehouseId,
                                quantity: quantity,
                              );
                          if (!context.mounted) return;
                          if (result['success'] == true) {
                            ref.invalidate(mineDetailProvider(detail.mine.id));
                            await ref.read(mineDetailProvider(detail.mine.id).future);
                            if (!context.mounted) return;
                            AppSnackbar.show(context, title: 'Başarılı', message: 'Transfer tamamlandı.', type: SnackbarType.success);
                            return;
                          }
                          AppSnackbar.show(context, title: 'Hata', message: result['message'] ?? 'Transfer başarısız oldu.', type: SnackbarType.error);
                          return;
                        }

                        await _startMineLogisticsOutputTransfer(
                          context: context,
                          ref: ref,
                          detail: detail,
                          inventory: inventory,
                          warehouseId: warehouseId,
                          quantity: quantity,
                        );
                      },
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _startMineLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required MineDetailModel detail,
    required MineProductionInventoryModel inventory,
    required String warehouseId,
    required int quantity,
  }) async {
    List<ProductionLogisticsVehicleOption> options;
    try {
      options = await ref.read(mineActionProvider).getProductionOutputTransferVehicleOptions(
            productionInventoryId: inventory.id,
            buyerWarehouseId: warehouseId,
            quantity: quantity,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(context, title: 'Hata', message: e.toString().replaceFirst('Exception: ', ''), type: SnackbarType.error);
      return;
    }
    if (!context.mounted) return;
    if (options.isEmpty) {
      AppSnackbar.show(context, title: 'Bilgi', message: 'Uygun araç bulunamadı.', type: SnackbarType.info);
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: 'Maden Lojistiği',
      subtitle: '$quantity adet output için araç seçin',
      options: options,
      onSelected: (vehicleId) async {
        final result = await ref.read(mineActionProvider).startProductionToWarehouseTransfer(
              productionInventoryId: inventory.id,
              buyerWarehouseId: warehouseId,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          ref.invalidate(mineDetailProvider(detail.mine.id));
          await ref.read(mineDetailProvider(detail.mine.id).future);
          if (!context.mounted) return;
          AppSnackbar.show(context, title: 'Başarılı', message: 'Araç yola çıktı.', type: SnackbarType.success);
          return;
        }
        AppSnackbar.show(context, title: 'Hata', message: result.message.isNotEmpty ? result.message : 'Başlatılamadı.', type: SnackbarType.error);
      },
    );
  }

  void _showProductionVehicleOptionsSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<ProductionLogisticsVehicleOption> options,
    required Future<void> Function(String? vehicleId) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h2),
            SizedBox(height: 6.h),
            Text(subtitle, style: AppTextStyles.body),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, b) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final color = option.canSelect ? AppColors.green : AppColors.red;
                  return InkWell(
                    onTap: option.canSelect
                        ? () async {
                            Navigator.pop(sheetContext);
                            await onSelected(option.vehicleId);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: option.canSelect ? AppColors.border : AppColors.red.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: color, size: 18.sp),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(option.vehicleName, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                              ),
                              Text(option.isRental ? 'Kiralık' : 'Özmal', style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Kapasite: ${option.capacity} | Mesafe: ${option.distanceKm.toStringAsFixed(0)} km | Süre: ${_formatTransferDuration(option.estimatedDurationSeconds)}',
                            style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Yakıt: ${option.fuelNeeded.toStringAsFixed(0)} | Kondisyon: ${option.conditionNeeded.toStringAsFixed(0)} | Kira: ${option.rentalCost.toStringAsFixed(0)}',
                            style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                          ),
                          if (!option.canSelect && option.disabledReason != null) ...[
                            SizedBox(height: 6.h),
                            Text(option.disabledReason!, style: AppTextStyles.body.copyWith(color: AppColors.red, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTransferDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }

  Future<void> _showQuantityDialog({
    required BuildContext context,
    required int maxQuantity,
    required String title,
    required String subtitle,
    required Future<void> Function(int quantity) onConfirm,
  }) async {
    final controller = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(title, style: AppTextStyles.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle, style: AppTextStyles.body),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Miktar (Maks: ${_fmt(maxQuantity)})',
                labelStyle: AppTextStyles.body.copyWith(color: AppColors.gold),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('İptal', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () async {
              final quantity = int.tryParse(controller.text) ?? 0;
              if (quantity <= 0 || quantity > maxQuantity) {
                AppSnackbar.show(context, title: 'Hata', message: 'Geçersiz miktar!', type: SnackbarType.error);
                return;
              }
              Navigator.pop(dialogContext);
              await onConfirm(quantity);
            },
            child: Text('Onayla', style: AppTextStyles.body.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  WIDGETS
// ════════════════════════════════════════════════════════════

class _MineHeroCard extends StatelessWidget {
  final MineDetailModel detail;

  const _MineHeroCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold), // ZORUNLU KART STANDARDI
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
            ),
            child: CachedAssetImage(fileName: detail.mineType.icon, fit: BoxFit.contain), // ZORUNLU GÖRSEL STANDARDI
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.mine.name,
                  style: AppTextStyles.h2, // ZORUNLU TIPOGRAFİ STANDARDI
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                Text(
                  '${detail.mineType.name} • ${detail.cityName}',
                  style: AppTextStyles.body, // ZORUNLU TIPOGRAFİ STANDARDI
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _StatusBadge(text: 'Seviye ${detail.mine.level}', color: AppColors.blue), // ZORUNLU RENK STANDARDI
                    SizedBox(width: 8.w),
                    _StatusBadge(
                      text: detail.mine.isActive ? 'AKTİF' : 'PASİF',
                      color: detail.mine.isActive ? AppColors.green : AppColors.red, // ZORUNLU RENK STANDARDI
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
}

class _ProductionStatusCard extends StatelessWidget {
  final MineDetailModel detail;

  const _ProductionStatusCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final product = detail.product;
    final hasProduct = product != null;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Üretim Durumu', style: AppTextStyles.titleGold),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                ),
                child: hasProduct
                    ? CachedAssetImage(fileName: product.urunIconu, fit: BoxFit.contain)
                    : Icon(Icons.help_outline, color: AppColors.textMuted, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasProduct ? product.urunAdi : 'Ürün Seçilmedi',
                      style: AppTextStyles.body.copyWith(
                        color: hasProduct ? AppColors.textPrimary : AppColors.textMuted,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Text('Kalite: ', style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                        _QualityIndicator(quality: detail.mine.qualityLevel, maxQuality: 5, size: 14.sp),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Üretim Hızı', style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                  SizedBox(height: 4.h),
                  Text(
                    hasProduct ? '${product.uretimAdedi} / sa' : '- / sa',
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Verim Çarpanı', style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                  SizedBox(height: 4.h),
                  Text(
                    'x${detail.mine.boostMultiplier.toStringAsFixed(1)}',
                    style: AppTextStyles.body.copyWith(color: AppColors.gold, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockCapacityCard extends StatelessWidget {
  final MineDetailModel detail;
  final int usedCapacity;
  final Function(MineProductionInventoryModel) onTransferRequested;
  final String Function(dynamic) fmt;

  const _StockCapacityCard({
    required this.detail,
    required this.usedCapacity,
    required this.onTransferRequested,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final capacity = detail.mine.outputCapacity;
    final ratio = capacity > 0 ? (usedCapacity / capacity).clamp(0.0, 1.0) : 0.0;
    final isFull = capacity > 0 && usedCapacity >= capacity;
    final isWarning = ratio >= 0.85 && !isFull;
    
    double avgCost = 0;
    if (detail.outputInventories.isNotEmpty) {
      double totalCost = 0;
      int totalQty = 0;
      for (final inv in detail.outputInventories) {
        totalCost += (inv.cost * inv.quantity);
        totalQty += inv.quantity;
      }
      if (totalQty > 0) avgCost = totalCost / totalQty;
    }

    int pendingQty = 0;
    for (final inv in detail.outputInventories) {
      pendingQty += inv.pendingQuantity.toInt();
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Çıkan Ürün Stoğu', style: AppTextStyles.titleGold),
              if (isWarning)
                Text(
                  'Kapasite dolmak üzere',
                  style: AppTextStyles.body.copyWith(color: AppColors.goldDark, fontSize: 11.sp, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt(usedCapacity),
                style: AppTextStyles.statValue.copyWith(color: isFull ? AppColors.red : AppColors.textPrimary, fontSize: 24.sp),
              ),
              Text(
                ' / ${fmt(capacity)}',
                style: AppTextStyles.body.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '%${(ratio * 100).toStringAsFixed(0)}',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Stack(
              children: [
                Container(height: 12.h, width: double.infinity, color: AppColors.cardBgLight),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: isFull ? AppColors.red : AppColors.gold,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bekleyen', style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                  SizedBox(height: 4.h),
                  Text(fmt(pendingQty), style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Ortalama Maliyet', style: AppTextStyles.body.copyWith(fontSize: 12.sp)),
                  SizedBox(height: 4.h),
                  Text('${avgCost.toStringAsFixed(2)}₺', style: AppTextStyles.body.copyWith(color: AppColors.red, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          if (detail.outputInventories.isNotEmpty) ...[
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.local_shipping_rounded, size: 16.sp, color: Colors.black),
                label: Text('Tümünü Depoya Aktar', style: AppTextStyles.body.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  elevation: 0,
                ),
                onPressed: () => onTransferRequested(detail.outputInventories.first),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _MineActionsCard extends StatelessWidget {
  final MineDetailModel detail;
  final int usedCapacity;
  final VoidCallback onTransferRequested;
  final VoidCallback onChangeProduct;
  final VoidCallback onToggleActive;

  const _MineActionsCard({
    required this.detail,
    required this.usedCapacity,
    required this.onTransferRequested,
    required this.onChangeProduct,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final hasProduct = detail.product != null;
    final hasStock = usedCapacity > 0;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hızlı Aksiyonlar', style: AppTextStyles.titleGold),
          SizedBox(height: 16.h),
          if (hasStock)
            Container(
              margin: EdgeInsets.only(bottom: 16.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.goldDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.goldDark, size: 18.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Ürün değiştirmek için önce mevcut stoğu depoya aktarmalısınız.',
                      style: AppTextStyles.body.copyWith(color: AppColors.goldDark, fontSize: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'Ürünü Değiştir',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.blue,
                  isDisabled: hasStock,
                  onTap: onChangeProduct,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _ActionBtn(
                  label: detail.mine.isActive ? 'Üretimi Durdur' : 'Üretimi Başlat',
                  icon: detail.mine.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: detail.mine.isActive ? AppColors.red : AppColors.green,
                  isDisabled: !hasProduct,
                  onTap: onToggleActive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceSummaryCard extends StatelessWidget {
  final MineDetailModel detail;
  final String Function(dynamic) fmt;

  const _PerformanceSummaryCard({required this.detail, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final capacity = detail.mine.outputCapacity;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: AppColors.textMuted, size: 16.sp),
              SizedBox(width: 8.w),
              Text('Performans Özeti', style: AppTextStyles.titleGold),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactStat('Günlük Üretim', 'Kayıt Bekleniyor'),
              _buildCompactStat('Toplam Kapasite', fmt(capacity)),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactStat('Son Aktarım', 'Henüz Yok'),
              _buildCompactStat('Tahmini Dolma', 'Hesaplanıyor'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body.copyWith(fontSize: 11.sp)),
        SizedBox(height: 4.h),
        Text(value, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _QualityIndicator extends StatelessWidget {
  final int quality;
  final int maxQuality;
  final double size;

  const _QualityIndicator({required this.quality, this.maxQuality = 5, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxQuality, (index) {
        final isActive = index < quality;
        return Icon(
          isActive ? Icons.star_rounded : Icons.star_border_rounded,
          color: isActive ? AppColors.gold : AppColors.textMuted.withValues(alpha: 0.3),
          size: size,
        );
      }),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isDisabled ? AppColors.cardBgLight.withValues(alpha: 0.05) : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: isDisabled ? AppColors.border.withValues(alpha: 0.3) : color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isDisabled ? AppColors.textMuted : color, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: isDisabled ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

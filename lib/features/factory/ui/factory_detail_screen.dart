import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';

class FactoryDetailScreen extends ConsumerWidget {
  final String factoryId;

  const FactoryDetailScreen({super.key, required this.factoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(factoryDetailProvider(factoryId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Fabrika Yonetimi'),
            Expanded(
              child: detailAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      style: TextStyle(color: AppColors.red, fontSize: 13.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (detail) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(factoryDetailProvider(factoryId));
                    await ref.read(factoryDetailProvider(factoryId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 28.h),
                    children: [
                      _buildHero(detail),
                      SizedBox(height: 14.h),
                      _buildOverview(detail),
                      SizedBox(height: 14.h),
                      _buildProductSection(context, ref, detail),
                      SizedBox(height: 18.h),
                      _buildSectionHeader(
                        'Input Akisi',
                        'Birden fazla hammaddeyi depodan cekerek uretimi besle.',
                      ),
                      SizedBox(height: 10.h),
                      _buildInventoryPanel(
                        context: context,
                        ref: ref,
                        detail: detail,
                        title: 'Input Stoklari',
                        caption: 'Maks kapasite: ${detail.factory.inputCapacity}',
                        progressColor: AppColors.blue,
                        progressValue: _inventoryRatio(
                          _calculateUsedCapacity(detail.inputInventories),
                          detail.factory.inputCapacity,
                        ),
                        inventories: detail.inputInventories,
                      ),
                      SizedBox(height: 18.h),
                      _buildSectionHeader(
                        'Output Akisi',
                        'Uretilen stoklari depoya aktar ve kapasiteyi bosalt.',
                      ),
                      SizedBox(height: 10.h),
                      _buildInventoryPanel(
                        context: context,
                        ref: ref,
                        detail: detail,
                        title: 'Output Stoklari',
                        caption: 'Maks kapasite: ${detail.factory.outputCapacity}',
                        progressColor: AppColors.green,
                        progressValue: _inventoryRatio(
                          _calculateUsedCapacity(detail.outputInventories),
                          detail.factory.outputCapacity,
                        ),
                        inventories: detail.outputInventories,
                      ),
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

  Widget _buildHero(FactoryDetailModel detail) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBgLight,
            AppColors.cardBg,
            AppColors.background,
          ],
        ),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 84.w,
                height: 84.w,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                  ),
                ),
                child: CachedAssetImage(
                  fileName: detail.factoryType.icon,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.factory.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${detail.cityName} | ${detail.factoryType.name}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _buildTag('Lv. ${detail.factory.level}', AppColors.gold),
                        _buildTag(
                          detail.factory.isActive ? 'AKTIF URETIM' : 'PASIF URETIM',
                          detail.factory.isActive ? AppColors.green : AppColors.red,
                        ),
                        _buildTag(
                          detail.product == null ? 'URUN SECILMEDI' : 'TEK URUN HATTI',
                          AppColors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(FactoryDetailModel detail) {
    final inputUsed = _calculateUsedCapacity(detail.inputInventories);
    final outputUsed = _calculateUsedCapacity(detail.outputInventories);

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Input Kapasitesi',
            value: '$inputUsed/${detail.factory.inputCapacity}',
            ratio: _inventoryRatio(inputUsed, detail.factory.inputCapacity),
            color: AppColors.blue,
            icon: Icons.south_west,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildMetricCard(
            title: 'Output Kapasitesi',
            value: '$outputUsed/${detail.factory.outputCapacity}',
            ratio: _inventoryRatio(outputUsed, detail.factory.outputCapacity),
            color: AppColors.green,
            icon: Icons.north_east,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildMetricCard(
            title: 'Kalite',
            value: detail.factory.qualityLevel > 0
                ? 'Kalite ${detail.factory.qualityLevel}'
                : 'Hazir Degil',
            ratio: detail.factory.qualityLevel <= 0
                ? 0
                : (detail.factory.qualityLevel / 5).clamp(0.0, 1.0),
            color: AppColors.gold,
            icon: Icons.workspace_premium,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required double ratio,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: color, size: 14.sp),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          _buildProgressBar(
            ratio: ratio,
            color: color,
            label: '%${(ratio * 100).round()}',
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) {
    final product = detail.product;
    final canToggleActive = product != null;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Aktif Urun',
            'Fabrika ayni anda yalnizca tek urun uretir.',
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                width: 54.w,
                height: 54.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: product == null
                    ? Icon(Icons.factory, color: AppColors.textMuted, size: 24.sp)
                    : CachedAssetImage(
                        fileName: product.urunIconu,
                        fit: BoxFit.contain,
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product?.urunAdi ?? 'Henuz urun secilmedi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      product == null
                          ? 'Uretimi baslatmak icin ilk urunu sec.'
                          : 'Kalite ${detail.factory.qualityLevel} | Saatlik uretim: ${product.uretimAdedi}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTag(
                detail.factory.isActive ? 'AKTIF' : 'PASIF',
                detail.factory.isActive ? AppColors.green : AppColors.red,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _buildMiniAction(
                  product == null ? 'Urun Sec' : 'Urun Degistir',
                  AppColors.gold,
                  () => _showProductDialog(context, ref, detail),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildMiniAction(
                  detail.factory.isActive ? 'Pasif Yap' : 'Aktif Et',
                  detail.factory.isActive ? AppColors.red : AppColors.green,
                  () => _toggleFactoryActive(context, ref, detail),
                  enabled: canToggleActive,
                ),
              ),
            ],
          ),
          if (!canToggleActive) ...[
            SizedBox(height: 10.h),
            Text(
              'Fabrikayi aktif etmek icin once uretilecek urunu belirle.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInventoryPanel({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required String title,
    required String caption,
    required Color progressColor,
    required double progressValue,
    required List<FactoryProductionInventoryModel> inventories,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                caption,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _buildProgressBar(
            ratio: progressValue,
            color: progressColor,
            label: '%${(progressValue * 100).round()} dolu',
          ),
          SizedBox(height: 12.h),
          if (inventories.isEmpty)
            _buildEmptyCard(
              detail.product == null
                  ? 'Once urun sec. Secimden sonra gereken input ve output kayitlari burada olusur.'
                  : 'Bu alanda stok kaydi bulunmuyor.',
            )
          else
            ...inventories.map(
              (inv) => _buildInventoryCard(context, ref, detail, inv),
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    FactoryProductionInventoryModel inventory,
  ) {
    final title = inventory.product?.urunAdi.isNotEmpty == true
        ? inventory.product!.urunAdi
        : inventory.productId;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (inventory.product?.urunIconu != null) ...[
                Container(
                  width: 40.w,
                  height: 40.w,
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: CachedAssetImage(
                    fileName: inventory.product!.urunIconu,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTag(
                inventory.isInput ? 'INPUT' : 'OUTPUT',
                inventory.isInput ? AppColors.blue : AppColors.green,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildProgressBar(
            ratio: _inventoryRatio(
              inventory.quantity,
              inventory.isInput
                  ? detail.factory.inputCapacity
                  : detail.factory.outputCapacity,
            ),
            color: inventory.isInput ? AppColors.blue : AppColors.green,
            label:
                'Miktar ${inventory.quantity} | Pending ${inventory.pendingQuantity.toStringAsFixed(1)}',
          ),
          SizedBox(height: 8.h),
          Text(
            'Kalite ${inventory.qualityLevel} | Maliyet ${inventory.cost.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
          ),
          SizedBox(height: 10.h),
          _buildMiniAction(
            inventory.isInput ? 'Depodan Besle' : 'Depoya Aktar',
            inventory.isInput ? AppColors.gold : AppColors.blue,
            () {
              if (inventory.isInput) {
                _startWarehouseToInventoryFlow(context, ref, detail, inventory);
              } else {
                _startInventoryToWarehouseFlow(context, ref, detail, inventory);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref.read(factoryActionProvider).getSelectableProducts(
            typeId: detail.factoryType.id,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString(),
        type: SnackbarType.error,
      );
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Urun Sec',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Text(
                        'Bu fabrika turu icin uygun urun bulunamadi.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (_, index) {
                        final selectableProduct = products[index];
                        final product = selectableProduct.product;
                        return ListTile(
                          tileColor: Colors.white.withValues(alpha: 0.04),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          leading: SizedBox(
                            width: 40.w,
                            height: 40.w,
                            child: CachedAssetImage(
                              fileName: product.urunIconu,
                              fit: BoxFit.contain,
                            ),
                          ),
                          title: Text(
                            product.urunAdi,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Uretilecek kalite: ${selectableProduct.maxQualityLevel} | Saatlik uretim: ${product.uretimAdedi}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.gold,
                          ),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _selectFactoryProduct(
                              context,
                              ref,
                              detail,
                              selectableProduct,
                            );
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

  Future<void> _selectFactoryProduct(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    SelectableProductionProductModel selectableProduct,
  ) async {
    final product = selectableProduct.product;
    final result = await ref.read(factoryActionProvider).setFactoryProduct(
          factoryId: detail.factory.id,
          productId: product.id,
          qualityLevel: selectableProduct.maxQualityLevel,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await ref.refresh(factoryDetailProvider(detail.factory.id).future);
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message:
            '${product.urunAdi} otomatik kalite ${selectableProduct.maxQualityLevel} ile ayarlandi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Urun secilemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _toggleFactoryActive(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) async {
    final result = await ref.read(factoryActionProvider).setFactoryActive(
          factoryId: detail.factory.id,
          isActive: !detail.factory.isActive,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await ref.refresh(factoryDetailProvider(detail.factory.id).future);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Fabrika durumu guncellenemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _startWarehouseToInventoryFlow(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    FactoryProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(factoryActionProvider)
        .getEligibleWarehouseSlotsForInventory(
          inventory: inventory,
          cityId: detail.factory.cityId,
        );

    if (!context.mounted) return;
    if (warehouses.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu input icin uygun depo stogu bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: ListView(
          children: [
            Text(
              'Kaynak Depo Sec',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            ...warehouses.map((warehouse) {
              final slots =
                  (warehouse['warehouse_slots'] as List<dynamic>? ?? const []);
              return Column(
                children: slots.map((slotMap) {
                  final slot = Map<String, dynamic>.from(slotMap as Map);
                  final qty = (slot['quantity'] as num?)?.toInt() ?? 0;
                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    child: ListTile(
                      tileColor: Colors.white.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      title: Text(
                        (warehouse['name'] ?? 'Depo').toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Stok: $qty',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.sp,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showQuantityDialog(
                          context: context,
                          maxQuantity: qty,
                          title: 'Miktar Girin',
                          subtitle:
                              '${inventory.product?.urunAdi ?? inventory.productId} inputu doldurulacak',
                          onConfirm: (quantity) async {
                            final result = await ref
                                .read(factoryActionProvider)
                                .transferWarehouseToProductionInventory(
                                  warehouseSlotId: slot['id'].toString(),
                                  productionInventoryId: inventory.id,
                                  quantity: quantity,
                                );
                            if (!context.mounted) return;
                            if (result['success'] == true) {
                              await ref.refresh(
                                factoryDetailProvider(detail.factory.id).future,
                              );
                              return;
                            }
                            AppSnackbar.show(
                              context,
                              title: 'Hata',
                              message:
                                  result['message'] ?? 'Transfer basarisiz oldu.',
                              type: SnackbarType.error,
                            );
                          },
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _startInventoryToWarehouseFlow(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    FactoryProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(factoryActionProvider)
        .getPlayerWarehousesByCity(detail.factory.cityId);

    if (!context.mounted) return;
    if (warehouses.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu sehirde aktif depon yok.',
        type: SnackbarType.info,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        child: ListView(
          children: [
            Text(
              'Hedef Depo Sec',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            ...warehouses.map((warehouse) {
              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                child: ListTile(
                  tileColor: Colors.white.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  title: Text(
                    (warehouse['name'] ?? 'Depo').toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    (warehouse['city']?['name'] ?? detail.cityName).toString(),
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.sp,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showQuantityDialog(
                      context: context,
                      maxQuantity: inventory.quantity,
                      title: 'Miktar Girin',
                      subtitle:
                          '${inventory.product?.urunAdi ?? inventory.productId} depoya aktarilacak',
                      onConfirm: (quantity) async {
                        final result = await ref
                            .read(factoryActionProvider)
                            .transferProductionInventoryToWarehouse(
                              productionInventoryId: inventory.id,
                              warehouseId: warehouse['id'].toString(),
                              quantity: quantity,
                            );
                        if (!context.mounted) return;
                        if (result['success'] == true) {
                          await ref.refresh(
                            factoryDetailProvider(detail.factory.id).future,
                          );
                          return;
                        }
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message:
                              result['message'] ?? 'Transfer basarisiz oldu.',
                          type: SnackbarType.error,
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
        backgroundColor: AppColors.background,
        title: Text(
          title,
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Miktar (Maks: $maxQuantity)',
                labelStyle: const TextStyle(color: AppColors.gold),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              final quantity = int.tryParse(controller.text) ?? 0;
              if (quantity <= 0 || quantity > maxQuantity) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gecersiz miktar!')),
                );
                return;
              }
              Navigator.pop(dialogContext);
              await onConfirm(quantity);
            },
            child: const Text(
              'Onayla',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar({
    required double ratio,
    required Color color,
    required String label,
  }) {
    return Container(
      height: 16.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.25)),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999.r),
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.55), color],
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMiniAction(
    String label,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 11.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.45)
                : AppColors.border.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled ? color : AppColors.textMuted,
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
      ),
    );
  }

  int _calculateUsedCapacity(List<FactoryProductionInventoryModel> inventories) {
    var total = 0;
    for (final inventory in inventories) {
      total += inventory.quantity;
    }
    return total;
  }

  double _inventoryRatio(int current, int capacity) {
    if (capacity <= 0) return 0.0;
    return (current / capacity).clamp(0.0, 1.0);
  }
}

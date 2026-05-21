import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';

class MineDetailScreen extends ConsumerWidget {
  final String mineId;

  const MineDetailScreen({super.key, required this.mineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(mineDetailProvider(mineId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Maden Yonetimi'),
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
                    ref.invalidate(mineDetailProvider(mineId));
                    await ref.read(mineDetailProvider(mineId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 28.h),
                    children: [
                      _buildHero(detail),
                      SizedBox(height: 14.h),
                      _buildOverview(detail),
                      SizedBox(height: 14.h),
                      _buildProductSection(context, ref, detail),
                      SizedBox(height: 14.h),
                      _buildProductionStatus(detail),
                      SizedBox(height: 18.h),
                      _buildSectionHeader(
                        'Cikis Stoklari',
                        'Cikarilan kaynaklari depoya aktar ve kapasiteyi bosalt.',
                      ),
                      SizedBox(height: 10.h),
                      _buildInventoryPanel(context, ref, detail),
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

  Widget _buildProductionStatus(MineDetailModel detail) {
    final outputUsed = _calculateUsedCapacity(detail.outputInventories);
    final outputCapacity = detail.mine.outputCapacity;
    final isFull = outputCapacity > 0 && outputUsed >= outputCapacity;
    final hasProduct = detail.product != null;
    final isActive = detail.mine.isActive;

    final statusTitle = !hasProduct
        ? 'Kaynak Seçimi Bekleniyor'
        : !isActive
            ? 'Üretim Pasif'
            : isFull
                ? 'Output Kapasitesi Dolu'
                : 'Üretime Hazır';

    final statusMessage = !hasProduct
        ? 'Madenin hangi kaynağı çıkaracağını seçmeden üretim başlamaz.'
        : !isActive
            ? 'Kaynak ayarlı fakat maden pasif durumda. Aktif ederek üretimi başlatabilirsin.'
            : isFull
                ? 'Output stokları dolmuş. Depoya aktarım yapmadan yeni üretim birikmez.'
                : 'Maden aktif ve uygun durumda. Üretim sürecinde output stokları otomatik birikir.';

    final statusColor = !hasProduct
        ? AppColors.gold
        : !isActive
            ? AppColors.red
            : isFull
                ? Colors.orange
                : AppColors.green;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  !hasProduct
                      ? Icons.tune
                      : !isActive
                          ? Icons.pause_circle
                          : isFull
                              ? Icons.inventory
                              : Icons.play_circle,
                  color: statusColor,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Üretim Durumu',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTag(
                hasProduct
                    ? 'Kalite ${detail.mine.qualityLevel}'
                    : 'Kaynak Yok',
                hasProduct ? AppColors.gold : AppColors.textMuted,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            statusMessage,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
              height: 1.35,
            ),
          ),
          if (hasProduct) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatusMetric(
                    'Saatlik Üretim',
                    '${detail.product!.uretimAdedi} adet',
                    AppColors.blue,
                    Icons.schedule,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _buildStatusMetric(
                    'Aktif Ürün',
                    detail.product!.urunAdi,
                    AppColors.gold,
                    Icons.diamond,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14.sp),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(MineDetailModel detail) {
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
      child: Row(
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
              fileName: detail.mineType.icon,
              fit: BoxFit.contain,
              errorWidget: Icon(
                Icons.diamond,
                color: AppColors.gold,
                size: 34.sp,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.mine.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${detail.cityName} | ${detail.mineType.name}',
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
                    _buildTag('Lv. ${detail.mine.level}', AppColors.gold),
                    _buildTag(
                      detail.mine.isActive ? 'AKTIF URETIM' : 'PASIF URETIM',
                      detail.mine.isActive ? AppColors.green : AppColors.red,
                    ),
                    _buildTag(
                      detail.product == null ? 'KAYNAK SECILMEDI' : 'TEK CIKTI HATTI',
                      AppColors.blue,
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

  Widget _buildOverview(MineDetailModel detail) {
    final outputUsed = _calculateUsedCapacity(detail.outputInventories);
    final qualityRatio = detail.mine.qualityLevel <= 0
        ? 0.0
        : (detail.mine.qualityLevel / 5).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Kapasite',
            value: '$outputUsed/${detail.mine.outputCapacity}',
            ratio: _inventoryRatio(outputUsed, detail.mine.outputCapacity),
            color: AppColors.green,
            icon: Icons.inventory_2,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildMetricCard(
            title: 'Kalite',
            value: detail.mine.qualityLevel > 0
                ? 'Seviye ${detail.mine.qualityLevel}'
                : 'Hazır Değil',
            ratio: qualityRatio,
            color: AppColors.gold,
            icon: Icons.workspace_premium,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildMetricCard(
            title: 'Boost',
            value: 'x${detail.mine.boostMultiplier.toStringAsFixed(1)}',
            ratio: (detail.mine.boostMultiplier / 3).clamp(0.0, 1.0),
            color: AppColors.blue,
            icon: Icons.bolt,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg,
            AppColors.cardBgLight.withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 13.sp),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
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
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            height: 4.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.r),
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.6), color],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '%${(ratio * 100).round()}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 8.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
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
            'Cikarilan Kaynak',
            'Maden ayni anda yalnizca tek bir kaynak ture odaklanir.',
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
                    ? Icon(Icons.diamond_outlined,
                        color: AppColors.textMuted, size: 24.sp)
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
                      product?.urunAdi ?? 'Henuz kaynak secilmedi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      product == null
                          ? 'Uretimi baslatmak icin cikti urununu sec.'
                          : 'Kalite ${detail.mine.qualityLevel} | Saatlik uretim: ${product.uretimAdedi}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTag(
                detail.mine.isActive ? 'AKTIF' : 'PASIF',
                detail.mine.isActive ? AppColors.green : AppColors.red,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _buildMiniAction(
                  product == null ? 'Kaynak Sec' : 'Kaynak Degistir',
                  AppColors.gold,
                  () => _showProductDialog(context, ref, detail),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildMiniAction(
                  detail.mine.isActive ? 'Pasif Yap' : 'Aktif Et',
                  detail.mine.isActive ? AppColors.red : AppColors.green,
                  () => _toggleMineActive(context, ref, detail),
                  enabled: canToggleActive,
                ),
              ),
            ],
          ),
          if (!canToggleActive) ...[
            SizedBox(height: 10.h),
            Text(
              'Madeni aktif etmek icin once cikarilacak kaynagi belirle.',
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

  Widget _buildInventoryPanel(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
  ) {
    final inventories = detail.outputInventories;
    final progressValue = _inventoryRatio(
      _calculateUsedCapacity(inventories),
      detail.mine.outputCapacity,
    );

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Çıkış Stokları',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Maks Kapasite: ${detail.mine.outputCapacity}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            height: 6.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressValue,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3.r),
                  gradient: const LinearGradient(
                    colors: [AppColors.green, Colors.tealAccent],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '%${(progressValue * 100).round()} Dolu',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          if (inventories.isEmpty)
            _buildEmptyCard(
              detail.product == null
                  ? 'Önce kaynak seç. Seçimden sonra çıkış stokları burada görünür.'
                  : 'Bu maden için henüz stok kaydı bulunmuyor.',
            )
          else
            ...inventories.map(
              (inventory) => _buildInventoryCard(context, ref, detail, inventory),
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    MineProductionInventoryModel inventory,
  ) {
    final title = inventory.product?.urunAdi.isNotEmpty == true
        ? inventory.product!.urunAdi
        : inventory.productId;
    final ratio = _inventoryRatio(inventory.quantity, detail.mine.outputCapacity);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
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
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: CachedAssetImage(
                    fileName: inventory.product!.urunIconu,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Kalite ${inventory.qualityLevel} | Maliyet ${inventory.cost.toStringAsFixed(2)}₺',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp),
                    ),
                  ],
                ),
              ),
              _buildTag('STOKTA', AppColors.green),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            height: 4.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.r),
                  gradient: const LinearGradient(
                    colors: [AppColors.green, Colors.tealAccent],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Miktar: ${inventory.quantity} adet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (inventory.pendingQuantity > 0)
                Text(
                  'Bekleyen: ${inventory.pendingQuantity.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 10.sp,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: _buildMiniAction(
              'DEPOYA AKTAR',
              AppColors.blue,
              () => _startInventoryToWarehouseFlow(context, ref, detail, inventory),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
  ) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref.read(mineActionProvider).getSelectableProducts(
            typeId: detail.mineType.id,
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
              'Kaynak Sec',
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
                        'Bu maden turu icin uygun kaynak bulunamadi.',
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
                            await _selectMineProduct(
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

  Future<void> _selectMineProduct(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    SelectableProductionProductModel selectableProduct,
  ) async {
    final product = selectableProduct.product;
    final result = await ref.read(mineActionProvider).setMineProduct(
          mineId: detail.mine.id,
          productId: product.id,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await ref.refresh(mineDetailProvider(detail.mine.id).future);
      final message = _buildMineProductSuccessMessage(
        result: result,
        fallbackProductName: product.urunAdi,
        fallbackQualityLevel: selectableProduct.maxQualityLevel,
      );
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: message,
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Kaynak secilemedi.',
      type: SnackbarType.error,
    );
  }

  String _buildMineProductSuccessMessage({
    required Map<String, dynamic> result,
    required String fallbackProductName,
    required int fallbackQualityLevel,
  }) {
    final productName =
        (result['product_name'] ?? fallbackProductName).toString();
    final qualityLevel =
        (result['quality_level'] as num?)?.toInt() ?? fallbackQualityLevel;
    final sameSetting = result['same_setting'] == true;
    final outputInventoryId = (result['output_inventory_id'] ?? '')
        .toString()
        .trim();
    final clearedPendingQuantity =
        (result['cleared_pending_quantity'] as num?)?.toDouble() ?? 0;

    if (sameSetting) {
      return '$productName zaten kalite $qualityLevel olarak ayarli.';
    }

    if (clearedPendingQuantity > 0 && outputInventoryId.isNotEmpty) {
      return '$productName kalite $qualityLevel ile ayarlandi. Bekleyen uretim sifirlandi ve output stogu hazirlandi.';
    }

    if (clearedPendingQuantity > 0) {
      return '$productName kalite $qualityLevel ile ayarlandi. Bekleyen uretim sifirlandi.';
    }

    if (outputInventoryId.isNotEmpty) {
      return '$productName kalite $qualityLevel ile ayarlandi. Output envanteri hazirlandi.';
    }

    return '$productName kalite $qualityLevel ile ayarlandi.';
  }

  Future<void> _toggleMineActive(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
  ) async {
    final result = await ref.read(mineActionProvider).setMineActive(
          mineId: detail.mine.id,
          isActive: !detail.mine.isActive,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await ref.refresh(mineDetailProvider(detail.mine.id).future);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Maden durumu guncellenemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _startInventoryToWarehouseFlow(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    MineProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(mineActionProvider)
        .getPlayerWarehousesByCity(detail.mine.cityId);

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
                            .read(mineActionProvider)
                            .transferProductionInventoryToWarehouse(
                              productionInventoryId: inventory.id,
                              warehouseId: warehouse['id'].toString(),
                              quantity: quantity,
                            );
                        if (!context.mounted) return;
                        if (result['success'] == true) {
                          await ref.refresh(
                            mineDetailProvider(detail.mine.id).future,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12.r),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Ink(
          padding: EdgeInsets.symmetric(vertical: 11.h),
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.35)
                  : AppColors.border.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: enabled ? color : AppColors.textMuted,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
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

  int _calculateUsedCapacity(List<MineProductionInventoryModel> inventories) {
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

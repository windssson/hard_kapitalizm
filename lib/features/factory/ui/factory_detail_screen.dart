import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';

class FactoryDetailScreen extends ConsumerStatefulWidget {
  final String factoryId;

  const FactoryDetailScreen({super.key, required this.factoryId});

  @override
  ConsumerState<FactoryDetailScreen> createState() =>
      _FactoryDetailScreenState();
}

class _FactoryDetailScreenState extends ConsumerState<FactoryDetailScreen> {
  @override
  void initState() {
    super.initState();
    _refreshOnEntry();
  }

  void _refreshOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(factoryDetailProvider(widget.factoryId));
      ref.read(factoryDetailProvider(widget.factoryId).future);
    });
  }

  void _onNavSelected(int index) {
    if (index == 1) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(factoryDetailProvider(widget.factoryId));

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _onNavSelected,
      ),
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
                    ref.invalidate(factoryDetailProvider(widget.factoryId));
                    await ref.read(factoryDetailProvider(widget.factoryId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 28.h),
                    children: [
                      _buildImmersiveHeader(detail),
                      SizedBox(height: 16.h),
                      _buildQuickActions(context, ref, detail),
                      SizedBox(height: 24.h),
                      _buildProductionFlow(context, ref, detail),
                      SizedBox(height: 24.h),
                      _buildMetricsGrid(detail),
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

      Widget _buildImmersiveHeader(FactoryDetailModel detail) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black54,
            AppColors.navBg.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 2.w),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CachedAssetImage(fileName: detail.factoryType.icon, fit: BoxFit.contain),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        detail.factory.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: detail.factory.isActive ? Colors.greenAccent : Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                            color: detail.factory.isActive ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.redAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.textMuted, size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(detail.cityName, style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp, fontWeight: FontWeight.w500)),
                    SizedBox(width: 16.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('Seviye ${detail.factory.level}', style: TextStyle(color: AppColors.gold, fontSize: 10.sp, fontWeight: FontWeight.bold)),
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

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, FactoryDetailModel detail) {
    int outputQty = 0;
    if (detail.outputInventories.isNotEmpty) {
      outputQty = detail.outputInventories.first.quantity;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: detail.factory.isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
          label: detail.factory.isActive ? 'Durdur' : 'Baslat',
          color: detail.factory.isActive ? Colors.redAccent : Colors.greenAccent,
          onTap: detail.product != null ? () => _toggleFactoryActive(context, ref, detail) : null,
        ),
        _buildActionButton(
          icon: Icons.local_shipping_rounded,
          label: 'Depoya Aktar',
          color: Colors.blueAccent,
          onTap: outputQty > 0 ? () => _startInventoryToWarehouseFlow(context, ref, detail, detail.outputInventories.first) : null,
        ),
        _buildActionButton(
          icon: Icons.upgrade_rounded,
          label: 'Yukselt',
          color: AppColors.gold,
          onTap: null, // Placeholder
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
    final isDisabled = onTap == null;
    final displayColor = isDisabled ? Colors.grey : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: 100.w,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: displayColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: displayColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: displayColor, size: 24.sp),
            SizedBox(height: 6.h),
            Text(label, style: TextStyle(color: isDisabled ? Colors.grey : Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionFlow(BuildContext context, WidgetRef ref, FactoryDetailModel detail) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Uretim Akisi', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () => _showProductDialog(context, ref, detail),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: AppColors.gold, size: 14.sp),
                      SizedBox(width: 4.w),
                      Text('Urun Degistir', style: TextStyle(color: AppColors.gold, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          if (detail.product == null)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Text('Lutfen uretim icin bir urun secin.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp)),
              ),
            )
          else
            Row(
              children: [
                // Left side: Inputs
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: detail.inputInventories.isEmpty
                        ? [Text('Girdi Yok', style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp))]
                        : detail.inputInventories.map((inv) {
                            double req = 0;
                            if (detail.product!.hammadde1Id == inv.productId) req = detail.product!.hammadde1Miktar ?? 0;
                            else if (detail.product!.hammadde2Id == inv.productId) req = detail.product!.hammadde2Miktar ?? 0;
                            else if (detail.product!.hammadde3Id == inv.productId) req = detail.product!.hammadde3Miktar ?? 0;
                            
                            double ratio = req > 0 ? (inv.quantity / req) : 0;
                            if (ratio > 1) ratio = 1.0;
                            
                            return _buildFlowItem(
                              icon: inv.product?.urunIconu ?? '',
                              title: inv.product?.urunAdi ?? inv.productId,
                              subtitle: '${inv.quantity} / $req',
                              progress: ratio,
                              onAddTap: () => _startWarehouseToInventoryFlow(context, ref, detail, inv),
                            );
                          }).toList(),
                  ),
                ),
                // Middle: Processing Arrow -> Circular Product -> Arrow
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold.withValues(alpha: 0.5), size: 14.sp),
                      SizedBox(width: 12.w),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64.w,
                            height: 64.w,
                            child: CircularProgressIndicator(
                              value: detail.factory.isActive ? null : 0,
                              strokeWidth: 3.w,
                              color: detail.factory.isActive ? Colors.greenAccent : AppColors.border,
                              backgroundColor: Colors.black45,
                            ),
                          ),
                          Container(
                            width: 50.w,
                            height: 50.w,
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              shape: BoxShape.circle,
                            ),
                            child: CachedAssetImage(fileName: detail.product!.urunIconu, fit: BoxFit.contain),
                          ),
                        ],
                      ),
                      SizedBox(width: 12.w),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold.withValues(alpha: 0.5), size: 14.sp),
                    ],
                  ),
                ),
                // Right side: Output
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: detail.outputInventories.isEmpty
                        ? [Text('Cikti Yok', style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp))]
                        : [
                            _buildFlowItem(
                              icon: detail.product!.urunIconu,
                              title: detail.product!.urunAdi,
                              subtitle: '${detail.outputInventories.first.quantity} / ${detail.factory.outputCapacity}',
                              progress: detail.factory.outputCapacity > 0 ? (detail.outputInventories.first.quantity / detail.factory.outputCapacity).clamp(0.0, 1.0) : 0,
                              isOutput: true,
                            )
                          ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFlowItem({
    required String icon,
    required String title,
    required String subtitle,
    required double progress,
    bool isOutput = false,
    VoidCallback? onAddTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CachedAssetImage(fileName: icon, width: 20.w, height: 20.w),
              if (onAddTap != null) ...[
                SizedBox(width: 4.w),
                InkWell(
                  onTap: onAddTap,
                  child: Icon(Icons.add_circle, color: AppColors.gold, size: 14.sp),
                ),
              ],
            ],
          ),
          SizedBox(height: 4.h),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 2.h),
          Text(subtitle, style: TextStyle(color: isOutput ? Colors.blueAccent : Colors.greenAccent, fontSize: 9.sp)),
          SizedBox(height: 4.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2.h,
              backgroundColor: Colors.black45,
              color: isOutput ? Colors.blueAccent : Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(FactoryDetailModel detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detayli Istatistikler', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 12.h),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 2.2,
          children: [
            _buildGlassMetricCard(
              title: 'Saatlik Uretim',
              value: detail.product != null ? '${detail.product!.uretimAdedi}' : '-',
              icon: Icons.speed,
              color: Colors.orangeAccent,
            ),
            _buildGlassMetricCard(
              title: 'Tahmini Deger',
              value: detail.outputInventories.isNotEmpty ? '₺${detail.outputInventories.first.product?.bazSatisFiyati.toInt() ?? 0}' : '-',
              icon: Icons.attach_money,
              color: Colors.greenAccent,
            ),
            _buildGlassMetricCard(
              title: 'Kalite Seviyesi',
              value: '${detail.factory.qualityLevel} Yildiz',
              icon: Icons.star_rounded,
              color: AppColors.gold,
            ),
            _buildGlassMetricCard(
              title: 'Birim Maliyet',
              value: detail.outputInventories.isNotEmpty ? '₺${detail.outputInventories.first.cost.toInt()}' : '-',
              icon: Icons.money_off,
              color: Colors.redAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp)),
                SizedBox(height: 4.h),
                Text(value, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold), maxLines: 1),
              ],
            ),
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
      final _ = await ref.refresh(factoryDetailProvider(detail.factory.id).future);
      ref.invalidate(factoryListProvider);
      final deletedObsoleteCount =
          (result['deleted_obsolete_inventory_count'] as num?)?.toInt() ?? 0;
      final cleanupNote = deletedObsoleteCount > 0
          ? ' Eski bos kayitlardan $deletedObsoleteCount adet temizlendi.'
          : '';
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message:
            '${product.urunAdi} otomatik kalite ${selectableProduct.maxQualityLevel} ile ayarlandi.$cleanupNote',
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
      final _ = await ref.refresh(factoryDetailProvider(detail.factory.id).future);
      ref.invalidate(factoryListProvider);
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: detail.factory.isActive
            ? 'Fabrika pasif moda alindi.'
            : 'Fabrika aktif edildi.',
        type: SnackbarType.success,
      );
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
        .getEligibleWarehouseSlotsForInventoryAllCities(
          inventory: inventory,
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
                        '${(warehouse['city']?['name'] ?? detail.cityName).toString()} | Stok: $qty',
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
                            final warehouseCityId =
                                (warehouse['city_id'] ?? '').toString();
                            if (_isSameCity(warehouseCityId, detail.factory.cityId)) {
                              final result = await ref
                                  .read(factoryActionProvider)
                                  .transferWarehouseToProductionInventory(
                                    warehouseSlotId: slot['id'].toString(),
                                    productionInventoryId: inventory.id,
                                    quantity: quantity,
                                  );
                              if (!context.mounted) return;
                              if (result['success'] == true) {
                                final _ = await ref.refresh(
                                  factoryDetailProvider(detail.factory.id).future,
                                );
                                AppSnackbar.show(
                                  context,
                                  title: 'Basarili',
                                  message: 'Ayni sehir input transferi tamamlandi.',
                                  type: SnackbarType.success,
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
                              return;
                            }

                            await _startFactoryLogisticsInputTransfer(
                              context: context,
                              ref: ref,
                              detail: detail,
                              inventory: inventory,
                              warehouseSlotId: slot['id'].toString(),
                              maxQuantity: qty,
                              quantity: quantity,
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
        .getWarehousesForProductionLogistics(
          productionCityId: detail.factory.cityId,
        );

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
              final warehouseId = warehouse.id;
              final sameCity = warehouse.isSameCity;
              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                child: ListTile(
                  tileColor: Colors.white.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  title: Text(
                    warehouse.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${warehouse.cityName} | ${sameCity ? 'Anlik Transfer' : 'Lojistik Transfer'}',
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
                        if (sameCity) {
                          final result = await ref
                              .read(factoryActionProvider)
                              .transferProductionInventoryToWarehouse(
                                productionInventoryId: inventory.id,
                                warehouseId: warehouseId,
                                quantity: quantity,
                              );
                          if (!context.mounted) return;
                          if (result['success'] == true) {
                            final _ = await ref.refresh(
                              factoryDetailProvider(detail.factory.id).future,
                            );
                            AppSnackbar.show(
                              context,
                              title: 'Basarili',
                              message: inventory.isInput
                                  ? 'Ayni sehir input iadesi tamamlandi.'
                                  : 'Ayni sehir output transferi tamamlandi.',
                              type: SnackbarType.success,
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
                          return;
                        }

                        await _startFactoryLogisticsOutputTransfer(
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

  Future<void> _startFactoryLogisticsInputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required FactoryProductionInventoryModel inventory,
    required String warehouseSlotId,
    required int maxQuantity,
    required int quantity,
  }) async {
    List<ProductionLogisticsVehicleOption> options;
    try {
      options = await ref
          .read(factoryActionProvider)
          .getProductionInputTransferVehicleOptions(
            warehouseSlotId: warehouseSlotId,
            productionInventoryId: inventory.id,
            quantity: quantity,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackbarType.error,
      );
      return;
    }

    if (!context.mounted) return;
    if (options.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu transfer icin uygun arac bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: 'Input Lojistigi',
      subtitle:
          '$quantity / $maxQuantity adet hammadde icin uygun araci secin',
      options: options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(factoryActionProvider)
            .startWarehouseToProductionTransfer(
              warehouseSlotId: warehouseSlotId,
              productionInventoryId: inventory.id,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          final _ = await ref.refresh(factoryDetailProvider(detail.factory.id).future);
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: 'Hammadde transferi icin arac yola cikti.',
            type: SnackbarType.success,
          );
          return;
        }
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: result.message.isNotEmpty
              ? result.message
              : 'Lojistik transferi baslatilamadi.',
          type: SnackbarType.error,
        );
      },
    );
  }

  Future<void> _startFactoryLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required FactoryProductionInventoryModel inventory,
    required String warehouseId,
    required int quantity,
  }) async {
    List<ProductionLogisticsVehicleOption> options;
    try {
      options = await ref
          .read(factoryActionProvider)
          .getProductionOutputTransferVehicleOptions(
            productionInventoryId: inventory.id,
            buyerWarehouseId: warehouseId,
            quantity: quantity,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackbarType.error,
      );
      return;
    }

    if (!context.mounted) return;
    if (options.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu transfer icin uygun arac bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: inventory.isInput ? 'Input Iade Lojistigi' : 'Output Lojistigi',
      subtitle: inventory.isInput
          ? '$quantity adet input iadesi icin uygun araci secin'
          : '$quantity adet output icin uygun araci secin',
      options: options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(factoryActionProvider)
            .startProductionToWarehouseTransfer(
              productionInventoryId: inventory.id,
              buyerWarehouseId: warehouseId,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          final _ = await ref.refresh(factoryDetailProvider(detail.factory.id).future);
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: inventory.isInput
                ? 'Input iadesi icin arac yola cikti.'
                : 'Output transferi icin arac yola cikti.',
            type: SnackbarType.success,
          );
          return;
        }
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: result.message.isNotEmpty
              ? result.message
              : 'Lojistik transferi baslatilamadi.',
          type: SnackbarType.error,
        );
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
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final color =
                      option.canSelect ? AppColors.green : AppColors.red;
                  return InkWell(
                    onTap: option.canSelect
                        ? () async {
                            Navigator.pop(sheetContext);
                            await onSelected(option.vehicleId);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: color),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  option.vehicleName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                option.isRental ? 'Kiralik' : 'Ozmal',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Kapasite: ${option.capacity} | Mesafe: ${option.distanceKm.toStringAsFixed(0)} km | Sure: ${_formatTransferDuration(option.estimatedDurationSeconds)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Yakit: ${option.fuelNeeded.toStringAsFixed(0)} | Kondisyon: ${option.conditionNeeded.toStringAsFixed(0)} | Kira: ${option.rentalCost.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          if (!option.canSelect &&
                              option.disabledReason != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              option.disabledReason!,
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  bool _isSameCity(String warehouseCityId, String productionCityId) {
    return warehouseCityId.isNotEmpty &&
        productionCityId.isNotEmpty &&
        warehouseCityId == productionCityId;
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
                AppSnackbar.show(
                  context,
                  title: 'Hata',
                  message: 'Gecersiz miktar!',
                  type: SnackbarType.error,
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

  }

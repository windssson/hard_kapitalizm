import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';

class FarmDetailScreen extends ConsumerWidget {
  final String farmId;

  const FarmDetailScreen({super.key, required this.farmId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(farmDetailProvider(farmId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Tarla Yonetimi'),
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
                    ref.invalidate(farmDetailProvider(farmId));
                    await ref.read(farmDetailProvider(farmId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.all(12.w),
                    children: [
                      _buildHeader(detail),
                      SizedBox(height: 12.h),
                      _buildSummary(detail),
                      SizedBox(height: 12.h),
                      _buildActionRow(context, ref, detail),
                      SizedBox(height: 14.h),
                      _buildSectionTitle('Uretim Slotlari'),
                      SizedBox(height: 8.h),
                      if (detail.slots.isEmpty)
                        _buildEmptyCard('Bu tarlada henuz uretim slotu yok.')
                      else
                        ...detail.slots.map(
                          (slot) => _buildSlotCard(context, ref, detail, slot),
                        ),
                      SizedBox(height: 14.h),
                      _buildSectionTitle('Input Stoklari'),
                      SizedBox(height: 8.h),
                      if (detail.inputInventories.isEmpty)
                        _buildEmptyCard('Hammadde input kaydi yok.')
                      else
                        ...detail.inputInventories.map(
                          (inv) => _buildInventoryCard(context, ref, detail, inv),
                        ),
                      SizedBox(height: 14.h),
                      _buildSectionTitle('Output Stoklari'),
                      SizedBox(height: 8.h),
                      if (detail.outputInventories.isEmpty)
                        _buildEmptyCard('Uretilmis output kaydi yok.')
                      else
                        ...detail.outputInventories.map(
                          (inv) => _buildInventoryCard(context, ref, detail, inv),
                        ),
                      SizedBox(height: 28.h),
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

  Widget _buildHeader(FarmDetailModel detail) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: CachedAssetImage(
              fileName: detail.farmType.icon,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.farm.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${detail.cityName} | ${detail.farmType.name}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    _buildHeaderChip('Lv. ${detail.farm.level}', AppColors.gold),
                    SizedBox(width: 8.w),
                    _buildHeaderChip(
                      detail.farm.isActive ? 'AKTIF' : 'PASIF',
                      detail.farm.isActive ? AppColors.green : AppColors.red,
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

  Widget _buildHeaderChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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

  Widget _buildSummary(FarmDetailModel detail) {
    final inputUsed = _calculateUsedCapacity(detail.inputInventories);
    final outputUsed = _calculateUsedCapacity(detail.outputInventories);
    final inputRatio = detail.farm.inputCapacity > 0
        ? (inputUsed / detail.farm.inputCapacity).clamp(0.0, 1.0)
        : 0.0;
    final outputRatio = detail.farm.outputCapacity > 0
        ? (outputUsed / detail.farm.outputCapacity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem(
            'Slot',
            '${detail.farm.currentSlotCount}/${detail.farm.maxSlotCount}',
          ),
          _buildSummaryItem(
            'Input',
            '$inputUsed/${detail.farm.inputCapacity}',
            progress: inputRatio,
            progressColor: AppColors.blue,
          ),
          _buildSummaryItem(
            'Output',
            '$outputUsed/${detail.farm.outputCapacity}',
            progress: outputRatio,
            progressColor: AppColors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value, {
    double? progress,
    Color? progressColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (progress != null) ...[
          SizedBox(height: 5.h),
          Container(
            width: 72.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor ?? AppColors.gold,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Slot Ac',
            Icons.add_box_outlined,
            AppColors.gold,
            () => _handleAddSlot(context, ref, detail),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildActionButton(
            'Yenile',
            Icons.refresh,
            AppColors.blue,
            () {
              ref.invalidate(farmDetailProvider(detail.farm.id));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: slot.isActive ? AppColors.borderGold : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!slot.isEmpty && slot.product?.urunIconu != null) ...[
                Container(
                  width: 42.w,
                  height: 42.w,
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: CachedAssetImage(
                    fileName: slot.product!.urunIconu,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: Text(
                  'Slot ${slot.slotIndex}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildHeaderChip(
                slot.isActive ? 'AKTIF' : 'PASIF',
                slot.isActive ? AppColors.green : AppColors.red,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            slot.isEmpty
                ? 'Urun secilmemis'
                : '${slot.product?.urunAdi ?? slot.productId} | Kalite ${slot.qualityLevel}',
            style: TextStyle(
              color: slot.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Boost: x${slot.boostMultiplier.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
          ),
          if (!slot.isEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              '10 dk tahmini: ${_estimateProductionPerTick(slot)} adet',
              style: TextStyle(
                color: AppColors.gold.withValues(alpha: 0.9),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Saatlik tahmini: ${_estimateProductionPerHour(slot)} adet',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
              ),
            ),
          ],
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildMiniAction(
                  'Urun Sec',
                  AppColors.gold,
                  () => _showSlotProductDialog(context, ref, detail, slot),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildMiniAction(
                  slot.isActive ? 'Pasif Yap' : 'Aktif Et',
                  slot.isActive ? AppColors.red : AppColors.green,
                  () => _toggleSlotActive(context, ref, detail, slot),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
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
              _buildHeaderChip(
                inventory.isInput ? 'INPUT' : 'OUTPUT',
                inventory.isInput ? AppColors.blue : AppColors.green,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Kalite ${inventory.qualityLevel} | Miktar ${inventory.quantity} | Pending ${inventory.pendingQuantity.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
          ),
          SizedBox(height: 4.h),
          Container(
            height: 6.h,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: inventory.isInput
                  ? (detail.farm.inputCapacity > 0
                        ? (inventory.quantity / detail.farm.inputCapacity).clamp(0.0, 1.0)
                        : 0.0)
                  : (detail.farm.outputCapacity > 0
                        ? (inventory.quantity / detail.farm.outputCapacity).clamp(0.0, 1.0)
                        : 0.0),
              child: Container(
                decoration: BoxDecoration(
                  color: inventory.isInput ? AppColors.blue : AppColors.green,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Maliyet: ${inventory.cost.toStringAsFixed(2)}',
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

  Widget _buildMiniAction(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 9.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddSlot(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
  ) async {
    final result = await ref.read(farmActionProvider).addProductionSlot(detail.farm.id);

    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(farmDetailProvider(detail.farm.id));
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Yeni uretim slotu acildi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Slot acilamadi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _toggleSlotActive(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) async {
    final result = await ref.read(farmActionProvider).setProductionSlotActive(
      slotId: slot.id,
      isActive: !slot.isActive,
    );

    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(farmDetailProvider(detail.farm.id));
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Slot durumu guncellenemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _showSlotProductDialog(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) async {
    final products = await ref
        .read(farmActionProvider)
        .getAcceptedProducts(detail.farmType.acceptedProductIds);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) => _buildProductSelectionSheet(
        sheetContext,
        ref,
        detail,
        slot,
        products,
      ),
    );
  }

  Widget _buildProductSelectionSheet(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
    List<ProductModel> products,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
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
            child: ListView.separated(
              itemCount: products.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (_, index) {
                final product = products[index];
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
                    'Saatlik uretim: ${product.uretimAdedi}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.sp,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.gold,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showQualitySelectionDialog(context, ref, detail, slot, product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQualitySelectionDialog(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
    ProductModel product,
  ) async {
    int selectedQuality = slot.qualityLevel > 0 ? slot.qualityLevel : 1;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            'Kalite Sec',
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
          ),
          content: DropdownButtonFormField<int>(
            value: selectedQuality,
            dropdownColor: AppColors.cardBg,
            style: const TextStyle(color: Colors.white),
            items: List.generate(
              5,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('Kalite ${index + 1}'),
              ),
            ),
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedQuality = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                final result = await ref.read(farmActionProvider).setProductionSlotProduct(
                  slotId: slot.id,
                  productId: product.id,
                  qualityLevel: selectedQuality,
                );

                if (!context.mounted) return;
                if (result['success'] == true) {
                  Navigator.pop(dialogContext);
                  ref.invalidate(farmDetailProvider(detail.farm.id));
                  return;
                }

                AppSnackbar.show(
                  context,
                  title: 'Hata',
                  message: result['message'] ?? 'Urun secilemedi.',
                  type: SnackbarType.error,
                );
              },
              child: const Text(
                'Kaydet',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startWarehouseToInventoryFlow(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref.read(farmActionProvider).getEligibleWarehouseSlotsForInventory(
      inventory: inventory,
      cityId: detail.farm.cityId,
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
              final slots = (warehouse['warehouse_slots'] as List<dynamic>? ?? const []);
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
                                .read(farmActionProvider)
                                .transferWarehouseToProductionInventory(
                                  warehouseSlotId: slot['id'].toString(),
                                  productionInventoryId: inventory.id,
                                  quantity: quantity,
                                );
                            if (!context.mounted) return;
                            if (result['success'] == true) {
                              ref.invalidate(farmDetailProvider(detail.farm.id));
                              return;
                            }
                            AppSnackbar.show(
                              context,
                              title: 'Hata',
                              message: result['message'] ?? 'Transfer basarisiz oldu.',
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
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(farmActionProvider)
        .getPlayerWarehousesByCity(detail.farm.cityId);

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
                            .read(farmActionProvider)
                            .transferProductionInventoryToWarehouse(
                              productionInventoryId: inventory.id,
                              warehouseId: warehouse['id'].toString(),
                              quantity: quantity,
                            );
                        if (!context.mounted) return;
                        if (result['success'] == true) {
                          ref.invalidate(farmDetailProvider(detail.farm.id));
                          return;
                        }
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message: result['message'] ?? 'Transfer basarisiz oldu.',
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
        title: Text(title, style: TextStyle(color: Colors.white, fontSize: 18.sp)),
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

  int _calculateUsedCapacity(List<FarmProductionInventoryModel> inventories) {
    var total = 0;
    for (final inventory in inventories) {
      total += inventory.quantity;
    }
    return total;
  }

  String _estimateProductionPerTick(FarmProductionSlotModel slot) {
    final product = slot.product;
    if (product == null) return '0';
    final perTick = (product.uretimAdedi / 6.0) * slot.boostMultiplier;
    return perTick.toStringAsFixed(perTick >= 10 ? 0 : 1);
  }

  String _estimateProductionPerHour(FarmProductionSlotModel slot) {
    final product = slot.product;
    if (product == null) return '0';
    final perHour = product.uretimAdedi * slot.boostMultiplier;
    return perHour.toStringAsFixed(perHour >= 10 ? 0 : 1);
  }
}

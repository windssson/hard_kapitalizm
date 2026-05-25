import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';

class FieldDetailScreen extends ConsumerStatefulWidget {
  final String fieldId;

  const FieldDetailScreen({super.key, required this.fieldId});

  @override
  ConsumerState<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends ConsumerState<FieldDetailScreen> {
  @override
  void initState() {
    super.initState();
    _refreshOnEntry();
  }

  void _refreshOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(fieldDetailProvider(widget.fieldId));
      ref.read(fieldDetailProvider(widget.fieldId).future);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(fieldDetailProvider(widget.fieldId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Ciftlik Yonetimi'),
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
                    ref.invalidate(fieldDetailProvider(widget.fieldId));
                    await ref.read(fieldDetailProvider(widget.fieldId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.all(12.w),
                    children: [
                      _buildHeader(detail),
                      SizedBox(height: 12.h),
                      _buildActionRow(context, ref, detail),
                      SizedBox(height: 14.h),
                      _buildSectionTitle('Uretim Slotlari'),
                      SizedBox(height: 8.h),
                      if (detail.slots.isEmpty)
                        _buildEmptyCard('Bu ciftlikte henuz uretim slotu yok.')
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
                          (inv) => _buildInventoryCard(
                            context,
                            ref,
                            detail,
                            inv,
                          ),
                        ),
                      SizedBox(height: 14.h),
                      _buildSectionTitle('Output Stoklari'),
                      SizedBox(height: 8.h),
                      if (detail.outputInventories.isEmpty)
                        _buildEmptyCard('Uretilmis output kaydi yok.')
                      else
                        ...detail.outputInventories.map(
                          (inv) => _buildInventoryCard(
                            context,
                            ref,
                            detail,
                            inv,
                          ),
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

  Widget _buildHeader(FieldDetailModel detail) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg.withValues(alpha: 0.8),
            AppColors.background.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CachedAssetImage(
              fileName: detail.fieldType.icon,
              fit: BoxFit.contain,
              errorWidget: Icon(
                Icons.grass,
                color: AppColors.green,
                size: 36.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.field.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.gold, size: 14.sp),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        '${detail.cityName} | ${detail.fieldType.name}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    _buildHeaderChip('Lv. ${detail.field.level}', AppColors.gold),
                    SizedBox(width: 8.w),
                    _buildHeaderChip(
                      detail.field.isActive ? 'AKTIF' : 'PASIF',
                      detail.field.isActive ? AppColors.green : AppColors.red,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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


  Widget _buildActionRow(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
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
              ref.invalidate(fieldDetailProvider(detail.field.id));
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
    return Padding(
      padding: EdgeInsets.only(left: 4.w, top: 8.h),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
        ),
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: slot.isActive 
              ? AppColors.borderGoldLight.withValues(alpha: 0.4) 
              : AppColors.border.withValues(alpha: 0.3),
        ),
        boxShadow: slot.isActive ? [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: !slot.isEmpty 
                        ? AppColors.green.withValues(alpha: 0.3) 
                        : Colors.white10,
                  ),
                ),
                child: (!slot.isEmpty && slot.product?.urunIconu != null)
                    ? CachedAssetImage(
                        fileName: slot.product!.urunIconu,
                        fit: BoxFit.contain,
                      )
                    : Icon(Icons.add_circle_outline, color: AppColors.textMuted, size: 24.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Slot ${slot.slotIndex}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildHeaderChip(
                          slot.isActive ? 'AKTIF' : 'PASIF',
                          slot.isActive ? AppColors.green : AppColors.red,
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      slot.isEmpty
                          ? 'Henuz urun secilmedi'
                          : '${slot.product?.urunAdi ?? slot.productId} | Kalite ${slot.qualityLevel}',
                      style: TextStyle(
                        color: slot.isEmpty ? AppColors.textMuted : AppColors.gold,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!slot.isEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSlotStat(
                    'Boost', 
                    'x${slot.boostMultiplier.toStringAsFixed(2)}',
                    Icons.speed,
                    Colors.orange,
                  ),
                  _buildSlotStat(
                    '10 Dk', 
                    '${_estimateProductionPerTick(slot)}',
                    Icons.timer,
                    AppColors.blue,
                  ),
                  _buildSlotStat(
                    'Saatlik', 
                    '${_estimateProductionPerHour(slot)}',
                    Icons.access_time,
                    AppColors.green,
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _buildMiniAction(
                  slot.isEmpty ? 'Urun Sec' : 'Urun Degistir',
                  AppColors.gold,
                  () => _showSlotProductDialog(context, ref, detail, slot),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildMiniAction(
                  slot.isActive ? 'Uretimi Durdur' : 'Uretime Basla',
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

  Widget _buildSlotStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16.sp),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
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
    );
  }

  Widget _buildInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionInventoryModel inventory,
  ) {
    final title =
        inventory.product?.urunAdi.isNotEmpty == true
            ? inventory.product!.urunAdi
            : inventory.productId;

    final capacity = inventory.isInput ? detail.field.inputCapacity : detail.field.outputCapacity;
    final progress = capacity > 0 ? (inventory.quantity / capacity).clamp(0.0, 1.0) : 0.0;
    final color = inventory.isInput ? AppColors.blue : AppColors.green;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: inventory.product?.urunIconu != null
                    ? CachedAssetImage(
                        fileName: inventory.product!.urunIconu,
                        fit: BoxFit.contain,
                      )
                    : Icon(Icons.inventory_2, color: AppColors.textMuted, size: 24.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildHeaderChip(
                          inventory.isInput ? 'INPUT' : 'OUTPUT',
                          color,
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Text(
                          'Kalite ${inventory.qualityLevel}',
                          style: TextStyle(color: AppColors.gold, fontSize: 11.sp, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ' • Pending: ${inventory.pendingQuantity.toStringAsFixed(1)}',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maliyet: ${inventory.cost.toStringAsFixed(2)}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
              ),
              Text(
                '${inventory.quantity} / $capacity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            height: 8.h,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999.r),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)
                  ]
                ),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          if (inventory.isInput)
            Row(
              children: [
                Expanded(
                  child: _buildMiniAction(
                    'Depodan Hammadde Getir',
                    AppColors.gold,
                    () => _startWarehouseToInventoryFlow(
                      context,
                      ref,
                      detail,
                      inventory,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildMiniAction(
                    'Depoya Geri Gonder',
                    AppColors.blue,
                    () => _startInventoryToWarehouseFlow(
                      context,
                      ref,
                      detail,
                      inventory,
                    ),
                  ),
                ),
              ],
            )
          else
            _buildMiniAction(
              'Uretimi Depoya Aktar',
              AppColors.blue,
              () => _startInventoryToWarehouseFlow(
                context,
                ref,
                detail,
                inventory,
              ),
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
        padding: EdgeInsets.symmetric(vertical: 10.h),
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
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddSlot(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
  ) async {
    final result = await ref
        .read(fieldActionProvider)
        .addProductionSlot(detail.field.id);

    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(fieldDetailProvider(detail.field.id));
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
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) async {
    final result = await ref.read(fieldActionProvider).setProductionSlotActive(
      slotId: slot.id,
      isActive: !slot.isActive,
    );

    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(fieldDetailProvider(detail.field.id));
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
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref
          .read(fieldActionProvider)
          .getSelectableProducts(
            ownerKind: 'field',
            typeId: detail.fieldType.id,
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
      builder: (sheetContext) => _buildProductSelectionSheet(
        context,
        sheetContext,
        ref,
        detail,
        slot,
        products,
      ),
    );
  }

  Widget _buildProductSelectionSheet(
    BuildContext parentContext,
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
    List<SelectableProductionProductModel> products,
  ) {
    final disabledProductIds = detail.slots
        .where((otherSlot) => otherSlot.id != slot.id)
        .map((otherSlot) => otherSlot.productId ?? '')
        .where((productId) => productId.isNotEmpty)
        .toSet();

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
            child: products.isEmpty
                ? Center(
                    child: Text(
                      'Bu ciftlik turu icin uygun urun bulunamadi.',
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
                      final isDisabled = disabledProductIds.contains(product.id);
                      return ListTile(
                        enabled: !isDisabled,
                        tileColor: isDisabled
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.white.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        leading: SizedBox(
                          width: 40.w,
                          height: 40.w,
                          child: Opacity(
                            opacity: isDisabled ? 0.4 : 1,
                            child: CachedAssetImage(
                              fileName: product.urunIconu,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        title: Text(
                          product.urunAdi,
                          style: TextStyle(
                            color: isDisabled
                                ? AppColors.textMuted
                                : Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          isDisabled
                              ? 'Bu urun baska bir slotta kullaniliyor'
                              : 'Maks kalite: ${selectableProduct.maxQualityLevel} | Saatlik uretim: ${product.uretimAdedi}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
                        ),
                        trailing: Icon(
                          isDisabled ? Icons.block : Icons.chevron_right,
                          color: isDisabled
                              ? AppColors.textMuted
                              : AppColors.gold,
                        ),
                        onTap: isDisabled
                            ? null
                            : () async {
                          Navigator.pop(context);
                          await _selectSlotProduct(
                            parentContext,
                            ref,
                            detail,
                            slot,
                            selectableProduct,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectSlotProduct(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
    SelectableProductionProductModel selectableProduct,
  ) async {
    final product = selectableProduct.product;
    final action = ref.read(fieldActionProvider);
    final result = slot.isEmpty
        ? await action.assignProductionSlotProduct(
            slotId: slot.id,
            productId: product.id,
            qualityLevel: selectableProduct.maxQualityLevel,
          )
        : await action.changeProductionSlotProduct(
            slotId: slot.id,
            productId: product.id,
            qualityLevel: selectableProduct.maxQualityLevel,
          );

    if (!context.mounted) return;
    if (result['success'] == true) {
      ref.invalidate(fieldDetailProvider(detail.field.id));
      final deletedObsoleteCount =
          (result['deleted_obsolete_inventory_count'] as num?)?.toInt() ?? 0;
      final cleanupNote = deletedObsoleteCount > 0
          ? ' Eski bos kayitlardan $deletedObsoleteCount adet temizlendi.'
          : '';
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message:
            slot.isEmpty
                ? '${product.urunAdi} kalite ${selectableProduct.maxQualityLevel} ile eklendi.'
                : '${product.urunAdi} kalite ${selectableProduct.maxQualityLevel} olarak degistirildi.$cleanupNote',
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

  Future<void> _startWarehouseToInventoryFlow(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(fieldActionProvider)
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
                          subtitle: '${inventory.product?.urunAdi ?? inventory.productId} inputu doldurulacak',
                          onConfirm: (quantity) async {
                            final warehouseCityId =
                                (warehouse['city_id'] ?? '').toString();
                            if (_isSameCity(warehouseCityId, detail.field.cityId)) {
                              final result = await ref
                                  .read(fieldActionProvider)
                                  .transferWarehouseToProductionInventory(
                                    warehouseSlotId: slot['id'].toString(),
                                    productionInventoryId: inventory.id,
                                    quantity: quantity,
                                  );
                              if (!context.mounted) return;
                              if (result['success'] == true) {
                                ref.invalidate(fieldDetailProvider(detail.field.id));
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
                                    result['message'] ??
                                    'Transfer basarisiz oldu.',
                                type: SnackbarType.error,
                              );
                              return;
                            }

                            await _startFieldLogisticsInputTransfer(
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
    FieldDetailModel detail,
    ProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(fieldActionProvider)
        .getWarehousesForProductionLogistics(
          productionCityId: detail.field.cityId,
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
                              .read(fieldActionProvider)
                              .transferProductionInventoryToWarehouse(
                                productionInventoryId: inventory.id,
                                warehouseId: warehouseId,
                                quantity: quantity,
                              );
                          if (!context.mounted) return;
                          if (result['success'] == true) {
                            ref.invalidate(fieldDetailProvider(detail.field.id));
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

                        await _startFieldLogisticsOutputTransfer(
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

  Future<void> _startFieldLogisticsInputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FieldDetailModel detail,
    required ProductionInventoryModel inventory,
    required String warehouseSlotId,
    required int maxQuantity,
    required int quantity,
  }) async {
    List<ProductionLogisticsVehicleOption> options;
    try {
      options = await ref
          .read(fieldActionProvider)
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
            .read(fieldActionProvider)
            .startWarehouseToProductionTransfer(
              warehouseSlotId: warehouseSlotId,
              productionInventoryId: inventory.id,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          ref.invalidate(fieldDetailProvider(detail.field.id));
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

  Future<void> _startFieldLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FieldDetailModel detail,
    required ProductionInventoryModel inventory,
    required String warehouseId,
    required int quantity,
  }) async {
    List<ProductionLogisticsVehicleOption> options;
    try {
      options = await ref
          .read(fieldActionProvider)
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
            .read(fieldActionProvider)
            .startProductionToWarehouseTransfer(
              productionInventoryId: inventory.id,
              buyerWarehouseId: warehouseId,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          ref.invalidate(fieldDetailProvider(detail.field.id));
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



  String _estimateProductionPerTick(ProductionSlotModel slot) {
    final product = slot.product;
    if (product == null) return '0';
    final perTick = (product.uretimAdedi / 6.0) * slot.boostMultiplier;
    return perTick.toStringAsFixed(perTick >= 10 ? 0 : 1);
  }

  String _estimateProductionPerHour(ProductionSlotModel slot) {
    final product = slot.product;
    if (product == null) return '0';
    final perHour = product.uretimAdedi * slot.boostMultiplier;
    return perHour.toStringAsFixed(perHour >= 10 ? 0 : 1);
  }
}

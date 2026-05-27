import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';

class FieldDetailScreen extends ConsumerStatefulWidget {
  final String fieldId;

  const FieldDetailScreen({super.key, required this.fieldId});

  @override
  ConsumerState<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends ConsumerState<FieldDetailScreen> {
  static const Map<int, int> _fieldBoostStarCosts = {
    6: 3,
    12: 6,
    24: 12,
  };

  @override
  void initState() {
    super.initState();
    _refreshOnEntry();
  }

  void _refreshOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(fieldActionProvider).completeDueBuildingBoosts();
      if (!mounted) return;
      await ref.read(fieldActionProvider).completeDueBuildingUpgrades();
      if (!mounted) return;
      _refreshFieldDetail();
    });
  }

  void _refreshFieldDetail() {
    ref.invalidate(fieldDetailProvider(widget.fieldId));
    ref.invalidate(activeFieldBoostProvider(widget.fieldId));
    ref.invalidate(activeFieldUpgradeProvider(widget.fieldId));
    ref.read(fieldDetailProvider(widget.fieldId).future);
    ref.read(activeFieldBoostProvider(widget.fieldId).future);
    ref.read(activeFieldUpgradeProvider(widget.fieldId).future);
  }

  Future<void> _refreshFieldEcosystem({
    String? warehouseId,
    bool includeTransfers = false,
  }) async {
    _refreshFieldDetail();
    ref.invalidate(fieldListProvider);
    ref.invalidate(playerStreamProvider);
    ref.invalidate(warehouseListProvider);
    ref.invalidate(warehouseDetailProvider);

    if (warehouseId != null && warehouseId.isNotEmpty) {
      ref.invalidate(warehouseDetailProvider(warehouseId));
    }

    if (includeTransfers) {
      ref.invalidate(buyerTransferMapProvider);
      ref.invalidate(buyerTransferHistoryProvider);
    }

    await ref.read(fieldDetailProvider(widget.fieldId).future);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(fieldDetailProvider(widget.fieldId));
    final activeBoost = ref.watch(activeFieldBoostProvider(widget.fieldId)).value;
    final activeUpgrade = ref.watch(
      activeFieldUpgradeProvider(widget.fieldId),
    ).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    await ref.read(fieldActionProvider).completeDueBuildingBoosts();
                    if (!mounted) return;
                    await ref.read(fieldActionProvider).completeDueBuildingUpgrades();
                    if (!mounted) return;
                    _refreshFieldDetail();
                    await ref.read(fieldDetailProvider(widget.fieldId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 24.h),
                    children: [
                      _buildHero(detail),
                      SizedBox(height: 10.h),
                      _buildQuickActions(
                        context,
                        ref,
                        detail,
                        activeBoost,
                        activeUpgrade,
                      ),
                      if (activeBoost != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveFieldBoostCard(boost: activeBoost),
                      ],
                      if (activeUpgrade != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveFieldUpgradeCard(
                          upgrade: activeUpgrade,
                          onFinishWithGold: () =>
                              _finishFieldUpgradeWithGold(activeUpgrade),
                          calculateStarCost: _calculateUpgradeStarCost,
                          formatCountdown: _formatCountdown,
                        ),
                      ],
                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Ciftlikler',
                        'Her ciftlikte ekili urunu, kaliteyi ve uretim akislarini buradan yonetebilirsin.',
                        icon: Icons.tune_rounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      if (detail.slots.isEmpty)
                        _buildEmptyCard(
                          'Bu ciftlikte henuz aktif uretim slotu yok.',
                        )
                      else
                        ...detail.slots.map(
                          (slot) => _buildSlotCard(context, ref, detail, slot),
                        ),
                      if (detail.orphanInputInventories.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _buildSectionHeader(
                          'Bagli Olmayan Hammaddeler',
                          'Urun degisikligi sonrasinda elde kalan hammaddeleri burada depoya geri aktarabilirsin.',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.blue,
                        ),
                        SizedBox(height: 10.h),
                        ...detail.orphanInputInventories.map(
                          (inventory) => _buildSlotInventoryCard(
                            context,
                            ref,
                            detail,
                            inventory,
                          ),
                        ),
                      ],
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

  Widget _buildHero(FieldDetailModel detail) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68.w,
                    height: 68.w,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          blurRadius: 12,
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
                        size: 32.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                detail.fieldType.name,
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: AppColors.gold,
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      detail.cityName,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 74.w),
                          child: _buildHeroChipColumn(detail),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  'Hammadde',
                  '${_calculateUsedCapacity(detail.inputInventories)}/${detail.field.inputCapacity}',
                  AppColors.blue,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.inputInventories),
                    detail.field.inputCapacity,
                  ),
                  icon: Icons.science_outlined,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildHeroStat(
                  'Uretilen urun',
                  '${_calculateUsedCapacity(detail.outputInventories)}/${detail.field.outputCapacity}',
                  AppColors.green,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.outputInventories),
                    detail.field.outputCapacity,
                  ),
                  icon: Icons.agriculture_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(
    String label,
    String value,
    Color color, {
    required double ratio,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14.sp),
              SizedBox(width: 7.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    final canBoost = detail.slots.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Wrap(
        spacing: 10.w,
        runSpacing: 10.h,
        children: [
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              'Slot Ac',
              Icons.add_box_outlined,
              AppColors.gold,
              () => _handleAddSlot(context, ref, detail),
            ),
          ),
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              'Boost',
              Icons.flash_on_rounded,
              canBoost ? AppColors.goldDark : AppColors.textMuted,
              canBoost
                  ? () => _showFieldBoostSheet(context, ref, detail, activeBoost)
                  : () {
                      AppSnackbar.show(
                        context,
                        title: 'Bilgi',
                        message:
                            'Boost baslatmadan once en az bir uretim slotu acmalisin.',
                        type: SnackbarType.info,
                      );
                    },
            ),
          ),
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              'Yukselt',
              Icons.upgrade_rounded,
              AppColors.green,
              () => _showFieldUpgradeSheet(context, ref, detail, activeUpgrade),
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15.sp),
            SizedBox(height: 3.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(icon, color: color, size: 16.sp),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.sp,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
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

  Widget _buildSlotCard(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    final slotActiveColor = slot.isActive ? AppColors.green : AppColors.red;
    final slotTitle = slot.isEmpty
        ? 'Bos Ciftlik ${slot.slotIndex}'
        : (slot.product?.urunAdi ?? slot.productId ?? 'Bilinmeyen Urun');
    final outputInventory = slot.isEmpty
        ? null
        : _outputInventoryForSlot(detail, slot);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(
        slot.isActive ? AppColors.gold : null,
        18.r,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58.w,
                height: 58.w,
                padding: EdgeInsets.all(9.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: !slot.isEmpty
                        ? AppColors.green.withValues(alpha: 0.3)
                        : Colors.white10,
                  ),
                ),
                child: slot.isEmpty || slot.product?.urunIconu == null
                    ? Icon(
                        Icons.add_circle_outline,
                        color: AppColors.textMuted,
                        size: 24.sp,
                      )
                    : CachedAssetImage(
                        fileName: slot.product!.urunIconu,
                        fit: BoxFit.contain,
                      ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slotTitle,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              if (slot.isEmpty)
                                Text(
                                  'Bu ciftlik beklemede. Urun secerek uretimi baslatabilirsin.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                _buildQualityStars(slot.qualityLevel),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTag(
                              slot.isActive ? 'AKTIF' : 'PASIF',
                              slotActiveColor,
                            ),
                            SizedBox(width: 6.w),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              offset: const Offset(0, 40),
                              color: AppColors.cardBgLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(
                                  color: AppColors.border.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Icon(
                                  Icons.more_vert,
                                  color: AppColors.textMuted,
                                  size: 18.sp,
                                ),
                              ),
                              onSelected: (value) {
                                if (value == 'product') {
                                  _showSlotProductDialog(context, ref, detail, slot);
                                } else if (value == 'toggle') {
                                  _toggleSlotActive(context, ref, detail, slot);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'product',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.category,
                                        color: AppColors.gold,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        slot.isEmpty ? 'Urun Sec' : 'Urun Degistir',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        slot.isActive
                                            ? Icons.stop_circle
                                            : Icons.play_circle,
                                        color: slot.isActive
                                            ? AppColors.red
                                            : AppColors.green,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        slot.isActive
                                            ? 'Uretimi Durdur'
                                            : 'Uretime Basla',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!slot.isEmpty) ...[
            SizedBox(height: 12.h),
            if (outputInventory != null) ...[
              _buildOutputSummaryRow(context, ref, detail, outputInventory),
              SizedBox(height: 10.h),
            ],
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: AppColors.textMuted,
                  size: 14.sp,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Tahmini saatlik uretim: ${_estimateProductionPerHour(slot)}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildSlotFlowGroup(context, ref, detail, slot),
          ],
        ],
      ),
    );
  }

  int _calculateUpgradeStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  String _formatCountdown(Duration remaining) {
    if (remaining.inSeconds <= 0) return 'Tamamlaniyor';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    }
    return '${remaining.inMinutes}dk';
  }

  Future<void> _showFieldBoostSheet(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    BuildingBoostModel? activeBoost,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ciftlik Boostu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              activeBoost != null
                  ? 'Bu ciftlikte zaten aktif bir boost var. Sure dolana kadar tum slotlar x${activeBoost.multiplier.toStringAsFixed(1)} hizla calisir.'
                  : 'Boost basladiginda tum ciftlik slotlarinin boost katsayisi 2 olur. Uretim hizi sure boyunca artar.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            if (activeBoost == null)
              ..._fieldBoostStarCosts.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await ref
                          .read(fieldActionProvider)
                          .startFieldBoost(
                            fieldId: detail.field.id,
                            durationHours: entry.key,
                            starCost: entry.value,
                          );
                      if (!context.mounted) return;
                      if (result['success'] == true) {
                        ref.invalidate(activeFieldBoostProvider(detail.field.id));
                        ref.invalidate(fieldDetailProvider(detail.field.id));
                        ref.invalidate(fieldListProvider);
                        ref.invalidate(playerStreamProvider);
                        AppSnackbar.show(
                          context,
                          title: 'Basarili',
                          message: 'Ciftlik boostu baslatildi.',
                          type: SnackbarType.success,
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message:
                              result['message'] ?? 'Ciftlik boostu baslatilamadi.',
                          type: SnackbarType.error,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.goldDark.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: AppColors.goldDark.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.flash_on_rounded,
                              color: AppColors.goldDark,
                              size: 18.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key} Saat',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tum slotlar x2 uretim hizi kazanir',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${entry.value} ★',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.goldDark.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  'Aktif boost bitene kadar yeni boost baslatilamaz.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFieldUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    if (activeUpgrade != null) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu ciftlik icin zaten devam eden bir yukseltme var.',
        type: SnackbarType.info,
      );
      return;
    }

    final targetLevel = detail.field.level + 1;
    final upgradeCost = (detail.fieldType.cost * targetLevel).toDouble();
    final durationMinutes =
        (detail.fieldType.constructionTimeMinutes * targetLevel).clamp(
          1,
          999999,
        );
    final nextInputCapacity = detail.field.inputCapacity * 2;
    final nextOutputCapacity = detail.field.outputCapacity * 2;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ciftlik Yukseltmesi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seviye ${detail.field.level} -> $targetLevel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Hammadde kapasitesi: ${detail.field.inputCapacity} -> $nextInputCapacity',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Uretilen urun kapasitesi: ${detail.field.outputCapacity} -> $nextOutputCapacity',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Sure: $durationMinutes dk',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Maliyet: TL ${upgradeCost.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final result = await ref
                      .read(fieldActionProvider)
                      .startFieldUpgrade(detail.field.id);
                  if (!context.mounted) return;
                  if (result['success'] == true) {
                    ref.invalidate(playerStreamProvider);
                    _refreshFieldDetail();
                    AppSnackbar.show(
                      context,
                      title: 'Basarili',
                      message: 'Ciftlik yukseltmesi baslatildi.',
                      type: SnackbarType.success,
                    );
                    return;
                  }
                  AppSnackbar.show(
                    context,
                    title: 'Hata',
                    message: result['message'] ?? 'Yukseltme baslatilamadi.',
                    type: SnackbarType.error,
                  );
                },
                icon: const Icon(Icons.upgrade_rounded),
                label: const Text('Yukseltmeyi Baslat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finishFieldUpgradeWithGold(BuildingUpgradeModel upgrade) async {
    final result = await ref
        .read(fieldActionProvider)
        .finishFieldUpgradeWithGold(upgrade.id);

    if (!mounted) return;
    if (result['success'] == true) {
      ref.invalidate(playerStreamProvider);
      _refreshFieldDetail();
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Ciftlik yukseltmesi tamamlandi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yukseltme tamamlanamadi.',
      type: SnackbarType.error,
    );
  }

  Widget _buildHeroChipColumn(FieldDetailModel detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildTag('Lv ${detail.field.level}', AppColors.gold),
      ],
    );
  }

  Widget _buildSlotFlowGroup(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    final inputInventories = _inputInventoriesForSlot(detail, slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFlowSection(
          title: 'Hammadde',
          color: AppColors.blue,
          child: inputInventories.isEmpty
              ? _buildInlineEmptyState(
                  'Bu slot icin bagli hammadde stogu bulunmuyor.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSharedInputCapacityBar(detail, inputInventories),
                    SizedBox(height: 10.h),
                    ...inputInventories.map(
                      (inventory) => _buildSlotInventoryCard(
                        context,
                        ref,
                        detail,
                        inventory,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFlowSection({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMiniFlowHeader(title, color),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }

  Widget _buildMiniFlowHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7.r),
          ),
          child: Icon(
            Icons.science_outlined,
            color: color,
            size: 13.sp,
          ),
        ),
        SizedBox(width: 7.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineEmptyState(String message) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
      ),
    );
  }

  Widget _buildSharedInputCapacityBar(
    FieldDetailModel detail,
    List<ProductionInventoryModel> inventories,
  ) {
    final capacity = detail.field.inputCapacity;
    final totalStock = inventories.fold<int>(
      0,
      (sum, inventory) => sum + inventory.quantity,
    );
    final totalPending = inventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.pendingQuantity,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$totalStock stok • ${totalPending.toStringAsFixed(1)} yolda / $capacity kapasite',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          _buildSegmentedCapacityBar(
            inventories: inventories,
            capacity: capacity,
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              ...inventories.map(
                (inventory) => _buildCapacityLegendChip(
                  inventory.product?.urunAdi.isNotEmpty == true
                      ? inventory.product!.urunAdi
                      : inventory.productId,
                  _inputColorForProduct(inventory.productId),
                ),
              ),
              _buildCapacityLegendChip('Yolda', AppColors.goldDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedCapacityBar({
    required List<ProductionInventoryModel> inventories,
    required int capacity,
  }) {
    if (capacity <= 0) {
      return Container(
        height: 8.h,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999.r),
        ),
      );
    }

    final segments = <({double amount, Color color})>[];
    for (final inventory in inventories) {
      if (inventory.quantity > 0) {
        segments.add((
          amount: inventory.quantity.toDouble(),
          color: _inputColorForProduct(inventory.productId),
        ));
      }
    }

    final totalPending = inventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.pendingQuantity,
    );
    if (totalPending > 0) {
      segments.add((amount: totalPending, color: AppColors.goldDark));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var left = 0.0;

        return Container(
          height: 8.h,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: Stack(
              children: [
                for (final segment in segments)
                  () {
                    final width = ((segment.amount / capacity) * maxWidth)
                        .clamp(0.0, maxWidth - left);
                    final positioned = Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: width,
                        color: segment.color,
                      ),
                    );
                    left += width;
                    return positioned;
                  }(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCapacityLegendChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<ProductionInventoryModel> _inputInventoriesForSlot(
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    final product = slot.product;
    if (slot.isEmpty || product == null) return const [];

    final productIds = <String>{
      if ((product.hammadde1Id ?? '').isNotEmpty) product.hammadde1Id!,
      if ((product.hammadde2Id ?? '').isNotEmpty) product.hammadde2Id!,
      if ((product.hammadde3Id ?? '').isNotEmpty) product.hammadde3Id!,
    };

    final inventories = detail.inputInventories
        .where((inventory) => productIds.contains(inventory.productId))
        .toList();

    inventories.sort((a, b) => a.productId.compareTo(b.productId));
    return inventories;
  }

  ProductionInventoryModel? _outputInventoryForSlot(
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    if (slot.isEmpty) return null;

    for (final inventory in detail.outputInventories) {
      if (inventory.productId == slot.productId &&
          inventory.qualityLevel == slot.qualityLevel) {
        return inventory;
      }
    }
    return null;
  }

  Widget _buildSlotInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionInventoryModel inventory,
  ) {
    final title = inventory.product?.urunAdi.isNotEmpty == true
        ? inventory.product!.urunAdi
        : inventory.productId;
    final color = inventory.isInput ? AppColors.blue : AppColors.green;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: color.withValues(alpha: 0.24)),
                ),
                child: inventory.product?.urunIconu != null
                    ? CachedAssetImage(
                        fileName: inventory.product!.urunIconu,
                        fit: BoxFit.contain,
                      )
                    : Icon(Icons.inventory_2, color: color, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    _buildQualityStars(inventory.qualityLevel),
                  ],
                ),
              ),
              Text(
                '${inventory.quantity}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maliyet: ${inventory.cost.toStringAsFixed(2)}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
              ),
              Text(
                'Yoldaki urunler ${inventory.pendingQuantity.toStringAsFixed(1)}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (inventory.isInput)
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                SizedBox(
                  width: 132.w,
                  child: _buildMiniAction(
                    'Stok Ekle',
                    AppColors.gold,
                    () => _startWarehouseToInventoryFlow(
                      context,
                      ref,
                      detail,
                      inventory,
                    ),
                  ),
                ),
                SizedBox(
                  width: 132.w,
                  child: _buildMiniAction(
                    'Depoya Gonder',
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
              'Depoya Aktar',
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

  Widget _buildOutputSummaryRow(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionInventoryModel inventory,
  ) {
    final ratio = _inventoryRatio(inventory.quantity, detail.field.outputCapacity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.agriculture_outlined,
              color: AppColors.green,
              size: 14.sp,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                'Uretilen urun stogu ${inventory.quantity}/${detail.field.outputCapacity}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _startInventoryToWarehouseFlow(
                context,
                ref,
                detail,
                inventory,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue.withValues(alpha: 0.16),
                foregroundColor: AppColors.blue,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                  side: BorderSide(
                    color: AppColors.blue.withValues(alpha: 0.28),
                  ),
                ),
              ),
              icon: Icon(Icons.move_up_rounded, size: 14.sp),
              label: Text(
                'Depoya Aktar',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Container(
          height: 5.h,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniAction(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 11.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
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
    FieldDetailModel detail,
  ) async {
    final result = await ref
        .read(fieldActionProvider)
        .addProductionSlot(detail.field.id);

    if (!context.mounted) return;
    if (result['success'] == true) {
      await _refreshFieldEcosystem();
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
    final result = await ref
        .read(fieldActionProvider)
        .setProductionSlotActive(slotId: slot.id, isActive: !slot.isActive);

    if (!context.mounted) return;
    if (result['success'] == true) {
      await _refreshFieldEcosystem();
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
          .getSelectableProducts(ownerKind: 'field', typeId: detail.fieldType.id);
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
      await _refreshFieldEcosystem();
      final deletedObsoleteCount =
          (result['deleted_obsolete_inventory_count'] as num?)?.toInt() ?? 0;
      final cleanupNote = deletedObsoleteCount > 0
          ? ' Eski bos kayitlardan $deletedObsoleteCount adet temizlendi.'
          : '';
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: slot.isEmpty
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
    List<Map<String, dynamic>> warehouses;
    try {
      warehouses = await ref
          .read(fieldActionProvider)
          .getEligibleWarehouseSlotsForInventoryAllCities(inventory: inventory);
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
    if (warehouses.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu hammadde icin uygun depo stogu bulunamadi.',
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
                              '${inventory.product?.urunAdi ?? inventory.productId} hammaddesi doldurulacak',
                          onConfirm: (quantity) async {
                            final warehouseCityId = (warehouse['city_id'] ?? '')
                                .toString();
                            if (_isSameCity(
                              warehouseCityId,
                              detail.field.cityId,
                            )) {
                              final result = await ref
                                  .read(fieldActionProvider)
                                  .transferWarehouseToProductionInventory(
                                    warehouseSlotId: slot['id'].toString(),
                                    productionInventoryId: inventory.id,
                                    quantity: quantity,
                                  );
                              if (!context.mounted) return;
                              if (result['success'] == true) {
                                await _refreshFieldEcosystem(
                                  includeTransfers: true,
                                );
                                AppSnackbar.show(
                                  context,
                                  title: 'Basarili',
                                  message:
                                      'Ayni sehir hammadde transferi tamamlandi.',
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
    List<ProductionLogisticsWarehouseOption> warehouses;
    try {
      warehouses = await ref
          .read(fieldActionProvider)
          .getWarehousesForProductionLogistics(
            productionCityId: detail.field.cityId,
            productId: inventory.productId,
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
    if (warehouses.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu urunu kabul eden aktif depon yok.',
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
                            await _refreshFieldEcosystem(
                              warehouseId: warehouseId,
                              includeTransfers: true,
                            );
                            AppSnackbar.show(
                              context,
                              title: 'Basarili',
                              message: inventory.isInput
                                  ? 'Ayni sehir hammadde iadesi tamamlandi.'
                                  : 'Ayni sehir uretilen urun transferi tamamlandi.',
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
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
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
    if (vehicleResult.options.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message:
            vehicleResult.unavailableReason ??
            'Bu transfer icin uygun arac bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: 'Hammadde Lojistigi',
      subtitle: '$quantity / $maxQuantity adet hammadde icin uygun araci secin',
      options: vehicleResult.options,
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
          await _refreshFieldEcosystem(includeTransfers: true);
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
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
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
    if (vehicleResult.options.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message:
            vehicleResult.unavailableReason ??
            'Bu transfer icin uygun arac bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: inventory.isInput
          ? 'Hammadde Iade Lojistigi'
          : 'Uretilen Urun Lojistigi',
      subtitle: inventory.isInput
          ? '$quantity adet hammadde iadesi icin uygun araci secin'
          : '$quantity adet uretilen urun icin uygun araci secin',
      options: vehicleResult.options,
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
          await _refreshFieldEcosystem(
            warehouseId: warehouseId,
            includeTransfers: true,
          );
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: inventory.isInput
                ? 'Hammadde iadesi icin arac yola cikti.'
                : 'Uretilen urun transferi icin arac yola cikti.',
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
    required Future<void> Function(String vehicleId) onSelected,
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
        child: ListView(
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
            SizedBox(height: 12.h),
            ...options.map(
              (option) => Container(
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: option.canSelect
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: ListTile(
                  enabled: option.canSelect,
                  onTap: option.canSelect
                      ? () async {
                          Navigator.pop(sheetContext);
                          await onSelected(option.vehicleId);
                        }
                      : null,
                  title: Text(
                    option.vehicleName,
                    style: TextStyle(
                      color: option.canSelect ? Colors.white : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    option.isRental
                        ? 'Kiralik | Kapasite ${option.capacity} | Maliyet ${option.totalPrice.toStringAsFixed(1)}'
                        : 'Kendi aracin | Kapasite ${option.capacity} | Maliyet ${option.totalPrice.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.sp,
                    ),
                  ),
                  trailing: option.canSelect
                      ? Icon(Icons.chevron_right, color: AppColors.gold, size: 18.sp)
                      : Icon(Icons.block, color: AppColors.textMuted, size: 18.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog({
    required BuildContext context,
    required int maxQuantity,
    required String title,
    required String subtitle,
    required Future<void> Function(int quantity) onConfirm,
  }) {
    final controller = TextEditingController(text: maxQuantity.toString());

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            child: const Text('Onayla', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  int _calculateUsedCapacity(List<ProductionInventoryModel> inventories) {
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

  Color _inputColorForProduct(String productId) {
    const palette = <Color>[
      Color(0xFF4FC3F7),
      Color(0xFF81C784),
      Color(0xFFFF8A65),
      Color(0xFFBA68C8),
      Color(0xFFFFD54F),
      Color(0xFF64B5F6),
    ];
    final hash = productId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[hash % palette.length];
  }

  bool _isSameCity(String warehouseCityId, String productionCityId) {
    return warehouseCityId.isNotEmpty && warehouseCityId == productionCityId;
  }

  String _estimateProductionPerHour(ProductionSlotModel slot) {
    final product = slot.product;
    if (product == null) return '0';
    final perHour = product.uretimAdedi * slot.boostMultiplier;
    return perHour.toStringAsFixed(perHour >= 10 ? 0 : 1);
  }

  Widget _buildQualityStars(int quality) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < quality;
        return Padding(
          padding: EdgeInsets.only(right: 2.w),
          child: Icon(
            isFilled ? Icons.star : Icons.star_border,
            color: isFilled ? AppColors.gold : AppColors.textMuted,
            size: 14.sp,
          ),
        );
      }),
    );
  }
}

class _ActiveFieldBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveFieldBoostCard({required this.boost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalSeconds = boost.finishAt.difference(boost.startedAt).inSeconds;
    final elapsedSeconds = now.difference(boost.startedAt).inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = boost.finishAt.difference(now);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.goldDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.goldDark.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: AppColors.goldDark,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boost Aktif',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${boost.durationHours} saat | Katsayi x${boost.multiplier.toStringAsFixed(1)} | ${boost.starCost} yildiz',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCountdownLabel(remaining),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.goldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFieldUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveFieldUpgradeCard({
    required this.upgrade,
    required this.onFinishWithGold,
    required this.calculateStarCost,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalSeconds = upgrade.finishAt.difference(upgrade.startedAt).inSeconds;
    final elapsedSeconds = now.difference(upgrade.startedAt).inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = upgrade.finishAt.difference(now);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.upgrade_rounded,
                  color: AppColors.green,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ciftlik Yukseltmesi Devam Ediyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Seviye ${upgrade.currentLevel} -> ${upgrade.targetLevel} | Hammadde ${upgrade.previousInputCapacity} -> ${upgrade.nextInputCapacity} | Cikti ${upgrade.previousOutputCapacity} -> ${upgrade.nextOutputCapacity}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCountdown(remaining),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
                foregroundColor: AppColors.goldLight,
              ),
              onPressed: onFinishWithGold,
              icon: const Icon(Icons.star_rounded),
              label: Text(
                '${calculateStarCost(upgrade.finishAt)} yildiz ile bitir',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCountdownLabel(Duration remaining) {
  if (remaining.inSeconds <= 0) return 'Tamamlaniyor';
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours > 0) {
    return '${hours}s ${minutes}dk';
  }
  return '${remaining.inMinutes}dk';
}

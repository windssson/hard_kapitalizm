import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';

class FarmDetailScreen extends ConsumerStatefulWidget {
  final String farmId;

  const FarmDetailScreen({super.key, required this.farmId});

  @override
  ConsumerState<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends ConsumerState<FarmDetailScreen> {
  @override
  void initState() {
    super.initState();
    _refreshOnEntry();
  }

  void _refreshOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(farmDetailProvider(widget.farmId));
      ref.read(farmDetailProvider(widget.farmId).future);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(farmDetailProvider(widget.farmId));

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    ref.invalidate(farmDetailProvider(widget.farmId));
                    await ref.read(farmDetailProvider(widget.farmId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 28.h),
                    children: [
                      _buildHero(detail),
                      SizedBox(height: 14.h),
                      _buildQuickActions(context, ref, detail),
                      SizedBox(height: 18.h),
                      _buildSectionHeader(
                        'Tarlalar',
                        'Tarlalar',
                        icon: Icons.tune_rounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      if (detail.slots.isEmpty)
                        _buildEmptyCard(
                          'Bu tarlada henuz aktif uretim slotu yok.',
                        )
                      else
                        ...detail.slots.map(
                          (slot) => _buildSlotCard(context, ref, detail, slot),
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

  Widget _buildHero(FarmDetailModel detail) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76.w,
                height: 76.w,
                padding: EdgeInsets.all(11.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(18.r),
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
                  fileName: detail.farmType.icon,
                  fit: BoxFit.contain,
                  errorWidget: Icon(
                    Icons.agriculture,
                    color: AppColors.green,
                    size: 36.sp,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.farm.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${detail.farmType.name}',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11.sp,
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
                                    fontSize: 12.sp,
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
                    SizedBox(width: 10.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildTag('Lv. ${detail.farm.level}', AppColors.gold),
                        SizedBox(height: 6.h),
                        _buildTag(
                          detail.farm.isActive ? 'AKTIF' : 'PASIF',
                          detail.farm.isActive
                              ? AppColors.green
                              : AppColors.red,
                        ),
                        SizedBox(height: 6.h),
                        _buildTag(
                          '${detail.farm.currentSlotCount}/${detail.farm.maxSlotCount} SLOT',
                          AppColors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  'Hammadde',
                  '${_calculateUsedCapacity(detail.inputInventories)}/${detail.farm.inputCapacity}',
                  AppColors.blue,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.inputInventories),
                    detail.farm.inputCapacity,
                  ),
                  icon: Icons.science_outlined,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildHeroStat(
                  'Uretilen urun',
                  '${_calculateUsedCapacity(detail.outputInventories)}/${detail.farm.outputCapacity}',
                  AppColors.green,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.outputInventories),
                    detail.farm.outputCapacity,
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
          SizedBox(height: 7.h),
          Container(
            height: 3.h,
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
    FarmDetailModel detail,
  ) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
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
              () => ref.invalidate(farmDetailProvider(detail.farm.id)),
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
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16.sp),
            SizedBox(height: 4.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10.sp,
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryPanel({
    required BuildContext context,
    required WidgetRef ref,
    required FarmDetailModel detail,
    required String title,
    required String caption,
    required Color progressColor,
    required double progressValue,
    required List<FarmProductionInventoryModel> inventories,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: progressColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            runSpacing: 8.h,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: progressColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Padding(
                padding: EdgeInsets.only(top: 5.h),
                child: Text(
                  caption,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _buildProgressBar(
            ratio: progressValue,
            color: progressColor,
            label: '%${(progressValue * 100).round()} dolu',
          ),
          SizedBox(height: 16.h),
          if (inventories.isEmpty)
            _buildEmptyCard('Bu alanda stok kaydi bulunmuyor.')
          else
            ...inventories.map(
              (inv) => _buildInventoryCard(context, ref, detail, inv),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required double ratio,
    required Color color,
    required String label,
  }) {
    return Container(
      height: 14.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999.r),
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.6), color],
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
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

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18.r),
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
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) {
    final slotActiveColor = slot.isActive ? AppColors.green : AppColors.red;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            slot.isEmpty
                                ? 'Bos Tarla ${slot.slotIndex}'
                                : (slot.product?.urunAdi ??
                                      slot.productId ??
                                      'Bilinmeyen Urun'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTag(
                              slot.isActive ? 'AKTIF' : 'PASIF',
                              slotActiveColor,
                            ),
                            SizedBox(width: 4.w),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              offset: const Offset(0, 40),
                              color: AppColors.cardBgLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
                              ),
                              child: Container(
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Icon(Icons.more_vert, color: AppColors.textMuted, size: 20.sp),
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
                                      Icon(Icons.category, color: AppColors.gold, size: 18.sp),
                                      SizedBox(width: 8.w),
                                      Text(
                                        slot.isEmpty ? 'Urun Sec' : 'Urun Degistir',
                                        style: TextStyle(color: Colors.white, fontSize: 13.sp),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        slot.isActive ? Icons.stop_circle : Icons.play_circle,
                                        color: slot.isActive ? AppColors.red : AppColors.green,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        slot.isActive ? 'Uretimi Durdur' : 'Uretime Basla',
                                        style: TextStyle(color: Colors.white, fontSize: 13.sp),
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
                    SizedBox(height: 6.h),
                    if (slot.isEmpty)
                      Text(
                        'Bu tarlada henuz urun secilmedi.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      _buildQualityStars(slot.qualityLevel),
                  ],
                ),
              ),
            ],
          ),
          if (!slot.isEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
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
            SizedBox(height: 12.h),
            _buildSlotFlowGroup(context, ref, detail, slot),
          ],
          // Action buttons moved to top-right menu
        ],
      ),
    );
  }

  Widget _buildSlotStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 92.w,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16.sp),
          SizedBox(height: 6.h),
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
      ),
    );
  }

  Widget _buildSlotFlowGroup(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) {
    final inputs = _inputInventoriesForSlot(detail, slot);
    final output = _outputInventoryForSlot(detail, slot);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMiniFlowHeader(
            'Hammaddeler',
            AppColors.blue,
            '${inputs.length} kayit',
          ),
          SizedBox(height: 8.h),
          if (inputs.isEmpty)
            _buildInlineEmptyState('Bu slot icin bagli hammadde kaydi yok.')
          else
            ...inputs.map(
              (inventory) => _buildSlotLinkedInventoryCard(
                context: context,
                ref: ref,
                detail: detail,
                inventory: inventory,
                accent: AppColors.blue,
              ),
            ),
          SizedBox(height: 12.h),
          _buildMiniFlowHeader(
            'Uretilen urun',
            AppColors.green,
            output == null ? 'Kayit yok' : 'Hazir',
          ),
          SizedBox(height: 8.h),
          if (output == null)
            _buildInlineEmptyState(
              'Bu slot icin bagli uretilen urun kaydi yok.',
            )
          else
            _buildSlotLinkedInventoryCard(
              context: context,
              ref: ref,
              detail: detail,
              inventory: output,
              accent: AppColors.green,
            ),
        ],
      ),
    );
  }

  Widget _buildMiniFlowHeader(String title, Color color, String badgeText) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
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
        _buildTag(badgeText, color),
      ],
    );
  }

  Widget _buildInlineEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
      ),
    );
  }

  Widget _buildSlotLinkedInventoryCard({
    required BuildContext context,
    required WidgetRef ref,
    required FarmDetailModel detail,
    required FarmProductionInventoryModel inventory,
    required Color accent,
  }) {
    final title = inventory.product?.urunAdi.isNotEmpty == true
        ? inventory.product!.urunAdi
        : inventory.productId;
    final maxCapacity = inventory.isInput
        ? detail.farm.inputCapacity
        : detail.farm.outputCapacity;
    final ratio = _inventoryRatio(inventory.quantity, maxCapacity);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
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
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: inventory.product?.urunIconu != null
                    ? CachedAssetImage(
                        fileName: inventory.product!.urunIconu,
                        fit: BoxFit.contain,
                      )
                    : Icon(Icons.inventory_2, color: accent, size: 18.sp),
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
                    Text(
                      'Kalite ${inventory.qualityLevel} / Bekleyen ${inventory.pendingQuantity.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${inventory.quantity}/$maxCapacity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          if (inventory.isInput)
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                SizedBox(
                  width: 132.w,
                  child: _buildMiniAction(
                    'Hammadde Getir',
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
                    'Geri Gonder',
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
            SizedBox(
              width: 132.w,
              child: _buildMiniAction(
                'Depoya Aktar',
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
      ),
    );
  }

  List<FarmProductionInventoryModel> _inputInventoriesForSlot(
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) {
    final product = slot.product;
    if (slot.isEmpty || product == null) return const [];

    final inputIds = <String>[
      if ((product.hammadde1Id ?? '').isNotEmpty) product.hammadde1Id!,
      if ((product.hammadde2Id ?? '').isNotEmpty) product.hammadde2Id!,
      if ((product.hammadde3Id ?? '').isNotEmpty) product.hammadde3Id!,
    ];

    final related = detail.inputInventories.where((inventory) {
      return inputIds.contains(inventory.productId);
    }).toList();

    related.sort((a, b) => a.productId.compareTo(b.productId));
    return related;
  }

  FarmProductionInventoryModel? _outputInventoryForSlot(
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
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

  Widget _buildInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
  ) {
    final title = inventory.product?.urunAdi.isNotEmpty == true
        ? inventory.product!.urunAdi
        : inventory.productId;
    final maxCapacity = inventory.isInput
        ? detail.farm.inputCapacity
        : detail.farm.outputCapacity;
    final ratio = _inventoryRatio(inventory.quantity, maxCapacity);
    final color = inventory.isInput ? AppColors.blue : AppColors.green;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.premiumCard(color, 18.r),
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
                    : Icon(Icons.inventory_2, color: color, size: 24.sp),
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
                        _buildTag(
                          inventory.isInput ? 'HAMMADDE' : 'URETILEN URUN',
                          color,
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Text(
                          'Kalite ${inventory.qualityLevel}',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' / Bekleyen: ${inventory.pendingQuantity.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
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
                '${inventory.quantity} / $maxCapacity',
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
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999.r),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          if (inventory.isInput)
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                SizedBox(
                  width: 146.w,
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
                SizedBox(
                  width: 146.w,
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
    FarmDetailModel detail,
  ) async {
    final result = await ref
        .read(farmActionProvider)
        .addProductionSlot(detail.farm.id);

    if (!context.mounted) return;
    if (result['success'] == true) {
      final _ = await ref.refresh(farmDetailProvider(detail.farm.id).future);
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
    final result = await ref
        .read(farmActionProvider)
        .setProductionSlotActive(slotId: slot.id, isActive: !slot.isActive);

    if (!context.mounted) return;
    if (result['success'] == true) {
      final _ = await ref.refresh(farmDetailProvider(detail.farm.id).future);
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
    List<SelectableProductionProductModel> products;
    try {
      products = await ref
          .read(farmActionProvider)
          .getSelectableProducts(ownerKind: 'farm', typeId: detail.farmType.id);
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
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
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
                      'Bu tarla turu icin uygun urun bulunamadi.',
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
                      final isDisabled = disabledProductIds.contains(
                        product.id,
                      );
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
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
    SelectableProductionProductModel selectableProduct,
  ) async {
    final product = selectableProduct.product;
    final action = ref.read(farmActionProvider);
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
      final _ = await ref.refresh(farmDetailProvider(detail.farm.id).future);
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
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(farmActionProvider)
        .getEligibleWarehouseSlotsForInventoryAllCities(inventory: inventory);

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
                              detail.farm.cityId,
                            )) {
                              final result = await ref
                                  .read(farmActionProvider)
                                  .transferWarehouseToProductionInventory(
                                    warehouseSlotId: slot['id'].toString(),
                                    productionInventoryId: inventory.id,
                                    quantity: quantity,
                                  );
                              if (!context.mounted) return;
                              if (result['success'] == true) {
                                final _ = await ref.refresh(
                                  farmDetailProvider(detail.farm.id).future,
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

                            await _startFarmLogisticsInputTransfer(
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
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
  ) async {
    final warehouses = await ref
        .read(farmActionProvider)
        .getWarehousesForProductionLogistics(
          productionCityId: detail.farm.cityId,
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
                              .read(farmActionProvider)
                              .transferProductionInventoryToWarehouse(
                                productionInventoryId: inventory.id,
                                warehouseId: warehouseId,
                                quantity: quantity,
                              );
                          if (!context.mounted) return;
                          if (result['success'] == true) {
                            final _ = await ref.refresh(
                              farmDetailProvider(detail.farm.id).future,
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

                        await _startFarmLogisticsOutputTransfer(
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

  Future<void> _startFarmLogisticsInputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FarmDetailModel detail,
    required FarmProductionInventoryModel inventory,
    required String warehouseSlotId,
    required int maxQuantity,
    required int quantity,
  }) async {
    List<ProductionLogisticsVehicleOption> options;
    try {
      options = await ref
          .read(farmActionProvider)
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
      title: 'Hammadde Lojistigi',
      subtitle: '$quantity / $maxQuantity adet hammadde icin uygun araci secin',
      options: options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(farmActionProvider)
            .startWarehouseToProductionTransfer(
              warehouseSlotId: warehouseSlotId,
              productionInventoryId: inventory.id,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          final _ = await ref.refresh(
            farmDetailProvider(detail.farm.id).future,
          );
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

  Future<void> _startFarmLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FarmDetailModel detail,
    required FarmProductionInventoryModel inventory,
    required String warehouseId,
    required int quantity,
  }) async {
    List<ProductionLogisticsVehicleOption> options;
    try {
      options = await ref
          .read(farmActionProvider)
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
      title: inventory.isInput
          ? 'Hammadde Iade Lojistigi'
          : 'Uretilen Urun Lojistigi',
      subtitle: inventory.isInput
          ? '$quantity adet hammadde iadesi icin uygun araci secin'
          : '$quantity adet uretilen urun icin uygun araci secin',
      options: options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(farmActionProvider)
            .startProductionToWarehouseTransfer(
              productionInventoryId: inventory.id,
              buyerWarehouseId: warehouseId,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          final _ = await ref.refresh(
            farmDetailProvider(detail.farm.id).future,
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
                  final color = option.canSelect
                      ? AppColors.green
                      : AppColors.red;
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
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                        ),
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
            child: const Text('Onayla', style: TextStyle(color: Colors.black)),
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

  double _inventoryRatio(int current, int capacity) {
    if (capacity <= 0) return 0.0;
    return (current / capacity).clamp(0.0, 1.0);
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

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
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';

class FactoryDetailScreen extends ConsumerStatefulWidget {
  final String factoryId;

  const FactoryDetailScreen({super.key, required this.factoryId});

  @override
  ConsumerState<FactoryDetailScreen> createState() =>
      _FactoryDetailScreenState();
}

class _FactoryDetailScreenState extends ConsumerState<FactoryDetailScreen> {
  static const Map<int, int> _factoryBoostStarCosts = {
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
      await ref.read(factoryActionProvider).completeDueBuildingBoosts();
      if (!mounted) return;
      await ref.read(factoryActionProvider).completeDueBuildingUpgrades();
      if (!mounted) return;
      _refreshFactoryDetail();
    });
  }

  void _refreshFactoryDetail() {
    ref.invalidate(factoryDetailProvider(widget.factoryId));
    ref.invalidate(activeFactoryBoostProvider(widget.factoryId));
    ref.invalidate(activeFactoryUpgradeProvider(widget.factoryId));
    ref.read(factoryDetailProvider(widget.factoryId).future);
    ref.read(activeFactoryBoostProvider(widget.factoryId).future);
    ref.read(activeFactoryUpgradeProvider(widget.factoryId).future);
  }

  Future<void> _refreshFactoryEcosystem({
    String? warehouseId,
    bool includeTransfers = false,
  }) async {
    _refreshFactoryDetail();
    ref.invalidate(factoryListProvider);
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

    await ref.read(factoryDetailProvider(widget.factoryId).future);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(factoryDetailProvider(widget.factoryId));
    final activeBoost = ref.watch(activeFactoryBoostProvider(widget.factoryId)).value;
    final activeUpgrade = ref.watch(
      activeFactoryUpgradeProvider(widget.factoryId),
    ).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    await ref.read(factoryActionProvider).completeDueBuildingBoosts();
                    if (!mounted) return;
                    await ref.read(factoryActionProvider).completeDueBuildingUpgrades();
                    if (!mounted) return;
                    _refreshFactoryDetail();
                    await ref.read(factoryDetailProvider(widget.factoryId).future);
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
                        _ActiveFactoryBoostCard(boost: activeBoost),
                      ],
                      if (activeUpgrade != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveFactoryUpgradeCard(
                          upgrade: activeUpgrade,
                          onFinishWithGold: () =>
                              _finishFactoryUpgradeWithGold(activeUpgrade),
                          calculateStarCost: _calculateUpgradeStarCost,
                          formatCountdown: _formatCountdown,
                        ),
                      ],
                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Uretim Hatti',
                        'Fabrikanin aktif urununu, hammadde akisini ve depoya sevklerini buradan yonetebilirsin.',
                        icon: Icons.precision_manufacturing_rounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      _buildProductionCard(context, ref, detail),
                      if (detail.orphanInputInventories.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _buildSectionHeader(
                          'Bagli Olmayan Hammaddeler',
                          'Urun degisikligi sonrasinda elde kalan hammaddeleri buradan depoya geri gonderebilirsin.',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.blue,
                        ),
                        SizedBox(height: 10.h),
                        ...detail.orphanInputInventories.map(
                          (inventory) => _buildInputInventoryCard(
                            context,
                            ref,
                            detail,
                            inventory,
                            isOrphan: true,
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

  Widget _buildHero(FactoryDetailModel detail) {
    final inputQty = detail.inputInventories.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final outputQty = detail.outputInventories.isNotEmpty
        ? detail.outputInventories.first.quantity
        : 0;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  fileName: detail.factoryType.icon,
                  fit: BoxFit.contain,
                  errorWidget: Icon(
                    Icons.precision_manufacturing_rounded,
                    color: AppColors.gold,
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
                            detail.factory.name,
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
                            detail.factoryType.name,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: AppColors.textMuted,
                                size: 14.sp,
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  detail.cityName,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
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
                    _buildTag('Lv ${detail.factory.level}', AppColors.gold),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildHeroStockSummary(
                  title: 'Hammadde',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.blue,
                  amountText: '$inputQty / ${detail.factory.inputCapacity}',
                  progress: _safeProgress(
                    inputQty.toDouble(),
                    detail.factory.inputCapacity.toDouble(),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildHeroStockSummary(
                  title: 'Uretilen urun',
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.green,
                  amountText: '$outputQty / ${detail.factory.outputCapacity}',
                  progress: _safeProgress(
                    outputQty.toDouble(),
                    detail.factory.outputCapacity.toDouble(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStockSummary({
    required String title,
    required IconData icon,
    required Color color,
    required String amountText,
    required double progress,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15.sp),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                amountText,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5.h,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    final hasProduct = detail.product != null;
    final canBoost = hasProduct && detail.factory.isActive;
    final canUpgrade = detail.factory.isActive;

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
              detail.factory.isActive ? 'Durdur' : 'Baslat',
              detail.factory.isActive
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              detail.factory.isActive ? AppColors.red : AppColors.green,
              hasProduct
                  ? () => _toggleFactoryActive(context, ref, detail)
                  : () {
                      AppSnackbar.show(
                        context,
                        title: 'Bilgi',
                        message:
                            'Uretimi baslatmadan once fabrikaya bir urun atamalisin.',
                        type: SnackbarType.info,
                      );
                    },
            ),
          ),
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              'Boost',
              Icons.flash_on_rounded,
              canBoost ? AppColors.goldDark : AppColors.textMuted,
              canBoost
                  ? () =>
                      _showFactoryBoostSheet(context, ref, detail, activeBoost)
                  : () {
                      AppSnackbar.show(
                        context,
                        title: 'Bilgi',
                        message:
                            hasProduct
                                ? 'Boost baslatmak icin fabrikanin aktif olmasi gerekir.'
                                : 'Boost baslatmadan once fabrikaya bir urun atamalisin.',
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
              canUpgrade ? AppColors.green : AppColors.textMuted,
              canUpgrade
                  ? () => _showFactoryUpgradeSheet(
                        context,
                        ref,
                        detail,
                        activeUpgrade,
                      )
                  : () {
                      AppSnackbar.show(
                        context,
                        title: 'Bilgi',
                        message:
                            'Yukseltme baslatmak icin fabrikanin aktif olmasi gerekir.',
                        type: SnackbarType.info,
                      );
                    },
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

  Widget _buildEmptyCard(String message, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          ),
          if (action != null) ...[
            SizedBox(height: 12.h),
            action,
          ],
        ],
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

  Widget _buildProductionCard(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) {
    if (detail.product == null) {
      return _buildEmptyCard(
        'Fabrikada henuz secili bir urun yok. Once urun secerek uretim hattini aktiflestir.',
        action: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _showProductDialog(context, ref, detail),
            icon: const Icon(Icons.category_outlined),
            label: const Text('Urun Sec'),
          ),
        ),
      );
    }

    final product = detail.product!;
    final outputInventory = detail.outputInventories.isNotEmpty
        ? detail.outputInventories.first
        : null;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(
        detail.factory.isActive ? AppColors.gold : null,
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
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: CachedAssetImage(
                  fileName: product.urunIconu,
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
                                product.urunAdi,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              _buildQualityStars(detail.factory.qualityLevel),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTag(
                              detail.factory.isActive ? 'AKTIF' : 'PASIF',
                              detail.factory.isActive
                                  ? AppColors.green
                                  : AppColors.red,
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
                                  _showProductDialog(context, ref, detail);
                                } else if (value == 'toggle') {
                                  _toggleFactoryActive(context, ref, detail);
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
                                        'Urun Degistir',
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
                                        detail.factory.isActive
                                            ? Icons.stop_circle
                                            : Icons.play_circle,
                                        color: detail.factory.isActive
                                            ? AppColors.red
                                            : AppColors.green,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        detail.factory.isActive
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
          SizedBox(height: 12.h),
          _buildOutputSummaryRow(context, ref, detail, outputInventory),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.textMuted, size: 14.sp),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Tahmini saatlik uretim: ${_estimateProductionPerHour(detail)}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.blue,
                size: 16.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Hammadde',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (detail.inputInventories.isEmpty)
            Text(
              'Bu urun icin hammadde stogu bulunmuyor.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
              ),
            )
          else ...[
            _buildSharedInputCapacityBar(detail),
            SizedBox(height: 10.h),
            ...detail.inputInventories.map(
              (inventory) => _buildInputInventoryCard(
                context,
                ref,
                detail,
                inventory,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSharedInputCapacityBar(FactoryDetailModel detail) {
    final capacity = detail.factory.inputCapacity;
    final totalStock = detail.inputInventories.fold<int>(
      0,
      (sum, inventory) => sum + inventory.quantity,
    );
    final totalPending = detail.inputInventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.pendingQuantity,
    );

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14.r),
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
          _buildFactorySegmentedCapacityBar(detail),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              ...detail.inputInventories.map(
                (inventory) => _buildCapacityLegendChip(
                  inventory.product?.urunAdi ?? inventory.productId,
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

  Widget _buildFactorySegmentedCapacityBar(FactoryDetailModel detail) {
    final capacity = detail.factory.inputCapacity;
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
    for (final inventory in detail.inputInventories) {
      if (inventory.quantity > 0) {
        segments.add((
          amount: inventory.quantity.toDouble(),
          color: _inputColorForProduct(inventory.productId),
        ));
      }
    }

    final totalPending = detail.inputInventories.fold<double>(
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

  Widget _buildOutputSummaryRow(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    FactoryProductionInventoryModel? inventory,
  ) {
    final quantity = inventory?.quantity ?? 0;
    final progress = _safeProgress(
      quantity.toDouble(),
      detail.factory.outputCapacity.toDouble(),
    );

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Uretilen urun stogu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: inventory != null && quantity > 0
                    ? () => _startInventoryToWarehouseFlow(
                        context,
                        ref,
                        detail,
                        inventory,
                      )
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue.withValues(alpha: 0.16),
                  foregroundColor: AppColors.blue,
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '$quantity / ${detail.factory.outputCapacity}',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.h,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    FactoryProductionInventoryModel inventory, {
    bool isOrphan = false,
  }) {
    final requiredAmount = isOrphan
        ? 0.0
        : _requiredAmountForInventory(detail, inventory.productId);
    final quantity = inventory.quantity;
    final pending = inventory.pendingQuantity;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: inventory.product?.urunIconu == null
                    ? Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textMuted,
                        size: 18.sp,
                      )
                    : CachedAssetImage(
                        fileName: inventory.product!.urunIconu,
                        fit: BoxFit.contain,
                      ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inventory.product?.urunAdi ?? inventory.productId,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    _buildQualityStars(inventory.qualityLevel),
                    SizedBox(height: 4.h),
                    Text(
                      isOrphan
                          ? 'Depoya geri gonderebilecegin bagimsiz hammadde'
                          : 'Tur basina gereken: ${requiredAmount.toStringAsFixed(requiredAmount % 1 == 0 ? 0 : 1)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: isOrphan
                    ? () => _startInventoryToWarehouseFlow(
                        context,
                        ref,
                        detail,
                        inventory,
                      )
                    : () => _startWarehouseToInventoryFlow(
                        context,
                        ref,
                        detail,
                        inventory,
                      ),
                icon: Icon(
                  isOrphan ? Icons.reply_all_rounded : Icons.add_box_outlined,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: (isOrphan ? AppColors.blue : AppColors.gold)
                      .withValues(alpha: 0.16),
                  foregroundColor:
                      isOrphan ? AppColors.blue : AppColors.goldLight,
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                    side: BorderSide(
                      color: (isOrphan ? AppColors.blue : AppColors.gold)
                          .withValues(alpha: 0.28),
                    ),
                  ),
                ),
                label: Text(
                  isOrphan ? 'Depoya Gonder' : 'Stok Ekle',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Stok: $quantity | Yoldaki urunler: ${pending.toStringAsFixed(pending % 1 == 0 ? 0 : 1)}',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _requiredAmountForInventory(
    FactoryDetailModel detail,
    String productId,
  ) {
    final product = detail.product;
    if (product == null) return 0;
    if (product.hammadde1Id == productId) return product.hammadde1Miktar ?? 0;
    if (product.hammadde2Id == productId) return product.hammadde2Miktar ?? 0;
    if (product.hammadde3Id == productId) return product.hammadde3Miktar ?? 0;
    return 0;
  }

  double _safeProgress(double current, double max) {
    if (max <= 0) return 0;
    return (current / max).clamp(0.0, 1.0);
  }

  String _estimateProductionPerHour(FactoryDetailModel detail) {
    final product = detail.product;
    if (product == null) return '-';
    final amount = product.uretimAdedi * detail.factory.boostMultiplier;
    return amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(1);
  }

  Widget _buildQualityStars(int qualityLevel) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < qualityLevel;
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

  Future<void> _showFactoryBoostSheet(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
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
              'Fabrika Boostu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              activeBoost != null
                  ? 'Bu fabrikada zaten aktif bir boost var. Sure dolana kadar uretim x${activeBoost.multiplier.toStringAsFixed(1)} hizla calisir.'
                  : 'Boost basladiginda fabrikanin uretim hizi sure boyunca 2 katina cikar.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            if (activeBoost == null)
              ..._factoryBoostStarCosts.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await ref
                          .read(factoryActionProvider)
                          .startFactoryBoost(
                            factoryId: detail.factory.id,
                            durationHours: entry.key,
                            starCost: entry.value,
                          );
                      if (!context.mounted) return;
                      if (result['success'] == true) {
                        ref.invalidate(activeFactoryBoostProvider(detail.factory.id));
                        ref.invalidate(factoryDetailProvider(detail.factory.id));
                        ref.invalidate(factoryListProvider);
                        ref.invalidate(playerStreamProvider);
                        AppSnackbar.show(
                          context,
                          title: 'Basarili',
                          message: 'Fabrika boostu baslatildi.',
                          type: SnackbarType.success,
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message:
                              result['message'] ?? 'Fabrika boostu baslatilamadi.',
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
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Katsayi x2.0',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: AppColors.gold,
                                size: 16.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${entry.value}',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              _buildEmptyCard(
                'Aktif boost bitene kadar yeni boost baslatilamaz.',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFactoryUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) {
        final nextLevel = detail.factory.level + 1;
        final nextInputCapacity = detail.factory.inputCapacity * 2;
        final nextOutputCapacity = detail.factory.outputCapacity * 2;
        final durationMinutes =
            detail.factoryType.constructionTimeMinutes * nextLevel;
        final upgradeCost = detail.factoryType.cost * nextLevel;

        return Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fabrika Yukseltmesi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                activeUpgrade != null
                    ? 'Bu fabrikada zaten devam eden bir yukseltme var.'
                    : 'Her seviye artisinda hammadde ve uretilen urun kapasitesi 2 katina cikar.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 16.h),
              if (activeUpgrade == null)
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seviye ${detail.factory.level} -> $nextLevel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'Hammadde kapasitesi: ${detail.factory.inputCapacity} -> $nextInputCapacity',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Uretilen urun kapasitesi: ${detail.factory.outputCapacity} -> $nextOutputCapacity',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Sure: ${durationMinutes} dk',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Maliyet: $upgradeCost TL',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            final result = await ref
                                .read(factoryActionProvider)
                                .startFactoryUpgrade(detail.factory.id);
                            if (!context.mounted) return;
                            if (result['success'] == true) {
                              ref.invalidate(
                                activeFactoryUpgradeProvider(detail.factory.id),
                              );
                              ref.invalidate(
                                factoryDetailProvider(detail.factory.id),
                              );
                              ref.invalidate(factoryListProvider);
                              ref.invalidate(playerStreamProvider);
                              AppSnackbar.show(
                                context,
                                title: 'Basarili',
                                message: 'Fabrika yukseltmesi baslatildi.',
                                type: SnackbarType.success,
                              );
                            } else {
                              AppSnackbar.show(
                                context,
                                title: 'Hata',
                                message:
                                    result['message'] ??
                                    'Fabrika yukseltmesi baslatilamadi.',
                                type: SnackbarType.error,
                              );
                            }
                          },
                          icon: const Icon(Icons.upgrade_rounded),
                          label: const Text('Yukseltmeyi Baslat'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildEmptyCard(
                  'Aktif yukseltme tamamlanmadan yeni bir yukseltme baslatilamaz.',
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishFactoryUpgradeWithGold(
    BuildingUpgradeModel upgrade,
  ) async {
    final result = await ref
        .read(factoryActionProvider)
        .finishFactoryUpgradeWithGold(upgrade.id);

    if (!mounted) return;

    if (result['success'] == true) {
      await _refreshFactoryEcosystem();
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Fabrika yukseltmesi tamamlandi.',
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
      await _refreshFactoryEcosystem();
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
      await _refreshFactoryEcosystem();
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
    List<Map<String, dynamic>> warehouses;
    try {
      warehouses = await ref
          .read(factoryActionProvider)
          .getEligibleWarehouseSlotsForInventoryAllCities(
            inventory: inventory,
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
                              '${inventory.product?.urunAdi ?? inventory.productId} hammaddesi aktarilacak',
                          onConfirm: (quantity) async {
                            final warehouseCityId =
                                (warehouse['city_id'] ?? '').toString();
                            if (_isSameCity(
                              warehouseCityId,
                              detail.factory.cityId,
                            )) {
                              final result = await ref
                                  .read(factoryActionProvider)
                                  .transferWarehouseToProductionInventory(
                                    warehouseSlotId: slot['id'].toString(),
                                    productionInventoryId: inventory.id,
                                    quantity: quantity,
                                  );
                              if (!context.mounted) return;
                              if (result['success'] == true) {
                                await _refreshFactoryEcosystem();
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
          productId: inventory.productId,
        );

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
                              .read(factoryActionProvider)
                              .transferProductionInventoryToWarehouse(
                                productionInventoryId: inventory.id,
                                warehouseId: warehouseId,
                                quantity: quantity,
                              );
                          if (!context.mounted) return;
                          if (result['success'] == true) {
                            await _refreshFactoryEcosystem(
                              warehouseId: warehouseId,
                            );
                            AppSnackbar.show(
                              context,
                              title: 'Basarili',
                              message: inventory.isInput
                                  ? 'Ayni sehir hammadde iadesi tamamlandi.'
                                  : 'Ayni sehir urun transferi tamamlandi.',
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
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
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
            .read(factoryActionProvider)
            .startWarehouseToProductionTransfer(
              warehouseSlotId: warehouseSlotId,
              productionInventoryId: inventory.id,
              quantity: quantity,
              vehicleId: vehicleId,
            );
        if (!context.mounted) return;
        if (result.success) {
          await _refreshFactoryEcosystem(includeTransfers: true);
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
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
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
      title: inventory.isInput ? 'Hammadde Iade Lojistigi' : 'Urun Lojistigi',
      subtitle: inventory.isInput
          ? '$quantity adet hammadde iadesi icin uygun araci secin'
          : '$quantity adet urun icin uygun araci secin',
      options: vehicleResult.options,
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
          await _refreshFactoryEcosystem(
            warehouseId: warehouseId,
            includeTransfers: true,
          );
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: inventory.isInput
                ? 'Hammadde iadesi icin arac yola cikti.'
                : 'Urun transferi icin arac yola cikti.',
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

class _ActiveFactoryBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveFactoryBoostCard({required this.boost});

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

class _ActiveFactoryUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveFactoryUpgradeCard({
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
                      'Fabrika Yukseltmesi Devam Ediyor',
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

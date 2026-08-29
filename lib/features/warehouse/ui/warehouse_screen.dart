import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/rewarded_time_reduce_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  final int _selectedIndex = -1;

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/company');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 3:
        context.go('/market');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehouseListProvider);
    final currentBrandName = ref
        .watch(playerBrandCompanyProvider)
        .value
        ?.brandName;

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/warehouses/new/city'),
        backgroundColor: AppColors.gold,
        icon: Icon(AppIcons.addHomeWork, color: AppColors.textOnAccent),
        label: Text(
          'Yeni Depo',
          style: AppTextStyles.button.standardCopyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Depolarım'),
            Expanded(
              child: warehousesAsync.when(
                data: (warehouses) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(warehouseListProvider.notifier).refresh(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                          sliver: SliverToBoxAdapter(
                            child: _buildStatsHeader(warehouses),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(5.w, 16.h, 5.w, 80.h),
                          sliver: warehouses.isEmpty
                              ? SliverToBoxAdapter(
                                  child: _buildEmptyState(
                                    hasAnyWarehouse: warehouses.isNotEmpty,
                                  ),
                                )
                              : SliverList.builder(
                                  itemCount: warehouses.length,
                                  itemBuilder: (context, index) {
                                    final warehouse = warehouses[index];
                                    return warehouse.isUnderConstruction
                                        ? _buildConstructionCard(warehouse)
                                        : _buildWarehouseCard(
                                            warehouse,
                                            currentBrandName,
                                          );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (error, stack) => _buildErrorState(error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(List<WarehouseModel> warehouses) {
    final activeCount = warehouses
        .where((warehouse) => warehouse.isActive)
        .length;
    final totalCapacity = warehouses.fold(
      0.0,
      (sum, warehouse) => sum + warehouse.capacity,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(null, 12.r),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatItem(
              AppIcons.warehouse,
              AppColors.gold,
              'Depo',
              warehouses.length.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.checkCircle,
              AppColors.green,
              'Aktif',
              activeCount.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.storage,
              AppColors.blue,
              'Kapasite',
              _formatCapacity(totalCapacity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: AppIconSizes.compact),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.caption,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarehouseCard(
    WarehouseModel warehouse,
    String? currentBrandName,
  ) {
    final filledSlots = warehouse.slots.where((slot) => !slot.isEmpty).toList();
    final usedStockCapacity = filledSlots.fold<double>(
      0,
      (sum, slot) => sum + (slot.quantity * slot.unitVolume),
    );
    final ratio = warehouse.capacity > 0
        ? ((usedStockCapacity + warehouse.reservedCapacity) /
                  warehouse.capacity)
              .clamp(0.0, 1.0)
        : 0.0;
    final isCritical = ratio >= 0.85;

    return GestureDetector(
      onTap: () => context.go('/warehouses/${warehouse.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(12.w),
        decoration: AppDecorations.premiumCard(
          isCritical ? AppColors.red : null,
          16.r,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 90.w,
                  height: 90.w,
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isCritical
                            ? AppColors.red.withValues(alpha: 0.12)
                            : AppColors.gold.withValues(alpha: 0.08),
                        AppFx.panelWash(0.32),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isCritical
                          ? AppColors.red.withValues(alpha: 0.4)
                          : AppColors.gold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: CachedAssetImage(
                    fileName: warehouse.typeIcon ?? 'depolar.webp',
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  width: 90.w,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.locationOn,
                        color: isCritical ? AppColors.red : AppColors.gold,
                        size: AppIconSizes.xSmall,
                      ),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          warehouse.cityName ?? 'Bilinmiyor',
                          style: AppTextStyles.body.standardCopyWith(
                            color: isCritical ? AppColors.red : AppColors.gold,
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          warehouse.name,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.title,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Wrap(
                        spacing: 4.w,
                        runSpacing: 4.h,
                        children: [
                          if (isCritical)
                            _buildSmallBadge(
                              '⚠️ %${(ratio * 100).toInt()} Dolu',
                              AppColors.red,
                            ),
                          _buildSmallBadge(
                            'Lv. ${warehouse.level}',
                            AppColors.gold,
                          ),
                          _buildSmallBadge(
                            warehouse.isActive ? 'Aktif' : 'Pasif',
                            warehouse.isActive
                                ? AppColors.green
                                : AppColors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _buildProgressBar(ratio),
                  SizedBox(height: 12.h),
                  filledSlots.isEmpty
                      ? Text(
                          'Boş Depo',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.label,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : SizedBox(
                          height: 52.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: filledSlots.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(width: 8.w),
                            itemBuilder: (context, index) => _buildMiniSlot(
                              filledSlots[index],
                              currentBrandName,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSlot(WarehouseSlotModel slot, String? currentBrandName) {
    if (slot.isEmpty) return const SizedBox();

    return SizedBox(
      width: 50.w,
      height: 50.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderGoldLight.withValues(alpha: 0.18),
              ),
            ),
          ),
          Container(
            width: 40.w,
            height: 40.w,
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: BrandedProductImage(
              fileName: slot.productIcon ?? 'default.webp',
              brandId: slot.brandId,
              brandName: _brandNameForSlot(slot, currentBrandName),
              productId: slot.productId,
              fit: BoxFit.contain,
              showFrame: false,
            ),
          ),
        ],
      ),
    );
  }

  String? _brandNameForSlot(WarehouseSlotModel slot, String? currentBrandName) {
    if (slot.brandId == '00000000-0000-0000-0000-000000000000') return null;
    return currentBrandName;
  }

  Widget _buildProgressBar(double ratio) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kapasite Kullanımı',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.caption,
              ),
            ),
            Text(
              '%${(ratio * 100).toInt()}',
              style: AppTextStyles.label.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.label,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: AppProgressBar(
            value: ratio,
            minHeight: 6.h,
            backgroundColor: AppFx.panelWash(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio > 0.9
                  ? AppColors.red
                  : ratio > 0.7
                  ? AppColors.warning
                  : AppColors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildConstructionCard(WarehouseModel warehouse) {
    final finishAt = warehouse.finishAt;
    final starCost = finishAt == null
        ? 0
        : _calculateStarCost(finishAt.toLocal());

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: starCost > 0 ? 0 : 16.h),
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.gold, 16.r),
          child: Row(
            children: [
              Container(
                width: 70.w,
                height: 70.w,
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  AppIcons.construction,
                  color: AppColors.gold,
                  size: AppIconSizes.xLarge,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warehouse.name,
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      warehouse.cityName ?? 'Bilinmeyen Şehir',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.bodySmall,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    if (finishAt != null)
                      _ConstructionCountdown(
                        finishAt: finishAt,
                        onFinish: () async {
                          final result = await ref
                              .read(warehouseActionProvider)
                              .completeConstruction(warehouse.id);
                          if (result['success'] == true) {
                            await ref
                                .read(warehouseListProvider.notifier)
                                .refresh();
                            if (mounted) {
                              await showExperienceFeedbackFromResult(
                                context,
                                result,
                              );
                            }
                          }
                        },
                      )
                    else
                      Text(
                        'İnşaat verisi güncelleniyor...',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.bodySmall,
                        ),
                      ),
                    if (finishAt != null) ...[
                      SizedBox(height: 10.h),
                      RewardedTimeReduceButton(
                        onPressed: () =>
                            _handleReduceConstructionTimeWithAd(warehouse.id),
                        caption:
                            'Bir reklam ödülü al ve depo inşaat süresini 10 dakika kısalt.',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (starCost > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: GoldFinishButton(
              starCost: starCost,
              onPressed: () => _handleQuickFinish(warehouse.id, starCost),
            ),
          ),
      ],
    );
  }

  int _calculateStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  Future<void> _handleQuickFinish(String id, int starCost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Depo İnşaatını Bitir',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.goldLight,
            fontSize: AppTypography.titleLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$starCost yıldız kullanarak depo inşaatını anında tamamlamak istiyor musunuz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Tamamla',
              style: AppTextStyles.button.standardCopyWith(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ref
        .read(warehouseActionProvider)
        .finishConstructionWithGold(id);

    if (result['success'] == true) {
      await ref.read(warehouseListProvider.notifier).refresh();
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Başarılı',
          message: 'Depo inşaatı anında tamamlandı!',
          type: SnackbarType.success,
        );
        await showExperienceFeedbackFromResult(context, result);
      }
    } else if (mounted) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Altın ile bitirme işlemi başarısız.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _handleReduceConstructionTimeWithAd(
    String constructionId,
  ) async {
    Map<String, dynamic>? rpcResult;
    final success = await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'construction_time_reduce',
      resourceId: constructionId,
      onApplyReduction: () async {
        final res = await ref
            .read(warehouseActionProvider)
            .reduceConstructionTimeWithAd(
              constructionId,
              syncProviders: false,
            );
        rpcResult = res;
        return res;
      },
      successMessage: 'İnşaat süresi 10 dakika kısaltıldı.',
    );

    if (success) {
      if (rpcResult != null && rpcResult!['new_finish_at'] != null) {
        final newFinishAt =
            DateTime.tryParse(rpcResult!['new_finish_at'].toString());
        if (newFinishAt != null) {
          ref
              .read(warehouseListProvider.notifier)
              .patchConstructionFinishAt(
                warehouseId: constructionId,
                finishAt: newFinishAt,
              );
          return;
        }
      }
      await ref.read(warehouseListProvider.notifier).refresh();
    }
  }

  Widget _buildEmptyState({required bool hasAnyWarehouse}) {
    final title = hasAnyWarehouse
        ? 'Seçili filtreye uygun depo bulunamadı.'
        : 'Henuz deponuz bulunmuyor.';

    return Center(
      child: Column(
        children: [
          SizedBox(height: 100.h),
          Icon(
            AppIcons.warehouseOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.emptyState,
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.title,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.errorOutline,
              color: AppColors.red,
              size: AppIconSizes.displayLarge,
            ),
            SizedBox(height: 12.h),
            Text(
              'Depo listesi yüklenemedi.',
              textAlign: TextAlign.center,
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCapacity(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M m3';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K m3';
    return '${value.toStringAsFixed(0)} m3';
  }
}

class _ConstructionCountdown extends ConsumerStatefulWidget {
  final DateTime finishAt;
  final VoidCallback onFinish;

  const _ConstructionCountdown({
    required this.finishAt,
    required this.onFinish,
  });

  @override
  ConsumerState<_ConstructionCountdown> createState() =>
      _ConstructionCountdownState();
}

class _ConstructionCountdownState
    extends ConsumerState<_ConstructionCountdown> {
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final timeLeft = widget.finishAt.difference(now);

    if (timeLeft.isNegative || timeLeft.inSeconds <= 0) {
      if (!_triggered) {
        _triggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onFinish();
        });
      }
      return const Text('Tamamlanıyor...');
    }

    final h = timeLeft.inHours.toString().padLeft(2, '0');
    final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final s = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      'Kalan Süre: $h:$m:$s',
      style: AppTextStyles.body.standardCopyWith(
        color: AppColors.gold,
        fontSize: AppTypography.body,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

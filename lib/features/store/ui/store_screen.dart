import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
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
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  static const String _defaultBrandId = '00000000-0000-0000-0000-000000000000';
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
    final storesAsync = ref.watch(storesListProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/store/new/city'),
        backgroundColor: AppColors.gold,
        icon: Icon(AppIcons.addBusiness, color: AppColors.textOnAccent),
        label: Text(
          'Magaza Kur',
          style: AppTextStyles.button.standardCopyWith(
            color: AppColors.textOnAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Magazalarim'),
            Expanded(
              child: storesAsync.when(
                data: (stores) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(storesListProvider.notifier).refresh(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(6.w, 12.h, 6.w, 0),
                          sliver: SliverToBoxAdapter(
                            child: _buildStatsHeader(stores),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(5.w, 16.h, 5.w, 40.h),
                          sliver: stores.isEmpty
                              ? SliverToBoxAdapter(child: _buildEmptyState())
                              : SliverList.builder(
                                  itemCount: stores.length,
                                  itemBuilder: (context, index) {
                                    final store = stores[index];
                                    return TweenAnimationBuilder<double>(
                                      duration: Duration(
                                        milliseconds:
                                            300 + (index * 100).clamp(0, 600),
                                      ),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(begin: 0, end: 1),
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.translate(
                                            offset: Offset(0, 30 * (1 - value)),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: store.isUnderConstruction
                                          ? _buildConstructionCard(store)
                                          : _buildAdvancedStoreCard(store),
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
                error: (error, stack) => Center(
                  child: Text(
                    'Hata: $error',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(List<StoreModel> stores) {
    final int activeCount = stores.where((s) => s.isActive).length;
    final int totalCapacity = stores.fold(
      0,
      (sum, s) => sum + s.summary.totalCapacity,
    );

    String formattedCapacity = totalCapacity >= 1000
        ? '${(totalCapacity / 1000).toStringAsFixed(1)}K'
        : totalCapacity.toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(null, 12.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            AppIcons.store,
            AppColors.gold,
            'Toplam',
            stores.length.toString(),
            AppColors.textPrimary,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            AppIcons.trendingUp,
            AppColors.green,
            'Aktif',
            activeCount.toString(),
            AppColors.green,
          ),
          Container(width: 1, height: 40.h, color: AppColors.border),
          _buildStatItem(
            AppIcons.inventory2,
            AppColors.info,
            'Kapasite',
            formattedCapacity,
            AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: AppIconSizes.medium),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.label,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.h2.standardCopyWith(
                color: valueColor,
                fontSize: AppTypography.titleLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConstructionCard(StoreModel store) {
    final finishAt = store.finishAt;
    final starCost = finishAt == null
        ? 0
        : _calculateStarCost(finishAt.toLocal());

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: starCost > 0 ? 0 : 10.h),
          padding: EdgeInsets.all(8.w),
          decoration: AppDecorations.premiumCard(
            AppColors.gold.withValues(alpha: 0.4),
            24.r,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 115.w,
                height: 115.w,
                decoration: BoxDecoration(
                  color: AppColors.transparent,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 0.8,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: CachedAssetImage(
                          fileName: store.storeType.icon,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Icon(
                      AppIcons.construction,
                      color: AppColors.gold,
                      size: AppIconSizes.displayLarge,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: store.name,
                            style: AppTextStyles.h1.standardCopyWith(
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.titleLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' - ${store.cityName ?? "Bilinmeyen"}',
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.gold.withValues(alpha: 0.7),
                              fontSize: AppTypography.bodyLarge,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    if (finishAt != null)
                      _ConstructionCountdown(
                        startedAt: store.startedAt ?? DateTime.now(),
                        finishAt: finishAt,
                        onFinish: () async {
                          final result = await ref
                              .read(storeActionProvider)
                              .completeConstruction(store.id);
                          if (mounted && result['success'] == true) {
                            await showExperienceFeedbackFromResult(
                              context,
                              result,
                            );
                          }
                          await ref.read(storesListProvider.notifier).refresh();
                        },
                      )
                    else
                      Text(
                        'Insaat verisi guncelleniyor...',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.body,
                        ),
                      ),
                    if (finishAt != null) ...[
                      SizedBox(height: 10.h),
                      RewardedTimeReduceButton(
                        onPressed: () =>
                            _handleReduceConstructionTimeWithAd(store.id),
                        caption:
                            'Bir reklam odulu al ve magaza insaat suresini 10 dakika kisalt.',
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
            padding: EdgeInsets.only(bottom: 10.h),
            child: GoldFinishButton(
              starCost: starCost,
              onPressed: () => _handleQuickFinish(store.id, starCost),
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

  Future<void> _handleQuickFinish(String constructionId, int starCost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Insaati Bitir',
          style: AppTextStyles.title.standardCopyWith(
            color: AppColors.goldLight,
            fontSize: AppTypography.titleLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$starCost ⭐ yildiz kullanarak insaati aninda tamamlamak istiyor musunuz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Iptal',
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

    if (confirm != true || !mounted) return;

    final result = await ref
        .read(storeActionProvider)
        .finishConstructionWithGold(constructionId);
    if (result['success'] == true) {
      await ref.read(storesListProvider.notifier).refresh();
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Tamamlandi',
          message: 'Insaat basariyla tamamlandi!',
          type: SnackbarType.success,
        );
        await showExperienceFeedbackFromResult(context, result);
      }
    } else {
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message:
              result['message']?.toString() ??
              'Altin ile aninda tamamlama basarisiz oldu. Altin bakiyeni kontrol edip tekrar dene.',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handleReduceConstructionTimeWithAd(
    String constructionId,
  ) async {
    final success = await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'construction_time_reduce',
      resourceId: constructionId,
      onApplyReduction: () => ref
          .read(storeActionProvider)
          .reduceConstructionTimeWithAd(constructionId),
      successMessage: 'Insaat suresi 10 dakika kisaltildi.',
    );

    if (success) {
      await ref.read(storesListProvider.notifier).refresh();
      ref.invalidate(playerBrandCompanyProvider);
    }
  }

  Widget _buildAdvancedStoreCard(StoreModel store) {
    final double stockCost = store.summary.totalStockCostValue ?? 0.0;
    final double stockSale = store.summary.totalStockSaleValue ?? 0.0;
    final double potentialProfit = stockSale - stockCost;
    final bool allSlotsEmpty = store.slots.every((s) => s.isEmpty);
    final bool anySlotOutOfStock = store.slots.any((s) => !s.isEmpty && s.quantity == 0);

    return GestureDetector(
      onTap: () => context.go('/store/${store.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: AppDecorations.premiumCard(AppColors.borderGold, 20.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT COLUMN
            Column(
              children: [
                Container(
                  width: 90.w,
                  height: 90.w,
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: AppColors.cardBgLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: CachedAssetImage(
                    fileName: store.storeType.icon,
                    width: 90.w,
                    height: 90.w,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.locationOn,
                      color: AppColors.gold,
                      size: AppIconSizes.xxSmall,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      store.cityName ?? 'Bilinmiyor',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.bodySmall,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 12.w),
            // MIDDLE & RIGHT COLUMNS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.name,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.title,
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
                          _buildSmallBadge(
                            'Lv. ${store.level}',
                            AppColors.gold,
                          ),
                          SizedBox(width: 6.w),
                          _buildSmallBadge(
                            store.isActive ? 'Aktif' : 'Pasif',
                            store.isActive ? AppColors.green : AppColors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: AppProgressBar(
                            value: store.summary.usedCapacityRatio.clamp(
                              0.0,
                              1.0,
                            ),
                            minHeight: 10.h,
                            backgroundColor: AppColors.textPrimary.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              store.summary.usedCapacityRatio >= 0.85
                                  ? AppColors.red
                                  : AppColors.green,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        '%${(store.summary.usedCapacityRatio * 100).round()}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: store.summary.usedCapacityRatio >= 0.85
                              ? AppColors.red
                              : AppColors.green,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.inventory2Outlined,
                            color: AppColors.textMuted,
                            size: 11.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Stok: ${AppMoney.compact(stockSale)}',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.bodySmall,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(width: 1.w, height: 12.h, color: AppColors.border.withValues(alpha: 0.5)),
                          SizedBox(width: 8.w),
                          Icon(
                            AppIcons.trendingUp,
                            color: potentialProfit > 0 ? AppColors.green : AppColors.textMuted,
                            size: 11.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Kâr: ${AppMoney.compact(potentialProfit, signed: true)}',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: potentialProfit > 0 ? AppColors.green : AppColors.textMuted,
                              fontSize: AppTypography.bodySmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (allSlotsEmpty)
                            _buildSmallBadge('Boş Mağaza', AppColors.orange)
                          else if (anySlotOutOfStock)
                            _buildSmallBadge('Stok Tükendi', AppColors.red),
                        ],
                      ),
                    ],
                  ),
                  if (store.slots.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: store.slots
                            .map((slot) => _buildSlotItem(slot))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotItem(StoreSlotModel slot) {
    final currentBrandName = ref
        .watch(playerBrandCompanyProvider)
        .value
        ?.brandName;
    final double fillRatio = slot.capacity > 0
        ? (slot.quantity / slot.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: EdgeInsets.only(right: 8.w),
      width: 44.w,
      height: 44.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!slot.isEmpty && slot.isActive) ...[
            AppProgressRing.stock(
              value: fillRatio,
              diameter: 44.w,
              strokeWidth: 2.2.w,
              semanticsLabel: 'Slot stok dolulugu',
            ),
          ] else
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.borderGoldLight.withValues(alpha: 0.18),
                ),
              ),
            ),
          Container(
            width: 32.w,
            height: 32.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: slot.isEmpty
                ? Icon(
                    AppIcons.add,
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    size: AppIconSizes.regular,
                  )
                : BrandedProductImage(
                    fileName: slot.productIcon ?? 'default.webp',
                    brandId: slot.brandId,
                    brandName: slot.brandId == _defaultBrandId
                        ? null
                        : currentBrandName,
                    productId: slot.productId,
                    fit: BoxFit.contain,
                    showFrame: false,
                  ),
          ),
          // Pasif indicator
          if (!slot.isEmpty && !slot.isActive)
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppFx.panelWash(0.62),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  AppIcons.pause,
                  color: AppColors.red,
                  size: AppIconSizes.regular,
                ),
              ),
            ),
          // Quality badge overlay
          if (!slot.isEmpty && slot.qualityLevel > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.star,
                      color: AppColors.gold,
                      size: 8.sp,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      slot.qualityLevel.toString(),
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.micro,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 60.h),
          Icon(
            AppIcons.storeOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.showcase,
          ),
          SizedBox(height: 16.h),
          Text(
            'Henuz bir magazan yok.',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstructionCountdown extends ConsumerStatefulWidget {
  final DateTime startedAt;
  final DateTime finishAt;
  final VoidCallback? onFinish;

  const _ConstructionCountdown({
    required this.startedAt,
    required this.finishAt,
    this.onFinish,
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
    final totalDuration = widget.finishAt
        .difference(widget.startedAt)
        .inSeconds;
    final elapsed = now.difference(widget.startedAt).inSeconds;
    final double progress = totalDuration > 0
        ? (elapsed / totalDuration).clamp(0.0, 1.0)
        : 1.0;

    final remaining = widget.finishAt.difference(now);

    String getTimeStr() {
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        if (!_triggered) {
          _triggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onFinish?.call();
          });
        }
        return 'Tamamlaniyor...';
      }
      final minutes = remaining.inMinutes;
      final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    final String timeStr = getTimeStr();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: AppProgressBar(
                  value: progress,
                  backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                  minHeight: 8.h,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              '%${(progress * 100).toInt()}',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.gold,
                fontSize: AppTypography.body,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Icon(
              AppIcons.timerOutlined,
              color: AppColors.textMuted,
              size: AppIconSizes.small,
            ),
            SizedBox(width: 6.w),
            Text(
              'Kalan: ',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.body,
              ),
            ),
            Text(
              timeStr,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

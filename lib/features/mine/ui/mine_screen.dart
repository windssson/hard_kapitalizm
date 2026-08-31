import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/construction_countdown_card.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';

class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});

  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen>
    with RouteRefreshMixin<MineScreen> {
  final int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void refreshRouteData() {
    ref.read(mineListProvider.notifier).refresh();
    ref.invalidate(mineConstructionProvider);
    ref.read(mineConstructionProvider.future);
  }

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

  Future<void> _refreshAll() async {
    ref.invalidate(mineConstructionProvider);
    await Future.wait([
      ref.read(mineListProvider.notifier).refresh(),
      ref.read(mineConstructionProvider.future),
      ref.read(playerProvider.future),
    ]);
  }

  Future<void> _completeConstruction(String constructionId) async {
    final result = await ref
        .read(mineActionProvider)
        .completeConstruction(constructionId, syncProviders: false);

    ref.invalidate(mineConstructionProvider);
    ref.invalidate(mineListProvider);

    if (!mounted) return;
    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message'] ?? 'Maden inşaatı tamamlanamadı.',
        type: SnackbarType.error,
      );
      return;
    }

    await showExperienceFeedbackFromResult(context, result);
  }

  Future<void> _finishConstructionWithGold(String constructionId) async {
    final result = await ref
        .read(mineActionProvider)
        .finishConstructionWithGold(constructionId, syncProviders: false);

    ref.invalidate(mineConstructionProvider);
    ref.invalidate(mineListProvider);

    if (!mounted) return;
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Tamamlandı',
        message: 'İnşaat anında tamamlandı.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yıldız ile bitirme başarısız oldu.',
      type: SnackbarType.error,
    );
  }

  Future<void> _reduceConstructionTimeWithAd(String constructionId) async {
    await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'construction_time_reduce',
      resourceId: constructionId,
      onApplyReduction: () => ref
          .read(mineActionProvider)
          .reduceConstructionTimeWithAd(constructionId),
      successMessage: 'İnşaat süresi 10 dakika kısaltıldı.',
    );
  }

  int _calculateStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  @override
  Widget build(BuildContext context) {
    final minesAsync = ref.watch(mineListProvider);
    final constructionAsync = ref.watch(mineConstructionProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mines/new/city'),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.textOnAccent,
        extendedPadding: EdgeInsets.symmetric(horizontal: 14.w),
        icon: Icon(AppIcons.add, size: AppIconSizes.compact),
        label: Text(
          'YENİ MADEN',
          style: AppTextStyles.button.standardCopyWith(
            fontWeight: FontWeight.bold,
            fontSize: AppTypography.bodySmall,
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Madenlerim'),
            Expanded(
              child: minesAsync.when(
                data: (mines) => constructionAsync.when(
                  data: (construction) {
                    return RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 0),
                            sliver: SliverToBoxAdapter(
                              child: _buildStatsHeader(mines),
                            ),
                          ),
                          if (construction != null)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(10.w, 16.h, 10.w, 0),
                              sliver: SliverToBoxAdapter(
                                child: _buildConstructionCard(construction),
                              ),
                            ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              10.w,
                              16.h,
                              10.w,
                              80.h,
                            ),
                            sliver: mines.isEmpty
                                ? SliverToBoxAdapter(
                                    child: construction == null
                                        ? _buildEmptyState()
                                        : const SizedBox.shrink(),
                                  )
                                : SliverList.builder(
                                    itemCount: mines.length,
                                    itemBuilder: (context, index) {
                                      return _buildMineCard(
                                        mines[index],
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
                  error: (error, stack) => _buildErrorState(
                    error,
                    onRetry: () => ref.refresh(mineConstructionProvider),
                  ),
                ),
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (error, stack) => _buildErrorState(
                  error,
                  onRetry: () => ref.refresh(mineListProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstructionCard(Map<String, dynamic> construction) {
    final finishAtRaw = construction['finish_at'];
    final finishAt = DateTime.tryParse(finishAtRaw?.toString() ?? '');
    final constructionId = construction['id']?.toString();
    final name = construction['name']?.toString();

    if (finishAt == null || constructionId == null) {
      return const SizedBox.shrink();
    }

    final starCost = _calculateStarCost(finishAt.toLocal());

    return Column(
      children: [
        ConstructionCountdownCard(
          title: name?.isNotEmpty == true ? name! : 'Yeni Maden',
          subtitle: 'Maden inşaatı devam ediyor',
          finishAt: finishAt.toLocal(),
          icon: AppIcons.diamondOutlined,
          onFinished: () => _completeConstruction(constructionId),
          onReduceTimeWithAd: () =>
              _reduceConstructionTimeWithAd(constructionId),
        ),
        if (starCost > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: GoldFinishButton(
              starCost: starCost,
              onPressed: () => _finishConstructionWithGold(constructionId),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsHeader(List<MineListItemModel> mines) {
    final activeCount = mines.where((item) => item.mine.isActive).length;
    final assignedCount = mines.where((item) => item.hasSelectedProduct).length;
    final totalOutputStock = mines.fold<int>(
      0,
      (sum, item) => sum + item.outputStockQuantity,
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
              AppIcons.diamondRounded,
              AppColors.gold,
              'Maden',
              mines.length.toString(),
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
              AppIcons.categoryOutlined,
              AppColors.warning,
              'Üretim',
              assignedCount.toString(),
            ),
            SizedBox(width: 14.w),
            Container(width: 1, height: 30.h, color: AppColors.border),
            SizedBox(width: 14.w),
            _buildStatItem(
              AppIcons.inventory2,
              AppColors.gold,
              'Stok',
              _formatCompact(totalOutputStock),
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
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          SizedBox(height: 60.h),
          Icon(
            AppIcons.diamondOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.showcase,
          ),
          SizedBox(height: 16.h),
          Text(
            'Henüz bir madenin yok.',
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => context.push('/mines/new/city'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardBgLight,
              side: BorderSide(color: AppColors.gold),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text('İLK MADENİNİ KUR', style: AppTextStyles.titleGold),
          ),
        ],
      ),
    );
  }

  Widget _buildMineCard(MineListItemModel item) {
    final mine = item.mine;
    final hasWarning = item.hasWarning;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: AppColors.cardBg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg.withValues(alpha: 0.85),
            AppColors.cardBgLight.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(
          color: hasWarning
              ? AppColors.warning.withValues(alpha: 0.8)
              : mine.isActive
                  ? AppColors.borderGold.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
          width: hasWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          if (hasWarning)
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.18),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else if (mine.isActive)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.03),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () => context.push('/mines/${mine.id}'),
          borderRadius: BorderRadius.circular(20.r),
          splashColor: AppColors.gold.withValues(alpha: 0.1),
          highlightColor: AppColors.gold.withValues(alpha: 0.05),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMineImage(item),
                    SizedBox(width: 10.w),
                    Expanded(child: _buildMineHeader(item)),
                  ],
                ),
                SizedBox(height: 8.h),
                _buildProductSection(item),
                SizedBox(height: 8.h),
                _buildOutputSection(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMineImage(MineListItemModel item) {
    return Container(
      width: 76.w,
      height: 76.w,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.3),
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
        fileName: item.mineTypeIcon,
        fit: BoxFit.contain,
        errorWidget: Icon(
          AppIcons.diamondRounded,
          color: AppColors.gold,
          size: AppIconSizes.xLarge,
        ),
      ),
    );
  }

  Widget _buildMineHeader(MineListItemModel item) {
    final mine = item.mine;
    final hasWarning = item.hasWarning;
    final warningReason = item.warningReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                mine.name,
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
            if (hasWarning && warningReason != null) ...[
              _buildSmallBadge(
                '⚠️ $warningReason',
                AppColors.warning,
              ),
              SizedBox(width: 6.w),
            ],
            _buildSmallBadge(
              mine.isActive ? 'Aktif' : 'Pasif',
              mine.isActive ? AppColors.green : AppColors.red,
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(
              AppIcons.locationOn,
              color: AppColors.gold,
              size: AppIconSizes.xSmall,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                item.cityName,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSmallBadge('Lv ${mine.level}', AppColors.blue),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          item.mineTypeName,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProductSection(MineListItemModel item) {
    final mine = item.mine;
    final product = item.selectedProduct;
    final hasProduct = item.hasSelectedProduct;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: hasProduct
            ? AppColors.cardBgLight.withValues(alpha: 0.3)
            : AppFx.panelWash(0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: hasProduct
              ? AppColors.green.withValues(alpha: 0.15)
              : AppColors.borderGold.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            padding: EdgeInsets.all(hasProduct ? 6.w : 10.w),
            decoration: BoxDecoration(
              color: hasProduct ? AppColors.cardBgLight : AppFx.panelWash(0.3),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: hasProduct
                    ? AppColors.green.withValues(alpha: 0.3)
                    : AppColors.borderGold.withValues(alpha: 0.2),
              ),
            ),
            child: hasProduct
                ? CachedAssetImage(
                    fileName: product!.urunIconu,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    AppIcons.addCircleOutline,
                    color: AppColors.gold.withValues(alpha: 0.4),
                    size: AppIconSizes.medium,
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasProduct) ...[
                  Text(
                    'Ürün ayarı gerekli',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.gold.withValues(alpha: 0.8),
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Ürün seçilmedi',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Detay ekranından ürün seçerek madeni başlat.',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.label,
                    ),
                  ),
                ] else ...[
                  Text(
                    product!.urunAdi,
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodyLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < mine.qualityLevel
                            ? AppIcons.star
                            : AppIcons.starBorder,
                        color: index < mine.qualityLevel
                            ? AppColors.gold
                            : AppColors.textMuted,
                        size: AppIconSizes.xxSmall,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasProduct)
                _buildSmallBadge(
                  'Saatlik ${(product!.uretimAdedi * (1.0 + (mine.qualityLevel - 1) * 0.20)).toInt()}',
                  AppColors.blue,
                ),
              if (mine.boostMultiplier > 1.0) ...[
                if (hasProduct) SizedBox(height: 4.h),
                _buildSmallBadge(
                  'Boost x${mine.boostMultiplier.toStringAsFixed(1)}',
                  AppColors.gold,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSection(MineListItemModel item) {
    final ratio = item.outputStockRatio;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.inventory2,
                    color: AppColors.textSecondary,
                    size: AppIconSizes.small,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Cevher stoğu',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '${_formatCompact(item.outputStockQuantity)} / ${_formatCompact(item.mine.outputCapacity)}',
                style: AppTextStyles.caption.standardCopyWith(
                  color: ratio >= 0.6
                      ? AppColors.green
                      : (ratio <= 0.25 ? AppColors.red : AppColors.textPrimary),
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppProgressBar.stock(value: ratio, size: AppProgressSize.compact),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatCompact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  Widget _buildErrorState(Object error, {required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.errorOutline,
            color: AppColors.red,
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 16.h),
          Text(
            'Hata: ${error.toString()}',
            style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}

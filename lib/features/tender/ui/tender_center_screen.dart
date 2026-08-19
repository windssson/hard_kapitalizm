import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/app_primitives.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/features/tender/data/tender_provider.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_center_model.dart';

class TenderCenterScreen extends ConsumerStatefulWidget {
  const TenderCenterScreen({super.key});

  @override
  ConsumerState<TenderCenterScreen> createState() => _TenderCenterScreenState();
}

class _TenderCenterScreenState extends ConsumerState<TenderCenterScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(tenderActionProvider).refreshTenderRuntime());
  }

  Future<void> _refresh() async {
    await ref.read(tenderActionProvider).refreshTenderRuntime();
    final _ = await ref.refresh(tenderCenterProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final tenderCenterAsync = ref.watch(tenderCenterProvider);
    final tickerNow =
        ref.watch(secondTickerProvider).asData?.value ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
        onItemSelected: (_) {},
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'İhale Merkezi'),
            Expanded(
              child: tenderCenterAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _TenderErrorState(message: error.toString()),
                data: (center) => DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                        child: _TenderSummaryBar(center: center),
                      ),
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: AppColors.borderGold.withValues(alpha: 0.28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppFx.shadow(0.24),
                                blurRadius: 8.r,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TabBar(
                            splashBorderRadius: BorderRadius.circular(14.r),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: AppColors.transparent,
                            indicator: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withValues(alpha: 0.32),
                                  AppColors.goldLight.withValues(alpha: 0.16),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: AppColors.borderGoldLight.withValues(alpha: 0.4),
                              ),
                            ),
                            labelColor: AppColors.goldLight,
                            unselectedLabelColor: AppColors.textSecondary,
                            labelStyle: AppTextStyles.label.standardCopyWith(
                              fontSize: AppTypography.bodySmall,
                              fontWeight: FontWeight.w900,
                            ),
                            unselectedLabelStyle: AppTextStyles.label.standardCopyWith(
                              fontSize: AppTypography.label,
                              fontWeight: FontWeight.w700,
                            ),
                            tabs: [
                              Tab(text: 'Açık (${center.openTenders.length})'),
                              Tab(
                                text:
                                    'İhalelerim (${center.myActiveTenders.length + center.myBidTenders.length})',
                              ),
                              Tab(text: 'Geçmiş (${center.myRecentTenders.length})'),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _OpenTendersTab(
                              center: center,
                              onRefresh: _refresh,
                              now: tickerNow,
                            ),
                            _MyTendersTab(
                              center: center,
                              onRefresh: _refresh,
                              now: tickerNow,
                            ),
                            _HistoryTendersTab(
                              center: center,
                              onRefresh: _refresh,
                            ),
                          ],
                        ),
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
}

class _TenderSummaryBar extends StatelessWidget {
  const _TenderSummaryBar({required this.center});

  final TenderCenterModel center;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: AppDecorations.premiumCard(null, 14.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCompactMetric('Açık', '${center.openTenders.length}', AppColors.gold),
          _buildDivider(),
          _buildCompactMetric('Aktif', '${center.myActiveTenders.length}', AppColors.blue),
          _buildDivider(),
          _buildCompactMetric('Teklifim', '${center.myBidTenders.length}', AppColors.green),
          _buildDivider(),
          _buildCompactMetric('Yolda', '${center.deliveryCount}', AppColors.goldLight),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.micro,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.titleBold.standardCopyWith(
            color: color,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1.w,
      height: 20.h,
      color: AppColors.border.withValues(alpha: 0.3),
    );
  }
}

class _OpenTendersTab extends StatelessWidget {
  const _OpenTendersTab({
    required this.center,
    required this.onRefresh,
    required this.now,
  });

  final TenderCenterModel center;
  final Future<void> Function() onRefresh;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 28.h),
        itemCount: center.openTenders.isEmpty ? 1 : center.openTenders.length,
        itemBuilder: (context, index) {
          if (center.openTenders.isEmpty) {
            return const AppEmptyStateCard(
              icon: AppIcons.gavelRounded,
              title: 'Şu an açık ihale yok',
              message: 'Yeni ilanlar geldiğinde burada göreceksin.',
            );
          }
          final item = center.openTenders[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _OpenTenderCard(item: item, now: now),
          );
        },
      ),
    );
  }
}

class _MyTendersTab extends StatelessWidget {
  const _MyTendersTab({
    required this.center,
    required this.onRefresh,
    required this.now,
  });

  final TenderCenterModel center;
  final Future<void> Function() onRefresh;
  final DateTime now;

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.standardCopyWith(
          color: AppColors.gold,
          fontSize: AppTypography.micro,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = center.myActiveTenders.isNotEmpty;
    final hasBids = center.myBidTenders.isNotEmpty;

    if (!hasActive && !hasBids) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 28.h),
          children: [
            const AppEmptyStateCard(
              icon: AppIcons.inventory2Outlined,
              title: 'Aktif ihale kaydın yok',
              message: 'Teklif verdiğinde ya da ihale kazandığında burada görünecek.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (hasActive) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
              sliver: SliverToBoxAdapter(
                child: _buildSectionLabel('Aldığın İhaleler (${center.myActiveTenders.length})'),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = center.myActiveTenders[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _ActiveTenderCard(item: item),
                    );
                  },
                  childCount: center.myActiveTenders.length,
                ),
              ),
            ),
          ],
          if (hasBids) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
              sliver: SliverToBoxAdapter(
                child: _buildSectionLabel('Verdiğin Teklifler (${center.myBidTenders.length})'),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 28.h),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = center.myBidTenders[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: _TenderBidCard(item: item, now: now),
                    );
                  },
                  childCount: center.myBidTenders.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTendersTab extends StatelessWidget {
  const _HistoryTendersTab({
    required this.center,
    required this.onRefresh,
  });

  final TenderCenterModel center;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 28.h),
        itemCount: center.myRecentTenders.isEmpty ? 1 : center.myRecentTenders.length,
        itemBuilder: (context, index) {
          if (center.myRecentTenders.isEmpty) {
            return const AppEmptyStateCard(
              icon: AppIcons.historyRounded,
              title: 'Geçmiş ihale kaydı yok',
              message: 'Tamamlanan veya başarısız ihaleler burada listelenecek.',
            );
          }
          final item = center.myRecentTenders[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _TenderHistoryCard(item: item),
          );
        },
      ),
    );
  }
}

class _OpenTenderCard extends StatelessWidget {
  const _OpenTenderCard({
    required this.item,
    required this.now,
  });

  final TenderListItemModel item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isFirstClaim = item.awardType == 'first_claim';

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/open/${item.tenderId}'),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.borderGoldLight.withValues(alpha: 0.5), 14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Kısım: İkon, Başlık, Ayrıntılar, Durum Rozeti
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppColors.borderGold.withValues(alpha: 0.2),
                      ),
                    ),
                    child: CachedAssetImage(
                      fileName: item.productIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: AppTypography.bodyLarge,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.label,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            _buildQualityStars(item.qualityLevel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppStatusPill(
                    icon: isFirstClaim ? AppIcons.flashOnRounded : AppIcons.gavelRounded,
                    text: isFirstClaim ? 'Hemen Al' : 'Teklif',
                    color: isFirstClaim ? AppColors.goldLight : AppColors.green,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Alt Kısım: Özet Metrikler ve Bilgiler
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRowItem('📦 Miktar', '${item.requiredQuantity} adet'),
                    _buildRowItem(
                      isFirstClaim ? '💰 Ödül' : '💰 Tavan',
                      AppMoney.compact(item.rewardCash),
                      valueColor: AppColors.green,
                    ),
                    if (!isFirstClaim && item.lowestBidAmount != null && item.lowestBidAmount! > 0)
                      _buildRowItem('📉 En Düşük', AppMoney.compact(item.lowestBidAmount!), valueColor: AppColors.goldLight)
                    else if (isFirstClaim)
                      _buildRowItem('🛡️ Teminat', AppMoney.compact(item.bondAmount), valueColor: AppColors.red)
                    else
                      _buildRowItem('📉 En Düşük', '-'),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              // Alt En Dış Kısım: Zaman ve Şehir
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.timerOutlined,
                        color: _countdownColor(item.acceptUntil, now),
                        size: AppIconSizes.xSmall,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTenderCountdown(item.acceptUntil, now),
                        style: AppTextStyles.label.standardCopyWith(
                          color: _countdownColor(item.acceptUntil, now),
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '📍 ${item.cityName} ${!isFirstClaim ? "• 👥 ${item.bidCount} teklif" : ""}',
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.micro,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.label.standardCopyWith(
            color: valueColor ?? AppColors.white,
            fontSize: AppTypography.label,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ActiveTenderCard extends StatelessWidget {
  const _ActiveTenderCard({required this.item});

  final PlayerTenderSummaryModel item;

  @override
  Widget build(BuildContext context) {
    final progress = item.requiredQuantity <= 0
        ? 0.0
        : (item.deliveredQuantity / item.requiredQuantity).clamp(0, 1).toDouble();

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/player/${item.playerTenderId}'),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.blue.withValues(alpha: 0.5), 14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: CachedAssetImage(
                      fileName: item.productIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: AppTypography.bodyLarge,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.label,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            _buildQualityStars(item.qualityLevel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppStatusPill(
                    icon: AppIcons.autoGraphRounded,
                    text: item.status.toUpperCase(),
                    color: AppColors.goldLight,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: AppProgressBar(
                  value: progress,
                  minHeight: 6.h,
                  backgroundColor: AppFx.panelWash(0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.gold,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📦 ${item.deliveredQuantity}/${item.requiredQuantity} adet (%${(progress * 100).round()})',
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.goldLight,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '📍 ${item.cityName}',
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenderBidCard extends StatelessWidget {
  const _TenderBidCard({
    required this.item,
    required this.now,
  });

  final TenderBidSummaryModel item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isLeading = item.lowestBidAmount != null &&
        (item.bidAmount - item.lowestBidAmount!).abs() < 0.01;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/open/${item.tenderId}'),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.green.withValues(alpha: 0.5), 14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: CachedAssetImage(
                      fileName: item.productIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: AppTypography.bodyLarge,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.label,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            _buildQualityStars(item.qualityLevel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppStatusPill(
                    icon: isLeading ? AppIcons.checkCircleOutline : AppIcons.gavelRounded,
                    text: isLeading ? 'En Düşük' : 'Teklifin',
                    color: isLeading ? AppColors.goldLight : AppColors.blue,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEKLİFİN',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.micro,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          AppMoney.compact(item.bidAmount),
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.green,
                            fontSize: AppTypography.label,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EN DÜŞÜK',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.micro,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          item.lowestBidAmount != null && item.lowestBidAmount! > 0
                              ? AppMoney.compact(item.lowestBidAmount!)
                              : '-',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.goldLight,
                            fontSize: AppTypography.label,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEMİNAT',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.micro,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          AppMoney.compact(item.bondPaid),
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.red,
                            fontSize: AppTypography.label,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.timerOutlined,
                        color: _countdownColor(item.acceptUntil, now),
                        size: AppIconSizes.xSmall,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTenderCountdown(item.acceptUntil, now),
                        style: AppTextStyles.label.standardCopyWith(
                          color: _countdownColor(item.acceptUntil, now),
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '📍 ${item.cityName} • 👥 ${item.bidCount} teklif',
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenderHistoryCard extends StatelessWidget {
  const _TenderHistoryCard({required this.item});

  final PlayerTenderSummaryModel item;

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == 'completed';
    final accent = isCompleted ? AppColors.green : AppColors.red;
    final label = isCompleted ? 'TAMAMLANDI' : 'BAŞARISIZ';
    final date = isCompleted ? item.completedAt : item.failedAt;
    final progress = item.requiredQuantity <= 0
        ? 0.0
        : (item.deliveredQuantity / item.requiredQuantity).clamp(0, 1).toDouble();

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/player/${item.playerTenderId}'),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(accent.withValues(alpha: 0.5), 14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: CachedAssetImage(
                      fileName: item.productIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: AppTypography.bodyLarge,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.label,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            _buildQualityStars(item.qualityLevel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppStatusPill(
                    icon: isCompleted ? AppIcons.checkCircleRounded : AppIcons.cancelRounded,
                    text: label,
                    color: accent,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: AppProgressBar(
                  value: progress,
                  minHeight: 6.h,
                  backgroundColor: AppFx.panelWash(0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📦 ${item.deliveredQuantity}/${item.requiredQuantity} adet teslim',
                    style: AppTextStyles.label.standardCopyWith(
                      color: accent,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _formatDateTime(date),
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenderErrorState extends StatelessWidget {
  const _TenderErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.red,
            fontSize: AppTypography.body,
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month $hour:$minute';
}

String _formatTenderCountdown(DateTime? target, DateTime now) {
  if (target == null) return '-';
  final remaining = target.toLocal().difference(now);
  if (remaining.inSeconds <= 0) return 'Süresi Doldu';
  final safe = remaining.isNegative ? Duration.zero : remaining;
  final hours = safe.inHours;
  final minutes = safe.inMinutes % 60;
  final seconds = safe.inSeconds % 60;
  if (hours > 0) {
    return '${hours}s ${minutes}dk';
  }
  return '${minutes}dk ${seconds.toString().padLeft(2, '0')}sn';
}

Color _countdownColor(DateTime? target, DateTime now) {
  if (target == null) return AppColors.textMuted;
  final remaining = target.toLocal().difference(now);
  if (remaining.inSeconds <= 0) return AppColors.red;
  if (remaining.inMinutes < 10) return AppColors.red;
  if (remaining.inMinutes < 30) return AppColors.warning;
  return AppColors.goldLight;
}

Widget _buildQualityStars(int qualityLevel) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (index) {
      final isFilled = index < qualityLevel;
      return Padding(
        padding: EdgeInsets.only(right: 1.w),
        child: Icon(
          isFilled ? AppIcons.starRounded : AppIcons.starBorderRounded,
          color: isFilled ? AppColors.gold : AppColors.textMuted.withValues(alpha: 0.3),
          size: 11.r,
        ),
      );
    }),
  );
}

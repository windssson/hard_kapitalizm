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

enum TenderOpenFilter {
  all,
  firstClaim,
  lowestBid,
  highReward,
}

class TenderCenterScreen extends ConsumerStatefulWidget {
  const TenderCenterScreen({super.key});

  @override
  ConsumerState<TenderCenterScreen> createState() => _TenderCenterScreenState();
}

class _TenderCenterScreenState extends ConsumerState<TenderCenterScreen> {
  TenderOpenFilter _selectedFilter = TenderOpenFilter.all;

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
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: AppColors.borderGold.withValues(alpha: 0.35),
                              width: 1.w,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TabBar(
                            splashBorderRadius: BorderRadius.circular(12.r),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: AppColors.transparent,
                            indicator: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withValues(alpha: 0.30),
                                  AppColors.goldLight.withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.5),
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
                              selectedFilter: _selectedFilter,
                              onFilterChanged: (f) => setState(() => _selectedFilter = f),
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
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.35),
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatItem(
              AppIcons.gavelRounded,
              AppColors.gold,
              'Açık İhale',
              center.openTenders.length.toString(),
            ),
            _buildDivider(),
            _buildStatItem(
              AppIcons.checkCircle,
              AppColors.green,
              'Aktif / Kazanılan',
              center.myActiveTenders.length.toString(),
            ),
            _buildDivider(),
            _buildStatItem(
              AppIcons.handshakeRounded,
              AppColors.blue,
              'Teklifim',
              center.myBidTenders.length.toString(),
            ),
            _buildDivider(),
            _buildStatItem(
              AppIcons.localShippingRounded,
              AppColors.goldLight,
              'Yolda',
              center.deliveryCount.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10.w),
      width: 1.w,
      height: 32.h,
      color: AppColors.border.withValues(alpha: 0.35),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(7.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.w,
            ),
          ),
          child: Icon(icon, color: color, size: 14.sp),
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
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              value,
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpenTendersTab extends StatelessWidget {
  const _OpenTendersTab({
    required this.center,
    required this.onRefresh,
    required this.now,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final TenderCenterModel center;
  final Future<void> Function() onRefresh;
  final DateTime now;
  final TenderOpenFilter selectedFilter;
  final ValueChanged<TenderOpenFilter> onFilterChanged;

  List<TenderListItemModel> _getFilteredTenders() {
    return center.openTenders.where((item) {
      switch (selectedFilter) {
        case TenderOpenFilter.firstClaim:
          return item.awardType == 'first_claim';
        case TenderOpenFilter.lowestBid:
          return item.awardType == 'lowest_bid';
        case TenderOpenFilter.highReward:
          return item.rewardCash >= 100000;
        case TenderOpenFilter.all:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredTenders();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          // Yatay Filtreleme Çipleri
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'Tümü (${center.openTenders.length})',
                    filter: TenderOpenFilter.all,
                  ),
                  SizedBox(width: 6.w),
                  _buildFilterChip(
                    label: '⚡ Hemen Al (${center.openTenders.where((t) => t.awardType == 'first_claim').length})',
                    filter: TenderOpenFilter.firstClaim,
                  ),
                  SizedBox(width: 6.w),
                  _buildFilterChip(
                    label: '⚖️ Teklif Usulü (${center.openTenders.where((t) => t.awardType == 'lowest_bid').length})',
                    filter: TenderOpenFilter.lowestBid,
                  ),
                  SizedBox(width: 6.w),
                  _buildFilterChip(
                    label: '💰 Yüksek Ödül (>100K)',
                    filter: TenderOpenFilter.highReward,
                  ),
                ],
              ),
            ),
          ),

          // İhale Listesi
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 28.h),
              itemCount: filtered.isEmpty ? 1 : filtered.length,
              itemBuilder: (context, index) {
                if (filtered.isEmpty) {
                  return const AppEmptyStateCard(
                    icon: AppIcons.gavelRounded,
                    title: 'Filtreye uygun ihale bulunamadı',
                    message: 'Farklı bir filtre seçebilir veya yeni ihaleleri bekleyebilirsin.',
                  );
                }
                final item = filtered[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _OpenTenderCard(item: item, now: now),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required TenderOpenFilter filter,
  }) {
    final isSelected = selectedFilter == filter;
    return GestureDetector(
      onTap: () => onFilterChanged(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.18)
              : AppColors.cardBgLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.border.withValues(alpha: 0.25),
            width: isSelected ? 1.2.w : 1.w,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: isSelected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 9.5.sp,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
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
          fontSize: 9.sp,
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
              padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 0),
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
              padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 0),
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
              message: 'Tamamlanan veya feshedilen ihaleler burada listelenecek.',
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
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.borderGold.withValues(alpha: 0.35),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Satır: Avatar + Başlık + Şehir + İhale Türü Rozeti
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sol: Ürün Avatarı
                  Container(
                    width: 52.w,
                    height: 52.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        width: 1.w,
                      ),
                    ),
                    child: CachedAssetImage(
                      fileName: item.productIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // Orta: Başlık, Ürün İsmi ve Kalite Yıldızları
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
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
                  SizedBox(width: 6.w),

                  // Sağ: İhale Türü Rozeti (Hemen Al / Teklif)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isFirstClaim
                            ? [
                                AppColors.gold.withValues(alpha: 0.35),
                                AppColors.goldDark.withValues(alpha: 0.20),
                              ]
                            : [
                                AppColors.green.withValues(alpha: 0.30),
                                const Color(0xFF1B8A5A).withValues(alpha: 0.15),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: isFirstClaim
                            ? AppColors.gold.withValues(alpha: 0.6)
                            : AppColors.green.withValues(alpha: 0.5),
                        width: 1.w,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFirstClaim
                              ? Icons.bolt_rounded
                              : AppIcons.gavelRounded,
                          size: 11.sp,
                          color: isFirstClaim ? AppColors.gold : AppColors.green,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          isFirstClaim ? 'Hemen Al' : 'Teklif',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: isFirstClaim ? AppColors.gold : AppColors.green,
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // Orta Bilgi Şeridi (Miktar | Ödül | Teminat/En Düşük)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRowItem(
                      'Miktar',
                      '${item.requiredQuantity} adet',
                      icon: AppIcons.inventory2,
                      iconColor: AppColors.goldLight,
                    ),
                    _buildRowItem(
                      isFirstClaim ? 'Ödül' : 'Tavan Ödül',
                      '₺${AppMoney.compact(item.rewardCash)}',
                      icon: AppIcons.paymentsRounded,
                      iconColor: AppColors.green,
                      valueColor: AppColors.green,
                    ),
                    if (!isFirstClaim &&
                        item.lowestBidAmount != null &&
                        item.lowestBidAmount! > 0)
                      _buildRowItem(
                        'En Düşük',
                        '₺${AppMoney.compact(item.lowestBidAmount!)}',
                        icon: AppIcons.trendingDownRounded,
                        iconColor: AppColors.goldLight,
                        valueColor: AppColors.goldLight,
                      )
                    else
                      _buildRowItem(
                        'Teminat',
                        '₺${AppMoney.compact(item.bondAmount)}',
                        icon: AppIcons.securityRounded,
                        iconColor: AppColors.red,
                        valueColor: AppColors.red,
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // Alt Satır: Kalan Süre + Şehir + Sağ Ok
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.timerOutlined,
                        color: _countdownColor(item.acceptUntil, now),
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTenderCountdown(item.acceptUntil, now),
                        style: AppTextStyles.label.standardCopyWith(
                          color: _countdownColor(item.acceptUntil, now),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.locationOn,
                        size: 11.sp,
                        color: AppColors.gold,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        item.cityName,
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isFirstClaim) ...[
                        SizedBox(width: 8.w),
                        Icon(
                          AppIcons.groupRounded,
                          size: 11.sp,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          '${item.bidCount} Teklif',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gold.withValues(alpha: 0.6),
                        size: 16.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowItem(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 9.5.sp, color: iconColor ?? AppColors.textMuted),
              SizedBox(width: 3.w),
            ],
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: 8.5.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppTextStyles.label.standardCopyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 10.5.sp,
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
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.green.withValues(alpha: 0.35),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.35),
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
                            color: AppColors.textPrimary,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'AKTİF TESLİMAT',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.green,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5.h,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.green : AppColors.gold,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.inventory2,
                        size: 11.sp,
                        color: AppColors.goldLight,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${item.deliveredQuantity}/${item.requiredQuantity} adet (%${(progress * 100).round()})',
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.goldLight,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.locationOn,
                        size: 11.sp,
                        color: AppColors.gold,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        item.cityName,
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gold.withValues(alpha: 0.6),
                        size: 16.sp,
                      ),
                    ],
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
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isLeading
                  ? AppColors.green.withValues(alpha: 0.4)
                  : AppColors.warning.withValues(alpha: 0.4),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isLeading
                            ? AppColors.green.withValues(alpha: 0.35)
                            : AppColors.warning.withValues(alpha: 0.35),
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
                            color: AppColors.textPrimary,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: (isLeading ? AppColors.green : AppColors.warning)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: (isLeading ? AppColors.green : AppColors.warning)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLeading ? Icons.emoji_events_rounded : Icons.warning_amber_rounded,
                          size: 11.sp,
                          color: isLeading ? AppColors.green : AppColors.warning,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          isLeading ? 'Lider Teklif' : 'Teklifin Geçildi',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: isLeading ? AppColors.green : AppColors.warning,
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.45),
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
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '₺${AppMoney.compact(item.bidAmount)}',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.green,
                            fontSize: 10.5.sp,
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
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          item.lowestBidAmount != null && item.lowestBidAmount! > 0
                              ? '₺${AppMoney.compact(item.lowestBidAmount!)}'
                              : '-',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.goldLight,
                            fontSize: 10.5.sp,
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
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '₺${AppMoney.compact(item.bondPaid)}',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.red,
                            fontSize: 10.5.sp,
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
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTenderCountdown(item.acceptUntil, now),
                        style: AppTextStyles.label.standardCopyWith(
                          color: _countdownColor(item.acceptUntil, now),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.locationOn,
                        size: 11.sp,
                        color: AppColors.gold,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        item.cityName,
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        AppIcons.groupRounded,
                        size: 11.sp,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${item.bidCount} Teklif',
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gold.withValues(alpha: 0.6),
                        size: 16.sp,
                      ),
                    ],
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
    final label = isCompleted ? 'TAMAMLANDI' : 'FESHEDİLDİ';
    final date = isCompleted ? item.completedAt : (item.failedAt ?? item.deadlineAt);
    final progress = item.requiredQuantity <= 0
        ? 0.0
        : (item.deliveredQuantity / item.requiredQuantity).clamp(0, 1).toDouble();

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/player/${item.playerTenderId}'),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
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
                            color: AppColors.textPrimary,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: accent,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5.h,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.inventory2,
                        size: 11.sp,
                        color: accent,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${item.deliveredQuantity}/${item.requiredQuantity} adet teslim',
                        style: AppTextStyles.label.standardCopyWith(
                          color: accent,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDateTime(date),
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.gold.withValues(alpha: 0.6),
                        size: 16.sp,
                      ),
                    ],
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

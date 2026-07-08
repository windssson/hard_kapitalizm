import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
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
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 3,
        onItemSelected: (_) {},
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Ihale Merkezi'),
            Expanded(
              child: tenderCenterAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _TenderErrorState(message: error.toString()),
                data: (center) => DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                        child: _TenderSummaryCard(center: center),
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
                                color: Colors.black.withValues(alpha: 0.24),
                                blurRadius: 8.r,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TabBar(
                            splashBorderRadius: BorderRadius.circular(14.r),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
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
                            labelStyle: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: 10.sp,
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 28.h),
        children: [
          _TenderSectionHeader(
            title: 'Acik Ihaleler',
            subtitle: '${center.openTenders.length} firsat',
          ),
          SizedBox(height: 8.h),
          if (center.openTenders.isEmpty)
            const _TenderEmptyCard(
              icon: Icons.gavel_rounded,
              title: 'Su an acik ihale yok',
              message: 'Yeni ilanlar geldiginde burada goreceksin.',
            )
          else
            ...center.openTenders.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _OpenTenderCard(item: item, now: now),
              ),
            ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 28.h),
        children: [
          _TenderSectionHeader(
            title: 'Aldigin Ihaleler',
            subtitle: '${center.myActiveTenders.length} aktif kayit',
          ),
          SizedBox(height: 8.h),
          if (center.myActiveTenders.isEmpty)
            const _TenderEmptyCard(
              icon: Icons.inventory_2_outlined,
              title: 'Aktif ihale kaydin yok',
              message: 'Bir ihale kazandiginda teslim ekranlari burada acilir.',
            )
          else
            ...center.myActiveTenders.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _ActiveTenderCard(item: item),
              ),
            ),
          SizedBox(height: 12.h),
          _TenderSectionHeader(
            title: 'Verdigin Teklifler',
            subtitle: '${center.myBidTenders.length} acik teklif',
          ),
          SizedBox(height: 8.h),
          if (center.myBidTenders.isEmpty)
            const _TenderEmptyCard(
              icon: Icons.price_change_outlined,
              title: 'Acik teklifin yok',
              message:
                  'Teklif usulu bir ihaleye teklif verdiginde burada goreceksin.',
            )
          else
            ...center.myBidTenders.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _TenderBidCard(item: item, now: now),
              ),
            ),
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 28.h),
        children: [
          _TenderSectionHeader(
            title: 'Gecmis Ihaleler',
            subtitle: '${center.myRecentTenders.length} kayit',
          ),
          SizedBox(height: 8.h),
          if (center.myRecentTenders.isEmpty)
            const _TenderEmptyCard(
              icon: Icons.history_rounded,
              title: 'Gecmis ihale kaydi yok',
              message: 'Tamamlanan veya basarisiz ihaleler burada listelenecek.',
            )
          else
            ...center.myRecentTenders.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: _TenderHistoryCard(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _TenderSummaryCard extends StatelessWidget {
  const _TenderSummaryCard({required this.center});

  final TenderCenterModel center;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(AppColors.gold, 20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.22),
                      AppColors.goldLight.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.34),
                  ),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.gold,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kamu İhale Masası',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Açık ihaleleri takip et, teklif ver ya da hızlı davranıp kap.',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textPrimary.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.goldLight,
                      size: 12.sp,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      '${center.deliveryCount} yolda',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _TenderMetricTile(
                  label: 'Açık İhale',
                  value: '${center.openTenders.length}',
                  color: AppColors.gold,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _TenderMetricTile(
                  label: 'Aktif İhale',
                  value: '${center.myActiveTenders.length}',
                  color: AppColors.blue,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _TenderMetricTile(
                  label: 'Teklifim',
                  value: '${center.myBidTenders.length}',
                  color: AppColors.green,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _TenderMetricTile(
                  label: 'Geçmiş',
                  value: '${center.myRecentTenders.length}',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TenderMetricTile extends StatelessWidget {
  const _TenderMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenderSectionHeader extends StatelessWidget {
  const _TenderSectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 18.h,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999.r),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/open/${item.tenderId}'),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.borderGoldLight, 16.r),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Row(
                              children: List.generate(
                                item.qualityLevel,
                                (index) => Icon(
                                  Icons.star_rounded,
                                  color: AppColors.gold,
                                  size: 10.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _TenderPill(
                    icon: item.awardType == 'first_claim'
                        ? Icons.flash_on_rounded
                        : Icons.gavel_rounded,
                    text: item.awardType == 'first_claim' ? 'Hemen Al' : 'Teklif',
                    color: item.awardType == 'first_claim'
                        ? AppColors.goldLight
                        : AppColors.green,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _TenderMetricItem(
                      label: 'TALEP MİKTAR',
                      value: '${item.requiredQuantity} adet',
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: _TenderMetricItem(
                      label: item.awardType == 'lowest_bid' ? 'TAVAN ÖDÜL' : 'ÖDÜL',
                      value: AppMoney.compact(item.rewardCash),
                      color: AppColors.green,
                    ),
                  ),
                  Expanded(
                    child: item.awardType == 'lowest_bid'
                        ? _TenderMetricItem(
                            label: 'EN DÜŞÜK',
                            value: item.lowestBidAmount != null && item.lowestBidAmount! > 0
                                ? AppMoney.compact(item.lowestBidAmount!)
                                : '-',
                            color: AppColors.goldLight,
                          )
                        : _TenderMetricItem(
                            label: 'TEMİNAT',
                            value: AppMoney.compact(item.bondAmount),
                            color: AppColors.red,
                          ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              const Divider(color: Colors.white10, height: 1),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: _countdownColor(item.acceptUntil, now),
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTenderCountdown(item.acceptUntil, now),
                        style: TextStyle(
                          color: _countdownColor(item.acceptUntil, now),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (item.hasPlayerBid && item.playerBidAmount != null)
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppColors.blue,
                          size: 12.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Teklifin: ${AppMoney.compact(item.playerBidAmount!)}',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  else if (item.awardType == 'lowest_bid')
                    Text(
                      '${item.bidCount} rakip teklif',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
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

class _ActiveTenderCard extends StatelessWidget {
  const _ActiveTenderCard({required this.item});

  final PlayerTenderSummaryModel item;

  @override
  Widget build(BuildContext context) {
    final progress = item.requiredQuantity <= 0
        ? 0.0
        : (item.deliveredQuantity / item.requiredQuantity).clamp(0, 1).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/player/${item.playerTenderId}'),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.blue, 16.r),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Row(
                              children: List.generate(
                                item.qualityLevel,
                                (index) => Icon(
                                  Icons.star_rounded,
                                  color: AppColors.gold,
                                  size: 10.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _TenderPill(
                    icon: Icons.auto_graph_rounded,
                    text: item.status.toUpperCase(),
                    color: AppColors.goldLight,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8.h,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.gold,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.deliveredQuantity}/${item.requiredQuantity} adet (%${(progress * 100).round()})',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.cityName,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
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
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/open/${item.tenderId}'),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(AppColors.green, 16.r),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Row(
                              children: List.generate(
                                item.qualityLevel,
                                (index) => Icon(
                                  Icons.star_rounded,
                                  color: AppColors.gold,
                                  size: 10.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _TenderPill(
                    icon: isLeading ? Icons.check_circle_outline : Icons.gavel_rounded,
                    text: isLeading ? 'EN DÜŞÜK' : 'TEKLİFİN',
                    color: isLeading ? AppColors.goldLight : AppColors.blue,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _TenderMetricItem(
                      label: 'TEKLİFİN',
                      value: AppMoney.compact(item.bidAmount),
                      color: AppColors.green,
                    ),
                  ),
                  Expanded(
                    child: _TenderMetricItem(
                      label: 'EN DÜŞÜK',
                      value: item.lowestBidAmount != null && item.lowestBidAmount! > 0
                          ? AppMoney.compact(item.lowestBidAmount!)
                          : '-',
                      color: AppColors.goldLight,
                    ),
                  ),
                  Expanded(
                    child: _TenderMetricItem(
                      label: 'TEMİNAT',
                      value: AppMoney.compact(item.bondPaid),
                      color: AppColors.red,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              const Divider(color: Colors.white10, height: 1),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: _countdownColor(item.acceptUntil, now),
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTenderCountdown(item.acceptUntil, now),
                        style: TextStyle(
                          color: _countdownColor(item.acceptUntil, now),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${item.cityName} (${item.bidCount} oyuncu)',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
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

class _TenderMetricItem extends StatelessWidget {
  const _TenderMetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 8.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/tenders/player/${item.playerTenderId}'),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(accent, 16.r),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Row(
                              children: List.generate(
                                item.qualityLevel,
                                (index) => Icon(
                                  Icons.star_rounded,
                                  color: AppColors.gold,
                                  size: 10.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _TenderPill(
                    icon: isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    text: label,
                    color: accent,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8.h,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.deliveredQuantity}/${item.requiredQuantity} adet teslim',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _formatDateTime(date),
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
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

class _TenderPill extends StatelessWidget {
  const _TenderPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}



class _TenderEmptyCard extends StatelessWidget {
  const _TenderEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: AppDecorations.premiumCard(AppColors.border, 16.r),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 28.sp),
          SizedBox(height: 10.h),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 11.sp),
          ),
        ],
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
          style: TextStyle(color: AppColors.red, fontSize: 12.sp),
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
  if (remaining.inSeconds <= 0) return 'Suresi Doldu';
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
  if (remaining.inMinutes < 30) return Colors.orange;
  return AppColors.goldLight;
}

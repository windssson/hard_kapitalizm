import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
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
    await ref.refresh(tenderCenterProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final tenderCenterAsync = ref.watch(tenderCenterProvider);
    final tickerNow = ref.watch(secondTickerProvider).valueOrNull ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
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
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.06),
                                Colors.black.withValues(alpha: 0.18),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.22),
                            ),
                          ),
                          child: TabBar(
                            splashBorderRadius: BorderRadius.circular(14.r),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withValues(alpha: 0.24),
                                  AppColors.goldLight.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.28),
                              ),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppColors.textMuted,
                            labelStyle: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            tabs: [
                              Tab(text: 'Acik (${center.openTenders.length})'),
                              Tab(
                                text:
                                    'Ihalelerin (${center.myActiveTenders.length + center.myBidTenders.length})',
                              ),
                              Tab(text: 'Gecmis (${center.myRecentTenders.length})'),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF20170B),
            const Color(0xFF121A27),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                      'Kamu Ihale Masasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Acik ihaleleri takip et, teklif ver ya da hizli davranip kap.',
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
                  label: 'Acik Ihale',
                  value: '${center.openTenders.length}',
                  color: AppColors.gold,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _TenderMetricTile(
                  label: 'Aktif Ihale',
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
                  label: 'Gecmis',
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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
          padding: EdgeInsets.all(13.w),
          decoration: AppDecorations.premiumCard(AppColors.borderGoldLight, 16.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TenderProductArt(iconPath: item.productIcon),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _TenderPill(
                          icon: item.awardType == 'first_claim'
                              ? Icons.flash_on_rounded
                              : Icons.gavel_rounded,
                          text: item.awardType == 'first_claim'
                              ? 'Ilk Alan'
                              : 'Teklif Usulu',
                          color: item.awardType == 'first_claim'
                              ? AppColors.goldLight
                              : AppColors.green,
                        ),
                        if (item.hasPlayerBid)
                          const _TenderPill(
                            icon: Icons.check_circle_outline,
                            text: 'Teklif Verdin',
                            color: AppColors.blue,
                          ),
                        if (item.awardType == 'lowest_bid')
                          _TenderPill(
                            icon: Icons.groups_2_outlined,
                            text: '${item.bidCount} oyuncu',
                            color: AppColors.blue,
                          ),
                        _TenderPill(
                          icon: Icons.shopping_bag_outlined,
                          text: '${item.requiredQuantity} adet',
                          color: AppColors.gold,
                        ),
                        _TenderPill(
                          icon: Icons.timer_outlined,
                          text: _formatTenderCountdown(item.acceptUntil, now),
                          color: _countdownColor(item.acceptUntil, now),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TenderInfoLine(
                              label: item.awardType == 'lowest_bid'
                                  ? 'Tavan Odul'
                                  : 'Odul',
                              value: AppMoney.compact(item.rewardCash),
                              color: AppColors.green,
                            ),
                          ),
                          Expanded(
                            child: _TenderInfoLine(
                              label: 'Teminat',
                              value: AppMoney.compact(item.bondAmount),
                              color: AppColors.red,
                            ),
                          ),
                          Expanded(
                            child: _TenderInfoLine(
                              label: item.awardType == 'lowest_bid'
                                  ? 'En Dusuk'
                                  : 'Tur',
                              value: item.awardType == 'lowest_bid'
                                  ? AppMoney.compact(item.lowestBidAmount ?? 0)
                                  : 'Hemen Al',
                              color: AppColors.goldLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.hasPlayerBid && item.playerBidAmount != null) ...[
                      SizedBox(height: 6.h),
                      Text(
                        'Senin teklifin: ${AppMoney.compact(item.playerBidAmount!)}',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Son Kabul: ${_formatDateTime(item.acceptUntil)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ],
                ),
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
          child: Row(
            children: [
              _TenderProductArt(iconPath: item.productIcon),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          item.status.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${item.cityName} - ${item.productName}',
                      style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                    ),
                    SizedBox(height: 10.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9.h,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.gold,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.deliveredQuantity}/${item.requiredQuantity} adet teslim',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '%${(progress * 100).round()}',
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
          padding: EdgeInsets.all(13.w),
          decoration: AppDecorations.premiumCard(AppColors.green, 16.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TenderProductArt(iconPath: item.productIcon),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          isLeading ? 'EN DUSUK' : 'AKTIF TEKLIF',
                          style: TextStyle(
                            color: isLeading
                                ? AppColors.goldLight
                                : AppColors.blue,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${item.cityName} - ${item.productName}',
                      style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _TenderPill(
                          icon: Icons.timer_outlined,
                          text: _formatTenderCountdown(item.acceptUntil, now),
                          color: _countdownColor(item.acceptUntil, now),
                        ),
                        _TenderPill(
                          icon: Icons.groups_2_outlined,
                          text: '${item.bidCount} oyuncu',
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TenderInfoLine(
                              label: 'Teklifin',
                              value: AppMoney.compact(item.bidAmount),
                              color: AppColors.green,
                            ),
                          ),
                          Expanded(
                            child: _TenderInfoLine(
                              label: 'En Dusuk',
                              value: AppMoney.compact(item.lowestBidAmount ?? 0),
                              color: AppColors.goldLight,
                            ),
                          ),
                          Expanded(
                            child: _TenderInfoLine(
                              label: 'Oyuncu',
                              value: '${item.bidCount}',
                              color: AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Teminat: ${AppMoney.compact(item.bondPaid)}  -  Son Kabul: ${_formatDateTime(item.acceptUntil)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenderProductArt extends StatelessWidget {
  const _TenderProductArt({required this.iconPath});

  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60.w,
      height: 60.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.22)),
      ),
      child: CachedAssetImage(
        fileName: iconPath,
        fit: BoxFit.contain,
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
    final label = isCompleted ? 'Tamamlandi' : 'Basarisiz';
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
          child: Row(
            children: [
              _TenderProductArt(iconPath: item.productIcon),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          label,
                          style: TextStyle(
                            color: accent,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${item.cityName} - ${item.productName}',
                      style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                    ),
                    SizedBox(height: 8.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8.h,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.deliveredQuantity}/${item.requiredQuantity} adet teslim',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _formatDateTime(date),
                          style: TextStyle(
                            color: accent,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

class _TenderInfoLine extends StatelessWidget {
  const _TenderInfoLine({
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
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
  return '$day.$month ${hour}:$minute';
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

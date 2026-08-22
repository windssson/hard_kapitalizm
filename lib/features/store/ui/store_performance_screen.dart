import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_performance_model.dart';

class StorePerformanceScreen extends ConsumerStatefulWidget {
  final String storeId;

  const StorePerformanceScreen({super.key, required this.storeId});

  @override
  ConsumerState<StorePerformanceScreen> createState() =>
      _StorePerformanceScreenState();
}

class _StorePerformanceScreenState
    extends ConsumerState<StorePerformanceScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!ref.read(storePerformanceDirtyProvider(widget.storeId))) return;
      await _refreshPerformance(clearDirty: true);
    });
  }

  Future<void> _refreshPerformance({required bool clearDirty}) async {
    ref.invalidate(storePerformanceProvider(widget.storeId));
    await ref.read(storePerformanceProvider(widget.storeId).future);
    if (clearDirty) {
      ref.read(storePerformanceDirtyProvider(widget.storeId).notifier).state =
          false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final performanceAsync = ref.watch(
      storePerformanceProvider(widget.storeId),
    );

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Mağaza Finans Raporu'),
            _buildTabBar(),
            Expanded(
              child: performanceAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildErrorState(context, ref, error),
                data: (data) => RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.cardBg,
                  onRefresh: () async {
                    await _refreshPerformance(clearDirty: true);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    children: [
                      if (_selectedTabIndex == 0) ...[
                        _buildMainProfitCard(data.summary),
                        SizedBox(height: 12.h),
                        _buildKpiGrid(data.summary),
                        SizedBox(height: 14.h),
                        _buildTopProductsList(
                          data.rows,
                          data.summary.totalProfit,
                        ),
                      ] else if (_selectedTabIndex == 1) ...[
                        _buildProductsTab(data.rows, data.summary.totalProfit),
                      ] else ...[
                        _buildDailyTab(data.rows),
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

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Genel Bakış', AppIcons.barChartRounded),
          _buildTabItem(1, 'Ürün Analizi', AppIcons.categoryRounded),
          _buildTabItem(2, 'Günlük Akış', AppIcons.calendarMonthRounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: 9.h),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.22),
                      AppColors.gold.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : AppColors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.gold : AppColors.textMuted,
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: AppTextStyles.label.standardCopyWith(
                  color: isSelected
                      ? AppColors.gold
                      : AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainProfitCard(StorePerformanceSummaryModel summary) {
    final profitMargin = summary.totalRevenue > 0
        ? (summary.totalProfit / summary.totalRevenue) * 100
        : 0.0;
    final totalCost = (summary.totalRevenue - summary.totalProfit).clamp(0.0, double.infinity);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.14),
            AppColors.cardBg.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.10),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppFx.shadow(0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(5.w),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.insightsRounded,
                            color: AppColors.gold,
                            size: 14.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'TOPLAM NET KÂR',
                          style: AppTextStyles.overline.standardCopyWith(
                            color: AppColors.gold,
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _formatCurrency(summary.totalProfit),
                      style: AppTextStyles.largeTitle.standardCopyWith(
                        color: summary.totalProfit >= 0
                            ? AppColors.gold
                            : AppColors.red,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Son 14 Günlük Toplam Mağaza Kazancı',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 68.w,
                height: 68.w,
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (profitMargin >= 20 ? AppColors.green : AppColors.gold)
                        .withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (profitMargin >= 20 ? AppColors.green : AppColors.gold)
                          .withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '%${profitMargin.toStringAsFixed(1)}',
                        style: AppTextStyles.label.standardCopyWith(
                          color: profitMargin >= 20
                              ? AppColors.green
                              : AppColors.gold,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Marj',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          // Finansal Hacim Çubuğu (Ciro vs Maliyet)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Ciro: ',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.caption,
                        ),
                      ),
                      Text(
                        _formatCurrency(summary.totalRevenue),
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.green,
                          fontSize: AppTypography.caption,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Maliyet: ',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.caption,
                        ),
                      ),
                      Text(
                        _formatCurrency(totalCost),
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.red,
                          fontSize: AppTypography.caption,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(StorePerformanceSummaryModel summary) {
    final avgRevenuePerEvent = summary.totalSaleEvents > 0
        ? summary.totalRevenue / summary.totalSaleEvents
        : 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10.w,
      mainAxisSpacing: 10.h,
      childAspectRatio: 1.85,
      children: [
        _buildGridKpiCard(
          'Toplam Ciro',
          _formatCurrency(summary.totalRevenue),
          'Brüt Satış',
          AppColors.green,
          AppIcons.paymentsRounded,
        ),
        _buildGridKpiCard(
          'Satılan Adet',
          _formatCompactNumber(summary.totalSoldQuantity.toDouble()),
          'Ürün Hacmi',
          AppColors.gold,
          AppIcons.inventoryRounded,
        ),
        _buildGridKpiCard(
          'Satış İşlemi',
          '${summary.totalSaleEvents} Fiş',
          'Kasa Hareketi',
          AppColors.blue,
          AppIcons.receiptLongRounded,
        ),
        _buildGridKpiCard(
          'İşlem Başı Ciro',
          _formatCurrency(avgRevenuePerEvent),
          'Sepet Ort.',
          AppColors.textSecondary,
          AppIcons.trendingUpRounded,
        ),
      ],
    );
  }

  Widget _buildGridKpiCard(
    String label,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.standardCopyWith(
                    color: color,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 8.5.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsList(
    List<StorePerformanceRowModel> rows,
    double totalProfit,
  ) {
    final aggregated = _getAggregatedProducts(rows);
    final topProducts = aggregated.take(3).toList();

    if (topProducts.isEmpty) return const SizedBox.shrink();

    final productsAsync = ref.watch(allProductsProvider);
    final productList = productsAsync.value ?? [];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.starRounded,
                  color: AppColors.gold,
                  size: 15.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'En Çok Kazandıran Ürünler (Top 3)',
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.white,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topProducts.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final item = topProducts[index];
              final matchingProd = productList.firstWhere(
                (p) => p.id == item.productId,
                orElse: () => ProductModel(
                  id: item.productId,
                  urunAdi: item.productName,
                  urunIconu: '${item.productId.toLowerCase()}.webp',
                  birimHacim: 0,
                  birimAgirlik: 0,
                  bazSatisFiyati: 0,
                  uretimAdedi: 0,
                  satisAdedi: 0,
                  enDusukFiyat: 0,
                  enYuksekFiyat: 0,
                  ortalamaFiyat: 0,
                  saticiSayisi: 0,
                  piyasadakiStok: 0,
                  createdAt: DateTime.now(),
                ),
              );

              final contributionRatio = totalProfit > 0
                  ? (item.profit / totalProfit)
                  : 0.0;
              final contributionPercent = (contributionRatio * 100).clamp(
                0.0,
                100.0,
              );

              return Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32.w,
                          height: 32.w,
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: CachedAssetImage(
                            fileName: matchingProd.urunIconu,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: AppTextStyles.label.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTypography.bodySmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.soldQuantity} Adet Satıldı',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(item.profit),
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.gold,
                                fontSize: AppTypography.bodySmall,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Ciro: ${_formatCurrency(item.revenue)}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.green,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: LinearProgressIndicator(
                              value: contributionRatio.clamp(0.0, 1.0),
                              backgroundColor: AppColors.background,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.gold,
                              ),
                              minHeight: 5.h,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Kâr Payı: %${contributionPercent.toStringAsFixed(1)}',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.gold,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(
    List<StorePerformanceRowModel> rows,
    double totalProfit,
  ) {
    final aggregated = _getAggregatedProducts(rows);
    if (aggregated.isEmpty) return _buildEmptyState();

    final productsAsync = ref.watch(allProductsProvider);
    final productList = productsAsync.value ?? [];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: aggregated.length,
      separatorBuilder: (context, index) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final item = aggregated[index];
        final matchingProd = productList.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => ProductModel(
            id: item.productId,
            urunAdi: item.productName,
            urunIconu: '${item.productId.toLowerCase()}.webp',
            birimHacim: 0,
            birimAgirlik: 0,
            bazSatisFiyati: 0,
            uretimAdedi: 0,
            satisAdedi: 0,
            enDusukFiyat: 0,
            enYuksekFiyat: 0,
            ortalamaFiyat: 0,
            saticiSayisi: 0,
            piyasadakiStok: 0,
            createdAt: DateTime.now(),
          ),
        );

        final avgPrice = item.soldQuantity > 0
            ? item.revenue / item.soldQuantity
            : 0.0;
        final margin = item.revenue > 0
            ? (item.profit / item.revenue) * 100
            : 0.0;

        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppFx.shadow(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: CachedAssetImage(
                      fileName: matchingProd.urunIconu,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: AppTypography.bodyLarge,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${item.saleEventCount} Ayrı Satış İşlemi',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(item.profit),
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Ciro: ${_formatCurrency(item.revenue)}',
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.green,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Divider(
                color: AppColors.border.withValues(alpha: 0.2),
                height: 1,
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetric(
                    'Satılan Adet',
                    item.soldQuantity.toString(),
                    AppColors.white,
                  ),
                  _buildMiniMetric(
                    'Ort. Fiyat',
                    _formatCurrency(avgPrice),
                    AppColors.textSecondary,
                  ),
                  _buildMiniMetric(
                    'Kâr Marjı',
                    '%${margin.toStringAsFixed(1)}',
                    margin >= 20 ? AppColors.green : AppColors.gold,
                  ),
                  _buildMiniMetric(
                    'Kâr Payı',
                    '%${(totalProfit > 0 ? (item.profit / totalProfit * 100) : 0).toStringAsFixed(1)}',
                    AppColors.gold,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyTab(List<StorePerformanceRowModel> rows) {
    final grouped = _getRowsByDate(rows);
    if (grouped.isEmpty) return _buildEmptyState();

    final productsAsync = ref.watch(allProductsProvider);
    final productList = productsAsync.value ?? [];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: grouped.length,
      separatorBuilder: (context, index) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final dayRows = grouped[date]!;

        double dayRevenue = 0;
        double dayProfit = 0;
        for (final r in dayRows) {
          dayRevenue += r.revenue;
          dayProfit += r.profit;
        }

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppFx.shadow(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              key: PageStorageKey<String>(date.toIso8601String()),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      AppIcons.calendarTodayRounded,
                      color: AppColors.gold,
                      size: 15.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    _formatDate(date),
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.white,
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 6.h),
                child: Row(
                  children: [
                    Text(
                      'Ciro: ',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                    Text(
                      _formatCompactNumber(dayRevenue),
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.green,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Text(
                      'Kâr: ',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                    Text(
                      _formatCompactNumber(dayProfit),
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              iconColor: AppColors.gold,
              collapsedIconColor: AppColors.textMuted,
              childrenPadding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
              children: dayRows.map((row) {
                final matchingProd = productList.firstWhere(
                  (p) => p.id == row.productId,
                  orElse: () => ProductModel(
                    id: row.productId,
                    urunAdi: row.productName,
                    urunIconu: '${row.productId.toLowerCase()}.webp',
                    birimHacim: 0,
                    birimAgirlik: 0,
                    bazSatisFiyati: 0,
                    uretimAdedi: 0,
                    satisAdedi: 0,
                    enDusukFiyat: 0,
                    enYuksekFiyat: 0,
                    ortalamaFiyat: 0,
                    saticiSayisi: 0,
                    piyasadakiStok: 0,
                    createdAt: DateTime.now(),
                  ),
                );

                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardBgLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28.w,
                        height: 28.w,
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: CachedAssetImage(
                          fileName: matchingProd.urunIconu,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.productName,
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.white,
                                fontSize: AppTypography.bodySmall,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Slot ${row.slotIndex} | Kalite ${row.qualityLevel}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: 9.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${row.soldQuantity} Adet',
                            style: AppTextStyles.label.standardCopyWith(
                              color: AppColors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Text(
                                'Ciro: ${_formatCompactNumber(row.revenue)}',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.green,
                                  fontSize: 9.sp,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'Kâr: ${_formatCompactNumber(row.profit)}',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: 9.5.sp,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: AppTextStyles.label.standardCopyWith(
            color: color,
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.insightsRounded,
              color: AppColors.gold,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'Henüz Performans Kaydı Yok',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.white,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Mağazanızda ilk satışlar gerçekleştikçe 14 günlük detaylı analiz raporları burada listelenecektir.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.barChart,
              color: AppColors.red,
              size: AppIconSizes.hero,
            ),
            SizedBox(height: 14.h),
            Text(
              'Mağaza raporu yüklenemedi.',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.white,
                fontSize: AppTypography.titleLarge,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              error.toString(),
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.body,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 14.h),
            ElevatedButton(
              onPressed: () => _refreshPerformance(clearDirty: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  List<AggregatedProductPerformance> _getAggregatedProducts(
    List<StorePerformanceRowModel> rows,
  ) {
    final Map<String, AggregatedProductPerformance> map = {};
    for (final row in rows) {
      map.putIfAbsent(
        row.productId,
        () => AggregatedProductPerformance(
          productId: row.productId,
          productName: row.productName,
        ),
      );
      final agg = map[row.productId]!;
      agg.soldQuantity += row.soldQuantity;
      agg.revenue += row.revenue;
      agg.profit += row.profit;
      agg.saleEventCount += row.saleEventCount;
    }
    final list = map.values.toList();
    list.sort((a, b) => b.profit.compareTo(a.profit));
    return list;
  }

  Map<DateTime, List<StorePerformanceRowModel>> _getRowsByDate(
    List<StorePerformanceRowModel> rows,
  ) {
    final Map<DateTime, List<StorePerformanceRowModel>> map = {};
    for (final row in rows) {
      final day = DateTime(
        row.performanceDate.year,
        row.performanceDate.month,
        row.performanceDate.day,
      );
      map.putIfAbsent(day, () => []);
      map[day]!.add(row);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<DateTime, List<StorePerformanceRowModel>> sortedMap = {};
    for (final key in sortedKeys) {
      final dayRows = map[key]!;
      dayRows.sort((a, b) => b.revenue.compareTo(a.revenue));
      sortedMap[key] = dayRows;
    }
    return sortedMap;
  }

  String _formatCompactNumber(double value) {
    return AppMoney.compact(value, withSymbol: false);
  }

  String _formatCurrency(double value) => AppMoney.compact(value);

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

class AggregatedProductPerformance {
  final String productId;
  final String productName;
  int soldQuantity;
  double revenue;
  double profit;
  int saleEventCount;

  AggregatedProductPerformance({
    required this.productId,
    required this.productName,
    this.soldQuantity = 0,
    this.revenue = 0.0,
    this.profit = 0.0,
    this.saleEventCount = 0,
  });
}

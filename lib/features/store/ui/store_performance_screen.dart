import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
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
    final performanceAsync = ref.watch(storePerformanceProvider(widget.storeId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Magaza Raporu'),
            _buildTabBar(),
            Expanded(
              child: performanceAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildErrorState(context, ref, error),
                data: (data) => RefreshIndicator(
                  onRefresh: () async {
                    await _refreshPerformance(clearDirty: true);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(12.w),
                    children: [
                      if (_selectedTabIndex == 0) ...[
                        _buildMainProfitCard(data.summary),
                        SizedBox(height: 12.h),
                        _buildKpiGrid(data.summary),
                        SizedBox(height: 12.h),
                        _buildTopProductsList(data.rows, data.summary.totalProfit),
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
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Ozet', Icons.bar_chart_rounded),
          _buildTabItem(1, 'Urunler', Icons.category_rounded),
          _buildTabItem(2, 'Gunluk', Icons.calendar_month_rounded),
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.35)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.gold : AppColors.textMuted,
                size: 13.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(AppColors.gold, 18.r),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: AppColors.gold,
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'TOPLAM NET KAR',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  _formatCurrency(summary.totalProfit),
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Son 14 Gunluk Toplam Kazancli Bakiye',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64.w,
            height: 64.w,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '%${profitMargin.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: profitMargin >= 20 ? AppColors.green : AppColors.gold,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Marj',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
      childAspectRatio: 1.7,
      children: [
        _buildGridKpiCard(
          'Toplam Ciro',
          _formatCurrency(summary.totalRevenue),
          AppColors.green,
          Icons.payments_rounded,
        ),
        _buildGridKpiCard(
          'Satilan Adet',
          summary.totalSoldQuantity.toString(),
          Colors.white,
          Icons.inventory_rounded,
        ),
        _buildGridKpiCard(
          'Satis Islemi',
          summary.totalSaleEvents.toString(),
          AppColors.blue,
          Icons.receipt_long_rounded,
        ),
        _buildGridKpiCard(
          'Islem Basi Ciro',
          _formatCurrency(avgRevenuePerEvent),
          AppColors.textSecondary,
          Icons.trending_up_rounded,
        ),
      ],
    );
  }

  Widget _buildGridKpiCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: AppDecorations.premiumCard(AppColors.border, 14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsList(List<StorePerformanceRowModel> rows, double totalProfit) {
    final aggregated = _getAggregatedProducts(rows);
    final topProducts = aggregated.take(3).toList();

    if (topProducts.isEmpty) return const SizedBox.shrink();

    final productsAsync = ref.watch(allProductsProvider);
    final productList = productsAsync.value ?? [];

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.premiumCard(AppColors.border, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.gold, size: 14.sp),
              SizedBox(width: 6.w),
              Text(
                'En Karli Urunler (Top 3)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topProducts.length,
            separatorBuilder: (context, index) => SizedBox(height: 10.h),
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

              final contributionRatio = totalProfit > 0 ? (item.profit / totalProfit) : 0.0;
              final contributionPercent = (contributionRatio * 100).clamp(0.0, 100.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: CachedAssetImage(
                          fileName: matchingProd.urunIconu,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          item.productName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(item.profit),
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: contributionRatio.clamp(0.0, 1.0),
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                            minHeight: 5.h,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      SizedBox(
                        width: 32.w,
                        child: Text(
                          '%${contributionPercent.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(List<StorePerformanceRowModel> rows, double totalProfit) {
    final aggregated = _getAggregatedProducts(rows);
    if (aggregated.isEmpty) return _buildEmptyState();

    final productsAsync = ref.watch(allProductsProvider);
    final productList = productsAsync.value ?? [];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: aggregated.length,
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
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

        final avgPrice = item.soldQuantity > 0 ? item.revenue / item.soldQuantity : 0.0;
        final margin = item.revenue > 0 ? (item.profit / item.revenue) * 100 : 0.0;

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: AppDecorations.premiumCard(null, 16.r),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 32.w,
                    height: 32.w,
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Toplam ${item.saleEventCount} islemde satildi',
                          style: TextStyle(
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
                        'Kar: ${_formatCurrency(item.profit)}',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Ciro: ${_formatCurrency(item.revenue)}',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              const Divider(color: AppColors.border, thickness: 0.5),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetric('Satilan Adet', item.soldQuantity.toString()),
                  _buildMiniMetric('Ort. Fiyat', _formatCurrency(avgPrice)),
                  _buildMiniMetric('Kar Marji', '%${margin.toStringAsFixed(1)}'),
                  _buildMiniMetric('Kar Payi', '%${(totalProfit > 0 ? (item.profit / totalProfit * 100) : 0).toStringAsFixed(1)}'),
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
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
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
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: Container(
            decoration: AppDecorations.premiumCard(null, 14.r),
            child: ExpansionTile(
              key: PageStorageKey<String>(date.toIso8601String()),
              title: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.textSecondary,
                    size: 13.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _formatDate(date),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Row(
                  children: [
                    Text(
                      'Ciro: ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                    Text(
                      _formatCompactNumber(dayRevenue),
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Kar: ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                    Text(
                      _formatCompactNumber(dayProfit),
                      style: TextStyle(
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
              childrenPadding: EdgeInsets.all(10.w),
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
                  margin: EdgeInsets.only(bottom: 6.h),
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CachedAssetImage(
                          fileName: matchingProd.urunIconu,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.productName,
                              style: TextStyle(
                                color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Slot ${row.slotIndex} | Q${row.qualityLevel}',
                                style: TextStyle(
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                Text(
                                  'Ciro: ${_formatCompactNumber(row.revenue)}',
                                  style: TextStyle(
                                    color: AppColors.green,
                                    fontSize: 9.sp,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'Kar: ${_formatCompactNumber(row.profit)}',
                                  style: TextStyle(
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

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: AppDecorations.premiumCard(AppColors.border, 16.r),
      child: Center(
        child: Text(
          'Son 14 gunde performans kaydi yok.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.sp,
          ),
          textAlign: TextAlign.center,
        ),
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
            const Icon(Icons.bar_chart, color: AppColors.red, size: 48),
            SizedBox(height: 14.h),
            Text(
              'Magaza raporu yuklenemedi.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              error.toString(),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 14.h),
            ElevatedButton(
              onPressed: () => _refreshPerformance(clearDirty: true),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  List<AggregatedProductPerformance> _getAggregatedProducts(List<StorePerformanceRowModel> rows) {
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

  Map<DateTime, List<StorePerformanceRowModel>> _getRowsByDate(List<StorePerformanceRowModel> rows) {
    final Map<DateTime, List<StorePerformanceRowModel>> map = {};
    for (final row in rows) {
      final day = DateTime(row.performanceDate.year, row.performanceDate.month, row.performanceDate.day);
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

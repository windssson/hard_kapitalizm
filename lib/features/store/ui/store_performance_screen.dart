import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
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
    extends ConsumerState<StorePerformanceScreen>
    with RouteRefreshMixin<StorePerformanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshRouteData());
  }

  @override
  void refreshRouteData() {
    ref.invalidate(storePerformanceProvider(widget.storeId));
    ref.read(storePerformanceProvider(widget.storeId).future);
  }

  @override
  Widget build(BuildContext context) {
    final performanceAsync = ref.watch(storePerformanceProvider(widget.storeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Magaza Raporu'),
            Expanded(
              child: performanceAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _buildErrorState(context, ref, error),
                data: (data) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(storePerformanceProvider(widget.storeId));
                    await ref.read(
                      storePerformanceProvider(widget.storeId).future,
                    );
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(12.w),
                    children: [
                      _buildSummaryCard(data.summary),
                      SizedBox(height: 14.h),
                      _buildInsightRow(data),
                      SizedBox(height: 14.h),
                      if (data.rows.isEmpty)
                        _buildEmptyState()
                      else ...[
                        Text(
                          'Gunluk Urun Performansi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        ..._sortRows(data.rows).map(_buildRowCard),
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
              onPressed: () =>
                  ref.refresh(storePerformanceProvider(widget.storeId)),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(StorePerformanceSummaryModel summary) {
    final avgRevenuePerEvent = summary.totalSaleEvents > 0
        ? summary.totalRevenue / summary.totalSaleEvents
        : 0.0;
    final profitMargin = summary.totalRevenue > 0
        ? (summary.totalProfit / summary.totalRevenue) * 100
        : 0.0;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Son 14 Gun Ozeti',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              _buildKpiCard(
                'Toplam Ciro',
                _formatCurrency(summary.totalRevenue),
                AppColors.green,
                Icons.payments_rounded,
              ),
              _buildKpiCard(
                'Toplam Kar',
                _formatCurrency(summary.totalProfit),
                AppColors.gold,
                Icons.savings_rounded,
              ),
              _buildKpiCard(
                'Satilan Adet',
                summary.totalSoldQuantity.toString(),
                Colors.white,
                Icons.inventory_rounded,
              ),
              _buildKpiCard(
                'Satis Islemi',
                summary.totalSaleEvents.toString(),
                AppColors.blue,
                Icons.receipt_long_rounded,
              ),
              _buildKpiCard(
                'Islem Basi Ciro',
                _formatCurrency(avgRevenuePerEvent),
                AppColors.textSecondary,
                Icons.trending_up_rounded,
              ),
              _buildKpiCard(
                'Kar Marji',
                '%${profitMargin.toStringAsFixed(1)}',
                profitMargin >= 20 ? AppColors.green : AppColors.gold,
                Icons.pie_chart_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(StorePerformanceResponseModel data) {
    final rows = _sortRows(data.rows);
    final topRevenueRow = rows.isEmpty
        ? null
        : rows.reduce((best, row) => row.revenue > best.revenue ? row : best);
    final topProfitRow = rows.isEmpty
        ? null
        : rows.reduce((best, row) => row.profit > best.profit ? row : best);

    return Row(
      children: [
        Expanded(
          child: _buildInsightCard(
            title: 'En Yuksek Ciro',
            row: topRevenueRow,
            accentColor: AppColors.green,
            metricLabel: 'Ciro',
            metricValue: topRevenueRow == null
                ? '-'
                : _formatCurrency(topRevenueRow.revenue),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildInsightCard(
            title: 'En Yuksek Kar',
            row: topProfitRow,
            accentColor: AppColors.gold,
            metricLabel: 'Kar',
            metricValue: topProfitRow == null
                ? '-'
                : _formatCurrency(topProfitRow.profit),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required StorePerformanceRowModel? row,
    required Color accentColor,
    required String metricLabel,
    required String metricValue,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            row?.productName ?? 'Kayit yok',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            row == null
                ? 'Son 14 gunde veri bulunmuyor.'
                : '${_formatDate(row.performanceDate)} | Slot ${row.slotIndex}',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '$metricLabel: $metricValue',
            style: TextStyle(
              color: accentColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String label,
    String value,
    Color valueColor,
    IconData icon,
  ) {
    return Container(
      width: 145.w,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: valueColor, size: 18.sp),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Son 14 gunde performans kaydi yok.',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13.sp,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRowCard(StorePerformanceRowModel row) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.productName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatDate(row.performanceDate),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Slot ${row.slotIndex} | Kalite ${row.qualityLevel}',
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.85),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Adet', row.soldQuantity.toString()),
              _buildMiniMetric('Ciro', _formatCompactNumber(row.revenue)),
              _buildMiniMetric('Kar', _formatCompactNumber(row.profit)),
              _buildMiniMetric('Islem', row.saleEventCount.toString()),
            ],
          ),
          if (row.lastSaleAt != null) ...[
            SizedBox(height: 8.h),
            Text(
              'Son satis: ${_formatDateTime(row.lastSaleAt!)}',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
              ),
            ),
          ],
        ],
      ),
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
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<StorePerformanceRowModel> _sortRows(List<StorePerformanceRowModel> rows) {
    final sorted = List<StorePerformanceRowModel>.from(rows);
    sorted.sort((a, b) {
      final dateCompare = b.performanceDate.compareTo(a.performanceDate);
      if (dateCompare != 0) return dateCompare;
      final revenueCompare = b.revenue.compareTo(a.revenue);
      if (revenueCompare != 0) return revenueCompare;
      return b.profit.compareTo(a.profit);
    });
    return sorted;
  }

  String _formatCompactNumber(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  String _formatCurrency(double value) => 'TL ${_formatCompactNumber(value)}';

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDate(date)} $hour:$minute';
  }
}

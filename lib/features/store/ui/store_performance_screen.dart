import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_performance_model.dart';

class StorePerformanceScreen extends ConsumerWidget {
  final String storeId;

  const StorePerformanceScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(storePerformanceProvider(storeId));

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
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(
                      error.toString(),
                      style: TextStyle(color: AppColors.red, fontSize: 14.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (data) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(storePerformanceProvider(storeId));
                    await ref.read(storePerformanceProvider(storeId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.all(12.w),
                    children: [
                      _buildSummaryCard(data.summary),
                      SizedBox(height: 14.h),
                      if (data.rows.isEmpty)
                        Container(
                          padding: EdgeInsets.all(18.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'Son 14 gunde performans kaydi yok.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...data.rows.map(_buildRowCard),
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

  Widget _buildSummaryCard(StorePerformanceSummaryModel summary) {
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
          _buildSummaryRow('Toplam Ciro', summary.totalRevenue, AppColors.green),
          _buildSummaryRow('Toplam Kar', summary.totalProfit, AppColors.gold),
          _buildSummaryRow(
            'Satilan Adet',
            summary.totalSoldQuantity.toDouble(),
            Colors.white,
            isCurrency: false,
          ),
          _buildSummaryRow(
            'Satis Islem Sayisi',
            summary.totalSaleEvents.toDouble(),
            AppColors.blue,
            isCurrency: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    Color valueColor, {
    bool isCurrency = true,
  }) {
    final displayValue = isCurrency ? value.toStringAsFixed(1) : value.toInt().toString();
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          ),
          Text(
            displayValue,
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
              _buildMiniMetric('Ciro', row.revenue.toStringAsFixed(1)),
              _buildMiniMetric('Kar', row.profit.toStringAsFixed(1)),
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

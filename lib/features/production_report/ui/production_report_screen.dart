import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/data/production_daily_stats_service.dart';
import 'package:hard_kapitalizm/core/models/production_daily_stat_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';

class ProductionReportScreen extends ConsumerWidget {
  final String ownerKind;
  final String ownerId;
  final String ownerName;

  const ProductionReportScreen({
    super.key,
    required this.ownerKind,
    required this.ownerId,
    required this.ownerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().toUtc();
    final dateTo = DateTime.utc(today.year, today.month, today.day);
    final dateFrom = dateTo.subtract(const Duration(days: 6));
    final query = ProductionDailyStatsQuery(
      ownerKind: ownerKind,
      ownerId: ownerId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final statsAsync = ref.watch(productionDailyStatsProvider(query));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Uretim Raporu'),
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.red, fontSize: 13.sp),
                    ),
                  ),
                ),
                data: (stats) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(productionDailyStatsProvider(query));
                    await ref.read(productionDailyStatsProvider(query).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 24.h),
                    children: [
                      _buildHero(),
                      SizedBox(height: 12.h),
                      if (stats.isEmpty)
                        _buildEmptyState()
                      else ...[
                        _buildSummaryGrid(stats),
                        SizedBox(height: 12.h),
                        _buildTopProducts(stats),
                        SizedBox(height: 12.h),
                        _buildDailyBreakdown(stats, dateFrom),
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

  Widget _buildHero() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ownerName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${_ownerKindLabel(ownerKind)} icin son 7 gunluk uretim ve kar raporu',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        children: [
          Icon(Icons.query_stats_rounded, color: AppColors.gold, size: 30.sp),
          SizedBox(height: 10.h),
          Text(
            'Henuz son 7 gun icinde kayitli uretim yok.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<ProductionDailyStatModel> stats) {
    final totalProduced = stats.fold<int>(0, (sum, item) => sum + item.producedQuantity);
    final totalRevenue = stats.fold<double>(0, (sum, item) => sum + item.estimatedRevenue);
    final totalCost = stats.fold<double>(0, (sum, item) => sum + item.totalCost);
    final totalProfit = stats.fold<double>(0, (sum, item) => sum + item.estimatedProfit);
    final activeDays = stats.map((item) => _dayKey(item.productionDate)).toSet();
    final todayKey = _dayKey(DateTime.now().toUtc());
    final todayProduced = stats
        .where((item) => _dayKey(item.productionDate) == todayKey)
        .fold<int>(0, (sum, item) => sum + item.producedQuantity);
    final todayRevenue = stats
        .where((item) => _dayKey(item.productionDate) == todayKey)
        .fold<double>(0, (sum, item) => sum + item.estimatedRevenue);
    final todayProfit = stats
        .where((item) => _dayKey(item.productionDate) == todayKey)
        .fold<double>(0, (sum, item) => sum + item.estimatedProfit);
    final avgPerActiveDay = activeDays.isEmpty ? 0 : (totalProduced / activeDays.length).round();

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        _buildMetricCard('Toplam Uretim', totalProduced.toString(), AppColors.gold),
        _buildMetricCard('Tahmini Gelir', _formatMoney(totalRevenue), AppColors.blue),
        _buildMetricCard('Toplam Maliyet', _formatMoney(totalCost), AppColors.red),
        _buildMetricCard('Tahmini Kar', _formatMoney(totalProfit), AppColors.green),
        _buildMetricCard('Bugun', todayProduced.toString(), Colors.orange),
        _buildMetricCard('Bugunku Gelir', _formatMoney(todayRevenue), Colors.orange),
        _buildMetricCard('Bugunku Kar', _formatMoney(todayProfit), AppColors.green),
        _buildMetricCard('Gunluk Ort.', avgPerActiveDay.toString(), AppColors.blue),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      width: 108.w,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(List<ProductionDailyStatModel> stats) {
    final topProducts = _groupByProduct(stats).values.toList()
      ..sort((a, b) => b.estimatedProfit.compareTo(a.estimatedProfit));

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Urun Bazli Karlilik',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          ...topProducts.take(5).map(
            (item) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.all(6.w),
                    child: item.icon.isNotEmpty
                        ? CachedAssetImage(fileName: item.icon, fit: BoxFit.contain)
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.gold,
                            size: 18.sp,
                          ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Adet: ${item.total} | Baz: ${_formatMoney(item.baseSalePrice)}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Gelir: ${_formatMoney(item.estimatedRevenue)} | Maliyet: ${_formatMoney(item.totalCost)}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMoney(item.estimatedProfit),
                    style: TextStyle(
                      color: item.estimatedProfit >= 0 ? AppColors.green : AppColors.red,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
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

  Widget _buildDailyBreakdown(
    List<ProductionDailyStatModel> stats,
    DateTime dateFrom,
  ) {
    final groupedQty = <String, int>{};
    final groupedRevenue = <String, double>{};
    final groupedCost = <String, double>{};
    final groupedProfit = <String, double>{};

    for (final item in stats) {
      final key = _dayKey(item.productionDate);
      groupedQty[key] = (groupedQty[key] ?? 0) + item.producedQuantity;
      groupedRevenue[key] = (groupedRevenue[key] ?? 0) + item.estimatedRevenue;
      groupedCost[key] = (groupedCost[key] ?? 0) + item.totalCost;
      groupedProfit[key] = (groupedProfit[key] ?? 0) + item.estimatedProfit;
    }

    final days = List<DateTime>.generate(
      7,
      (index) => DateTime.utc(dateFrom.year, dateFrom.month, dateFrom.day + index),
    );

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gunluk Karlilik',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          ...days.map((day) {
            final key = _dayKey(day);
            final quantity = groupedQty[key] ?? 0;
            final revenue = groupedRevenue[key] ?? 0;
            final cost = groupedCost[key] ?? 0;
            final profit = groupedProfit[key] ?? 0;
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 86.w,
                        child: Text(
                          _formatShortDate(day),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: LinearProgressIndicator(
                            value: _progressForDay(quantity, groupedQty),
                            minHeight: 8.h,
                            backgroundColor: AppColors.cardBgLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      SizedBox(
                        width: 36.w,
                        child: Text(
                          quantity.toString(),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Gelir: ${_formatMoney(revenue)} | Maliyet: ${_formatMoney(cost)} | Kar: ${_formatMoney(profit)}',
                      style: TextStyle(
                        color: profit >= 0 ? AppColors.green : AppColors.red,
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Map<String, _ProductAggregate> _groupByProduct(
    List<ProductionDailyStatModel> stats,
  ) {
    final result = <String, _ProductAggregate>{};
    for (final item in stats) {
      final current = result[item.productId];
      if (current == null) {
        result[item.productId] = _ProductAggregate(
          id: item.productId,
          name: item.productName,
          icon: item.productIcon,
          baseSalePrice: item.baseSalePrice,
          total: item.producedQuantity,
          totalCost: item.totalCost,
          estimatedRevenue: item.estimatedRevenue,
          estimatedProfit: item.estimatedProfit,
        );
      } else {
        result[item.productId] = current.copyWith(
          total: current.total + item.producedQuantity,
          totalCost: current.totalCost + item.totalCost,
          estimatedRevenue: current.estimatedRevenue + item.estimatedRevenue,
          estimatedProfit: current.estimatedProfit + item.estimatedProfit,
        );
      }
    }
    return result;
  }

  double _progressForDay(int quantity, Map<String, int> grouped) {
    final maxValue = grouped.values.fold<int>(0, (best, item) => item > best ? item : best);
    if (maxValue <= 0) return 0;
    return (quantity / maxValue).clamp(0, 1).toDouble();
  }

  String _dayKey(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Oca',
      'Sub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Agu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
  }

  String _ownerKindLabel(String kind) {
    switch (kind) {
      case 'factory':
        return 'Fabrika';
      case 'farm':
        return 'Tarla';
      case 'field':
        return 'Ciftlik';
      case 'mine':
        return 'Maden';
      default:
        return 'Uretim Birimi';
    }
  }

  String _formatMoney(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B TL';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M TL';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K TL';
    return '${value.toStringAsFixed(0)} TL';
  }
}

class _ProductAggregate {
  final String id;
  final String name;
  final String icon;
  final double baseSalePrice;
  final int total;
  final double totalCost;
  final double estimatedRevenue;
  final double estimatedProfit;

  const _ProductAggregate({
    required this.id,
    required this.name,
    required this.icon,
    required this.baseSalePrice,
    required this.total,
    required this.totalCost,
    required this.estimatedRevenue,
    required this.estimatedProfit,
  });

  _ProductAggregate copyWith({
    String? id,
    String? name,
    String? icon,
    double? baseSalePrice,
    int? total,
    double? totalCost,
    double? estimatedRevenue,
    double? estimatedProfit,
  }) {
    return _ProductAggregate(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      baseSalePrice: baseSalePrice ?? this.baseSalePrice,
      total: total ?? this.total,
      totalCost: totalCost ?? this.totalCost,
      estimatedRevenue: estimatedRevenue ?? this.estimatedRevenue,
      estimatedProfit: estimatedProfit ?? this.estimatedProfit,
    );
  }
}

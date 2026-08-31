import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/data/production_daily_stats_service.dart';
import 'package:hard_kapitalizm/core/models/production_daily_stat_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
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
    final today = DateTime.now();
    final dateTo = DateTime(today.year, today.month, today.day);
    final dateFrom = dateTo.subtract(const Duration(days: 6));
    final query = ProductionDailyStatsQuery(
      ownerKind: ownerKind,
      ownerId: ownerId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final statsAsync = ref.watch(productionDailyStatsProvider(query));

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Üretim Raporu'),
            Expanded(
              child: statsAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                        fontSize: AppTypography.bodyLarge,
                      ),
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
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.headline,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${_ownerKindLabel(ownerKind)} için son 7 günlük özet',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodySmall,
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
          Icon(AppIcons.queryStatsRounded, color: AppColors.gold, size: AppIconSizes.xLarge),
          SizedBox(height: 10.h),
          Text(
            'Henuz son 7 gun icinde kayitli uretim yok.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<ProductionDailyStatModel> stats) {
    final totalProduced = stats.fold<int>(
      0,
      (sum, item) => sum + item.producedQuantity,
    );
    final totalProfit = stats.fold<double>(
      0,
      (sum, item) => sum + item.estimatedProfit,
    );
    final topProducts = _groupByProduct(stats).values.toList()
      ..sort((a, b) => b.estimatedProfit.compareTo(a.estimatedProfit));
    final topProduct = topProducts.isNotEmpty ? topProducts.first : null;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Toplam Üretim',
            totalProduced.toString(),
            AppColors.gold,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildMetricCard(
            'Tahmini Kar',
            _formatMoney(totalProfit),
            AppColors.green,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildMetricCard(
            'En Kârlı Ürün',
            topProduct?.name ?? '-',
            AppColors.blue,
            subtitle: topProduct == null
                ? null
                : _formatMoney(topProduct.estimatedProfit),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardBg,
            Color.alphaBlend(color.withValues(alpha: 0.05), AppColors.cardBg),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.standardCopyWith(
              color: color,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textSecondary,
                fontSize: AppTypography.micro,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
            'Öne Çıkan Ürünler',
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          ...topProducts.take(3).map(
            (item) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.cardBgLight,
                    AppColors.cardBg.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.borderGoldLight.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.2),
                    blurRadius: 4.r,
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
                      color: AppFx.panelWash(0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.all(6.w),
                    child: item.icon.isNotEmpty
                        ? CachedAssetImage(
                            fileName: item.icon,
                            fit: BoxFit.contain,
                          )
                        : Icon(
                            AppIcons.inventory2Outlined,
                            color: AppColors.gold,
                            size: AppIconSizes.regular,
                          ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${item.total} adet üretildi',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Tahmini kar: ${_formatMoney(item.estimatedProfit)}',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.caption,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMoney(item.unitProfit),
                    style: AppTextStyles.body.standardCopyWith(
                      color: item.unitProfit >= 0
                          ? AppColors.green
                          : AppColors.red,
                      fontSize: AppTypography.bodySmall,
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
    final groupedProfit = <String, double>{};

    for (final item in stats) {
      final key = _dayKey(item.productionDate);
      groupedQty[key] = (groupedQty[key] ?? 0) + item.producedQuantity;
      groupedProfit[key] = (groupedProfit[key] ?? 0) + item.estimatedProfit;
    }

    final days = List<DateTime>.generate(
      7,
      (index) => DateTime.utc(
        dateFrom.year,
        dateFrom.month,
        dateFrom.day + index,
      ),
    );

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Son 7 Gun',
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          ...days.map((day) {
            final key = _dayKey(day);
            final quantity = groupedQty[key] ?? 0;
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
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.bodySmall,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: AppProgressBar(
                            value: _progressForDay(quantity, groupedQty),
                            minHeight: 8.h,
                            backgroundColor: AppColors.cardBgLight,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(
                                  profit >= 0 ? AppColors.green : AppColors.red,
                                ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      SizedBox(
                        width: 36.w,
                        child: Text(
                          quantity.toString(),
                          textAlign: TextAlign.right,
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.bodySmall,
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
                      'Kar: ${_formatMoney(profit)}',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: profit >= 0 ? AppColors.green : AppColors.red,
                        fontSize: AppTypography.caption,
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
          total: item.producedQuantity,
          estimatedProfit: item.estimatedProfit,
        );
      } else {
        result[item.productId] = current.copyWith(
          total: current.total + item.producedQuantity,
          estimatedProfit: current.estimatedProfit + item.estimatedProfit,
        );
      }
    }
    return result;
  }

  double _progressForDay(int quantity, Map<String, int> grouped) {
    final maxValue = grouped.values.fold<int>(
      0,
      (best, item) => item > best ? item : best,
    );
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
        return 'Çiftlik';
      case 'mine':
        return 'Maden';
      default:
        return 'Üretim Birimi';
    }
  }

  String _formatMoney(double value) {
    return AppMoney.compact(value);
  }
}

class _ProductAggregate {
  final String id;
  final String name;
  final String icon;
  final int total;
  final double estimatedProfit;

  const _ProductAggregate({
    required this.id,
    required this.name,
    required this.icon,
    required this.total,
    required this.estimatedProfit,
  });

  double get unitProfit => total <= 0 ? 0 : estimatedProfit / total;

  _ProductAggregate copyWith({
    String? id,
    String? name,
    String? icon,
    int? total,
    double? estimatedProfit,
  }) {
    return _ProductAggregate(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      total: total ?? this.total,
      estimatedProfit: estimatedProfit ?? this.estimatedProfit,
    );
  }
}

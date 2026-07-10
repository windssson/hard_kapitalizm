import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_finance_entry_model.dart';

class LogisticsFinanceReportScreen extends ConsumerWidget {
  const LogisticsFinanceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(logisticsFinanceEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Lojistik Raporu'),
            Expanded(
              child: entriesAsync.when(
                data: (entries) => _buildContent(entries),
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => _buildError(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<LogisticsFinanceEntryModel> entries) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final recentEntries = entries
        .where((entry) => !entry.createdAt.toLocal().isBefore(start))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalIncome = recentEntries
        .where((entry) => entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final totalExpense = recentEntries
        .where((entry) => entry.isExpense)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final net = totalIncome - totalExpense;

    return ListView(
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 80.h),
      children: [
        _buildSummaryCard(totalIncome, totalExpense, net),
        SizedBox(height: 14.h),
        _buildDailyStrip(recentEntries, now),
        SizedBox(height: 18.h),
        Text(
          'SON 7 GUN KAYITLARI',
          style: AppTextStyles.titleGold.standardCopyWith(fontSize: AppTypography.body),
        ),
        SizedBox(height: 10.h),
        if (recentEntries.isEmpty)
          _buildEmptyState()
        else
          ...recentEntries.map(_buildEntryCard),
      ],
    );
  }

  Widget _buildSummaryCard(double income, double expense, double net) {
    final netColor = net >= 0 ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Son 7 Gun',
            style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.headline),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'Gelir',
                  income,
                  AppColors.green,
                  AppIcons.trendingUp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSummaryMetric(
                  'Gider',
                  expense,
                  AppColors.red,
                  AppIcons.trendingDown,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSummaryMetric(
                  'Net',
                  net,
                  netColor,
                  AppIcons.accountBalanceWalletOutlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppIconSizes.regular),
          SizedBox(height: 7.h),
          Text(
            label,
            style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
          ),
          Text(
            _formatMoney(amount),
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStrip(
    List<LogisticsFinanceEntryModel> entries,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    return SizedBox(
      height: 96.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final day = start.add(Duration(days: index));
          final dayEntries = entries
              .where((entry) => _isSameDay(entry.createdAt.toLocal(), day))
              .toList();
          final income = dayEntries
              .where((entry) => entry.isIncome)
              .fold<double>(0, (sum, entry) => sum + entry.amount);
          final expense = dayEntries
              .where((entry) => entry.isExpense)
              .fold<double>(0, (sum, entry) => sum + entry.amount);
          return _buildDailyCard(day, income, expense);
        },
      ),
    );
  }

  Widget _buildDailyCard(DateTime day, double income, double expense) {
    return Container(
      width: 104.w,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(day),
            style: AppTextStyles.titleGold.standardCopyWith(fontSize: AppTypography.label),
          ),
          SizedBox(height: 8.h),
          Text(
            '+${_formatMoney(income)}',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.green,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '-${_formatMoney(expense)}',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.red,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(LogisticsFinanceEntryModel entry) {
    final color = entry.isIncome ? AppColors.green : AppColors.red;
    final sign = entry.isIncome ? '+' : '-';
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_categoryIcon(entry.category), color: color, size: AppIconSizes.regular),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description ?? _categoryLabel(entry.category),
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  '${_categoryLabel(entry.category)} | ${_formatDateTime(entry.createdAt.toLocal())}',
                  style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
                ),
              ],
            ),
          ),
          Text(
            '$sign${_formatMoney(entry.amount)}',
            style: AppTextStyles.body.standardCopyWith(
              color: color,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.w900,
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Son 7 gunde gelir-gider kaydi yok.',
        style: AppTextStyles.body,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Text(
        'Rapor verileri yuklenemedi.',
        style: AppTextStyles.body,
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'vehicle_purchase' => AppIcons.localShippingRounded,
      'fuel_purchase' => AppIcons.localGasStation,
      'maintenance' => AppIcons.build,
      'rental_income' => AppIcons.paymentsOutlined,
      _ => AppIcons.receiptLong,
    };
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'vehicle_purchase' => 'Arac Alimi',
      'fuel_purchase' => 'Yakit Gideri',
      'maintenance' => 'Bakim Gideri',
      'rental_income' => 'Kira Geliri',
      _ => 'Kayit',
    };
  }

  String _formatMoney(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDate(date)} $hour:$minute';
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

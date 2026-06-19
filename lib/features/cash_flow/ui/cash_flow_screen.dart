import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/cash_flow/data/cash_flow_provider.dart';
import 'package:hard_kapitalizm/features/cash_flow/models/cash_movement_entry_model.dart';

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(cashMovementEntriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Cash Hareketleri'),
            Expanded(
              child: entriesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _CashFlowError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(cashMovementEntriesProvider),
                ),
                data: (entries) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(cashMovementEntriesProvider);
                    await ref.read(cashMovementEntriesProvider.future);
                  },
                  child: entries.isEmpty
                      ? const _CashFlowEmpty()
                      : _CashFlowList(entries: entries),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowList extends StatelessWidget {
  const _CashFlowList({required this.entries});

  final List<CashMovementEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    final income = entries
        .where((entry) => entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final expense = entries
        .where((entry) => !entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount.abs());
    final net = income - expense;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 28.h),
      itemCount: entries.length + 1,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CashFlowSummaryCard(
            totalCount: entries.length,
            income: income,
            expense: expense,
            net: net,
          );
        }

        final entry = entries[index - 1];
        return _CashFlowEntryCard(entry: entry);
      },
    );
  }
}

class _CashFlowSummaryCard extends StatelessWidget {
  const _CashFlowSummaryCard({
    required this.totalCount,
    required this.income,
    required this.expense,
    required this.net,
  });

  final int totalCount;
  final double income;
  final double expense;
  final double net;

  @override
  Widget build(BuildContext context) {
    final netColor = net >= 0 ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(AppColors.gold, 20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tum Cash Akisi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$totalCount kayit listeleniyor',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Giren',
                  value: _formatMoney(income),
                  color: AppColors.green,
                  icon: Icons.south_west_rounded,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _MetricCard(
                  label: 'Cikan',
                  value: _formatMoney(expense),
                  color: AppColors.red,
                  icon: Icons.north_east_rounded,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _MetricCard(
                  label: 'Net',
                  value: _formatMoney(net),
                  color: netColor,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowEntryCard extends StatelessWidget {
  const _CashFlowEntryCard({required this.entry});

  final CashMovementEntryModel entry;

  @override
  Widget build(BuildContext context) {
    final accentColor = entry.isIncome ? AppColors.green : AppColors.red;
    final icon = entry.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final amountPrefix = entry.isIncome ? '+' : '-';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.premiumCard(accentColor, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: accentColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatDateTime(entry.createdAt),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$amountPrefix${_formatMoney(entry.amount.abs())}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if ((entry.description ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              entry.description!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.sp,
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _InfoChip(
                label: 'Tip',
                value: entry.isIncome ? 'Giris' : 'Cikis',
                color: accentColor,
              ),
              if ((entry.category ?? '').trim().isNotEmpty)
                _InfoChip(
                  label: 'Kategori',
                  value: _formatLabel(entry.category!),
                  color: AppColors.gold,
                ),
              if (entry.balanceAfter != null)
                _InfoChip(
                  label: 'Bakiye',
                  value: _formatMoney(entry.balanceAfter!),
                  color: AppColors.blue,
                ),
              if ((entry.referenceType ?? '').trim().isNotEmpty)
                _InfoChip(
                  label: 'Kaynak',
                  value: _formatLabel(entry.referenceType!),
                  color: Colors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CashFlowEmpty extends StatelessWidget {
  const _CashFlowEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(22.w),
      children: [
        SizedBox(height: 120.h),
        Container(
          padding: EdgeInsets.all(24.w),
          decoration: AppDecorations.premiumCard(AppColors.border, 20.r),
          child: Column(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.textMuted,
                size: 48.sp,
              ),
              SizedBox(height: 14.h),
              Text(
                'Henuz cash hareketi yok.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Kazanc, satin alim, transfer veya diger bakiye degisiklikleri burada gorunecek.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CashFlowError extends StatelessWidget {
  const _CashFlowError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(22.w),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: AppDecorations.premiumCard(AppColors.red, 20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.red, size: 42.sp),
              SizedBox(height: 12.h),
              Text(
                'Cash hareketleri yuklenemedi.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.sp,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 14.h),
              TextButton(
                onPressed: onRetry,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMoney(double amount) {
  final absolute = amount.abs();
  if (absolute >= 1000000000) {
    return '${(amount / 1000000000).toStringAsFixed(1)}B';
  }
  if (absolute >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (absolute >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toStringAsFixed(0);
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

String _formatLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/cash_flow/data/cash_flow_provider.dart';
import 'package:hard_kapitalizm/features/cash_flow/models/cash_movement_entry_model.dart';

class _ChartDataPoint {
  final DateTime date;
  final double income;
  final double expense;

  _ChartDataPoint({
    required this.date,
    required this.income,
    required this.expense,
  });
}

List<_ChartDataPoint> _getDailyDataPoints(List<CashMovementEntryModel> entries) {
  final Map<DateTime, (double income, double expense)> dailyMap = {};

  for (final entry in entries) {
    final date = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    final current = dailyMap[date] ?? (0.0, 0.0);
    if (entry.isIncome) {
      dailyMap[date] = (current.$1 + entry.amount, current.$2);
    } else {
      dailyMap[date] = (current.$1, current.$2 + entry.amount.abs());
    }
  }

  final sortedDates = dailyMap.keys.toList()..sort();
  final List<_ChartDataPoint> points = [];

  if (sortedDates.isEmpty) {
    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      points.add(
        _ChartDataPoint(
          date: today.subtract(Duration(days: i)),
          income: 0,
          expense: 0,
        ),
      );
    }
    return points;
  }

  final displayDates =
      sortedDates.length > 7
          ? sortedDates.sublist(sortedDates.length - 7)
          : sortedDates;

  for (final date in displayDates) {
    final val = dailyMap[date]!;
    points.add(_ChartDataPoint(date: date, income: val.$1, expense: val.$2));
  }

  if (points.length < 5) {
    final firstDate = points.first.date;
    final needed = 5 - points.length;
    for (int i = needed; i > 0; i--) {
      points.insert(
        0,
        _ChartDataPoint(
          date: firstDate.subtract(Duration(days: i)),
          income: 0,
          expense: 0,
        ),
      );
    }
  }

  return points;
}

class CashFlowScreen extends ConsumerStatefulWidget {
  const CashFlowScreen({super.key});

  @override
  ConsumerState<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends ConsumerState<CashFlowScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(cashMovementEntriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Para Hareketleri'),
            _buildTabSelector(),
            Expanded(
              child: entriesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _CashFlowError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(cashMovementEntriesProvider),
                ),
                data:
                    (entries) => RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(cashMovementEntriesProvider);
                        await ref.read(cashMovementEntriesProvider.future);
                      },
                      child:
                          entries.isEmpty
                              ? const _CashFlowEmpty()
                              : _selectedTab == 0
                              ? _buildAnalysisView(entries)
                              : _CashFlowList(entries: entries),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              0,
              'Grafik & Analiz',
              Icons.analytics_outlined,
            ),
          ),
          Expanded(
            child: _buildTabButton(1, 'İşlem Geçmişi', Icons.history_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.gold.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color:
                isSelected ? AppColors.gold.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected ? AppColors.gold : AppColors.textMuted,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisView(List<CashMovementEntryModel> entries) {
    final income = entries
        .where((entry) => entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final expense = entries
        .where((entry) => !entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount.abs());
    final net = income - expense;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 28.h),
      children: [
        _CashFlowSummaryCard(
          totalCount: entries.length,
          income: income,
          expense: expense,
          net: net,
        ),
        SizedBox(height: 14.h),
        _CashFlowLineChart(entries: entries),
        SizedBox(height: 14.h),
        _CashFlowCategoryBreakdown(entries: entries),
      ],
    );
  }
}

class _CashFlowLineChart extends StatelessWidget {
  final List<CashMovementEntryModel> entries;

  const _CashFlowLineChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final dailyData = _getDailyDataPoints(entries);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(null, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Akış Trendi (Günlük)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const _LegendItem(color: AppColors.green, label: 'Gelir'),
                  SizedBox(width: 10.w),
                  const _LegendItem(color: AppColors.red, label: 'Gider'),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 180.h,
            width: double.infinity,
            child: CustomPaint(painter: _ChartPainter(points: dailyData)),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_ChartDataPoint> points;

  _ChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double paddingLeft = 40.w;
    final double paddingRight = 8.w;
    final double paddingTop = 12.h;
    final double paddingBottom = 20.h;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    double maxVal = 0.0;
    for (final p in points) {
      if (p.income > maxVal) maxVal = p.income;
      if (p.expense > maxVal) maxVal = p.expense;
    }
    if (maxVal == 0) maxVal = 1000.0;
    maxVal = maxVal * 1.15;

    final int gridLinesCount = 3;
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (int i = 0; i <= gridLinesCount; i++) {
      final double ratio = i / gridLinesCount;
      final double y = paddingTop + chartHeight * (1 - ratio);

      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(paddingLeft + chartWidth, y),
        gridPaint,
      );

      final double val = maxVal * ratio;
      textPainter.text = TextSpan(
        text: _formatMoney(val),
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 9.sp,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          paddingLeft - textPainter.width - 6.w,
          y - textPainter.height / 2,
        ),
      );
    }

    final datePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 1;

    canvas.drawLine(
      Offset(paddingLeft, paddingTop + chartHeight),
      Offset(paddingLeft + chartWidth, paddingTop + chartHeight),
      datePaint,
    );

    final double stepX = chartWidth / (points.length - 1);
    for (int i = 0; i < points.length; i++) {
      final double x = paddingLeft + i * stepX;

      final dayStr =
          '${points[i].date.day.toString().padLeft(2, '0')}.${points[i].date.month.toString().padLeft(2, '0')}';
      textPainter.text = TextSpan(
        text: dayStr,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, paddingTop + chartHeight + 6.h),
      );
    }

    Path getPath(double Function(_ChartDataPoint) getValue) {
      final path = Path();
      for (int i = 0; i < points.length; i++) {
        final double x = paddingLeft + i * stepX;
        final double val = getValue(points[i]);
        final double y = paddingTop + chartHeight * (1 - (val / maxVal));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    void drawTrend(
      double Function(_ChartDataPoint) getValue,
      Color color,
    ) {
      final path = getPath(getValue);

      final fillPath = Path.from(path);
      fillPath.lineTo(paddingLeft + chartWidth, paddingTop + chartHeight);
      fillPath.lineTo(paddingLeft, paddingTop + chartHeight);
      fillPath.close();

      final fillPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.01)],
            ).createShader(
              Rect.fromLTRB(
                paddingLeft,
                paddingTop,
                paddingLeft + chartWidth,
                paddingTop + chartHeight,
              ),
            )
            ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      final linePaint =
          Paint()
            ..color = color
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()..color = color;
      final dotBgPaint = Paint()..color = AppColors.cardBg;
      for (int i = 0; i < points.length; i++) {
        final double x = paddingLeft + i * stepX;
        final double val = getValue(points[i]);
        final double y = paddingTop + chartHeight * (1 - (val / maxVal));

        if (val > 0) {
          canvas.drawCircle(Offset(x, y), 4.r, dotPaint);
          canvas.drawCircle(Offset(x, y), 2.r, dotBgPaint);
        }
      }
    }

    drawTrend((p) => p.income, AppColors.green);
    drawTrend((p) => p.expense, AppColors.red);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _CashFlowCategoryBreakdown extends StatelessWidget {
  final List<CashMovementEntryModel> entries;

  const _CashFlowCategoryBreakdown({required this.entries});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> incomeMap = {};
    double totalIncome = 0;

    final Map<String, double> expenseMap = {};
    double totalExpense = 0;

    for (final entry in entries) {
      final category = entry.category ?? 'Diğer';
      if (entry.isIncome) {
        incomeMap[category] = (incomeMap[category] ?? 0) + entry.amount;
        totalIncome += entry.amount;
      } else {
        expenseMap[category] = (expenseMap[category] ?? 0) + entry.amount.abs();
        totalExpense += entry.amount.abs();
      }
    }

    final sortedIncomes =
        incomeMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final sortedExpenses =
        expenseMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(null, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kategori Dağılım Analizi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),

          Text(
            'Gelir Kaynakları',
            style: TextStyle(
              color: AppColors.green,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          if (sortedIncomes.isEmpty)
            Text(
              'Gelir kaydı bulunmuyor.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
            )
          else
            ...sortedIncomes.map(
              (e) => _buildBreakdownRow(
                label: e.key,
                amount: e.value,
                total: totalIncome,
                color: AppColors.green,
              ),
            ),

          SizedBox(height: 20.h),

          Text(
            'Gider Kalemleri',
            style: TextStyle(
              color: AppColors.red,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          if (sortedExpenses.isEmpty)
            Text(
              'Gider kaydı bulunmuyor.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
            )
          else
            ...sortedExpenses.map(
              (e) => _buildBreakdownRow(
                label: e.key,
                amount: e.value,
                total: totalExpense,
                color: AppColors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required double amount,
    required double total,
    required Color color,
  }) {
    final percent = total > 0 ? (amount / total) : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatLabel(label),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${AppMoney.compact(amount)} (%${(percent * 100).toStringAsFixed(1)})',
                style: TextStyle(
                  color: color,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: SizedBox(
              height: 6.h,
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: color.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
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
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
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
            'Tüm Para Akışı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$totalCount kayıt listeleniyor',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
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
                  label: 'Çıkan',
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
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
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
    final icon =
        entry.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
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
                'Henüz para hareketi yok.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Kazanç, satın alım, transfer veya diğer bakiye değişiklikleri burada görünecek.',
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
  const _CashFlowError({required this.message, required this.onRetry});

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
                'Para hareketleri yüklenemedi.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
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
              TextButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMoney(double amount) {
  return AppMoney.compact(amount, withSymbol: false);
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
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

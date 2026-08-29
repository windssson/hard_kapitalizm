import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
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
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(cashMovementEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Para Hareketleri'),
            _buildTabSelector(),
            Expanded(
              child: entriesAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => _CashFlowError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(cashMovementEntriesProvider),
                ),
                data: (entries) => RefreshIndicator(
                  color: AppColors.gold,
                  onRefresh: () async {
                    ref.invalidate(cashMovementEntriesProvider);
                    await ref.read(cashMovementEntriesProvider.future);
                  },
                  child: entries.isEmpty
                      ? const _CashFlowEmpty()
                      : _selectedTab == 0
                          ? _buildAnalysisView(entries)
                          : _buildHistoryView(entries),
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
        color: AppFx.panelWash(0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppFx.softOverlay(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              0,
              'Grafik & Analiz',
              AppIcons.analyticsOutlined,
            ),
          ),
          Expanded(
            child: _buildTabButton(1, 'İşlem Geçmişi', AppIcons.historyRounded),
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
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.4)
                : AppColors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppIconSizes.compact,
              color: isSelected ? AppColors.gold : AppColors.textMuted,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                fontSize: AppTypography.body,
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

  Widget _buildHistoryView(List<CashMovementEntryModel> allEntries) {
    // 1. Filtreleme
    final filtered = allEntries.where((entry) {
      if (_selectedFilter == 'income' && !entry.isIncome) return false;
      if (_selectedFilter == 'expense' && entry.isIncome) return false;
      if (_selectedFilter == 'tender') {
        final cat = (entry.category ?? '').toLowerCase();
        final ref = (entry.referenceType ?? '').toLowerCase();
        if (!cat.contains('tender') && !ref.contains('tender')) return false;
      }
      if (_selectedFilter == 'store') {
        final cat = (entry.category ?? '').toLowerCase();
        final ref = (entry.referenceType ?? '').toLowerCase();
        if (!cat.contains('store') && !cat.contains('sale') && !ref.contains('store')) {
          return false;
        }
      }
      if (_selectedFilter == 'production') {
        final cat = (entry.category ?? '').toLowerCase();
        final ref = (entry.referenceType ?? '').toLowerCase();
        if (!cat.contains('farm') &&
            !cat.contains('field') &&
            !cat.contains('factory') &&
            !cat.contains('mine') &&
            !cat.contains('construction') &&
            !ref.contains('farm') &&
            !ref.contains('field') &&
            !ref.contains('factory') &&
            !ref.contains('mine')) {
          return false;
        }
      }

      // Arama filtresi
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = entry.title.toLowerCase();
        final desc = (entry.description ?? '').toLowerCase();
        final cat = _formatLabel(entry.category ?? '').toLowerCase();
        final refKind = _formatLabel(entry.referenceType ?? '').toLowerCase();
        if (!title.contains(q) && !desc.contains(q) && !cat.contains(q) && !refKind.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Arama ve Filtre Çubuğu
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          child: Column(
            children: [
              // Arama Çubuğu
              Container(
                height: 42.h,
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.3),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppFx.softOverlay(0.08)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                  ),
                  decoration: InputDecoration(
                    hintText: 'İşlem, kategori veya açıklama ara...',
                    hintStyle: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.gold,
                      size: AppIconSizes.compact,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(
                              AppIcons.closeRounded,
                              color: AppColors.textMuted,
                              size: AppIconSizes.compact,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              // Filtre Butonları (Horizontal Scroll)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Tümü', Icons.list_alt_rounded),
                    SizedBox(width: 6.w),
                    _buildFilterChip('income', 'Gelirler (+)', AppIcons.southWestRounded, color: AppColors.green),
                    SizedBox(width: 6.w),
                    _buildFilterChip('expense', 'Giderler (-)', AppIcons.northEastRounded, color: AppColors.red),
                    SizedBox(width: 6.w),
                    _buildFilterChip('tender', 'İhaleler', AppIcons.gavelRounded, color: AppColors.gold),
                    SizedBox(width: 6.w),
                    _buildFilterChip('store', 'Mağaza / Satış', AppIcons.storefrontOutlined, color: AppColors.blue),
                    SizedBox(width: 6.w),
                    _buildFilterChip('production', 'Üretim / Tesis', AppIcons.factoryOutlined, color: AppColors.orange),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Liste Görünümü
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off_outlined, size: AppIconSizes.hero, color: AppColors.textMuted),
                      SizedBox(height: 10.h),
                      Text(
                        'Arama kriterlerine uygun işlem bulunamadı.',
                        style: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 28.h),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return _CashFlowEntryCard(
                      entry: entry,
                      onTap: () => _showTransactionReceiptSheet(context, entry),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, {Color? color}) {
    final isSelected = _selectedFilter == key;
    final activeColor = color ?? AppColors.gold;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.16) : AppFx.panelWash(0.25),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.6) : AppFx.softOverlay(0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.sp,
              color: isSelected ? activeColor : AppColors.textMuted,
            ),
            SizedBox(width: 5.w),
            Text(
              label,
              style: AppTextStyles.caption.standardCopyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: AppTypography.label,
              ),
            ),
          ],
        ),
      ),
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
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.title,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _LegendItem(color: AppColors.green, label: 'Gelir'),
                  SizedBox(width: 10.w),
                  _LegendItem(color: AppColors.red, label: 'Gider'),
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
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
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
          ..color = AppFx.softOverlay(0.05)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (int i = 0; i <= gridLinesCount; i++) {
      final double ratio = i / gridLinesCount;
      final double y = paddingTop + chartHeight * (1 - ratio);
      final double val = maxVal * ratio;

      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: _formatCompactNumber(val),
        style: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.6),
          fontSize: 9.sp,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout(maxWidth: paddingLeft - 6.w);
      textPainter.paint(
        canvas,
        Offset(
          paddingLeft - textPainter.width - 6.w,
          y - textPainter.height / 2,
        ),
      );
    }

    final int count = points.length;
    final double stepX = count > 1 ? chartWidth / (count - 1) : chartWidth;

    for (int i = 0; i < count; i++) {
      final double x = paddingLeft + (i * stepX);
      final date = points[i].date;
      final label = '${date.day}/${date.month}';

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.7),
          fontSize: 9.sp,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - (textPainter.width / 2), size.height - paddingBottom + 6.h),
      );
    }

    final incomePath = Path();
    final expensePath = Path();

    final List<Offset> incomePoints = [];
    final List<Offset> expensePoints = [];

    for (int i = 0; i < count; i++) {
      final double x = paddingLeft + (i * stepX);
      final double yInc =
          paddingTop + chartHeight * (1 - (points[i].income / maxVal));
      final double yExp =
          paddingTop + chartHeight * (1 - (points[i].expense / maxVal));

      incomePoints.add(Offset(x, yInc));
      expensePoints.add(Offset(x, yExp));

      if (i == 0) {
        incomePath.moveTo(x, yInc);
        expensePath.moveTo(x, yExp);
      } else {
        incomePath.lineTo(x, yInc);
        expensePath.lineTo(x, yExp);
      }
    }

    final incomePaint =
        Paint()
          ..color = AppColors.green
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final expensePaint =
        Paint()
          ..color = AppColors.red
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(incomePath, incomePaint);
    canvas.drawPath(expensePath, expensePaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dotBorderPaint =
        Paint()
          ..color = AppColors.cardBg
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    for (final p in incomePoints) {
      dotPaint.color = AppColors.green;
      canvas.drawCircle(p, 4.w, dotPaint);
      canvas.drawCircle(p, 4.w, dotBorderPaint);
    }

    for (final p in expensePoints) {
      dotPaint.color = AppColors.red;
      canvas.drawCircle(p, 4.w, dotPaint);
      canvas.drawCircle(p, 4.w, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;

  String _formatCompactNumber(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
    return val.toStringAsFixed(0);
  }
}

class _CashFlowCategoryBreakdown extends StatelessWidget {
  final List<CashMovementEntryModel> entries;

  const _CashFlowCategoryBreakdown({required this.entries});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> categoryIncome = {};
    final Map<String, double> categoryExpense = {};

    double totalIncome = 0;
    double totalExpense = 0;

    for (final entry in entries) {
      final rawCat =
          (entry.category ?? entry.referenceType ?? 'Diger').trim().isEmpty
              ? 'Diger'
              : (entry.category ?? entry.referenceType ?? 'Diger');
      final label = _formatLabel(rawCat);

      if (entry.isIncome) {
        categoryIncome[label] = (categoryIncome[label] ?? 0) + entry.amount;
        totalIncome += entry.amount;
      } else {
        final exp = entry.amount.abs();
        categoryExpense[label] = (categoryExpense[label] ?? 0) + exp;
        totalExpense += exp;
      }
    }

    final sortedExpense =
        categoryExpense.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final sortedIncome =
        categoryIncome.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(null, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harcama ve Gelir Dağılımı',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          if (sortedExpense.isNotEmpty) ...[
            Text(
              'En Çok Harcanan Kalemler',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.red,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            ...sortedExpense
                .take(4)
                .map(
                  (e) => _buildCategoryBar(
                    label: e.key,
                    amount: e.value,
                    total: totalExpense,
                    color: AppColors.red,
                  ),
                ),
            SizedBox(height: 16.h),
          ],
          if (sortedIncome.isNotEmpty) ...[
            Text(
              'En Yüksek Gelir Kaynakları',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.green,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            ...sortedIncome
                .take(4)
                .map(
                  (e) => _buildCategoryBar(
                    label: e.key,
                    amount: e.value,
                    total: totalIncome,
                    color: AppColors.green,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBar({
    required String label,
    required double amount,
    required double total,
    required Color color,
  }) {
    final double ratio = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final int percent = (ratio * 100).round();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.label,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    '₺${_formatMoney(amount)}',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '%$percent',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: color,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Stack(
            children: [
              Container(
                height: 5.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppFx.softOverlay(0.06),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4.r),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            style: AppTextStyles.h1.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.headline,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$totalCount kayıt listeleniyor',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodySmall,
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
                  icon: AppIcons.southWestRounded,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _MetricCard(
                  label: 'Çıkan',
                  value: _formatMoney(expense),
                  color: AppColors.red,
                  icon: AppIcons.northEastRounded,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _MetricCard(
                  label: 'Net',
                  value: _formatMoney(net),
                  color: netColor,
                  icon: AppIcons.accountBalanceWalletOutlined,
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
          Icon(icon, color: color, size: AppIconSizes.regular),
          SizedBox(height: 6.h),
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.label,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowEntryCard extends StatelessWidget {
  const _CashFlowEntryCard({required this.entry, this.onTap});

  final CashMovementEntryModel entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = entry.isIncome ? AppColors.green : AppColors.red;
    final icon =
        entry.isIncome ? AppIcons.arrowDownwardRounded : AppIcons.arrowUpwardRounded;
    final amountPrefix = entry.isIncome ? '+' : '-';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: AppDecorations.premiumCard(accentColor.withValues(alpha: 0.3), 16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, color: accentColor, size: AppIconSizes.medium),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.title,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        _formatDateTime(entry.createdAt),
                        style: AppTextStyles.body.standardCopyWith(
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
                      '$amountPrefix₺${_formatMoney(entry.amount.abs())}',
                      style: AppTextStyles.body.standardCopyWith(
                        color: accentColor,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Detay',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: 10.sp,
                          ),
                        ),
                        Icon(AppIcons.chevronRight, size: 12.sp, color: AppColors.textMuted),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if ((entry.description ?? '').trim().isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                entry.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
                  height: 1.3,
                ),
              ),
            ],
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
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
                    value: '₺${_formatMoney(entry.balanceAfter!)}',
                    color: AppColors.blue,
                  ),
                if ((entry.referenceType ?? '').trim().isNotEmpty)
                  _InfoChip(
                    label: 'Kaynak',
                    value: _formatLabel(entry.referenceType!),
                    color: AppColors.textPrimary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showTransactionReceiptSheet(BuildContext context, CashMovementEntryModel entry) {
  final accentColor = entry.isIncome ? AppColors.green : AppColors.red;
  final icon = entry.isIncome ? AppIcons.arrowDownwardRounded : AppIcons.arrowUpwardRounded;
  final prefix = entry.isIncome ? '+' : '-';

  final double? beforeBal = entry.raw['balance_before'] != null
      ? (entry.raw['balance_before'] as num).toDouble()
      : (entry.balanceAfter != null ? entry.balanceAfter! - entry.amount : null);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (ctx) {
      return Container(
        margin: EdgeInsets.only(top: 60.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          border: Border.all(color: AppFx.softOverlay(0.1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tutamaç
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                SizedBox(height: 16.h),
                // İkon & Başlık
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: accentColor, size: AppIconSizes.large),
                ),
                SizedBox(height: 10.h),
                Text(
                  entry.title,
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.titleLarge,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  '$prefix₺${_formatMoney(entry.amount.abs())}',
                  style: AppTextStyles.h1.standardCopyWith(
                    color: accentColor,
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 16.h),
                Divider(color: AppFx.softOverlay(0.08), height: 1),
                SizedBox(height: 14.h),
                // Dekont Detay Listesi
                _buildReceiptRow('İşlem Tarihi', _formatDateTime(entry.createdAt)),
                _buildReceiptRow('Kategori', _formatLabel(entry.category ?? '-')),
                if (entry.referenceType != null && entry.referenceType!.isNotEmpty)
                  _buildReceiptRow('İşlem Kaynağı', _formatLabel(entry.referenceType!)),
                if (beforeBal != null)
                  _buildReceiptRow('Önceki Bakiye', '₺${_formatMoney(beforeBal)}'),
                if (entry.balanceAfter != null)
                  _buildReceiptRow('Sonraki Bakiye', '₺${_formatMoney(entry.balanceAfter!)}'),
                if ((entry.description ?? '').trim().isNotEmpty)
                  _buildReceiptRow('Açıklama / Not', entry.description!),
                if (entry.id.isNotEmpty)
                  _buildReceiptRow(
                    'İşlem No',
                    entry.id,
                    isCopyable: true,
                    context: ctx,
                  ),
                SizedBox(height: 20.h),
                // Kapat Butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.black,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: Text(
                      'Tamam',
                      style: AppTextStyles.button.standardCopyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.body,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildReceiptRow(String label, String value, {bool isCopyable = false, BuildContext? context}) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 5.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
        ),
        SizedBox(width: 12.w),
        Flexible(
          child: GestureDetector(
            onTap: isCopyable && context != null
                ? () {
                    Clipboard.setData(ClipboardData(text: value));
                    AppSnackbar.info(
                      context,
                      'İşlem No kopyalandı: $value',
                      duration: const Duration(seconds: 2),
                    );
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.body.standardCopyWith(
                      color: isCopyable ? AppColors.gold : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ),
                if (isCopyable) ...[
                  SizedBox(width: 4.w),
                  Icon(Icons.content_copy_rounded, size: 14.sp, color: AppColors.gold),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.caption.standardCopyWith(
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
                AppIcons.accountBalanceWalletOutlined,
                color: AppColors.textMuted,
                size: AppIconSizes.hero,
              ),
              SizedBox(height: 14.h),
              Text(
                'Henüz para hareketi yok.',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Kazanç, satın alım, transfer veya diğer bakiye değişiklikleri burada görünecek.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.body,
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
              Icon(AppIcons.errorOutline, color: AppColors.red, size: AppIconSizes.displayLarge),
              SizedBox(height: 12.h),
              Text(
                'Para hareketleri yüklenemedi.',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.bodySmall,
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
  final cleanValue = value.trim().toLowerCase();

  const Map<String, String> translations = {
    // Categories
    'achievement_reward': 'Başarım Ödülü',
    'mission_reward': 'Görev Ödülü',
    'daily_streak_reward': 'Günlük Giriş Ödülü',
    'store_sale': 'Mağaza Satışı',
    'store_sales': 'Mağaza Satışları',
    'store_purchase': 'Mağaza Alımı',
    'sales': 'Satış Geliri',
    'market_purchase': 'Pazar Alımı',
    'market_sale': 'Pazar Satışı',
    'building_construction': 'Bina İnşaatı',
    'building_sale': 'Tesis Satış İadesi',
    'factory_sale': 'Fabrika Satışı',
    'farm_sale': 'Tarla Satışı',
    'field_sale': 'Çiftlik Satışı',
    'mine_sale': 'Maden Satışı',
    'warehouse_sale': 'Depo Satışı',
    'factory_construction': 'Fabrika İnşaatı',
    'farm_construction': 'Tarla İnşaatı',
    'field_construction': 'Çiftlik İnşaatı',
    'mine_construction': 'Maden İnşaatı',
    'store_construction': 'Mağaza İnşaatı',
    'warehouse_construction': 'Depo İnşaatı',
    'arge_research': 'Ar-Ge Araştırması',
    'arge_construction': 'Ar-Ge Merkezi Kurulumu',
    'loan_payout': 'Kredi Çekimi',
    'loan_payment': 'Kredi Taksit Ödemesi',
    'loan_payment_auto': 'Otomatik Taksit Tahsilatı',
    'deposit_placed': 'Vadeli Mevduat Açılışı',
    'deposit_claimed': 'Mevduat Tahsilatı',
    'deposit_early_withdrawal': 'Mevduat Erken Kapatma',
    'building_upgrade': 'Bina Yükseltme',
    'warehouse_expansion': 'Depo Genişletme',
    'warehouse_upgrade': 'Depo Yükseltme',
    'tax_payment': 'Vergi Ödemesi',
    'tax_debt_payment': 'Vergi Borcu Ödemesi',
    'sales_tax': 'Satış Vergisi',
    'vehicle_purchase': 'Araç Satın Alımı',
    'vehicle_repair': 'Araç Bakım/Onarım',
    'vehicle_rental_income': 'Araç Kiralama Geliri',
    'license_purchase': 'Lisans Satın Alımı',
    'reward': 'Ödül',
    'tender_bid': 'İhale Teklifi',
    'tender_award': 'İhale Kazanımı',
    'transfer_cost': 'Nakliye / Sevk Maliyeti',
    'tender_reward_paid': 'İhale Hakediş Ödemesi',
    'tender_bond_paid': 'İhale Teminat Ödemesi',
    'tender_bond_refunded': 'İhale Teminat İadesi',
    'tender_bid_bond_paid': 'İhale Teklif Teminatı',
    'tender_bid_bond_refunded': 'İhale Teklif Teminat İadesi',
    'tender_delivery_transport_paid': 'İhale Sevkiyat Maliyeti',
    'logistics_construction': 'Lojistik Tesisi Kurulumu',
    'marketing_campaign': 'Pazarlama Kampanyası',
    'brand_registration': 'Marka Tescil Harcı',

    // Reference Kinds / Reference Types
    'store': 'Mağaza',
    'city': 'Şehir',
    'product': 'Ürün',
    'logistics_transfer': 'Lojistik Transfer',
    'warehouse': 'Depo',
    'factory': 'Fabrika',
    'farm': 'Tarla',
    'field': 'Çiftlik',
    'mine': 'Maden',
    'loan': 'Banka Kredisi',
    'deposit': 'Vadeli Mevduat',
    'tax': 'Vergi Dairesi',
    'logistics': 'Lojistik',
    'mission': 'Görev Sistemi',
    'tender': 'Kamu İhalesi',
    'building': 'Bina Kurumu',
    'player': 'Oyuncu İşlemi',
    'arge_center': 'Ar-Ge Merkezi',
    'player_tender': 'Kamu İhalesi',
    'logistics_company': 'Lojistik Şirketi',
    'vehicle': 'Araç',
    'brand': 'Marka Şirketi',
  };

  if (translations.containsKey(cleanValue)) {
    return translations[cleanValue]!;
  }

  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .map(
        (part) => part.length > 1
            ? '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}'
            : part.toUpperCase(),
      )
      .join(' ');
}

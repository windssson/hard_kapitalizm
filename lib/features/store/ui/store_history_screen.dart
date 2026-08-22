import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_history_item_model.dart';

enum _StoreHistoryFilter {
  all('Tüm Hareketler', AppIcons.history),
  incoming('Girişler', AppIcons.southWest),
  outgoing('Çıkışlar', AppIcons.northEast),
  sales('Satışlar', AppIcons.pointOfSale);

  const _StoreHistoryFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}

class StoreHistoryScreen extends ConsumerStatefulWidget {
  final String storeId;

  const StoreHistoryScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreHistoryScreen> createState() => _StoreHistoryScreenState();
}

class _StoreHistoryScreenState extends ConsumerState<StoreHistoryScreen> {
  _StoreHistoryFilter _selectedFilter = _StoreHistoryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!ref.read(storeHistoryDirtyProvider(widget.storeId))) return;
      await _refreshHistory(clearDirty: true);
    });
  }

  Future<void> _refreshHistory({required bool clearDirty}) async {
    ref.invalidate(storeHistoryProvider(widget.storeId));
    await ref.read(storeHistoryProvider(widget.storeId).future);
    if (clearDirty) {
      ref.read(storeHistoryDirtyProvider(widget.storeId).notifier).state =
          false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(storeHistoryProvider(widget.storeId));

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Mağaza Hareket Geçmişi'),
            Expanded(
              child: historyAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                        fontSize: AppTypography.bodyLarge,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (items) {
                  final filteredItems = _applyFilter(items);
                  return RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.cardBg,
                    onRefresh: () async {
                      await _refreshHistory(clearDirty: true);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      children: [
                        _buildFilterBar(items),
                        SizedBox(height: 10.h),
                        _buildSummaryHeader(filteredItems),
                        SizedBox(height: 12.h),
                        if (filteredItems.isEmpty)
                          _buildEmptyState()
                        else
                          ...List.generate(filteredItems.length, (index) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: TweenAnimationBuilder<double>(
                                duration: Duration(
                                  milliseconds: 250 +
                                      (index * 40).clamp(0, 400),
                                ),
                                curve: Curves.easeOutCubic,
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 16 * (1 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildHistoryCard(filteredItems[index]),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(List<StoreHistoryItemModel> allItems) {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _StoreHistoryFilter.values.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (_, index) {
          final filter = _StoreHistoryFilter.values[index];
          final isSelected = filter == _selectedFilter;
          final count = _getFilterCount(allItems, filter);

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.22),
                          AppColors.gold.withValues(alpha: 0.08),
                        ],
                      )
                    : null,
                color: isSelected ? null : AppColors.cardBg.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.6)
                      : AppColors.border.withValues(alpha: 0.3),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter.icon,
                    size: 14.sp,
                    color: isSelected ? AppColors.gold : AppColors.textMuted,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    filter.label,
                    style: AppTextStyles.label.standardCopyWith(
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.textSecondary,
                      fontSize: 11.5.sp,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.25)
                          : AppColors.cardBgLight,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      count.toString(),
                      style: AppTextStyles.caption.standardCopyWith(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.textMuted,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _getFilterCount(
    List<StoreHistoryItemModel> items,
    _StoreHistoryFilter filter,
  ) {
    switch (filter) {
      case _StoreHistoryFilter.all:
        return items.length;
      case _StoreHistoryFilter.incoming:
        return items.where((i) => i.isIncomingTransfer).length;
      case _StoreHistoryFilter.outgoing:
        return items.where((i) => i.isOutgoingTransfer).length;
      case _StoreHistoryFilter.sales:
        return items.where((i) => i.isSale).length;
    }
  }

  Widget _buildSummaryHeader(List<StoreHistoryItemModel> items) {
    final totalQuantity = items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalAmount = items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final totalSecondaryAmount = items.fold<double>(
      0,
      (sum, item) => sum + (item.secondaryAmount ?? 0),
    );
    final saleCount = items.where((item) => item.isSale).length;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.25),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedFilter.label,
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.white,
                  fontSize: AppTypography.bodyLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${items.length} Kayıt Bulundu',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'Toplam Hacim',
                  _formatCompactNumber(totalQuantity.toDouble()),
                  AppColors.white,
                  AppIcons.inventoryRounded,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSummaryMetric(
                  'Toplam Tutar',
                  _formatCurrency(totalAmount),
                  AppColors.green,
                  AppIcons.paymentsRounded,
                ),
              ),
              if (saleCount > 0) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildSummaryMetric(
                    'Toplam Kâr',
                    _formatCurrency(totalSecondaryAmount),
                    AppColors.gold,
                    AppIcons.insightsRounded,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12.sp),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.standardCopyWith(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  List<StoreHistoryItemModel> _applyFilter(List<StoreHistoryItemModel> items) {
    switch (_selectedFilter) {
      case _StoreHistoryFilter.all:
        return items;
      case _StoreHistoryFilter.incoming:
        return items.where((item) => item.isIncomingTransfer).toList();
      case _StoreHistoryFilter.outgoing:
        return items.where((item) => item.isOutgoingTransfer).toList();
      case _StoreHistoryFilter.sales:
        return items.where((item) => item.isSale).toList();
    }
  }

  Widget _buildEmptyState() {
    final description = switch (_selectedFilter) {
      _StoreHistoryFilter.all =>
        'Depodan gelen, pazardan alınan, depoya aktarılan ürünler ve satış özetleri burada listelenecektir.',
      _StoreHistoryFilter.incoming =>
        'Bu mağazaya henüz depodan veya pazardan giriş hareketi yapılmadı.',
      _StoreHistoryFilter.outgoing =>
        'Bu mağazadan henüz depoya giden çıkış hareketi bulunmuyor.',
      _StoreHistoryFilter.sales =>
        'Bu mağazada henüz tamamlanmış bir satış hareketi yok.',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.history,
              color: AppColors.gold,
              size: 26.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'Hareket Kaydı Bulunamadı',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.white,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            description,
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

  Widget _buildHistoryCard(StoreHistoryItemModel item) {
    final accentColor = item.isSale
        ? AppColors.green
        : item.isIncomingTransfer
            ? AppColors.gold
            : AppColors.blue;
    final statusColor = _statusColor(item.status);
    final icon = item.isSale
        ? AppIcons.pointOfSale
        : item.isIncomingTransfer
            ? AppIcons.southWest
            : AppIcons.northEast;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 8,
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
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 18.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.white,
                        fontSize: AppTypography.body,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.subtitle,
                      style: AppTextStyles.body.standardCopyWith(
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
                  _buildStatusChip(_statusLabel(item.status), statusColor),
                  SizedBox(height: 4.h),
                  Text(
                    _formatDate(item.happenedAt),
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: 9.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Divider(
            color: AppColors.border.withValues(alpha: 0.2),
            height: 1,
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.qualityLevel != null) ...[
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          for (int i = 0; i < 5; i++)
                            Icon(
                              i < (item.qualityLevel ?? 1)
                                  ? AppIcons.starRounded
                                  : AppIcons.starBorderRounded,
                              color: i < (item.qualityLevel ?? 1)
                                  ? AppColors.gold
                                  : AppColors.textMuted.withValues(alpha: 0.2),
                              size: 10.sp,
                            ),
                          SizedBox(width: 4.w),
                          Text(
                            'Kalite ${item.qualityLevel}',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 6.w,
                children: [
                  _buildMetricBadge('Miktar', '${item.quantity} Adet', AppColors.white),
                  _buildMetricBadge(
                    item.isSale ? 'Ciro' : 'Tutar',
                    _formatCurrency(item.amount),
                    AppColors.green,
                  ),
                  if (item.secondaryAmount != null)
                    _buildMetricBadge(
                      item.isSale ? 'Kâr' : 'Kira',
                      _formatCurrency(item.secondaryAmount!),
                      AppColors.gold,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: 8.5.sp,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.label.standardCopyWith(
              color: color,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color accentColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: accentColor,
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_transit':
        return 'Yolda';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'in_transit':
        return AppColors.blue;
      case 'completed':
        return AppColors.green;
      case 'cancelled':
        return AppColors.red;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatCompactNumber(double value) {
    return AppMoney.compact(value, withSymbol: false);
  }

  String _formatCurrency(double value) => AppMoney.compact(value);

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}

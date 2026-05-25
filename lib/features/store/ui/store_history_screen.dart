import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/navigation/route_refresh_mixin.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_history_item_model.dart';

enum _StoreHistoryFilter {
  all('Tum Hareketler'),
  incoming('Girisler'),
  outgoing('Cikislar'),
  sales('Satislar');

  const _StoreHistoryFilter(this.label);

  final String label;
}

class StoreHistoryScreen extends ConsumerStatefulWidget {
  final String storeId;

  const StoreHistoryScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreHistoryScreen> createState() => _StoreHistoryScreenState();
}

class _StoreHistoryScreenState extends ConsumerState<StoreHistoryScreen>
    with RouteRefreshMixin<StoreHistoryScreen> {
  _StoreHistoryFilter _selectedFilter = _StoreHistoryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshRouteData());
  }

  @override
  void refreshRouteData() {
    ref.invalidate(storeHistoryProvider(widget.storeId));
    ref.read(storeHistoryProvider(widget.storeId).future);
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(storeHistoryProvider(widget.storeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Magaza Gecmisi'),
            _buildFilterBar(),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      style: TextStyle(color: AppColors.red, fontSize: 13.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (items) {
                  final filteredItems = _applyFilter(items);
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(storeHistoryProvider(widget.storeId));
                      await ref.read(storeHistoryProvider(widget.storeId).future);
                    },
                    child: filteredItems.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(24.w),
                            children: [
                              _buildSummaryHeader(filteredItems),
                              SizedBox(height: 16.h),
                              SizedBox(height: 120.h),
                              _buildEmptyState(),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16.w),
                            itemCount: filteredItems.length + 1,
                            separatorBuilder: (_, __) => SizedBox(height: 12.h),
                            itemBuilder: (_, index) {
                              if (index == 0) {
                                return _buildSummaryHeader(filteredItems);
                              }
                              return _buildHistoryCard(filteredItems[index - 1]);
                            },
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

  Widget _buildFilterBar() {
    return Column(
      children: [
        SizedBox(
          height: 56.h,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, index) {
              final filter = _StoreHistoryFilter.values[index];
              final isSelected = filter == _selectedFilter;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.55)
                          : AppColors.border.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        color: isSelected ? AppColors.gold : Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemCount: _StoreHistoryFilter.values.length,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 6.h),
          child: Text(
            'Tamamlanan anlik ve sureli magaza hareketleri burada listelenir.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
            ),
          ),
        ),
      ],
    );
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedFilter.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${items.length} kayit icin hizli ozet',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildSummaryChip(
                'Kayit',
                items.length.toString(),
                AppColors.gold,
              ),
              _buildSummaryChip(
                'Miktar',
                _formatCompactNumber(totalQuantity.toDouble()),
                Colors.white,
              ),
              _buildSummaryChip(
                'Toplam Tutar',
                _formatCurrency(totalAmount),
                AppColors.green,
              ),
              if (saleCount > 0)
                _buildSummaryChip(
                  'Toplam Kar',
                  _formatCurrency(totalSecondaryAmount),
                  AppColors.blue,
                ),
            ],
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
        'Depodan gelen, pazardan alinan, depoya giden urunler ve satis ozetleri burada gorunecek.',
      _StoreHistoryFilter.incoming =>
        'Bu magazaya gelen urun hareketi henuz yok.',
      _StoreHistoryFilter.outgoing =>
        'Bu magazadan depoya giden urun hareketi henuz yok.',
      _StoreHistoryFilter.sales =>
        'Bu magazada henuz listelenecek satis ozeti yok.',
    };
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.history, color: AppColors.textMuted, size: 52.sp),
          SizedBox(height: 16.h),
          Text(
            'Henuz gecmis kaydi yok.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
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
        ? Icons.point_of_sale
        : item.isIncomingTransfer
            ? Icons.south_west
            : Icons.north_east;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
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
                      item.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(item.happenedAt),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildStatusChip(_statusLabel(item.status), statusColor),
              if (!item.isSale)
                _buildStatusChip(
                  item.isIncomingTransfer ? 'Giris' : 'Cikis',
                  accentColor,
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            item.productName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildMetricChip('Miktar', '${item.quantity}'),
              if (item.qualityLevel != null)
                _buildMetricChip('Kalite', 'Lv.${item.qualityLevel}'),
              _buildMetricChip(
                item.isSale ? 'Ciro' : 'Tutar',
                item.amount.toStringAsFixed(1),
              ),
              if (item.secondaryAmount != null)
                _buildMetricChip(
                  item.isSale ? 'Kar' : 'Kira',
                  item.secondaryAmount!.toStringAsFixed(1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color accentColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_transit':
        return 'Yolda';
      case 'completed':
        return 'Tamamlandi';
      case 'cancelled':
        return 'Iptal';
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

  Widget _buildSummaryChip(String label, String value, Color accentColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
            style: TextStyle(
              color: accentColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}

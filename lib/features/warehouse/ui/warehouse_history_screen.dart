import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_history_item_model.dart';

enum _WarehouseHistoryFilter {
  all('Tum Hareketler'),
  incoming('Girisler'),
  outgoing('Cikislar'),
  sales('Satislar');

  const _WarehouseHistoryFilter(this.label);

  final String label;
}

class WarehouseHistoryScreen extends ConsumerStatefulWidget {
  final String warehouseId;

  const WarehouseHistoryScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<WarehouseHistoryScreen> createState() =>
      _WarehouseHistoryScreenState();
}

class _WarehouseHistoryScreenState
    extends ConsumerState<WarehouseHistoryScreen> {
  _WarehouseHistoryFilter _selectedFilter = _WarehouseHistoryFilter.all;

  Future<void> _refresh() async {
    ref.invalidate(warehouseHistoryProvider(widget.warehouseId));
    await ref.read(warehouseHistoryProvider(widget.warehouseId).future);
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(warehouseHistoryProvider(widget.warehouseId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Depo Hareketleri'),
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
                data: (items) {
                  final filteredItems = _applyFilter(items);
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: filteredItems.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16.w),
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
            itemCount: _WarehouseHistoryFilter.values.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (_, index) {
              final filter = _WarehouseHistoryFilter.values[index];
              final isSelected = filter == _selectedFilter;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
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
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 6.h),
          child: Text(
            'Depoya giren ve depodan cikan urun hareketleri burada listelenir.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.sp,
            ),
          ),
        ),
      ],
    );
  }

  List<WarehouseHistoryItemModel> _applyFilter(
    List<WarehouseHistoryItemModel> items,
  ) {
    switch (_selectedFilter) {
      case _WarehouseHistoryFilter.all:
        return items;
      case _WarehouseHistoryFilter.incoming:
        return items.where((item) => item.isIncoming).toList();
      case _WarehouseHistoryFilter.outgoing:
        return items.where((item) => item.isOutgoing).toList();
      case _WarehouseHistoryFilter.sales:
        return items.where((item) => item.isSale).toList();
    }
  }

  Widget _buildSummaryHeader(List<WarehouseHistoryItemModel> items) {
    final incomingCount = items.where((item) => item.isIncoming).length;
    final outgoingCount = items.where((item) => item.isOutgoing).length;
    final salesCount = items.where((item) => item.isSale).length;
    final brandedCount = items.where((item) => item.hasBrand).length;
    final totalQuantity = items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalTransportCost = items.fold<double>(
      0,
      (sum, item) => sum + item.transportCost + item.rentalCost,
    );

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.premiumCard(null, 18.r),
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
              _buildSummaryChip('Kayit', items.length.toString(), AppColors.gold),
              _buildSummaryChip('Giris', incomingCount.toString(), AppColors.green),
              _buildSummaryChip('Cikis', outgoingCount.toString(), AppColors.blue),
              _buildSummaryChip('Satis', salesCount.toString(), AppColors.gold),
              _buildSummaryChip(
                'Markali',
                brandedCount.toString(),
                AppColors.gold,
              ),
              _buildSummaryChip(
                'Toplam Adet',
                _formatCompactNumber(totalQuantity.toDouble()),
                Colors.white,
              ),
              _buildSummaryChip(
                'Nakliye',
                _formatCurrency(totalTransportCost),
                AppColors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, Color accentColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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

  Widget _buildEmptyState() {
    final description = switch (_selectedFilter) {
      _WarehouseHistoryFilter.all =>
        'Pazar, magaza, uretim ve depolar arasi hareketler burada gorunecek.',
      _WarehouseHistoryFilter.incoming =>
        'Bu depoya gelen hareket kaydi henuz yok.',
      _WarehouseHistoryFilter.outgoing =>
        'Bu depodan cikan hareket kaydi henuz yok.',
      _WarehouseHistoryFilter.sales =>
        'Bu depodan market uzerinden gerceklesen satis kaydi henuz yok.',
    };

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: AppDecorations.premiumCard(AppColors.border, 20.r),
      child: Column(
        children: [
          Icon(Icons.history, color: AppColors.textMuted, size: 52.sp),
          SizedBox(height: 16.h),
          Text(
            'Henuz hareket kaydi yok.',
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

  Widget _buildHistoryCard(WarehouseHistoryItemModel item) {
    final accentColor = item.isSale
        ? AppColors.gold
        : item.isIncoming
        ? AppColors.green
        : AppColors.blue;
    final totalLogisticsCost = item.transportCost + item.rentalCost;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(accentColor, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: CachedAssetImage(fileName: item.productIcon),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${item.sourceName} -> ${item.targetName}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
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
              _buildStatusChip(
                item.isSale
                    ? 'Satis'
                    : item.isIncoming
                    ? 'Giris'
                    : 'Cikis',
                accentColor,
              ),
              _buildStatusChip(_statusLabel(item.status), _statusColor(item.status)),
              _buildStatusChip(
                '${item.sourceCityName} -> ${item.targetCityName}',
                AppColors.gold,
              ),
              _buildStatusChip('Kalite ${item.qualityLevel}', Colors.white),
              _buildStatusChip(
                item.hasBrand ? 'Markali' : 'Brandsiz',
                item.hasBrand ? AppColors.gold : AppColors.textMuted,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildMetricChip('Miktar', '${item.quantity}'),
              _buildMetricChip('Mal Bedeli', _formatCurrency(item.totalPrice)),
              _buildMetricChip(
                'Nakliye',
                _formatCurrency(totalLogisticsCost),
              ),
              _buildMetricChip(
                'Tasima',
                item.isRental ? 'Kiralik' : 'Ozmal',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
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

  String _formatCompactNumber(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  String _formatCurrency(double value) =>
      'TL ${_formatCompactNumber(value)}';

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}

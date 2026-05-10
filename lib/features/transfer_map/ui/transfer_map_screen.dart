import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_history_item_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';

class TransferMapScreen extends ConsumerStatefulWidget {
  const TransferMapScreen({super.key});

  @override
  ConsumerState<TransferMapScreen> createState() => _TransferMapScreenState();
}

class _TransferMapScreenState extends ConsumerState<TransferMapScreen> {
  final int _selectedIndex = 2;
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _isCompletingDueTransfers = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
      _checkDueTransfers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDueTransfers();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  Future<void> _checkDueTransfers() async {
    if (_isCompletingDueTransfers) return;

    final transfers = ref.read(buyerTransferMapProvider).value;
    if (transfers == null || transfers.isEmpty) return;

    final hasDueTransfer = transfers.any(
      (transfer) => !transfer.finishAt.isAfter(_now),
    );
    if (!hasDueTransfer) return;

    _isCompletingDueTransfers = true;
    try {
      final result = await ref.read(marketActionProvider).completeDueMarketTransfers();
      ref.invalidate(buyerTransferMapProvider);
      ref.invalidate(buyerTransferHistoryProvider);
      if (!mounted) return;

      final completedCount = (result['completed_count'] as num?)?.toInt() ?? 0;
      if (result['success'] == true && completedCount > 0) {
        AppSnackbar.show(
          context,
          title: 'Teslimat Tamamlandi',
          message: '$completedCount transfer depoya ulasti.',
          type: SnackbarType.success,
        );
      }
    } finally {
      _isCompletingDueTransfers = false;
    }
  }

  Future<void> _showTransferInfo(TransferMapItemModel transfer) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
          side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.35)),
        ),
        title: Text(
          transfer.product.name,
          style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 42.w,
                  height: 42.w,
                  child: CachedAssetImage(fileName: transfer.product.icon),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    '${transfer.quantity} adet tasiniyor',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildInfoRow('Cikis', transfer.sellerWarehouse.city.name),
            _buildInfoRow('Varis', transfer.buyerWarehouse.city.name),
            _buildInfoRow(
              'Tip',
              transfer.isRental ? 'Kiralik Arac' : 'Kendi Araciniz',
            ),
            _buildInfoRow(
              'Urun Bedeli',
              transfer.totalPrice.toStringAsFixed(1),
            ),
            _buildInfoRow(
              'Kira Bedeli',
              transfer.rentalCost.toStringAsFixed(1),
            ),
            _buildInfoRow(
              'Kalan Sure',
              _formatRemaining(transfer.finishAt.difference(_now)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transfersAsync = ref.watch(buyerTransferMapProvider);
    final historyAsync = ref.watch(buyerTransferHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Transfer Haritasi'),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: _buildModeSelector(),
            ),
            Expanded(
              child: _selectedTab == 0
                  ? transfersAsync.when(
                      data: (transfers) => RefreshIndicator(
                        onRefresh: () async {
                          await _checkDueTransfers();
                          ref.invalidate(buyerTransferMapProvider);
                        },
                        child: transfers.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                children: [
                                  SizedBox(height: 120.h),
                                  _buildEmptyState(),
                                ],
                              )
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  12.w,
                                  12.h,
                                  12.w,
                                  24.h,
                                ),
                                child: Column(
                                  children: [
                                    _buildMapCard(transfers),
                                    SizedBox(height: 16.h),
                                    ...transfers.map(_buildTransferSummaryCard),
                                  ],
                                ),
                              ),
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    )
                  : historyAsync.when(
                      data: (history) => RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(buyerTransferHistoryProvider);
                        },
                        child: history.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                children: [
                                  SizedBox(height: 120.h),
                                  _buildHistoryEmptyState(),
                                ],
                              )
                            : ListView.separated(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  16.w,
                                  12.h,
                                  16.w,
                                  24.h,
                                ),
                                itemBuilder: (context, index) =>
                                    _buildHistoryCard(history[index]),
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: 12.h),
                                itemCount: history.length,
                              ),
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              index: 0,
              label: 'Aktif',
              icon: Icons.route,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildModeButton(
              index: 1,
              label: 'Gecmis',
              icon: Icons.history,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTab == index) return;
        setState(() {
          _selectedTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.5)
                : Colors.transparent,
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

  Widget _buildMapCard(List<TransferMapItemModel> transfers) {
    final cities = <TransferMapCityModel>[
      for (final transfer in transfers) transfer.sellerWarehouse.city,
      for (final transfer in transfers) transfer.buyerWarehouse.city,
    ];
    final uniqueCities = <String, TransferMapCityModel>{
      for (final city in cities) city.id: city,
    }.values.toList();

    final minX = uniqueCities.map((e) => e.x).reduce(math.min);
    final maxX = uniqueCities.map((e) => e.x).reduce(math.max);
    final minY = uniqueCities.map((e) => e.y).reduce(math.min);
    final maxY = uniqueCities.map((e) => e.y).reduce(math.max);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const heightRatio = 0.9;
          final mapHeight = width * heightRatio;
          const padding = 26.0;

          Offset project(TransferMapCityModel city) {
            final normalizedX = (city.y - minY) / math.max(maxY - minY, 0.0001);
            final normalizedY = (maxX - city.x) / math.max(maxX - minX, 0.0001);
            return Offset(
              padding + normalizedX * (width - (padding * 2)),
              padding + normalizedY * (mapHeight - (padding * 2)),
            );
          }

          return SizedBox(
            height: mapHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TransferMapPainter(
                      transfers: transfers,
                      projector: project,
                    ),
                  ),
                ),
                ...uniqueCities.map((city) {
                  final position = project(city);
                  return Positioned(
                    left: position.dx - 6.w,
                    top: position.dy - 6.w,
                    child: Column(
                      children: [
                        Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            city.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                ...transfers.map((transfer) {
                  final start = project(transfer.sellerWarehouse.city);
                  final end = project(transfer.buyerWarehouse.city);
                  final progress = _calculateProgress(transfer);
                  final position = Offset.lerp(start, end, progress)!;
                  return Positioned(
                    left: position.dx - 14.w,
                    top: position.dy - 14.w,
                    child: GestureDetector(
                      onTap: () => _showTransferInfo(transfer),
                      child: Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          color: transfer.isRental
                              ? Colors.orange
                              : AppColors.gold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (transfer.isRental
                                      ? Colors.orange
                                      : AppColors.gold)
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          transfer.isRental
                              ? Icons.local_shipping
                              : Icons.directions_car,
                          color: Colors.black,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransferSummaryCard(TransferMapItemModel transfer) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42.w,
            height: 42.w,
            child: CachedAssetImage(fileName: transfer.product.icon),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.product.name,
                  style: AppTextStyles.h2.copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${transfer.sellerWarehouse.city.name} -> ${transfer.buyerWarehouse.city.name}',
                  style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transfer.quantity} adet',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                _formatRemaining(transfer.finishAt.difference(_now)),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.map_outlined, color: AppColors.textMuted, size: 54.sp),
          SizedBox(height: 16.h),
          Text(
            'Aktif transfer bulunmuyor.',
            style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Marketten satin aldiginiz urunler yola ciktiginda burada goreceksiniz.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.history, color: AppColors.textMuted, size: 54.sp),
          SizedBox(height: 16.h),
          Text(
            'Transfer gecmisi bulunmuyor.',
            style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Tamamlanan transferler burada listelenecek.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TransferHistoryItemModel item) {
    final statusColor = item.status == 'completed'
        ? AppColors.green
        : Colors.orange;
    final completedText = item.completedAt == null
        ? '-'
        : _formatDateTime(item.completedAt!);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: CachedAssetImage(fileName: item.product.icon),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: AppTextStyles.h2.copyWith(fontSize: 15.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${item.sellerWarehouse.city.name} -> ${item.buyerWarehouse.city.name}',
                      style: AppTextStyles.body.copyWith(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 5.h,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _statusLabel(item.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(child: _buildHistoryMetric('Miktar', '${item.quantity} adet')),
              Expanded(
                child: _buildHistoryMetric(
                  'Urun Bedeli',
                  '${item.totalPrice.toStringAsFixed(1)}₺',
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildHistoryMetric(
                  'Nakliye',
                  item.isRental
                      ? '${item.rentalCost.toStringAsFixed(1)}₺'
                      : 'Kendi Arac',
                ),
              ),
              Expanded(
                child: _buildHistoryMetric('Teslim', completedText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          SizedBox(
            width: 70.w,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateProgress(TransferMapItemModel transfer) {
    final total = transfer.finishAt.difference(transfer.startedAt).inSeconds;
    if (total <= 0) return 1;
    final elapsed = _now.difference(transfer.startedAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _formatRemaining(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDateTime(DateTime value) {
    final safe = value.toLocal();
    final day = safe.day.toString().padLeft(2, '0');
    final month = safe.month.toString().padLeft(2, '0');
    final hour = safe.hour.toString().padLeft(2, '0');
    final minute = safe.minute.toString().padLeft(2, '0');
    return '$day.$month ${hour}:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Tamamlandi';
      case 'cancelled':
        return 'Iptal';
      default:
        return status;
    }
  }
}

class _TransferMapPainter extends CustomPainter {
  final List<TransferMapItemModel> transfers;
  final Offset Function(TransferMapCityModel city) projector;

  _TransferMapPainter({
    required this.transfers,
    required this.projector,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final transfer in transfers) {
      final start = projector(transfer.sellerWarehouse.city);
      final end = projector(transfer.buyerWarehouse.city);
      linePaint.color = transfer.isRental
          ? Colors.orange.withValues(alpha: 0.85)
          : AppColors.gold.withValues(alpha: 0.85);
      canvas.drawLine(start, end, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TransferMapPainter oldDelegate) => true;
}

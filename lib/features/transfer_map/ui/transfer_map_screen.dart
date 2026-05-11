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
      final result = await ref
          .read(marketActionProvider)
          .completeDueMarketTransfers();
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
    final accentColor = transfer.isRental ? Colors.orange : AppColors.gold;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
        ),
        titlePadding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 0),
        contentPadding: EdgeInsets.all(24.w),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                transfer.isRental ? Icons.local_shipping : Icons.directions_car,
                color: accentColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.product.name,
                    style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Transfer Detaylari',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  _buildDialogInfoRow(
                    Icons.my_location,
                    'Cikis',
                    transfer.sellerWarehouse.city.name,
                  ),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 24.h,
                  ),
                  _buildDialogInfoRow(
                    Icons.location_on,
                    'Varis',
                    transfer.buyerWarehouse.city.name,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _buildDialogDetailRow('Miktar', '${transfer.quantity} adet'),
            _buildDialogDetailRow(
              'Nakliye Tipi',
              transfer.isRental ? 'Kiralik Arac' : 'Kendi Araciniz',
            ),
            _buildDialogDetailRow(
              'Urun Bedeli',
              '${transfer.totalPrice.toStringAsFixed(1)}₺',
            ),
            _buildDialogDetailRow(
              'Kira Bedeli',
              '${transfer.rentalCost.toStringAsFixed(1)}₺',
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, color: accentColor, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Kalan Sure: ${_formatRemaining(transfer.finishAt.difference(_now))}',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 16.sp),
        SizedBox(width: 12.w),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
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
                                physics: const AlwaysScrollableScrollPhysics(),
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
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              index: 0,
              label: 'Aktif Transferler',
              icon: Icons.route,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildModeButton(
              index: 1,
              label: 'Gecmis Kayitlar',
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
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.3),
                    AppColors.gold.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: isSelected ? AppColors.gold : AppColors.textMuted,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

    const double minLat = 35.9;
    const double maxLat = 42.7;
    const double minLon = 25.7;
    const double maxLon = 47.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Canli Takip',
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.gold,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.my_location,
                        color: AppColors.textMuted,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final mapHeight = width / 1.35; // Sabit en/boy oranı

                    Offset project(TransferMapCityModel city) {
                      final normalizedX = (city.y - minLon) / (maxLon - minLon);
                      final normalizedY = (maxLat - city.x) / (maxLat - minLat);
                      return Offset(
                        normalizedX * width,
                        normalizedY * mapHeight,
                      );
                    }

                    return SizedBox(
                      height: mapHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: const AssetImage('assets/backmap.webp'),
                                  fit: BoxFit.fill,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withValues(alpha: 0.5),
                                    BlendMode.darken,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                            const markerWidth = 80.0;
                            return Positioned(
                              left: position.dx - markerWidth / 2,
                              top: position.dy - 8.w,
                              width: markerWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 16.w,
                                    height: 16.w,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.gold.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      city.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          ...transfers.map((transfer) {
                            final start = project(
                              transfer.sellerWarehouse.city,
                            );
                            final end = project(transfer.buyerWarehouse.city);
                            final progress = _calculateProgress(transfer);
                            final position = Offset.lerp(start, end, progress)!;
                            return Positioned(
                              left: position.dx - 18.w,
                              top: position.dy - 18.w,
                              child: GestureDetector(
                                onTap: () => _showTransferInfo(transfer),
                                child: Container(
                                  width: 36.w,
                                  height: 36.w,
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: transfer.isRental
                                          ? Colors.orange
                                          : AppColors.gold,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (transfer.isRental
                                                    ? Colors.orange
                                                    : AppColors.gold)
                                                .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    transfer.isRental
                                        ? Icons.local_shipping
                                        : Icons.directions_car,
                                    color: transfer.isRental
                                        ? Colors.orange
                                        : AppColors.gold,
                                    size: 18.sp,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferSummaryCard(TransferMapItemModel transfer) {
    final progress = _calculateProgress(transfer);
    final accentColor = transfer.isRental ? Colors.orange : AppColors.gold;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: CachedAssetImage(fileName: transfer.product.icon),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          transfer.product.name,
                          style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            transfer.isRental ? 'Kiralik' : 'Özmal',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Text(
                          transfer.sellerWarehouse.city.name,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12.sp,
                            color: Colors.white,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.textMuted,
                            size: 14.sp,
                          ),
                        ),
                        Text(
                          transfer.buyerWarehouse.city.name,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12.sp,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.textMuted,
                size: 14.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                '${transfer.quantity} Adet',
                style: AppTextStyles.body.copyWith(
                  fontSize: 12.sp,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.timer_outlined,
                color: AppColors.textMuted,
                size: 14.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                _formatRemaining(transfer.finishAt.difference(_now)),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 6.h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.route_outlined,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: 54.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Aktif Transfer Yok',
            style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            'Marketten satin aldiginiz urunler yola ciktiginda veya bir satisa gonderdiginizde burada canli olarak takip edebilirsiniz.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_outlined,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: 54.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Gecmis Kayit Bulunamadi',
            style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            'Tamamlanan veya iptal edilen tum sevkiyatlariniz burada loglanacaktir.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: CachedAssetImage(fileName: item.product.icon),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Text(
                          item.sellerWarehouse.city.name,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12.sp,
                            color: Colors.white,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.textMuted,
                            size: 14.sp,
                          ),
                        ),
                        Text(
                          item.buyerWarehouse.city.name,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12.sp,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.status == 'completed'
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: statusColor,
                      size: 12.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _statusLabel(item.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHistoryMetric(
                  Icons.inventory_2_outlined,
                  'Miktar',
                  '${item.quantity} adet',
                ),
                _buildHistoryMetric(
                  Icons.attach_money,
                  'Urun Bedeli',
                  '${item.totalPrice.toStringAsFixed(1)}₺',
                ),
                _buildHistoryMetric(
                  Icons.local_shipping_outlined,
                  'Nakliye',
                  item.isRental
                      ? '${item.rentalCost.toStringAsFixed(1)}₺'
                      : 'Özmal',
                ),
                _buildHistoryMetric(
                  Icons.calendar_today_outlined,
                  'Tarih',
                  completedText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryMetric(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 12.sp),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
            ),
          ],
        ),
        SizedBox(height: 6.h),
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
    return '$day.$month $hour:$minute';
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

  _TransferMapPainter({required this.transfers, required this.projector});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dot grid background
    final bgPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    for (double i = 0; i < size.width; i += 20) {
      for (double j = 0; j < size.height; j += 20) {
        canvas.drawCircle(Offset(i, j), 1, bgPaint);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (final transfer in transfers) {
      final start = projector(transfer.sellerWarehouse.city);
      final end = projector(transfer.buyerWarehouse.city);
      linePaint.color = transfer.isRental
          ? Colors.orange.withValues(alpha: 0.6)
          : AppColors.gold.withValues(alpha: 0.6);

      _drawDashedLine(canvas, start, end, linePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    var distance = (p2 - p1).distance;
    var direction = (p2 - p1) / distance;

    var start = p1;
    while (distance >= 0) {
      var next = start + direction * dashWidth;
      if (distance < dashWidth) {
        next = p1 + direction * (p2 - p1).distance;
      }
      canvas.drawLine(start, next, paint);
      start = next + direction * dashSpace;
      distance -= dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TransferMapPainter oldDelegate) => true;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';

class MarketScreen extends ConsumerWidget {
  final String productId;
  final String warehouseId;
  final String playerId;
  final String cityId;

  const MarketScreen({
    super.key,
    required this.productId,
    required this.warehouseId,
    required this.playerId,
    required this.cityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(marketProductProvider(productId));
    final listingsAsync = ref.watch(marketListingsProvider(productId));
    final buyerWarehouseAsync = ref.watch(
      marketBuyerWarehouseProvider(warehouseId),
    );
    final capacityAsync = ref.watch(
      warehouseCapacityStatusProvider(warehouseId),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Pazar'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(marketProductProvider(productId));
                  ref.invalidate(marketListingsProvider(productId));
                  ref.invalidate(marketBuyerWarehouseProvider(warehouseId));
                  ref.invalidate(warehouseCapacityStatusProvider(warehouseId));
                  await Future.wait([
                    ref.read(marketProductProvider(productId).future),
                    ref.read(marketListingsProvider(productId).future),
                    ref.read(marketBuyerWarehouseProvider(warehouseId).future),
                    ref.read(warehouseCapacityStatusProvider(warehouseId).future),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      productAsync.when(
                        data: (product) => _buildProductHeader(
                          product,
                          buyerWarehouseAsync.value,
                          capacityAsync.value,
                        ),
                        loading: () => _buildLoadingCard(),
                        error: (error, stack) =>
                            _buildErrorCard('Urun bilgisi alinamadi.'),
                      ),
                      SizedBox(height: 16.h),
                      _buildBuyerWarehouseCard(
                        buyerWarehouseAsync.value,
                        capacityAsync.value,
                      ),
                      SizedBox(height: 16.h),
                      listingsAsync.when(
                        data: (listings) => _buildListingsSection(
                          listings,
                          buyerWarehouseAsync.value,
                        ),
                        loading: () => _buildLoadingCard(),
                        error: (error, stack) => _buildErrorCard(
                          'Pazar listesi alinamadi: $error',
                        ),
                      ),
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

  Widget _buildProductHeader(
    ProductModel? product,
    MarketBuyerWarehouseModel? buyerWarehouse,
    WarehouseCapacityStatusModel? capacityStatus,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Row(
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.borderGoldLight.withValues(alpha: 0.35),
              ),
            ),
            child: CachedAssetImage(
              fileName: product?.urunIconu ?? 'default',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.urunAdi ?? productId,
                  style: AppTextStyles.h2.copyWith(color: AppColors.goldLight),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Satisa acik depolar bu urun icin listeleniyor.',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildInfoChip(
                      Icons.inventory_2_outlined,
                      'Urun ID: $productId',
                    ),
                    _buildInfoChip(
                      Icons.location_city,
                      'Sehir: ${buyerWarehouse?.cityName ?? cityId}',
                    ),
                    _buildInfoChip(
                      Icons.space_dashboard_outlined,
                      'Bos: ${capacityStatus?.availableCapacity.toStringAsFixed(1) ?? '...'}',
                    ),
                    _buildInfoChip(
                      Icons.straighten,
                      'Birim Hacim: ${product?.birimHacim.toStringAsFixed(1) ?? '0.0'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerWarehouseCard(
    MarketBuyerWarehouseModel? buyerWarehouse,
    WarehouseCapacityStatusModel? capacityStatus,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alici Depo', style: AppTextStyles.titleGold),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                width: 62.w,
                height: 62.w,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: CachedAssetImage(
                  fileName: buyerWarehouse?.warehouseIcon ?? 'warehouse.webp',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buyerWarehouse?.warehouseName ?? 'Depo bilgisi yukleniyor',
                      style: AppTextStyles.h2.copyWith(fontSize: 15.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      buyerWarehouse?.cityName ?? cityId,
                      style: AppTextStyles.body.copyWith(color: AppColors.gold),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _buildInfoChip(
                          Icons.check_circle_outline,
                          buyerWarehouse?.isActive == true ? 'Aktif' : 'Pasif',
                        ),
                        _buildInfoChip(
                          Icons.space_dashboard_outlined,
                          'Bos: ${capacityStatus?.availableCapacity.toStringAsFixed(1) ?? '...'}',
                        ),
                        _buildInfoChip(
                          Icons.pie_chart_outline,
                          'Dolu: ${capacityStatus?.usedCapacity.toStringAsFixed(1) ?? '...'}',
                        ),
                        _buildInfoChip(
                          Icons.lock_outline,
                          'Rezerve: ${capacityStatus?.reservedCapacity.toStringAsFixed(1) ?? '...'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListingsSection(
    List<MarketListingModel> listings,
    MarketBuyerWarehouseModel? buyerWarehouse,
  ) {
    if (listings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.storefront_outlined,
              color: AppColors.textMuted,
              size: 42.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              'Bu urun icin satista depo bulunamadi.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
          child: Text(
            'Satis Noktalari (${listings.length})',
            style: AppTextStyles.titleGold,
          ),
        ),
        ...listings.map(
          (listing) => _buildListingCard(listing, buyerWarehouse),
        ),
      ],
    );
  }

  Widget _buildListingCard(
    MarketListingModel listing,
    MarketBuyerWarehouseModel? buyerWarehouse,
  ) {
    final distance = buyerWarehouse == null
        ? null
        : _calculateDistance(
            buyerWarehouse.cityX,
            buyerWarehouse.cityY,
            listing.cityX,
            listing.cityY,
          );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.border),
            ),
            child: CachedAssetImage(
              fileName: listing.warehouseIcon ?? 'warehouse.webp',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.warehouseName,
                  style: AppTextStyles.h2.copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  listing.cityName,
                  style: AppTextStyles.body.copyWith(color: AppColors.gold),
                ),
                SizedBox(height: 4.h),
                Text(
                  distance == null
                      ? 'Uzaklik hesaplanamadi'
                      : 'Uzaklik: ${distance.toStringAsFixed(1)} birim',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBadge(
                        Icons.inventory,
                        'Stok',
                        listing.quantity.toString(),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildStatBadge(
                        Icons.star,
                        'Kalite',
                        listing.qualityLevel.toString(),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildStatBadge(
                        Icons.payments_outlined,
                        'Maliyet',
                        listing.cost.toStringAsFixed(1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 12.sp),
          SizedBox(width: 6.w),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 12.sp),
          SizedBox(height: 6.h),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 10.sp)),
          SizedBox(height: 2.h),
          Text(
            value,
            style: AppTextStyles.titleGold.copyWith(
              fontSize: 13.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: AppTextStyles.body.copyWith(color: AppColors.red),
      ),
    );
  }

  double _calculateDistance(
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt((dx * dx) + (dy * dy));
  }
}

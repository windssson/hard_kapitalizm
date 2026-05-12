import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_store_slot_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class MarketScreen extends ConsumerStatefulWidget {
  final String productId;
  final String warehouseId;
  final String playerId;
  final String cityId;
  final String targetType;
  final String storeId;
  final String storeSlotId;

  const MarketScreen({
    super.key,
    required this.productId,
    required this.warehouseId,
    required this.playerId,
    required this.cityId,
    this.targetType = 'warehouse',
    this.storeId = '',
    this.storeSlotId = '',
  });

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  bool get _isStoreTarget =>
      widget.targetType == 'store' && widget.storeSlotId.isNotEmpty;

  Future<void> _refreshAll() async {
    ref.invalidate(marketProductProvider(widget.productId));
    ref.invalidate(marketListingsProvider(widget.productId));
    if (_isStoreTarget) {
      ref.invalidate(marketBuyerStoreSlotProvider(widget.storeSlotId));
      if (widget.storeId.isNotEmpty) {
        ref.invalidate(storeDetailProvider(widget.storeId));
      }
    } else {
      ref.invalidate(marketBuyerWarehouseProvider(widget.warehouseId));
      ref.invalidate(warehouseCapacityStatusProvider(widget.warehouseId));
    }
    ref.invalidate(buyerActiveMarketTransfersProvider);
  }

  Future<void> _openPurchaseSheet(
    MarketListingModel listing,
    ProductModel? product,
    MarketBuyerStoreSlotModel? buyerStoreSlot,
  ) async {
    if (product == null) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'Urun bilgisi yuklenmeden satin alma acilamaz.',
        type: SnackbarType.error,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSheet(
        listing: listing,
        buyerWarehouseId: _isStoreTarget ? null : widget.warehouseId,
        buyerStoreSlotId: _isStoreTarget ? widget.storeSlotId : null,
        buyerStoreSlot: buyerStoreSlot,
        fallbackTargetCityId: widget.cityId,
        product: product,
        parentContext: context,
        onSuccess: _refreshAll,
      ),
    );
  }

  Future<void> _completeTransfer(String transferId) async {
    final result = await ref
        .read(marketActionProvider)
        .completeMarketTransfer(transferId);

    await _refreshAll();
    if (!mounted) return;

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Teslimat Tamamlandi',
        message: 'Transfer edilen urunler deponuza ulasti.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message']?.toString() ?? 'Transfer tamamlanamadi.',
      type: SnackbarType.error,
    );
  }

  MarketBuyerStoreSlotModel? _deriveBuyerStoreSlot(
    StoreModel? store,
    MarketBuyerStoreSlotModel? rawStoreSlot,
    Map<String, dynamic>? fallbackCity,
  ) {
    if (store == null) return null;

    final slot = store.slots.where((e) => e.id == widget.storeSlotId).firstOrNull;
    if (slot == null) return null;

    return MarketBuyerStoreSlotModel(
      storeSlotId: slot.id,
      storeId: store.id,
      storeName: store.name,
      cityId: store.cityId ?? widget.cityId,
      cityName:
          store.cityName ??
          rawStoreSlot?.cityName ??
          fallbackCity?['name']?.toString() ??
          'Bilinmeyen Sehir',
      cityX: _resolveCoordinate(
        rawStoreSlot?.cityX,
        fallbackCity?['map_position_x'],
      ),
      cityY: _resolveCoordinate(
        rawStoreSlot?.cityY,
        fallbackCity?['map_position_y'],
      ),
      isActive: store.isActive,
      productId: slot.productId,
      qualityLevel: slot.qualityLevel,
      quantity: slot.quantity,
      pendingQuantity: slot.pendingQuantity,
      capacity: slot.capacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(marketProductProvider(widget.productId));
    final listingsAsync = ref.watch(marketListingsProvider(widget.productId));
    final fallbackCityAsync = widget.cityId.isNotEmpty
        ? ref.watch(marketCityProvider(widget.cityId))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final buyerWarehouseAsync = _isStoreTarget
        ? AsyncValue<MarketBuyerWarehouseModel?>.data(null)
        : ref.watch(marketBuyerWarehouseProvider(widget.warehouseId));
    final rawBuyerStoreSlotAsync = _isStoreTarget
        ? ref.watch(marketBuyerStoreSlotProvider(widget.storeSlotId))
        : AsyncValue<MarketBuyerStoreSlotModel?>.data(null);
    final buyerStoreAsync = _isStoreTarget && widget.storeId.isNotEmpty
        ? ref.watch(storeDetailProvider(widget.storeId))
        : AsyncValue<StoreModel?>.data(null);
    final buyerStoreSlot = _isStoreTarget
        ? _deriveBuyerStoreSlot(
            buyerStoreAsync.value,
            rawBuyerStoreSlotAsync.value,
            fallbackCityAsync.value,
          )
        : null;
    final capacityAsync = _isStoreTarget
        ? AsyncValue<WarehouseCapacityStatusModel?>.data(null)
        : ref.watch(warehouseCapacityStatusProvider(widget.warehouseId));
    final transfersAsync = ref.watch(buyerActiveMarketTransfersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Global Pazar'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                color: AppColors.gold,
                backgroundColor: AppColors.cardBg,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      productAsync.when(
                        data: (product) => _buildProductHeader(
                          product,
                          capacityAsync.value,
                          buyerStoreSlot,
                        ),
                        loading: _buildLoadingCard,
                        error: (e, s) =>
                            _buildErrorCard('Urun bilgisi yuklenemedi.'),
                      ),
                      SizedBox(height: 20.h),
                      _buildSectionHeader(
                        'ALICI MERKEZI',
                        _isStoreTarget ? 'Magaza Slotu' : 'Depo Detaylari',
                      ),
                      SizedBox(height: 12.h),
                      _isStoreTarget
                          ? _buildBuyerStoreSlotCard(buyerStoreSlot)
                          : _buildBuyerWarehouseCard(
                              buyerWarehouseAsync.value,
                              capacityAsync.value,
                            ),
                      SizedBox(height: 24.h),
                      _buildSectionHeader('YOLDAKI TRANSFERLER', 'Teslim Takibi'),
                      SizedBox(height: 12.h),
                      transfersAsync.when(
                        data: _buildTransfersSection,
                        loading: _buildLoadingCard,
                        error: (e, s) =>
                            _buildErrorCard('Transfer takibi alinamadi.'),
                      ),
                      SizedBox(height: 24.h),
                      _buildSectionHeader('SATIS NOKTALARI', 'Pazar Listesi'),
                      SizedBox(height: 12.h),
                          listingsAsync.when(
                        data: (listings) => _buildListingsSection(
                          listings: listings,
                          buyer: buyerWarehouseAsync.value,
                          buyerStoreSlot: buyerStoreSlot,
                          fallbackCity: fallbackCityAsync.value,
                          product: productAsync.value,
                        ),
                        loading: _buildLoadingCard,
                        error: (e, s) =>
                            _buildErrorCard('Pazar verileri alinamadi.'),
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
    WarehouseCapacityStatusModel? capacity,
    MarketBuyerStoreSlotModel? storeSlot,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardBg, AppColors.cardBgLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.4),
              ),
            ),
            child: CachedAssetImage(fileName: product?.urunIconu ?? 'default.webp'),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.urunAdi ?? 'Yukleniyor...',
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 22.sp,
                    color: AppColors.goldLight,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Bu urun icin aktif ilanlari inceleyin ve uygun aracinizi secin.',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _buildMiniBadge(
                      Icons.straighten,
                      '${product?.birimHacim.toStringAsFixed(1) ?? '0'} m3',
                    ),
                    SizedBox(width: 8.w),
                    _buildMiniBadge(
                      _isStoreTarget
                          ? Icons.storefront_outlined
                          : Icons.warehouse_outlined,
                      _isStoreTarget
                          ? 'Slot Bos: ${storeSlot?.availableCapacity.toStringAsFixed(0) ?? '0'}'
                          : 'Bos: ${capacity?.availableCapacity.toStringAsFixed(1) ?? '0'} m3',
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
    MarketBuyerWarehouseModel? buyer,
    WarehouseCapacityStatusModel? capacity,
  ) {
    final available = capacity?.availableCapacity ?? 0.0;
    final totalCandidate = capacity?.totalCapacity ?? 1.0;
    final total = totalCandidate <= 0 ? 1.0 : totalCandidate;
    final fillRatio = (1 - (available / total)).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.warehouse_outlined, color: AppColors.gold),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buyer?.warehouseName ?? 'Merkez Depo',
                      style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                    ),
                    Text(
                      buyer?.cityName ?? 'Sehir bekleniyor...',
                      style: AppTextStyles.body.copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(buyer?.isActive ?? false),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DEPO DOLULUK ORANI',
                style: AppTextStyles.titleGold.copyWith(fontSize: 10.sp),
              ),
              Text(
                '%${(fillRatio * 100).toInt()}',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildPremiumProgressBar(fillRatio, AppColors.gold),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildSimpleStat('BOS', '${available.toStringAsFixed(1)} m3'),
              _buildSimpleStat(
                'REZERVE',
                '${capacity?.reservedCapacity.toStringAsFixed(1) ?? '0'} m3',
              ),
              _buildSimpleStat(
                'TOPLAM',
                '${capacity?.totalCapacity.toStringAsFixed(1) ?? '0'} m3',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerStoreSlotCard(MarketBuyerStoreSlotModel? storeSlot) {
    final used = (storeSlot?.quantity ?? 0) + (storeSlot?.pendingQuantity ?? 0);
    final total = (storeSlot?.capacity ?? 0) <= 0 ? 1 : storeSlot!.capacity;
    final fillRatio = (used / total).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.storefront_outlined, color: AppColors.gold),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeSlot?.storeName ?? 'Magaza',
                      style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                    ),
                    Text(
                      storeSlot?.cityName ?? 'Sehir bekleniyor...',
                      style: AppTextStyles.body.copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(storeSlot?.isActive ?? false),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SLOT DOLULUK ORANI',
                style: AppTextStyles.titleGold.copyWith(fontSize: 10.sp),
              ),
              Text(
                '%${(fillRatio * 100).toInt()}',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildPremiumProgressBar(fillRatio, AppColors.gold),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildSimpleStat(
                'MEVCUT',
                '${storeSlot?.quantity ?? 0}/${storeSlot?.capacity ?? 0}',
              ),
              _buildSimpleStat(
                'YOLDA',
                '${storeSlot?.pendingQuantity ?? 0}',
              ),
              _buildSimpleStat(
                'BOS',
                '${storeSlot?.availableCapacity.toStringAsFixed(0) ?? '0'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransfersSection(List<MarketTransferModel> transfers) {
    if (transfers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Su anda yolda olan aktif transferiniz yok.',
          style: AppTextStyles.body,
        ),
      );
    }

    return Column(
      children: transfers
          .map(
            (transfer) => _MarketTransferCountdownCard(
              transfer: transfer,
              onFinish: () => _completeTransfer(transfer.id),
            ),
          )
          .toList(),
    );
  }

  Widget _buildListingsSection({
    required List<MarketListingModel> listings,
    required MarketBuyerWarehouseModel? buyer,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
    required Map<String, dynamic>? fallbackCity,
    required ProductModel? product,
  }) {
    if (listings.isEmpty) return _buildEmptyState();

    return Column(
      children: listings
          .map(
            (listing) => _buildListingCard(
              listing,
              buyer,
              buyerStoreSlot,
              fallbackCity,
              product,
            ),
          )
          .toList(),
    );
  }

  Widget _buildListingCard(
    MarketListingModel listing,
    MarketBuyerWarehouseModel? buyer,
    MarketBuyerStoreSlotModel? buyerStoreSlot,
    Map<String, dynamic>? fallbackCity,
    ProductModel? product,
  ) {
    final targetCityX = _resolveCoordinate(
      buyerStoreSlot?.cityX ?? buyer?.cityX,
      fallbackCity?['map_position_x'],
    );
    final targetCityY = _resolveCoordinate(
      buyerStoreSlot?.cityY ?? buyer?.cityY,
      fallbackCity?['map_position_y'],
    );
    final hasTarget =
        _hasUsableCoordinates(targetCityX, targetCityY) &&
        _hasUsableCoordinates(listing.cityX, listing.cityY);
    final distanceKm = !hasTarget
        ? 0.0
        : _calculateDistanceKm(
            targetCityX,
            targetCityY,
            listing.cityX,
            listing.cityY,
          );
    final distanceColor = distanceKm < 250
        ? AppColors.green
        : (distanceKm < 750 ? AppColors.gold : AppColors.red);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6.w,
                decoration: BoxDecoration(color: distanceColor),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56.w,
                            height: 56.w,
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppColors.cardBgLight,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: CachedAssetImage(
                              fileName:
                                  listing.warehouseIcon ?? 'warehouse.webp',
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.warehouseName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.gold,
                                      size: 10.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      listing.cityName,
                                      style: AppTextStyles.body.copyWith(
                                        fontSize: 11.sp,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${distanceKm.toStringAsFixed(0)} km',
                                style: TextStyle(
                                  color: distanceColor,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Mesafe',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 9.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          _buildListingStat(
                            Icons.inventory_2_outlined,
                            'STOK',
                            listing.quantity.toString(),
                            AppColors.blue,
                          ),
                          SizedBox(width: 10.w),
                          _buildListingStat(
                            Icons.stars,
                            'KALITE',
                            'Lv.${listing.qualityLevel}',
                            AppColors.gold,
                          ),
                          SizedBox(width: 10.w),
                          _buildListingStat(
                            Icons.payments_outlined,
                            'FIYAT',
                            listing.price.toStringAsFixed(1),
                            AppColors.green,
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        height: 38.h,
                        child: ElevatedButton.icon(
                          onPressed: () => _openPurchaseSheet(
                            listing,
                            product,
                            buyerStoreSlot,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          icon: const Icon(
                            Icons.shopping_cart_checkout,
                            color: Colors.black,
                            size: 16,
                          ),
                          label: Text(
                            'SATIN AL',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleGold.copyWith(letterSpacing: 1.2)),
        Text(
          subtitle,
          style: AppTextStyles.body.copyWith(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 10.sp),
          SizedBox(width: 4.w),
          Text(
            label,
            style: AppTextStyles.body.copyWith(fontSize: 9.sp, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool active) {
    final color = active ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        active ? 'AKTIF' : 'PASIF',
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListingStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.cardBgLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 12.sp),
                SizedBox(width: 4.w),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumProgressBar(double ratio, Color color) {
    return Stack(
      children: [
        Container(
          height: 8.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBgLight,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 8.h,
          width: 320.w * ratio,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.7), color],
            ),
            borderRadius: BorderRadius.circular(4.r),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(30.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, color: AppColors.textMuted, size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            'Satis Noktasi Bulunamadi',
            style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Bu urun icin su anda fiyat girilmis aktif satis listesi bulunmuyor.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() => Container(
    height: 100.h,
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: const Center(
      child: CircularProgressIndicator(color: AppColors.gold),
    ),
  );

  Widget _buildErrorCard(String message) => Container(
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16.r),
    ),
    child: Text(message, style: TextStyle(color: AppColors.red)),
  );

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final startLat = _degreesToRadians(lat1);
    final endLat = _degreesToRadians(lat2);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(startLat) *
            math.cos(endLat) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _resolveCoordinate(dynamic primary, dynamic fallback) {
    final primaryValue = _parseCoordinate(primary);
    if (primaryValue != 0) return primaryValue;
    return _parseCoordinate(fallback);
  }

  double _parseCoordinate(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _hasUsableCoordinates(double x, double y) {
    return x != 0 && y != 0;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180);
}

class _PurchaseSheet extends ConsumerStatefulWidget {
  final MarketListingModel listing;
  final String? buyerWarehouseId;
  final String? buyerStoreSlotId;
  final MarketBuyerStoreSlotModel? buyerStoreSlot;
  final String fallbackTargetCityId;
  final ProductModel product;
  final BuildContext parentContext;
  final Future<void> Function() onSuccess;

  const _PurchaseSheet({
    required this.listing,
    required this.buyerWarehouseId,
    required this.buyerStoreSlotId,
    required this.buyerStoreSlot,
    required this.fallbackTargetCityId,
    required this.product,
    required this.parentContext,
    required this.onSuccess,
  });

  @override
  ConsumerState<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends ConsumerState<_PurchaseSheet> {
  late final TextEditingController _quantityController;
  int _quantity = 1;
  bool _isSubmitting = false;
  String? _selectedVehicleId;

  bool get _isSameCityInstantStorePurchase {
    final storeSlot = widget.buyerStoreSlot;
    if (widget.buyerStoreSlotId == null ||
        widget.buyerStoreSlotId!.isEmpty ||
        (storeSlot == null && widget.fallbackTargetCityId.isEmpty)) {
      return false;
    }
    final targetCityId = (storeSlot?.cityId.isNotEmpty ?? false)
        ? storeSlot!.cityId
        : widget.fallbackTargetCityId;
    return targetCityId == widget.listing.cityId;
  }

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(String value) {
    final parsed = int.tryParse(value) ?? 1;
    final safe = parsed.clamp(1, widget.listing.quantity);
    final safeText = safe.toString();

    if (_quantityController.text != safeText) {
      _quantityController.value = TextEditingValue(
        text: safeText,
        selection: TextSelection.collapsed(offset: safeText.length),
      );
    }

    if (safe != _quantity) {
      setState(() {
        _quantity = safe;
        _selectedVehicleId = null;
      });
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }

  Future<void> _submit(
    List<MarketTransferVehicleOptionModel> options,
  ) async {
    if (!_isSameCityInstantStorePurchase && _selectedVehicleId == null) {
      AppSnackbar.show(
        context,
        title: 'Secim Gerekli',
        message: 'Devam etmek icin bir arac secin.',
        type: SnackbarType.warning,
      );
      return;
    }

    final selected = _isSameCityInstantStorePurchase
        ? null
        : options.where((e) => e.vehicleId == _selectedVehicleId).firstOrNull;

    if (!_isSameCityInstantStorePurchase &&
        (selected == null || !selected.canSelect)) {
      AppSnackbar.show(
        context,
        title: 'Gecersiz Arac',
        message: 'Secilen arac bu miktar icin uygun degil.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final targetStoreSlot = widget.buyerStoreSlot;
    final shouldPrepareStoreSlot =
        widget.buyerStoreSlotId != null &&
        widget.buyerStoreSlotId!.isNotEmpty &&
        targetStoreSlot != null &&
        targetStoreSlot.quantity == 0 &&
        targetStoreSlot.pendingQuantity == 0 &&
        (targetStoreSlot.productId == null ||
            targetStoreSlot.qualityLevel != widget.listing.qualityLevel);

    if (shouldPrepareStoreSlot) {
      final setupResult = await ref.read(storeActionProvider).setStoreSlotProduct(
            slotId: widget.buyerStoreSlotId!,
            productId: widget.product.id,
            qualityLevel: widget.listing.qualityLevel,
          );

      if (!mounted) return;

      if (setupResult['success'] != true) {
        setState(() {
          _isSubmitting = false;
        });
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: setupResult['message']?.toString() ??
              'Magaza slotu hazirlanamadi.',
          type: SnackbarType.error,
        );
        return;
      }
    }

    final result = await ref.read(marketActionProvider).startMarketTransfer(
          buyerWarehouseId: widget.buyerWarehouseId,
          buyerStoreSlotId: widget.buyerStoreSlotId,
          sellerSlotId: widget.listing.slotId,
          quantity: _quantity,
          vehicleId: selected?.vehicleId,
        );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      await widget.onSuccess();
      if (!mounted) return;
      Navigator.of(context).pop();
      final isInstant = result['mode']?.toString() == 'instant';
      AppSnackbar.show(
        widget.parentContext,
        title: 'Basarili',
        message: isInstant
            ? 'Satin alma aninda tamamlandi.'
            : 'Transfer baslatildi. Arac yola cikti.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message']?.toString() ?? 'Transfer baslatilamadi.',
      type: SnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = MarketVehicleOptionsParams(
      buyerWarehouseId: widget.buyerWarehouseId,
      buyerStoreSlotId: widget.buyerStoreSlotId,
      sellerSlotId: widget.listing.slotId,
      quantity: _quantity,
    );
    final optionsAsync = _isSameCityInstantStorePurchase
        ? AsyncValue<List<MarketTransferVehicleOptionModel>>.data(const [])
        : ref.watch(marketTransferVehicleOptionsProvider(params));
    final requiredCapacity = _quantity * widget.product.birimHacim;
    final totalPrice = _quantity * widget.listing.price;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        20.h,
        16.w,
        MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Satin Alma',
                style: AppTextStyles.h1.copyWith(fontSize: 20.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                '${widget.listing.warehouseName} deposundan alim yapacaksiniz.',
                style: AppTextStyles.body,
              ),
              if (_isSameCityInstantStorePurchase) ...[
                SizedBox(height: 8.h),
                Text(
                  'Ayni sehir oldugu icin teslimat aninda tamamlanacak.',
                  style: AppTextStyles.body.copyWith(color: AppColors.green),
                ),
              ],
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Birim Fiyat',
                      widget.listing.price.toStringAsFixed(1),
                      AppColors.green,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildSummaryCard(
                      'Kalite',
                      'Lv.${widget.listing.qualityLevel}',
                      AppColors.gold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                onChanged: _updateQuantity,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Miktar',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  helperText:
                      'Maksimum ${widget.listing.quantity} adet, hacim ${requiredCapacity.toStringAsFixed(1)} m3',
                  helperStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Urun Bedeli', style: AppTextStyles.body),
                    Text(
                      totalPrice.toStringAsFixed(1),
                      style: AppTextStyles.titleGold,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              if (!_isSameCityInstantStorePurchase) ...[
                Text(
                  'Arac Secimi',
                  style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                ),
                SizedBox(height: 10.h),
              ],
              optionsAsync.when(
                data: (options) {
                  if (!_isSameCityInstantStorePurchase && options.isEmpty) {
                    return _buildInfoBox(
                      'Bu transfer icin uygun veya kiralanabilir arac bulunamadi.',
                      AppColors.red,
                    );
                  }

                  final selected = options
                      .where((e) => e.vehicleId == _selectedVehicleId)
                      .firstOrNull;
                  final totalCost =
                      totalPrice + (selected?.rentalCost ?? 0.0);

                  return Column(
                    children: [
                      if (!_isSameCityInstantStorePurchase) ...[
                        ...options.map(_buildVehicleOptionCard),
                        SizedBox(height: 12.h),
                      ],
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgLight.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _buildCostRow(
                              'Urun Bedeli',
                              totalPrice.toStringAsFixed(1),
                            ),
                            SizedBox(height: 6.h),
                            _buildCostRow(
                              'Kira Bedeli',
                              (selected?.rentalCost ?? 0)
                                  .toStringAsFixed(1),
                            ),
                            SizedBox(height: 6.h),
                            _buildCostRow(
                              'Toplam',
                              totalCost.toStringAsFixed(1),
                              highlight: true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        height: 44.h,
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submit(options),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  'TRANSFERI BASLAT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => _buildInfoBox(
                  error.toString(),
                  AppColors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleOptionCard(MarketTransferVehicleOptionModel option) {
    final isSelected = _selectedVehicleId == option.vehicleId;
    final cardColor = option.canSelect
        ? (isSelected
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.cardBg)
        : AppColors.red.withValues(alpha: 0.08);
    final borderColor = option.canSelect
        ? (isSelected ? AppColors.gold : AppColors.border)
        : AppColors.red;

    return GestureDetector(
      onTap: option.canSelect
          ? () {
              setState(() {
                _selectedVehicleId = option.vehicleId;
              });
            }
          : null,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.vehicleName,
                    style: AppTextStyles.h2.copyWith(fontSize: 15.sp),
                  ),
                ),
                if (option.isRental)
                  _buildTypeBadge('Kiralik', Colors.orange)
                else
                  _buildTypeBadge('Kendi Aracin', AppColors.green),
              ],
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildInlineStat('Kapasite', '${option.capacity}'),
                _buildInlineStat('Hiz', '${option.speedKmh} km/s'),
                _buildInlineStat(
                  'Yakit',
                  '${option.currentFuel}/${option.fuelCapacity}',
                ),
                _buildInlineStat(
                  'Gerekli',
                  option.fuelNeeded.toStringAsFixed(0),
                ),
                _buildInlineStat('Kondisyon', '${option.condition}%'),
                _buildInlineStat(
                  'Asinma',
                  option.conditionNeeded.toStringAsFixed(0),
                ),
                _buildInlineStat(
                  'Mesafe',
                  '${option.distanceKm.toStringAsFixed(0)} km',
                ),
                _buildInlineStat(
                  'Sure',
                  _formatDuration(option.estimatedDurationSeconds),
                ),
                if (option.isRental)
                  _buildInlineStat(
                    'Kira',
                    option.rentalCost.toStringAsFixed(1),
                  ),
              ],
            ),
            if (option.disabledReason != null) ...[
              SizedBox(height: 10.h),
              Text(
                option.disabledReason!,
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStat(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.sp,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoBox(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 12.sp),
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool highlight = false}) {
    final color = highlight ? AppColors.gold : Colors.white;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MarketTransferCountdownCard extends StatefulWidget {
  final MarketTransferModel transfer;
  final Future<void> Function() onFinish;

  const _MarketTransferCountdownCard({
    required this.transfer,
    required this.onFinish,
  });

  @override
  State<_MarketTransferCountdownCard> createState() =>
      _MarketTransferCountdownCardState();
}

class _MarketTransferCountdownCardState
    extends State<_MarketTransferCountdownCard> {
  late Duration _remaining;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.transfer.finishAt.difference(DateTime.now());
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _remaining = widget.transfer.finishAt.difference(DateTime.now());
      });

      if (_remaining.inSeconds <= 0) {
        _fireOnce();
        return;
      }

      _tick();
    });
  }

  void _fireOnce() {
    if (_triggered) return;
    _triggered = true;
    Future.microtask(widget.onFinish);
  }

  @override
  Widget build(BuildContext context) {
    final safe = _remaining.isNegative ? Duration.zero : _remaining;
    final h = safe.inHours.toString().padLeft(2, '0');
    final m = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final s = (safe.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              widget.transfer.isRental
                  ? Icons.local_shipping
                  : Icons.directions_car,
              color: AppColors.gold,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.transfer.quantity} adet ${widget.transfer.productId}',
                  style: AppTextStyles.h2.copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  widget.transfer.isRental
                      ? 'Kiralik arac yolda'
                      : 'Kendi araciniz yolda',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: 6.h),
                Text(
                  safe.inSeconds <= 0
                      ? 'Teslim ediliyor...'
                      : 'Kalan sure: $h:$m:$s',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

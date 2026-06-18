import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_store_slot_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

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
    this.productId = '',
    this.warehouseId = '',
    this.playerId = '',
    this.cityId = '',
    this.targetType = 'warehouse',
    this.storeId = '',
    this.storeSlotId = '',
  });

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final List<_MarketCartItem> _cartItems = [];
  String? _lockedSourceCityId;
  bool _cityCatalogEnabled = false;
  String _productSearchQuery = '';
  String _warehouseCityFilter = '';
  late String _selectedProductId;
  late String _selectedWarehouseId;
  late String _selectedCityId;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.productId;
    _selectedWarehouseId = widget.warehouseId;
    _selectedCityId = widget.cityId;
    _warehouseCityFilter = widget.cityId;
  }

  String get _activeProductId => _selectedProductId;
  String get _activeWarehouseId => _selectedWarehouseId;
  String get _activeCityId => _selectedCityId;
  bool get _requiresInitialSelection =>
      !_isStoreTarget &&
      (_activeProductId.isEmpty ||
          _activeWarehouseId.isEmpty ||
          _activeCityId.isEmpty);

  bool get _isStoreTarget =>
      widget.targetType == 'store' && widget.storeSlotId.isNotEmpty;

  String get _targetTypeLabel => _isStoreTarget ? 'Magaza Rafina' : 'Depoya';
  bool get _hasCart => _cartItems.isNotEmpty;
  int get _cartTotalQuantity =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get _cartTotalProductCost =>
      _cartItems.fold(0, (sum, item) => sum + item.totalProductPrice);
  double get _cartTotalVolume =>
      _cartItems.fold(0, (sum, item) => sum + item.totalVolume);
  bool get _isLockedToCityCatalog =>
      _lockedSourceCityId != null && _cityCatalogEnabled;

  Future<void> _refreshPage() async {
    if (_activeProductId.isNotEmpty) {
      ref.invalidate(marketProductProvider(_activeProductId));
      ref.invalidate(marketListingsProvider(_activeProductId));
    }
    if (_lockedSourceCityId != null) {
      ref.invalidate(marketCityListingsProvider(_lockedSourceCityId!));
    }
    if (_isStoreTarget) {
      if (widget.storeId.isNotEmpty) {
        ref.invalidate(storeDetailPageProvider(widget.storeId));
      }
      return;
    }

    if (_activeWarehouseId.isNotEmpty) {
      ref.invalidate(marketBuyerWarehouseProvider(_activeWarehouseId));
      ref.invalidate(warehouseCapacityStatusProvider(_activeWarehouseId));
      ref.invalidate(warehouseDetailProvider(_activeWarehouseId));
    }
  }

  Future<void> _refreshAfterPurchase({
    required bool isInstant,
  }) async {
    if (_activeProductId.isNotEmpty) {
      ref.invalidate(marketProductProvider(_activeProductId));
      ref.invalidate(marketListingsProvider(_activeProductId));
    }
    if (_lockedSourceCityId != null) {
      ref.invalidate(marketCityListingsProvider(_lockedSourceCityId!));
    }
    ref.invalidate(playerProvider);
    ref.invalidate(buyerTransferMapProvider);
    ref.invalidate(buyerTransferHistoryProvider);
    if (_isStoreTarget) {
      if (widget.storeId.isNotEmpty) {
        ref.invalidate(storeDetailPageProvider(widget.storeId));
      }
    } else {
      if (_activeWarehouseId.isNotEmpty) {
        ref.invalidate(marketBuyerWarehouseProvider(_activeWarehouseId));
        ref.invalidate(warehouseCapacityStatusProvider(_activeWarehouseId));
      }
      ref.invalidate(warehouseListProvider);
      if (_activeWarehouseId.isNotEmpty) {
        ref.invalidate(warehouseDetailProvider(_activeWarehouseId));
      }
    }
  }

  Future<void> _refreshAfterPreparedStoreSlotRollback() async {
    if (!_isStoreTarget) return;
    if (widget.storeId.isNotEmpty) {
      ref.invalidate(storeDetailPageProvider(widget.storeId));
    }
  }

  Future<void> _openAddToCartSheet(
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

    final capacityStatus = !_isStoreTarget && _activeWarehouseId.isNotEmpty
        ? ref.read(warehouseCapacityStatusProvider(_activeWarehouseId)).value
        : null;
    if (!_canAddListingToCart(
      listing: listing,
      product: product,
      capacity: capacityStatus,
      buyerStoreSlot: buyerStoreSlot,
    )) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Kapasite Yetersiz',
        message: _listingCapacityWarning(
          listing: listing,
          product: product,
          capacity: capacityStatus,
          buyerStoreSlot: buyerStoreSlot,
        ),
        type: SnackbarType.warning,
      );
      return;
    }

    final selection = await showDialog<_MarketCartSelection?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520.w),
          child: _AddToCartSheet(
            listing: listing,
            buyerStoreSlot: buyerStoreSlot,
            buyerWarehouseId: _isStoreTarget ? null : _activeWarehouseId,
            product: product,
          ),
        ),
      ),
    );

    if (selection == null || selection.quantity <= 0) return;
    if (_lockedSourceCityId != null &&
        _lockedSourceCityId != selection.listing.cityId) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Sehir Kilidi',
        message:
            'Sepetteki urunlerle ayni sehirden devam etmelisiniz: ${_resolveLockedCityName()}.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() {
      _lockedSourceCityId ??= selection.listing.cityId;
      _cartItems.addOrMerge(selection.listing, selection.quantity);
    });

    if (!mounted) return;
    AppSnackbar.show(
      context,
      title: 'Sepete Eklendi',
      message:
          '${selection.listing.productName} x${selection.quantity} sepete eklendi.',
      type: SnackbarType.success,
    );
  }

  String _resolveLockedCityName() {
    if (_lockedSourceCityId == null) return '-';
    final match = _cartItems
        .where((item) => item.listing.cityId == _lockedSourceCityId)
        .firstOrNull;
    return match?.listing.cityName ?? '-';
  }


  void _removeCartItem(_MarketCartItem item) {
    setState(() {
      _cartItems.removeWhere((entry) => entry.key == item.key);
      if (_cartItems.isEmpty) {
        _lockedSourceCityId = null;
        _cityCatalogEnabled = false;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _lockedSourceCityId = null;
      _cityCatalogEnabled = false;
    });
  }

  Future<void> _enableCityCatalogMode() async {
    if (_lockedSourceCityId == null) return;
    setState(() {
      _cityCatalogEnabled = true;
    });
  }

  List<MarketListingModel> _applyCartCityRules(List<MarketListingModel> listings) {
    if (_lockedSourceCityId == null) return listings;

    final sameCity = listings
        .where((listing) => listing.cityId == _lockedSourceCityId)
        .toList();

    if (_cityCatalogEnabled) {
      return sameCity;
    }

    return sameCity
        .where((listing) => listing.productId == _activeProductId)
        .toList();
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
        style: AppTextStyles.body.copyWith(color: color, fontSize: 12.sp),
      ),
    );
  }

  Widget _buildTypeBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(color: color, fontSize: 9.sp),
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
      cityId: store.cityId ?? _activeCityId,
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

  List<MarketListingModel> _withNpcListing({
    required List<MarketListingModel> listings,
    required ProductModel? product,
    required Map<String, dynamic>? fallbackCity,
    required MarketBuyerWarehouseModel? buyer,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
  }) {
    if (product == null || product.bazSatisFiyati <= 0) return listings;
    if (listings.any((listing) => listing.isNpc && listing.productId == product.id)) {
      return listings;
    }

    final lockedCityListing = _lockedSourceCityId == null
        ? null
        : listings.where((listing) => listing.cityId == _lockedSourceCityId).firstOrNull;

    final cityId =
        (_lockedSourceCityId ??
                buyerStoreSlot?.cityId ??
                buyer?.cityId ??
                _activeCityId)
            .toString();
    if (cityId.isEmpty) return listings;

    final cityName = (lockedCityListing?.cityName ??
            buyerStoreSlot?.cityName ??
            buyer?.cityName ??
            fallbackCity?['name'] ??
            'Pazar')
        .toString();
    final cityX = _resolveCoordinate(
      lockedCityListing?.cityX ?? buyerStoreSlot?.cityX ?? buyer?.cityX,
      fallbackCity?['map_position_x'],
    );
    final cityY = _resolveCoordinate(
      lockedCityListing?.cityY ?? buyerStoreSlot?.cityY ?? buyer?.cityY,
      fallbackCity?['map_position_y'],
    );

    return [
      ...listings,
      MarketListingModel.npc(
        productId: product.id,
        productName: product.urunAdi,
        productIcon: product.urunIconu,
        unitVolume: product.birimHacim,
        price: product.bazSatisFiyati * 1.25,
        cityId: cityId,
        cityName: cityName,
        cityX: cityX,
        cityY: cityY,
      ),
    ];
  }

  List<MarketListingModel> _filterListingsForTargetSlot(
    List<MarketListingModel> listings,
    MarketBuyerStoreSlotModel? buyerStoreSlot,
  ) {
    if (!_isStoreTarget || buyerStoreSlot == null) return listings;

    final hasLockedStock =
        buyerStoreSlot.quantity > 0 || buyerStoreSlot.pendingQuantity > 0;
    final lockedQuality = buyerStoreSlot.qualityLevel;

    if (!hasLockedStock || lockedQuality <= 0) {
      return listings;
    }

    return listings
        .where((listing) => listing.qualityLevel == lockedQuality)
        .toList();
  }

  Widget _buildTargetSummaryCard({
    required ProductModel? product,
    required MarketBuyerWarehouseModel? buyerWarehouse,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
    required WarehouseCapacityStatusModel? capacity,
  }) {
    final bool isStore = _isStoreTarget;
    final String targetName = isStore
        ? (buyerStoreSlot?.storeName ?? 'Magaza')
        : (buyerWarehouse?.warehouseName ?? 'Merkez Depo');
    final String cityName = isStore
        ? (buyerStoreSlot?.cityName ?? 'Sehir bekleniyor...')
        : (buyerWarehouse?.cityName ?? 'Sehir bekleniyor...');
    final bool isActive = isStore
        ? (buyerStoreSlot?.isActive ?? false)
        : (buyerWarehouse?.isActive ?? false);
    final String productText = product?.urunAdi ?? 'Urun';

    // Capacity & Progress Bar Calculations
    double fillRatio = 0.0;
    String totalText = '';
    String availableText = '';
    if (isStore) {
      final used = (buyerStoreSlot?.quantity ?? 0) + (buyerStoreSlot?.pendingQuantity ?? 0);
      final total = (buyerStoreSlot?.capacity ?? 0) <= 0 ? 1 : buyerStoreSlot!.capacity;
      fillRatio = (used / total).clamp(0.0, 1.0);
      totalText = '$total';
      availableText = '${buyerStoreSlot?.availableCapacity.toStringAsFixed(0) ?? '0'} bos alan';
    } else {
      final available = capacity?.availableCapacity ?? 0.0;
      final totalCandidate = capacity?.totalCapacity ?? 1.0;
      final total = totalCandidate <= 0 ? 1.0 : totalCandidate;
      fillRatio = (1.0 - (available / total)).clamp(0.0, 1.0);
      totalText = '${capacity?.totalCapacity.toStringAsFixed(1) ?? '0'} m3';
      availableText = '${available.toStringAsFixed(1)} m3 bos kapasite';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.10),
            AppColors.blue.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  isStore
                      ? Icons.storefront_outlined
                      : Icons.warehouse_outlined,
                  color: AppColors.gold,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alim Hedefi: $productText',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        TextButton(
                          onPressed: _resetWarehouseSelection,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Depo Degistir',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      targetName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(fontSize: 14.sp),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(isActive),
              SizedBox(width: 6.w),
              _buildTypeBadge(_targetTypeLabel, AppColors.gold),
            ],
          ),
          SizedBox(height: 12.h),

          // Progress bar & Capacity Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Doluluk: %${(fillRatio * 100).toInt()}',
                style: AppTextStyles.body.copyWith(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
              Text(
                isStore
                  ? 'Bos: ${buyerStoreSlot?.availableCapacity.toStringAsFixed(0) ?? '0'} / Toplam: $totalText'
                  : 'Bos: ${capacity?.availableCapacity.toStringAsFixed(1) ?? '0'} m3 / Toplam: $totalText',
                style: AppTextStyles.body.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          _buildPremiumProgressBar(fillRatio, AppColors.gold),

          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildInlineStat('Sehir', cityName),
              _buildInlineStat('Kapasite Durumu', availableText),
            ],
          ),
        ],
      ),
    );
  }

  bool _canAddListingToCart({
    required MarketListingModel listing,
    required ProductModel? product,
    required WarehouseCapacityStatusModel? capacity,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
  }) {
    if (_isStoreTarget) {
      return (buyerStoreSlot?.availableCapacity ?? 0) > 0;
    }
    final unitVolume = listing.unitVolume > 0
        ? listing.unitVolume
        : (product?.birimHacim ?? 0);
    if (unitVolume <= 0) return false;
    return (capacity?.availableCapacity ?? 0) >= unitVolume;
  }

  String? _buildCapacityBannerMessage({
    required ProductModel? product,
    required WarehouseCapacityStatusModel? capacity,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
    required List<MarketListingModel> listings,
  }) {
    if (_requiresInitialSelection) return null;

    if (_isStoreTarget) {
      final available = buyerStoreSlot?.availableCapacity ?? 0;
      if (available <= 0) {
        return 'Hedef slotta bos alan kalmadi. Sepete ekleme kapatildi.';
      }
      if (listings.isEmpty) return null;
      return null;
    }

    final available = capacity?.availableCapacity ?? 0;
    if (available <= 0) {
      return 'Secili depoda hic bos kapasite kalmadi. Yeni alim baslatilamaz.';
    }

    final unitVolume = product?.birimHacim ?? 0;
    if (unitVolume > 0) {
      final maxUnits = (available / unitVolume).floor();
      if (maxUnits <= 0) {
        return 'Bu urun icin secili depoda yeterli yer yok. En az ${unitVolume.toStringAsFixed(1)} m3 bos alan gerekli.';
      }
      if (maxUnits < 5) {
        return 'Dikkat: secili depoda bu urunden en fazla $maxUnits adet yer var.';
      }
    }

    return null;
  }

  String _listingCapacityWarning({
    required MarketListingModel listing,
    required ProductModel? product,
    required WarehouseCapacityStatusModel? capacity,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
  }) {
    if (_isStoreTarget) {
      final available = buyerStoreSlot?.availableCapacity ?? 0;
      return 'Hedef slotta bos alan yok. Kalan alan: ${available.toStringAsFixed(0)}.';
    }
    final unitVolume = listing.unitVolume > 0
        ? listing.unitVolume
        : (product?.birimHacim ?? 0);
    final available = capacity?.availableCapacity ?? 0;
    return 'Bu ilan sepete eklenemiyor. Gereken en az hacim: ${unitVolume.toStringAsFixed(1)} m3, mevcut bos kapasite: ${available.toStringAsFixed(1)} m3.';
  }

  void _onNavSelected(int index) {
    if (index == 3) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/company');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  void _resetCartState() {
    _cartItems.clear();
    _lockedSourceCityId = null;
    _cityCatalogEnabled = false;
  }

  Widget _buildCompactSelectionBar({
    required ProductModel? product,
    required MarketBuyerWarehouseModel? buyerWarehouse,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
    required WarehouseCapacityStatusModel? capacity,
  }) {
    final bool isStore = _isStoreTarget;
    final String targetName = isStore
        ? (buyerStoreSlot?.storeName ?? 'Magaza')
        : (buyerWarehouse?.warehouseName ?? 'Merkez Depo');
    final String cityName = isStore
        ? (buyerStoreSlot?.cityName ?? 'Sehir')
        : (buyerWarehouse?.cityName ?? 'Sehir');
    final String capacityText = isStore
        ? 'Bos ${buyerStoreSlot?.availableCapacity.toStringAsFixed(0) ?? '0'}'
        : 'Bos ${capacity?.availableCapacity.toStringAsFixed(1) ?? '0'} m3';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product?.urunAdi ?? 'Urun Sec',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h2.copyWith(fontSize: 13.sp),
                ),
              ),
              TextButton(
                onPressed: _resetProductSelection,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Urun Degistir',
                  style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              _buildInlineStat('Hedef', targetName),
              _buildInlineStat('Sehir', cityName),
              _buildInlineStat('Kapasite', capacityText),
            ],
          ),
          SizedBox(height: 6.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetWarehouseSelection,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Depo Degistir',
                style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetProductSelection() {
    setState(() {
      _selectedProductId = '';
      _productSearchQuery = '';
    });
  }

  void _resetWarehouseSelection() {
    setState(() {
      _selectedWarehouseId = '';
      _selectedCityId = '';
      _warehouseCityFilter = '';
      _selectedProductId = '';
      _productSearchQuery = '';
      _resetCartState();
    });
  }

  Set<String> _acceptedProductIdsForWarehouse(WarehouseModel? warehouse) {
    final rawAcceptedIds = warehouse?.warehouseType?['accepted_product_ids'];
    if (rawAcceptedIds == null) return const <String>{};
    final cleaned = rawAcceptedIds
        .toString()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('"', '')
        .replaceAll("'", '');

    return cleaned
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Widget _buildInitialSelectionCard(
    List<ProductModel> products,
    List<WarehouseModel> warehouses,
  ) {
    final activeWarehouses = warehouses
        .where((warehouse) => warehouse.isActive && warehouse.warehouseKind != 'store')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectedWarehouse = activeWarehouses
        .where((warehouse) => warehouse.id == _activeWarehouseId)
        .firstOrNull;
    final acceptedProductIds = _acceptedProductIdsForWarehouse(selectedWarehouse);
    final sortedProducts = [...products]
      ..sort((a, b) => a.urunAdi.compareTo(b.urunAdi));
    final warehouseScopedProducts = selectedWarehouse == null
        ? const <ProductModel>[]
        : sortedProducts.where((product) {
            if (acceptedProductIds.isEmpty) return true;
            return acceptedProductIds.contains(product.id.toUpperCase());
          }).toList();
    final filteredProducts = warehouseScopedProducts.where((product) {
      final query = _productSearchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return product.urunAdi.toLowerCase().contains(query);
    }).toList();
    final selectedProduct = sortedProducts
        .where((product) => product.id == _activeProductId)
        .firstOrNull;
    final cityGroups = <String, List<WarehouseModel>>{};
    for (final warehouse in activeWarehouses) {
      final cityName = (warehouse.cityName ?? 'Bilinmeyen Sehir').trim();
      cityGroups.putIfAbsent(cityName, () => []).add(warehouse);
    }
    final sortedCityNames = cityGroups.keys.toList()..sort();
    final visibleCityNames = _warehouseCityFilter.isEmpty
        ? sortedCityNames
        : sortedCityNames.where((cityName) {
            final firstWarehouse = cityGroups[cityName]!.first;
            return firstWarehouse.cityId == _warehouseCityFilter;
          }).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Hedef Depo',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11.sp,
                ),
              ),
              const Spacer(),
              if (selectedWarehouse != null)
                Text(
                  selectedWarehouse.cityName ?? '-',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.gold,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          if (sortedCityNames.isNotEmpty)
            SizedBox(
              height: 38.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sortedCityNames.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final cityName = isAll ? 'Tum Sehirler' : sortedCityNames[index - 1];
                  final cityId = isAll ? '' : cityGroups[cityName]!.first.cityId;
                  final isSelected = _warehouseCityFilter == cityId;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _warehouseCityFilter = cityId;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.gold.withValues(alpha: 0.14)
                            : AppColors.cardBgLight.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.border.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Text(
                        cityName,
                        style: TextStyle(
                          color: isSelected ? AppColors.gold : Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (sortedCityNames.isNotEmpty) SizedBox(height: 10.h),
          if (activeWarehouses.isNotEmpty)
            ...visibleCityNames.expand((cityName) {
              final warehousesInCity = cityGroups[cityName]!
                ..sort((a, b) => a.name.compareTo(b.name));
              return [
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h, top: 2.h),
                  child: Text(
                    cityName,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.gold,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...warehousesInCity.map(
                  (warehouse) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _buildSelectableWarehouseCard(
                      warehouse: warehouse,
                      isSelected: warehouse.id == _activeWarehouseId,
                      onTap: () {
                        setState(() {
                          _selectedWarehouseId = warehouse.id;
                          _selectedCityId = warehouse.cityId;
                          _warehouseCityFilter = warehouse.cityId;
                          _selectedProductId = '';
                          _productSearchQuery = '';
                          _resetCartState();
                        });
                      },
                    ),
                  ),
                ),
              ];
            }),
          if (activeWarehouses.isEmpty) ...[
            SizedBox(height: 12.h),
            _buildInfoBox(
              'Pazara alim yapabilmek icin once aktif bir normal depo gerekli.',
              AppColors.red,
            ),
          ] else if (selectedWarehouse == null) ...[
            SizedBox(height: 10.h),
            _buildInfoBox(
              'Once hedef depoyu sec. Sonra yalnizca bu deponun kabul ettigi urunler listelenecek.',
              AppColors.blue,
            ),
          ] else ...[
            SizedBox(height: 12.h),
            TextField(
              onChanged: (value) {
                setState(() {
                  _productSearchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Urun ara',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardBgLight.withValues(alpha: 0.35),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.7),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Urun',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 11.sp,
              ),
            ),
            SizedBox(height: 6.h),
            if (filteredProducts.isEmpty)
              _buildInfoBox(
                'Bu depo icin uygun urun bulunamadi.',
                AppColors.red,
              )
            else
              SizedBox(
                height: 78.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8.w),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final isSelected = product.id == _activeProductId;
                    return _buildSelectableProductCard(
                      product: product,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedProductId = product.id;
                        });
                      },
                    );
                  },
                ),
              ),
            if (selectedProduct != null) ...[
              SizedBox(height: 10.h),
              _buildSelectedProductSummary(selectedProduct),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSelectableProductCard({
    required ProductModel product,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92.w,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.14)
              : AppColors.cardBgLight.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: CachedAssetImage(fileName: product.urunIconu),
            ),
            SizedBox(height: 6.h),
            Expanded(
              child: Text(
                product.urunAdi,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppColors.gold : Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedProductSummary(ProductModel product) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: CachedAssetImage(fileName: product.urunIconu),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secili Urun',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  product.urunAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${product.bazSatisFiyati.toStringAsFixed(1)} TL',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableWarehouseCard({
    required WarehouseModel warehouse,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final availableCapacity =
        (warehouse.capacity - warehouse.reservedCapacity).clamp(0, double.infinity);
    final capacityColor = availableCapacity <= 0
        ? AppColors.red
        : availableCapacity <= 25
        ? AppColors.gold
        : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blue.withValues(alpha: 0.12)
              : AppColors.cardBgLight.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.warehouse_outlined,
                color: isSelected ? AppColors.blue : AppColors.gold,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warehouse.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${warehouse.cityName ?? 'Bilinmeyen Sehir'} • ${availableCapacity.toStringAsFixed(0)} bos',
                    style: TextStyle(
                      color: capacityColor,
                      fontSize: 10.sp,
                      fontWeight: availableCapacity <= 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.blue, size: 20.sp),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final warehousesAsync = ref.watch(warehouseListProvider);
    final productAsync = _activeProductId.isNotEmpty
        ? ref.watch(marketProductProvider(_activeProductId))
        : const AsyncValue<ProductModel?>.data(null);
    final listingsAsync = _activeProductId.isEmpty
        ? const AsyncValue<List<MarketListingModel>>.data([])
        : _isLockedToCityCatalog
        ? ref.watch(marketCityListingsProvider(_lockedSourceCityId!))
        : ref.watch(marketListingsProvider(_activeProductId));
    final fallbackCityAsync = _activeCityId.isNotEmpty
        ? ref.watch(marketCityProvider(_activeCityId))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final buyerWarehouseAsync = _isStoreTarget
        ? AsyncValue<MarketBuyerWarehouseModel?>.data(null)
        : _activeWarehouseId.isNotEmpty
        ? ref.watch(marketBuyerWarehouseProvider(_activeWarehouseId))
        : const AsyncValue<MarketBuyerWarehouseModel?>.data(null);
    final buyerStoreAsync = _isStoreTarget && widget.storeId.isNotEmpty
        ? ref.watch(storeDetailPageProvider(widget.storeId)).whenData(
            (page) => page.store,
          )
        : const AsyncValue<StoreModel?>.data(null);
    final buyerStoreSlot = _isStoreTarget
        ? _deriveBuyerStoreSlot(
            buyerStoreAsync.value,
            null,
            fallbackCityAsync.value,
          )
        : null;
    final capacityAsync = _isStoreTarget
        ? AsyncValue<WarehouseCapacityStatusModel?>.data(null)
        : _activeWarehouseId.isNotEmpty
        ? ref.watch(warehouseCapacityStatusProvider(_activeWarehouseId))
        : const AsyncValue<WarehouseCapacityStatusModel?>.data(null);
    final previewListings = listingsAsync.value ?? const <MarketListingModel>[];
    final capacityBannerMessage = _buildCapacityBannerMessage(
      product: productAsync.value,
      capacity: capacityAsync.value,
      buyerStoreSlot: buyerStoreSlot,
      listings: previewListings,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _hasCart ? _buildCartLauncherButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 3,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Global Pazar'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshPage,
                color: AppColors.gold,
                backgroundColor: AppColors.cardBg,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        5.w,
                        12.h,
                        5.w,
                        _hasCart ? 92.h : 32.h,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (_requiresInitialSelection) ...[
                            productsAsync.when(
                              data: (products) => warehousesAsync.when(
                                data: (warehouses) =>
                                    _buildInitialSelectionCard(products, warehouses),
                                loading: _buildLoadingCard,
                                error: (e, s) =>
                                    _buildErrorCard('Depo listesi alinamadi.'),
                              ),
                              loading: _buildLoadingCard,
                              error: (e, s) =>
                                  _buildErrorCard('Urun listesi alinamadi.'),
                            ),
                            SizedBox(height: 8.h),
                          ],
                          if (!_requiresInitialSelection) ...[
                            _buildCompactSelectionBar(
                              product: productAsync.value,
                              buyerWarehouse: buyerWarehouseAsync.value,
                              buyerStoreSlot: buyerStoreSlot,
                              capacity: capacityAsync.value,
                            ),
                          ],
                          if (capacityBannerMessage != null) ...[
                            SizedBox(height: 8.h),
                            _buildInfoBox(
                              capacityBannerMessage,
                              capacityBannerMessage.contains('Dikkat')
                                  ? AppColors.gold
                                  : AppColors.red,
                            ),
                          ],
                          if (_lockedSourceCityId != null) ...[
                            SizedBox(height: 8.h),
                            _buildInfoBox(
                              _cityCatalogEnabled
                                  ? 'Sepet sehri kilitlendi: ${_resolveLockedCityName()}. Urun kilidi kalkti; bu sehirdeki tum market ilanlari gosteriliyor.'
                                  : 'Sepet sehri kilitlendi: ${_resolveLockedCityName()}. Alimi tamamlarsaniz mevcut urunle devam eder, alisverise devam ederseniz ayni sehrin tum ilanlari acilir.',
                              AppColors.gold,
                            ),
                          ],
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                      sliver: SliverToBoxAdapter(
                        child: _buildSectionHeader('SATIS NOKTALARI', 'Pazar Listesi'),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      sliver: listingsAsync.when(
                        data: (listings) {
                          final baseListings = _withNpcListing(
                            listings: listings,
                            product: productAsync.value,
                            fallbackCity: fallbackCityAsync.value,
                            buyer: buyerWarehouseAsync.value,
                            buyerStoreSlot: buyerStoreSlot,
                          );
                          final filteredListings = _applyCartCityRules(
                            _filterListingsForTargetSlot(
                              baseListings,
                              buyerStoreSlot,
                            ),
                          );

                          return _buildListingsSliver(
                            listings: filteredListings,
                            buyer: buyerWarehouseAsync.value,
                            buyerStoreSlot: buyerStoreSlot,
                            fallbackCity: fallbackCityAsync.value,
                            product: productAsync.value,
                            showQualityLockNotice:
                                _isStoreTarget &&
                                buyerStoreSlot != null &&
                                (buyerStoreSlot.quantity > 0 ||
                                    buyerStoreSlot.pendingQuantity > 0) &&
                                buyerStoreSlot.qualityLevel > 0,
                          );
                        },
                        loading: () => SliverToBoxAdapter(
                          child: _buildLoadingCard(),
                        ),
                        error: (e, s) => SliverToBoxAdapter(
                          child: _buildErrorCard('Pazar verileri alinamadi.'),
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
    );
  }

  Widget _buildProductHeader(
    ProductModel? product,
    WarehouseCapacityStatusModel? capacity,
    MarketBuyerStoreSlotModel? storeSlot,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
            ),
            child: CachedAssetImage(fileName: product?.urunIconu ?? 'default.webp'),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product?.urunAdi ?? 'Yukleniyor...',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 16.sp,
                          color: AppColors.goldLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    TextButton(
                      onPressed: _resetProductSelection,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Urun Degistir',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.straighten, color: AppColors.gold, size: 12.sp),
                    SizedBox(width: 4.w),
                    Text('${product?.birimHacim.toStringAsFixed(1) ?? '0'} m3', style: AppTextStyles.body.copyWith(fontSize: 10.sp)),
                    SizedBox(width: 12.w),
                    Icon(_isStoreTarget ? Icons.storefront_outlined : Icons.warehouse_outlined, color: AppColors.gold, size: 12.sp),
                    SizedBox(width: 4.w),
                    Text(_isStoreTarget
                          ? 'Slot Bos: ${storeSlot?.availableCapacity.toStringAsFixed(0) ?? '0'}'
                          : 'Bos: ${capacity?.availableCapacity.toStringAsFixed(1) ?? '0'} m3', style: AppTextStyles.body.copyWith(fontSize: 10.sp, color: AppColors.gold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildListingsSliver({
    required List<MarketListingModel> listings,
    required MarketBuyerWarehouseModel? buyer,
    required MarketBuyerStoreSlotModel? buyerStoreSlot,
    required Map<String, dynamic>? fallbackCity,
    required ProductModel? product,
    required bool showQualityLockNotice,
  }) {
    if (listings.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildListDelegate.fixed([
        if (showQualityLockNotice) ...[
          _buildInfoBox(
            'Bu slotta aktif veya yoldaki stok oldugu icin yalnizca ayni kalite ilanlar gosteriliyor.',
            AppColors.gold,
          ),
          SizedBox(height: 10.h),
        ],
        ...listings.map(
          (listing) => _buildListingCard(
            listing,
            buyer,
            buyerStoreSlot,
            fallbackCity,
            product,
          ),
        ),
      ]),
    );
  }

  Widget _buildListingCard(
    MarketListingModel listing,
    MarketBuyerWarehouseModel? buyer,
    MarketBuyerStoreSlotModel? buyerStoreSlot,
    Map<String, dynamic>? fallbackCity,
    ProductModel? product,
  ) {
    final capacityStatus = !_isStoreTarget && _activeWarehouseId.isNotEmpty
        ? ref.read(warehouseCapacityStatusProvider(_activeWarehouseId)).value
        : null;
    final canAddToCart = _canAddListingToCart(
      listing: listing,
      product: product,
      capacity: capacityStatus,
      buyerStoreSlot: buyerStoreSlot,
    );
    final addDisabledReason = canAddToCart
        ? null
        : _listingCapacityWarning(
            listing: listing,
            product: product,
            capacity: capacityStatus,
            buyerStoreSlot: buyerStoreSlot,
          );
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
    final isInstantDelivery =
        _activeCityId.isNotEmpty && _activeCityId == listing.cityId;
    final priceDeltaPercent = _resolvePriceDeltaPercent(product, listing.price);
    final priceDeltaBadge = _buildPriceDeltaBadge(priceDeltaPercent);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5.w,
                decoration: BoxDecoration(color: distanceColor),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42.w,
                                  height: 42.w,
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBgLight,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.borderGold.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Padding(
                                      padding: EdgeInsets.all(5.w),
                                      child: CachedAssetImage(
                                        fileName: listing.sellerAvatarId,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        listing.sellerPlayerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        '${listing.warehouseName} • ${listing.cityName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.body.copyWith(
                                          fontSize: 10.sp,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                Container(
                                  width: 34.w,
                                  height: 34.w,
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBgLight,
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: AppColors.border.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: CachedAssetImage(
                                    fileName: listing.productIcon,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        listing.productName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.goldLight,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Birim Hacim: ${listing.unitVolume.toStringAsFixed(1)} m3',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.body.copyWith(
                                          fontSize: 9.sp,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Wrap(
                              spacing: 10.w,
                              runSpacing: 4.h,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildInlineMetric(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Stok',
                                  value: listing.quantity.toString(),
                                  color: AppColors.blue,
                                ),
                                _buildInlineQualityMetric(
                                  label: 'Kalite',
                                  qualityLevel: listing.qualityLevel,
                                  color: AppColors.gold,
                                ),
                                if (listing.isNpc)
                                  _buildTypeBadge(
                                    'NPC / Kalite 1',
                                    AppColors.blue,
                                  ),
                                _buildTypeBadge(
                                  isInstantDelivery
                                      ? 'Ayni sehir / Aninda'
                                      : 'Sehirler arasi / Arac',
                                  isInstantDelivery
                                      ? AppColors.green
                                      : AppColors.gold,
                                ),
                                if (priceDeltaBadge != null)
                                  _buildTypeBadge(
                                    priceDeltaBadge.$1,
                                    priceDeltaBadge.$2,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppColors.green.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '₺${listing.price.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: distanceColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: distanceColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '${distanceKm.toStringAsFixed(0)} km',
                              style: TextStyle(
                                color: distanceColor,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          SizedBox(
                            height: 28.h,
                            child: ElevatedButton(
                              onPressed: canAddToCart
                                  ? () => _openAddToCartSheet(
                                        listing,
                                        product,
                                        buyerStoreSlot,
                                      )
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              child: Text(
                                'EKLE',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ),
                          ),
                          if (addDisabledReason != null) ...[
                            SizedBox(height: 6.h),
                            SizedBox(
                              width: 110.w,
                              child: Text(
                                'Kapasite yetersiz',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: AppColors.red,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildInlineMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12.sp),
        SizedBox(width: 4.w),
        Text(
          '$label:',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineQualityMetric({
    required String label,
    required int qualityLevel,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.stars, color: color, size: 12.sp),
        SizedBox(width: 4.w),
        Text(
          '$label:',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 4.w),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final filled = index < qualityLevel;
            return Padding(
              padding: EdgeInsets.only(right: 1.w),
              child: Icon(
                filled ? Icons.star : Icons.star_border,
                color: filled ? color : Colors.white24,
                size: 10.sp,
              ),
            );
          }),
        ),
      ],
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



  Widget _buildStatusBadge(bool active) {
    final color = active ? AppColors.green : AppColors.red;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
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

  double _currentTargetAvailableCapacity() {
    if (_isStoreTarget) {
      return 0;
    }
    if (_activeWarehouseId.isEmpty) return 0;
    return ref
            .read(warehouseCapacityStatusProvider(_activeWarehouseId))
            .value
            ?.availableCapacity ??
        0;
  }

  bool get _cartFitsCurrentCapacity =>
      _isStoreTarget || _cartTotalVolume <= _currentTargetAvailableCapacity();

  _MarketCartItem? get _largestCartItemByVolume {
    if (_cartItems.isEmpty) return null;
    _MarketCartItem? largest;
    for (final item in _cartItems) {
      if (largest == null || item.totalVolume > largest.totalVolume) {
        largest = item;
      }
    }
    return largest;
  }

  Widget _buildCartIconsRow() {
    final previewItems = _cartItems.take(4).toList();
    return Row(
      children: [
        ...previewItems.map(
          (item) => Container(
            width: 28.w,
            height: 28.w,
            margin: EdgeInsets.only(right: 6.w),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.25),
              ),
            ),
            child: CachedAssetImage(fileName: item.listing.productIcon),
          ),
        ),
        if (_cartItems.length > previewItems.length)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '+${_cartItems.length - previewItems.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showCartSheet() async {
    if (!_hasCart) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _buildCartSummaryBar(),
    );
  }

  Widget _buildCartLauncherButton() {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: GestureDetector(
        onTap: _showCartSheet,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.borderGold.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, color: AppColors.gold, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Sepet • $_cartTotalQuantity',
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${_cartTotalProductCost.toStringAsFixed(1)} TL',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.gold,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(Icons.expand_less, color: AppColors.textMuted, size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSummaryBar() {
    final currentAvailableCapacity = _currentTargetAvailableCapacity();
    final remainingAfterCart =
        (currentAvailableCapacity - _cartTotalVolume).clamp(-999999, 999999);
    final capacityOk = _cartFitsCurrentCapacity;
    final capacityColor = capacityOk ? AppColors.green : AppColors.red;
    final largestItem = _largestCartItemByVolume;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(
            top: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sepet • $_cartTotalQuantity adet • ${_cartTotalProductCost.toStringAsFixed(1)} TL',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                _buildCartIconsRow(),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Sehir: ${_resolveLockedCityName()} - Hacim: ${_cartTotalVolume.toStringAsFixed(1)} m3',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 10.sp,
              ),
            ),
            if (largestItem != null) ...[
              SizedBox(height: 4.h),
              Text(
                'En cok yer kaplayan: ${largestItem.listing.productName} • ${largestItem.totalVolume.toStringAsFixed(1)} m3',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.gold,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (!_isStoreTarget) ...[
              SizedBox(height: 6.h),
              Text(
                capacityOk
                    ? 'Hedef kapasite uygun • Kalan: ${remainingAfterCart.toStringAsFixed(1)} m3'
                    : 'Kapasite asildi • Eksik: ${(-remainingAfterCart).toStringAsFixed(1)} m3',
                style: AppTextStyles.body.copyWith(
                  color: capacityColor,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            SizedBox(height: 10.h),
            SizedBox(
              height: 56.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _cartItems.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final item = _cartItems[index];
                  return _buildCartItemPill(item);
                },
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cityCatalogEnabled ? null : _enableCityCatalogMode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text('Alisverise Devam Et'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: capacityOk ? _openCartCheckout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Alimi Tamamla'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemPill(_MarketCartItem item) {
    return Container(
      width: 190.w,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: CachedAssetImage(fileName: item.listing.productIcon),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.listing.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${item.quantity} adet • ${item.totalVolume.toStringAsFixed(1)} m3',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeCartItem(item),
            child: Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(
                Icons.close,
                size: 13.sp,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCartCheckout() async {
    if (_cartItems.isEmpty || _lockedSourceCityId == null) return;
    if (!_cartFitsCurrentCapacity) {
      AppSnackbar.show(
        context,
        title: 'Kapasite Yetersiz',
        message:
            'Sepet hacmi hedef depo kapasitesini asiyor. Sepeti kucultmeden alim tamamlanamaz.',
        type: SnackbarType.warning,
      );
      return;
    }
    if (_isStoreTarget) {
      AppSnackbar.show(
        context,
        title: 'Gecici Kapali',
        message:
            'Magaza slotuna dogrudan market alimi kapatildi. Yeni akista alimlar magaza deposuna yapilacak.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (_lockedSourceCityId == _activeCityId) {
      await _submitMultiMarketTransfer();
      return;
    }

    await _showIntercityMarketVehiclePicker();
  }

  Future<void> _showIntercityMarketVehiclePicker() async {
    final cities = await ref.read(activeCitiesProvider.future);
    final sourceCity = _findCityById(cities, _lockedSourceCityId!);
    final targetCity = _findCityById(cities, _activeCityId);

    if (sourceCity == null || targetCity == null) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Sehir Verisi Eksik',
        message: 'Arac secimi icin sehir bilgileri okunamadi.',
        type: SnackbarType.error,
      );
      return;
    }

    final TransferVehicleOptionsResult<MarketTransferVehicleOptionModel> vehicleResult;
    try {
      vehicleResult = await ref.read(marketActionProvider).getIntercityVehicleOptions(
            sourceCityId: _lockedSourceCityId!,
            targetCityId: _activeCityId,
            totalVolume: _cartTotalVolume,
          );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Arac Secim Hatasi',
        message: 'Arac secenekleri alinamadi: ${e.toString()}',
        type: SnackbarType.error,
      );
      return;
    }
    final options = vehicleResult.options;

    if (options.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Arac Yok',
        message:
            vehicleResult.unavailableReason ??
            'Sehirler arasi alim icin uygun arac bulunamadi.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arac Secin',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '${sourceCity.name} -> ${targetCity.name} | ${_cartTotalVolume.toStringAsFixed(1)} m3',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  return TransferVehicleOptionCard(
                    vehicleName: option.vehicleName,
                    isRental: option.isRental,
                    capacity: option.capacity,
                    distanceKm: option.distanceKm,
                    durationLabel: _formatTransferDuration(
                      option.estimatedDurationSeconds,
                    ),
                    transportCost: option.transportCost,
                    rentalCost: option.rentalCost,
                    fuelCost: option.fuelCost,
                    fuelNeeded: option.fuelNeeded,
                    conditionNeeded: option.conditionNeeded,
                    canSelect: option.canSelect,
                    isSelected: false,
                    disabledReason: option.disabledReason,
                    onTap: option.canSelect
                        ? () async {
                            Navigator.of(sheetContext).pop();
                            await _submitMultiMarketTransfer(
                              vehicleId: option.vehicleId,
                            );
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitMultiMarketTransfer({String? vehicleId}) async {
    final items = _cartItems
        .map(
          (item) => {
            'source_kind': item.listing.isNpc ? 'npc_market' : 'warehouse_slot',
            'seller_slot_id': item.listing.isNpc ? null : item.listing.slotId,
            'city_id': item.listing.cityId,
            'product_id': item.listing.productId,
            'quality_level': item.listing.qualityLevel,
            'brand_id': item.listing.brandId,
            'quantity': item.quantity,
            'unit_price': item.listing.price,
            'unit_cost': item.listing.cost,
            'unit_volume': item.listing.unitVolume,
          },
        )
        .toList();

    final result = await ref.read(marketActionProvider).startMultiMarketTransfer(
          buyerWarehouseId: _activeWarehouseId,
          sourceCityId: _lockedSourceCityId!,
          items: items,
          vehicleId: vehicleId,
        );

    if (!mounted) return;

    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Transfer baslatilamadi.',
        type: SnackbarType.error,
      );
      return;
    }

    final isInstant = result['mode']?.toString() == 'instant';
    if (isInstant && result['transfer_id'] != null) {
      final completeResult = await ref
          .read(warehouseActionProvider)
          .completeLogisticsTransfer(result['transfer_id'].toString());
      if (completeResult['success'] != true) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          title: 'Hata',
          message:
              completeResult['message']?.toString() ??
              'Anlik market transferi tamamlanamadi.',
          type: SnackbarType.error,
        );
        return;
      }
    }

    await _refreshAfterPurchase(isInstant: isInstant);
    _clearCart();

    if (!mounted) return;
    AppSnackbar.show(
      context,
      title: 'Basarili',
      message: isInstant
          ? 'Market alimi aninda tamamlandi.'
          : 'Coklu market transferi baslatildi. Arac yola cikti.',
      type: SnackbarType.success,
    );
  }

  CityModel? _findCityById(List<CityModel> cities, String cityId) {
    for (final city in cities) {
      if (city.id == cityId) return city;
    }
    return null;
  }

  int _calculateDurationSeconds({
    required double distanceKm,
    required int speedKmh,
  }) {
    if (speedKmh <= 0) return 60;
    return math.max(60, ((math.max(distanceKm, 1) / speedKmh) * 3600).ceil());
  }

  int _calculateConditionLoss(double distanceKm) {
    return math.max(1, (distanceKm / 25.0).ceil());
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  String _formatTransferDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }
}

class _PurchaseSheet extends ConsumerStatefulWidget {
  final MarketListingModel listing;
  final String? buyerWarehouseId;
  final String? buyerStoreSlotId;
  final MarketBuyerStoreSlotModel? buyerStoreSlot;
  final String targetCityId;
  final ProductModel product;
  final BuildContext parentContext;
  final Future<void> Function({required bool isInstant}) onSuccess;
  final Future<void> Function() onPreparedSlotRollback;

  const _PurchaseSheet({
    required this.listing,
    required this.buyerWarehouseId,
    required this.buyerStoreSlotId,
    required this.buyerStoreSlot,
    required this.targetCityId,
    required this.product,
    required this.parentContext,
    required this.onSuccess,
    required this.onPreparedSlotRollback,
  });

  @override
  ConsumerState<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _MarketCartSelection {
  final MarketListingModel listing;
  final int quantity;

  const _MarketCartSelection({
    required this.listing,
    required this.quantity,
  });
}

class _MarketCartItem {
  final MarketListingModel listing;
  final int quantity;

  const _MarketCartItem({
    required this.listing,
    required this.quantity,
  });

  String get key => listing.slotId;
  double get totalProductPrice => quantity * listing.price;
  double get totalVolume => quantity * listing.unitVolume;

  _MarketCartItem copyWith({int? quantity}) {
    return _MarketCartItem(
      listing: listing,
      quantity: quantity ?? this.quantity,
    );
  }
}

class _AddToCartSheet extends ConsumerStatefulWidget {
  final MarketListingModel listing;
  final ProductModel product;
  final String? buyerWarehouseId;
  final MarketBuyerStoreSlotModel? buyerStoreSlot;

  const _AddToCartSheet({
    required this.listing,
    required this.product,
    required this.buyerWarehouseId,
    required this.buyerStoreSlot,
  });

  @override
  ConsumerState<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends ConsumerState<_AddToCartSheet> {
  late final TextEditingController _quantityController;
  int _quantity = 1;

  bool get _isStoreTarget => widget.buyerStoreSlot != null;

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

  int _computeMaxQuantity({
    required double playerCash,
    required double reservedCash,
    required double reservedVolume,
    WarehouseCapacityStatusModel? warehouseCapacity,
  }) {
    final byStock = widget.listing.quantity;
    final remainingCash = math.max(playerCash - reservedCash, 0);
    final byCash = widget.listing.price <= 0
        ? byStock
        : (remainingCash / widget.listing.price).floor();

    int byCapacity = byStock;
    if (_isStoreTarget) {
      final free = math.max(
        (widget.buyerStoreSlot?.availableCapacity ?? 0) - reservedVolume,
        0,
      );
      byCapacity = widget.listing.unitVolume <= 0
          ? byStock
          : (free / widget.listing.unitVolume).floor();
    } else if (warehouseCapacity != null) {
      final free = math.max(
        warehouseCapacity.availableCapacity - reservedVolume,
        0,
      );
      byCapacity = widget.listing.unitVolume <= 0
          ? byStock
          : (free / widget.listing.unitVolume).floor();
    }

    return [byStock, byCash, byCapacity].reduce((a, b) => a < b ? a : b).clamp(
          0,
          byStock,
        );
  }

  void _updateQuantity(int maxQuantity, String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _quantity = 0;
      });
      return;
    }

    final parsed = int.tryParse(value) ?? 0;
    final safe = maxQuantity <= 0 ? 0 : parsed.clamp(1, maxQuantity);
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouseCapacityAsync = !_isStoreTarget && widget.buyerWarehouseId != null
        ? ref.watch(warehouseCapacityStatusProvider(widget.buyerWarehouseId!))
        : const AsyncValue<WarehouseCapacityStatusModel?>.data(null);
    final player = ref.watch(playerProvider).value;
    final inheritedState = context.findAncestorStateOfType<_MarketScreenState>();
    final reservedCash = inheritedState?._cartTotalProductCost ?? 0;
    final reservedVolume = inheritedState?._cartTotalVolume ?? 0;
    final maxQuantity = _computeMaxQuantity(
      playerCash: player?.cash.toDouble() ?? 0,
      reservedCash: reservedCash,
      reservedVolume: reservedVolume,
      warehouseCapacity: warehouseCapacityAsync.value,
    );
    final totalPrice = _quantity * widget.listing.price;

    if (_quantity > maxQuantity && maxQuantity >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateQuantity(maxQuantity, maxQuantity.toString());
      });
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          14.w,
          14.h,
          14.w,
          MediaQuery.of(context).viewInsets.bottom + 14.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sepete Ekle',
                      style: AppTextStyles.h1.copyWith(fontSize: 20.sp),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                '${widget.listing.sellerPlayerName} oyuncusundan ${widget.listing.productName} sececeksiniz.',
                style: AppTextStyles.body,
              ),
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 6.h,
                  children: [
                    Text(
                      'Sehir: ${widget.listing.cityName}',
                      style: AppTextStyles.body.copyWith(fontSize: 10.sp),
                    ),
                    Text(
                      'Fiyat: ${widget.listing.price.toStringAsFixed(1)}',
                      style: AppTextStyles.body.copyWith(fontSize: 10.sp),
                    ),
                    Text(
                      'Kalite: Lv.${widget.listing.qualityLevel}',
                      style: AppTextStyles.body.copyWith(fontSize: 10.sp),
                    ),
                    Text(
                      'Maksimum: $maxQuantity',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 10.sp,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: _quantityController,
                readOnly: true,
                showCursor: true,
                enableInteractiveSelection: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Miktar',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  helperText: maxQuantity > 0
                      ? '1 - $maxQuantity adet arasi girebilirsiniz'
                      : 'Yeterli nakit veya kapasite yok',
                  helperStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                  ),
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
              SizedBox(height: 10.h),
              NumericKeyboard(
                controller: _quantityController,
                onChanged: (value) => _updateQuantity(maxQuantity, value),
                shortcuts: [
                  NumericKeyboardShortcut(
                    label: '1/4',
                    value: maxQuantity <= 0
                        ? '0'
                        : (maxQuantity / 4).floor().clamp(1, maxQuantity).toString(),
                  ),
                  NumericKeyboardShortcut(
                    label: 'Yari',
                    value: maxQuantity <= 0
                        ? '0'
                        : (maxQuantity / 2).floor().clamp(1, maxQuantity).toString(),
                  ),
                  NumericKeyboardShortcut(
                    label: 'Tamami',
                    value: maxQuantity.toString(),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Urun Bedeli', style: AppTextStyles.body),
                        Text(
                          totalPrice.toStringAsFixed(1),
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 42.h,
                child: ElevatedButton(
                  onPressed: _quantity <= 0
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            _MarketCartSelection(
                              listing: widget.listing,
                              quantity: _quantity,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'SEPETE EKLE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseSheetState extends ConsumerState<_PurchaseSheet> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          14.w,
          14.h,
          14.w,
          MediaQuery.of(context).viewInsets.bottom + 14.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tekli Alim Kapali',
                    style: AppTextStyles.h1.copyWith(fontSize: 20.sp),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Eski tekli market satin alma akisi devre disi birakildi. Yeni sistemde alimlar coklu sepet akisi uzerinden ilerliyor.',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
  Widget _buildCartSummaryBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(
            top: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sepet: ${_cartItems.length} kalem • $_cartTotalQuantity adet • ₺${_cartTotalProductCost.toStringAsFixed(1)}',
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Sehir: ${_resolveLockedCityName()} • Hacim: ${_cartTotalVolume.toStringAsFixed(1)} m3',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 10.sp,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cityCatalogEnabled ? null : _enableCityCatalogMode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text('Alisverise Devam Et'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openCartCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Alimi Tamamla'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCartCheckout() async {
    if (_cartItems.isEmpty || _lockedSourceCityId == null) return;
    if (_isStoreTarget) {
      AppSnackbar.show(
        context,
        title: 'Gecici Kapali',
        message:
            'Magaza slotuna dogrudan market alimi kapatildi. Yeni akista alimlar magaza deposuna yapilacak.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (_lockedSourceCityId == _activeCityId) {
      await _submitMultiMarketTransfer();
      return;
    }

    await _showIntercityMarketVehiclePicker();
  }

  Future<void> _showIntercityMarketVehiclePicker() async {
    List<LogisticsVehicleModel> vehicles = const [];
    try {
      vehicles = await ref.read(logisticsVehicleListProvider.future);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Araclar Alinamadi',
        message: e.toString(),
        type: SnackbarType.error,
      );
      return;
    }

    final cities = await ref.read(activeCitiesProvider.future);
    final sourceCity = _findCityById(cities, _lockedSourceCityId!);
    final targetCity = _findCityById(cities, _activeCityId);

    if (sourceCity == null || targetCity == null) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Sehir Verisi Eksik',
        message: 'Arac secimi icin sehir bilgileri okunamadi.',
        type: SnackbarType.error,
      );
      return;
    }

    final distanceKm = _calculateDistanceKm(
      sourceCity.mapPositionX,
      sourceCity.mapPositionY,
      targetCity.mapPositionX,
      targetCity.mapPositionY,
    );

    final options = vehicles
        .where((vehicle) => vehicle.status == 'idle')
        .map((vehicle) {
          final fuelNeeded = _round2(distanceKm * vehicle.fuelRate);
          final conditionNeeded = _calculateConditionLoss(distanceKm);
          final transportCost = _round2(fuelNeeded * vehicle.fuelCost);
          final durationSeconds = _calculateDurationSeconds(
            distanceKm: distanceKm,
            speedKmh: vehicle.speedKmh,
          );
          final canSelect =
              vehicle.capacity >= _cartTotalVolume.ceil() &&
              vehicle.speedKmh > 0 &&
              vehicle.currentFuel >= fuelNeeded.ceil() &&
              vehicle.condition > 0;

          String? disabledReason;
          if (vehicle.capacity < _cartTotalVolume.ceil()) {
            disabledReason = 'Kapasite yetersiz';
          } else if (vehicle.speedKmh <= 0) {
            disabledReason = 'Arac hizi gecersiz';
          } else if (vehicle.currentFuel < fuelNeeded.ceil()) {
            disabledReason = 'Yeterli yakit yok';
          } else if (vehicle.condition <= 0) {
            disabledReason = 'Bakim gerekli';
          }

          return MarketTransferVehicleOptionModel(
            vehicleId: vehicle.id,
            vehicleOwnerPlayerId: vehicle.playerId,
            vehicleName:
                'Arac ${vehicle.logisticsVehicleTypeId.length <= 4 ? vehicle.logisticsVehicleTypeId : vehicle.logisticsVehicleTypeId.substring(0, 4)}',
            isRental: false,
            capacity: vehicle.capacity,
            speedKmh: vehicle.speedKmh,
            currentFuel: vehicle.currentFuel,
            fuelCapacity: vehicle.fuelCapacity,
            fuelRate: vehicle.fuelRate,
            condition: vehicle.condition,
            rentalPrice: 0,
            distanceKm: distanceKm,
            fuelNeeded: fuelNeeded,
            conditionNeeded: conditionNeeded.toDouble(),
            rentalCost: 0,
            fuelCost: transportCost,
            transportCost: transportCost,
            estimatedDurationSeconds: durationSeconds,
            canSelect: canSelect,
            disabledReason: disabledReason,
          );
        })
        .toList();

    if (options.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Arac Yok',
        message: 'Sehirler arasi alim icin idle arac bulunamadi.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arac Secin',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '${sourceCity.name} -> ${targetCity.name} | ${_cartTotalVolume.toStringAsFixed(1)} m3',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  return TransferVehicleOptionCard(
                    vehicleName: option.vehicleName,
                    isRental: option.isRental,
                    capacity: option.capacity,
                    distanceKm: option.distanceKm,
                    durationLabel: _formatTransferDuration(
                      option.estimatedDurationSeconds,
                    ),
                    transportCost: option.transportCost,
                    rentalCost: option.rentalCost,
                    fuelCost: option.fuelCost,
                    fuelNeeded: option.fuelNeeded,
                    conditionNeeded: option.conditionNeeded,
                    canSelect: option.canSelect,
                    isSelected: false,
                    disabledReason: option.disabledReason,
                    onTap: option.canSelect
                        ? () async {
                            Navigator.of(sheetContext).pop();
                            await _submitMultiMarketTransfer(
                              vehicleId: option.vehicleId,
                            );
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitMultiMarketTransfer({String? vehicleId}) async {
    final items = _cartItems
        .map(
          (item) => {
            'seller_slot_id': item.listing.slotId,
            'quantity': item.quantity,
          },
        )
        .toList();

    final result = await ref.read(marketActionProvider).startMultiMarketTransfer(
          buyerWarehouseId: _activeWarehouseId,
          sourceCityId: _lockedSourceCityId!,
          items: items,
          vehicleId: vehicleId,
        );

    if (!mounted) return;

    if (result['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Transfer baslatilamadi.',
        type: SnackbarType.error,
      );
      return;
    }

    final isInstant = result['mode']?.toString() == 'instant';
    if (isInstant && result['transfer_id'] != null) {
      final completeResult = await ref
          .read(warehouseActionProvider)
          .completeLogisticsTransfer(result['transfer_id'].toString());
      if (completeResult['success'] != true) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          title: 'Hata',
          message:
              completeResult['message']?.toString() ??
              'Anlik market transferi tamamlanamadi.',
          type: SnackbarType.error,
        );
        return;
      }
    }

    await _refreshAfterPurchase(isInstant: isInstant);
    _clearCart();

    if (!mounted) return;
    AppSnackbar.show(
      context,
      title: 'Basarili',
      message: isInstant
          ? 'Market alimi aninda tamamlandi.'
          : 'Coklu market transferi baslatildi. Arac yola cikti.',
      type: SnackbarType.success,
    );
  }

  CityModel? _findCityById(List<CityModel> cities, String cityId) {
    for (final city in cities) {
      if (city.id == cityId) return city;
    }
    return null;
  }

  int _calculateDurationSeconds({
    required double distanceKm,
    required int speedKmh,
  }) {
    if (speedKmh <= 0) return 60;
    return math.max(60, ((math.max(distanceKm, 1) / speedKmh) * 3600).ceil());
  }

  int _calculateConditionLoss(double distanceKm) {
    return math.max(1, (distanceKm / 25.0).ceil());
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  String _formatTransferDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }
  */

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

double _resolvePriceDeltaPercent(ProductModel? product, double listingPrice) {
  final averagePrice = product?.ortalamaFiyat ?? 0;
  if (averagePrice <= 0) return 0;
  return ((listingPrice - averagePrice) / averagePrice) * 100;
}

(String, Color)? _buildPriceDeltaBadge(double deltaPercent) {
  if (deltaPercent <= -8) {
    return ('Ort. alti', AppColors.green);
  }
  if (deltaPercent >= 8) {
    return ('Ort. ustu', AppColors.red);
  }
  return ('Ort. yakin', AppColors.gold);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _MarketCartListExtension on List<_MarketCartItem> {
  void addOrMerge(MarketListingModel listing, int quantity) {
    final index = indexWhere((item) => item.key == listing.slotId);
    if (index == -1) {
      add(_MarketCartItem(listing: listing, quantity: quantity));
      return;
    }

    final current = this[index];
    this[index] = current.copyWith(quantity: current.quantity + quantity);
  }
}

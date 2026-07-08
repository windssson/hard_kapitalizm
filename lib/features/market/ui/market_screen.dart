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
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

class MarketScreen extends ConsumerStatefulWidget {
  final String productId;
  final String warehouseId;
  final String playerId;
  final String cityId;

  const MarketScreen({
    super.key,
    this.productId = '',
    this.warehouseId = '',
    this.playerId = '',
    this.cityId = '',
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
      _activeProductId.isEmpty ||
      _activeWarehouseId.isEmpty ||
      _activeCityId.isEmpty;

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

    if (_activeWarehouseId.isNotEmpty) {
      ref.invalidate(marketBuyerWarehouseProvider(_activeWarehouseId));
      ref.invalidate(warehouseCapacityStatusProvider(_activeWarehouseId));
      ref.invalidate(warehouseDetailProvider(_activeWarehouseId));
    }
  }

  Future<void> _refreshAfterPurchase({required bool isInstant}) async {
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
    if (_activeWarehouseId.isNotEmpty) {
      ref.invalidate(marketBuyerWarehouseProvider(_activeWarehouseId));
      ref.invalidate(warehouseCapacityStatusProvider(_activeWarehouseId));
    }
    ref.invalidate(warehouseListProvider);
    if (_activeWarehouseId.isNotEmpty) {
      ref.invalidate(warehouseDetailProvider(_activeWarehouseId));
    }
  }

  Future<void> _openAddToCartSheet(
    MarketListingModel listing,
    ProductModel? product,
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

    final capacityStatus = _activeWarehouseId.isNotEmpty
        ? ref.read(warehouseCapacityStatusProvider(_activeWarehouseId)).value
        : null;
    if (!_canAddListingToCart(
      listing: listing,
      product: product,
      capacity: capacityStatus,
    )) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Kapasite Yetersiz',
        message: _listingCapacityWarning(
          listing: listing,
          product: product,
          capacity: capacityStatus,
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
            buyerWarehouseId: _activeWarehouseId,
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

  List<MarketListingModel> _applyCartCityRules(
    List<MarketListingModel> listings,
  ) {
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

  Widget _buildLojistikKilitBanner() {
    if (_lockedSourceCityId == null) return const SizedBox.shrink();

    final cityName = _resolveLockedCityName();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppColors.blue.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: AppColors.blue, size: 12.sp),
          SizedBox(width: 6.w),
          Text(
            'Lojistik Rotası:',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            cityName,
            style: TextStyle(
              color: AppColors.blue,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: _showLojistikBilgiDialog,
            child: Icon(
              Icons.help_outline,
              color: AppColors.blue,
              size: 13.sp,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearCart,
            child: Text(
              'Sıfırla',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLojistikBilgiDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping, color: AppColors.blue, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Lojistik Taşıma Kuralları',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'Sepete ilk eklediğiniz ürünün bulunduğu şehir çıkış noktası olarak kilitlenir. '
                'Tek bir transfer seferinde lojistik araçları sadece aynı şehirden kalkan ürünleri birleştirebilir. '
                'Farklı bir şehirden ürün eklemek istiyorsanız sepeti sıfırlamanız gerekir.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.sp,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 14.h),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Anladım',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
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

  List<MarketListingModel> _withNpcListing({
    required List<MarketListingModel> listings,
    required ProductModel? product,
    required Map<String, dynamic>? fallbackCity,
    required MarketBuyerWarehouseModel? buyer,
  }) {
    if (product == null || product.bazSatisFiyati <= 0) return listings;
    if (listings.any(
      (listing) => listing.isNpc && listing.productId == product.id,
    )) {
      return listings;
    }

    final lockedCityListing = _lockedSourceCityId == null
        ? null
        : listings
              .where((listing) => listing.cityId == _lockedSourceCityId)
              .firstOrNull;

    final cityId = (_lockedSourceCityId ?? buyer?.cityId ?? _activeCityId)
        .toString();
    if (cityId.isEmpty) return listings;

    final cityName =
        (lockedCityListing?.cityName ??
                buyer?.cityName ??
                fallbackCity?['name'] ??
                'Pazar')
            .toString();
    final cityX = _resolveCoordinate(
      lockedCityListing?.cityX ?? buyer?.cityX,
      fallbackCity?['map_position_x'],
    );
    final cityY = _resolveCoordinate(
      lockedCityListing?.cityY ?? buyer?.cityY,
      fallbackCity?['map_position_y'],
    );

    return [
      ...listings,
      MarketListingModel.npc(
        productId: product.id,
        productName: product.urunAdi,
        productIcon: product.urunIconu,
        unitVolume: product.birimHacim,
        price: product.bazSatisFiyati * 1.02,
        cityId: cityId,
        cityName: cityName,
        cityX: cityX,
        cityY: cityY,
      ),
    ];
  }

  bool _canAddListingToCart({
    required MarketListingModel listing,
    required ProductModel? product,
    required WarehouseCapacityStatusModel? capacity,
  }) {
    final unitVolume = listing.unitVolume > 0
        ? listing.unitVolume
        : (product?.birimHacim ?? 0);
    if (unitVolume <= 0) return false;
    return (capacity?.availableCapacity ?? 0) >= unitVolume;
  }

  String? _buildCapacityBannerMessage({
    required ProductModel? product,
    required WarehouseCapacityStatusModel? capacity,
    required List<MarketListingModel> listings,
  }) {
    if (_requiresInitialSelection) return null;

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
  }) {
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

  Widget _buildUnifiedSelectionCard({
    required ProductModel? product,
    required List<ProductModel> products,
    required Set<String> sellingProductIds,
    required Map<String, int> productNeedById,
    required Set<String> activeProductionIngredients,
    required Map<String, int> productionNeedById,
    required MarketBuyerWarehouseModel? buyerWarehouse,
    required WarehouseCapacityStatusModel? capacity,
  }) {
    final String targetName = buyerWarehouse?.warehouseName ?? 'Merkez Depo';
    final String cityName = buyerWarehouse?.cityName ?? 'Şehir';

    final double totalCap = capacity?.totalCapacity ?? 0.0;
    final double usedCap = capacity?.usedCapacity ?? 0.0;
    final double cartVolume = _cartTotalVolume;

    final String capacityLabel = cartVolume > 0
        ? '${usedCap.toStringAsFixed(1)} + ${cartVolume.toStringAsFixed(1)} / ${totalCap.toStringAsFixed(0)} m³'
        : '${usedCap.toStringAsFixed(1)} / ${totalCap.toStringAsFixed(0)} m³';

    final needCount = product != null ? (productNeedById[product.id] ?? 0) : 0;
    final prodNeedCount = product != null ? (productionNeedById[product.id] ?? 0) : 0;
    final isProductionInput = product != null ? activeProductionIngredients.contains(product.id) : false;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Sol Kısım: Depo Seçimi
              Expanded(
                child: GestureDetector(
                  onTap: _resetWarehouseSelection,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(Icons.warehouse_outlined, color: AppColors.gold, size: 16.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                Text(
                                  cityName,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(Icons.swap_horiz, size: 10.sp, color: AppColors.gold),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Dikey Bölücü
              Container(
                height: 32.h,
                width: 1.w,
                color: AppColors.borderGold.withValues(alpha: 0.15),
                margin: EdgeInsets.symmetric(horizontal: 10.w),
              ),
              // Sağ Kısım: Ürün Seçimi
              Expanded(
                child: product == null
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () => _openProductSelectionSheet(
                          products: products,
                          sellingProductIds: sellingProductIds,
                          productNeedById: productNeedById,
                          activeProductionIngredients: activeProductionIngredients,
                          productionNeedById: productionNeedById,
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Container(
                              width: 26.w,
                              height: 26.w,
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: CachedAssetImage(fileName: product.urunIconu),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.urunAdi,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.goldLight,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          needCount > 0
                                              ? 'İhtiyaç: $needCount'
                                              : (prodNeedCount > 0
                                                  ? 'İhtiyaç: $prodNeedCount (Üretim)'
                                                  : (isProductionInput ? 'Üretim' : 'Değiştir')),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: needCount > 0
                                                ? AppColors.gold
                                                : (prodNeedCount > 0 || isProductionInput
                                                    ? AppColors.blue
                                                    : AppColors.textMuted),
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      Icon(Icons.swap_horiz, size: 10.sp, color: AppColors.gold),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Kapasite Bilgisi & İlerleme Çubuğu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kapasite Doluluğu',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                capacityLabel,
                style: TextStyle(
                  color: cartVolume > 0 ? AppColors.goldLight : Colors.white70,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          _buildCapacityProgressBar(total: totalCap, used: usedCap, cart: cartVolume),
        ],
      ),
    );
  }

  Widget _buildCapacityProgressBar({
    required double total,
    required double used,
    required double cart,
  }) {
    if (total <= 0) return const SizedBox.shrink();

    final double usedProgress = (used / total).clamp(0.0, 1.0);
    final double cartProgress = (cart / total).clamp(0.0, 1.0 - usedProgress);
    final double remainingProgress = (1.0 - usedProgress - cartProgress).clamp(0.0, 1.0);

    return Container(
      height: 6.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.r),
        child: Row(
          children: [
            if (usedProgress > 0)
              Expanded(
                flex: (usedProgress * 1000).toInt(),
                child: Container(
                  color: AppColors.blue,
                ),
              ),
            if (cartProgress > 0)
              Expanded(
                flex: (cartProgress * 1000).toInt(),
                child: Container(
                  color: AppColors.gold,
                ),
              ),
            if (remainingProgress > 0)
              Spacer(
                flex: (remainingProgress * 1000).toInt(),
              ),
          ],
        ),
      ),
    );
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

  List<ProductModel> _productsForActiveWarehouse(
    List<ProductModel> products,
    List<WarehouseModel> warehouses,
  ) {
    final selectedWarehouse = warehouses
        .where((warehouse) => warehouse.id == _activeWarehouseId)
        .firstOrNull;
    final acceptedProductIds = _acceptedProductIdsForWarehouse(
      selectedWarehouse,
    );
    final scopedProducts = acceptedProductIds.isEmpty
        ? products.toList()
        : products
              .where(
                (product) =>
                    acceptedProductIds.contains(product.id.toUpperCase()),
              )
              .toList();

    scopedProducts.sort((a, b) => a.urunAdi.compareTo(b.urunAdi));
    return scopedProducts;
  }



  void _openProductSelectionSheet({
    required List<ProductModel> products,
    required Set<String> sellingProductIds,
    required Map<String, int> productNeedById,
    required Set<String> activeProductionIngredients,
    required Map<String, int> productionNeedById,
  }) {
    final sortedProductsList = [...products];
    sortedProductsList.sort((a, b) {
      final aSelling = sellingProductIds.contains(a.id);
      final bSelling = sellingProductIds.contains(b.id);
      final aProd = activeProductionIngredients.contains(a.id);
      final bProd = activeProductionIngredients.contains(b.id);

      final aPriority = (aSelling || aProd) ? 1 : 0;
      final bPriority = (bSelling || bProd) ? 1 : 0;

      if (aPriority != bPriority) {
        return bPriority.compareTo(aPriority);
      }
      return a.urunAdi.compareTo(b.urunAdi);
    });

    final options = sortedProductsList.map((product) {
      final isSelling = sellingProductIds.contains(product.id);
      final needCount = productNeedById[product.id] ?? 0;
      final prodNeedCount = productionNeedById[product.id] ?? 0;
      final isProductionInput = activeProductionIngredients.contains(product.id);
      
      String? badge;
      if (isSelling) {
        if (needCount > 0) {
          badge = 'Satışta (İhtiyaç: $needCount)';
        } else {
          badge = 'Satışta';
        }
      } else if (needCount > 0) {
        badge = 'İhtiyaç: $needCount';
      }

      if (prodNeedCount > 0) {
        if (badge != null) {
          badge = '$badge • İhtiyaç: $prodNeedCount (Üretim)';
        } else {
          badge = 'İhtiyaç: $prodNeedCount (Üretim)';
        }
      } else if (isProductionInput) {
        if (badge != null) {
          badge = '$badge • Üretim';
        } else {
          badge = 'Üretim';
        }
      }

      return ProductSelectionOption(
        id: product.id,
        title: product.urunAdi,
        subtitle: '${product.bazSatisFiyati.toStringAsFixed(0)} TL Baz Fiyat',
        iconPath: product.urunIconu,
        badgeText: badge,
        onTap: () {
          Navigator.pop(context);
          setState(() {
            _selectedProductId = product.id;
          });
        },
      );
    }).toList();

    ProductSelectionSheet.show(
      context: context,
      title: 'Ürün Seçin',
      options: options,
    );
  }

  Widget _buildInitialSelectionCard(
    List<ProductModel> products,
    List<WarehouseModel> warehouses,
    List<StoreModel> stores,
    Map<String, int> productionNeedById,
    Set<String> activeProductionIngredients,
  ) {
    final activeWarehouses =
        warehouses.where((warehouse) => warehouse.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final selectedWarehouse = activeWarehouses
        .where((warehouse) => warehouse.id == _activeWarehouseId)
        .firstOrNull;
    final selectedStore = _storeForWarehouse(
      stores: stores,
      warehouse: selectedWarehouse,
    );
    final sellingProductIds = _sellingProductIdsForStore(selectedStore);
    final productNeedById = _neededCapacityByProductForStore(selectedStore);

    final acceptedProductIds = _acceptedProductIdsForWarehouse(
      selectedWarehouse,
    );
    final sortedProducts = [...products]
      ..sort((a, b) => a.urunAdi.compareTo(b.urunAdi));
    final warehouseScopedProducts = selectedWarehouse == null
        ? const <ProductModel>[]
        : sortedProducts.where((product) {
            if (acceptedProductIds.isEmpty) return true;
            return acceptedProductIds.contains(product.id.toUpperCase());
          }).toList();

    if (selectedWarehouse != null) {
      warehouseScopedProducts.sort((a, b) {
        final aSelling = sellingProductIds.contains(a.id);
        final bSelling = sellingProductIds.contains(b.id);
        final aProd = activeProductionIngredients.contains(a.id);
        final bProd = activeProductionIngredients.contains(b.id);

        final aPriority = (aSelling || aProd) ? 1 : 0;
        final bPriority = (bSelling || bProd) ? 1 : 0;

        if (aPriority != bPriority) {
          return bPriority.compareTo(aPriority);
        }
        return a.urunAdi.compareTo(b.urunAdi);
      });
    }
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
      final cityName = (warehouse.cityName ?? 'Bilinmeyen Şehir').trim();
      cityGroups.putIfAbsent(cityName, () => []).add(warehouse);
    }
    final sortedCityNames = cityGroups.keys.toList()..sort();
    final visibleCityNames = _warehouseCityFilter.isEmpty
        ? sortedCityNames
        : sortedCityNames.where((cityName) {
            final firstWarehouse = cityGroups[cityName]!.first;
            return firstWarehouse.cityId == _warehouseCityFilter;
          }).toList();

    // Step 1: Warehouse Selection Mode
    if (selectedWarehouse == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: AppDecorations.premiumCard(
          AppColors.borderGold.withValues(alpha: 0.25),
          20.r,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warehouse, color: AppColors.gold, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'Hedef Depo Seçin',
                  style: AppTextStyles.h2.copyWith(fontSize: 14.sp),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (sortedCityNames.isNotEmpty)
              SizedBox(
                height: 38.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sortedCityNames.length + 1,
                  separatorBuilder: (context, index) => SizedBox(width: 8.w),
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final cityName = isAll
                        ? 'Tüm Şehirler'
                        : sortedCityNames[index - 1];
                    final cityId = isAll
                        ? ''
                        : cityGroups[cityName]!.first.cityId;
                    final isSelected = _warehouseCityFilter == cityId;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _warehouseCityFilter = cityId;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: isSelected
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold.withValues(alpha: 0.25),
                                    AppColors.goldDark.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: AppColors.gold,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.12,
                                    ),
                                    blurRadius: 6,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                color: AppColors.cardBgLight.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: AppColors.border.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                        child: Center(
                          child: Text(
                            cityName,
                            style: TextStyle(
                              color: isSelected ? AppColors.gold : Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (sortedCityNames.isNotEmpty) SizedBox(height: 12.h),
            if (activeWarehouses.isNotEmpty)
              ...visibleCityNames.expand((cityName) {
                final warehousesInCity = cityGroups[cityName]!
                  ..sort((a, b) => a.name.compareTo(b.name));
                return [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h, top: 4.h),
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
                'Pazara alim yapabilmek icin once aktif bir depo gerekli.',
                AppColors.red,
              ),
            ],
          ],
        ),
      );
    }

    // Step 2: Product Selection Mode (Warehouse is selected, Product is empty)
    final double availableCapacity =
        (selectedWarehouse.capacity - selectedWarehouse.reservedCapacity).clamp(
          0,
          double.infinity,
        );
    final double reservedCapacity = selectedWarehouse.reservedCapacity.clamp(
      0.0,
      selectedWarehouse.capacity,
    );
    final double fillPercent = selectedWarehouse.capacity > 0
        ? (reservedCapacity / selectedWarehouse.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: AppDecorations.premiumCard(
        AppColors.borderGold.withValues(alpha: 0.25),
        20.r,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed Selected Warehouse Header Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.warehouse_outlined,
                    color: AppColors.blue,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEDEF DEPO SEÇİLDİ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        selectedWarehouse.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      _buildTypeBadge(
                        selectedWarehouse.warehouseKind == 'store'
                            ? 'Magaza Deposu'
                            : 'Normal Depo',
                        selectedWarehouse.warehouseKind == 'store'
                            ? AppColors.blue
                            : AppColors.gold,
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2.r),
                              child: LinearProgressIndicator(
                                value: fillPercent,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  fillPercent > 0.9
                                      ? AppColors.red
                                      : fillPercent > 0.75
                                      ? AppColors.gold
                                      : AppColors.green,
                                ),
                                minHeight: 3.h,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '${availableCapacity.toStringAsFixed(0)} m3 bos',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                TextButton.icon(
                  onPressed: _resetWarehouseSelection,
                  icon: Icon(
                    Icons.swap_horiz,
                    size: 14.sp,
                    color: AppColors.gold,
                  ),
                  label: Text(
                    'Değiştir',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          TextField(
            onChanged: (value) {
              setState(() {
                _productSearchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ürün ara...',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.gold.withValues(alpha: 0.6),
                size: 18.sp,
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 10.h,
                horizontal: 16.w,
              ),
              filled: true,
              fillColor: AppColors.cardBgLight.withValues(alpha: 0.5),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: AppColors.borderGold.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'Ürün Seçin',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          if (filteredProducts.isEmpty)
            _buildInfoBox('Bu depo için uygun ürün bulunamadı.', AppColors.red)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8.h,
                crossAxisSpacing: 8.w,
                childAspectRatio: 2.2,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                final isSelected = product.id == _activeProductId;
                return _buildSelectableProductCard(
                  product: product,
                  isSelected: isSelected,
                  isSellingInStore: sellingProductIds.contains(product.id),
                  isProductionInput: activeProductionIngredients.contains(product.id),
                  needCount: productNeedById[product.id] ?? 0,
                  prodNeedCount: productionNeedById[product.id] ?? 0,
                  onTap: () {
                    setState(() {
                      _selectedProductId = product.id;
                    });
                  },
                );
              },
            ),
          if (selectedProduct != null) ...[
            SizedBox(height: 14.h),
            _buildSelectedProductSummary(selectedProduct),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectableProductCard({
    required ProductModel product,
    required bool isSelected,
    required bool isSellingInStore,
    required bool isProductionInput,
    required int needCount,
    required int prodNeedCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: isSelected
            ? AppDecorations.glowingAction(AppColors.gold, 14.r)
            : BoxDecoration(
                color: AppColors.cardBgLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
        child: Row(
          children: [
            // Sol Taraf: Büyük Ürün İkonu
            Container(
              width: 38.w,
              height: 38.w,
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.3)
                      : AppColors.border.withValues(alpha: 0.3),
                ),
              ),
              child: CachedAssetImage(fileName: product.urunIconu),
            ),
            SizedBox(width: 10.w),
            // Sağ Taraf: Detaylar (Başlık, Baz Fiyat, Mini Etiketler)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.urunAdi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? AppColors.gold : Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${product.bazSatisFiyati.toStringAsFixed(0)} TL',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isSellingInStore || needCount > 0 || prodNeedCount > 0 || isProductionInput) ...[
                    SizedBox(height: 4.h),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          if (isSellingInStore)
                            _buildMiniChip(
                              needCount > 0 ? 'Satış ($needCount)' : 'Satışta',
                              AppColors.green,
                            ),
                          if (!isSellingInStore && needCount > 0)
                            _buildMiniChip(
                              'İhtiyaç: $needCount',
                              AppColors.gold,
                            ),
                          if (prodNeedCount > 0)
                            _buildMiniChip(
                              'Üretim ($prodNeedCount)',
                              AppColors.blue,
                            )
                          else if (isProductionInput)
                            _buildMiniChip(
                              'Üretim',
                              AppColors.blue,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      margin: EdgeInsets.only(right: 4.w),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5.w),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 7.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSelectedProductSummary(ProductModel product) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: AppDecorations.glowingAction(
        AppColors.gold.withValues(alpha: 0.5),
        14.r,
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: CachedAssetImage(fileName: product.urunIconu),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seçili Ürün',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  product.urunAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
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
              fontSize: 11.sp,
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
    final availableCapacity = (warehouse.capacity - warehouse.reservedCapacity)
        .clamp(0, double.infinity);
    final double reservedCapacity = warehouse.reservedCapacity.clamp(
      0.0,
      warehouse.capacity,
    );
    final double fillPercent = warehouse.capacity > 0
        ? (reservedCapacity / warehouse.capacity).clamp(0.0, 1.0)
        : 0.0;
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
        decoration: isSelected
            ? AppDecorations.premiumCard(AppColors.blue, 14.r)
            : BoxDecoration(
                color: AppColors.cardBgLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.blue.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.blue.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Icon(
                warehouse.warehouseKind == 'store'
                    ? Icons.storefront_outlined
                    : Icons.warehouse_outlined,
                color: isSelected ? AppColors.blue : AppColors.gold,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
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
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        warehouse.cityName ?? 'Bilinmeyen Sehir',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.sp,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (warehouse.warehouseKind == 'store'
                                      ? AppColors.blue
                                      : AppColors.gold)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999.r),
                          border: Border.all(
                            color:
                                (warehouse.warehouseKind == 'store'
                                        ? AppColors.blue
                                        : AppColors.gold)
                                    .withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          warehouse.warehouseKind == 'store'
                              ? 'Magaza'
                              : 'Normal',
                          style: TextStyle(
                            color: warehouse.warehouseKind == 'store'
                                ? AppColors.blue
                                : AppColors.goldLight,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${availableCapacity.toStringAsFixed(0)} m3 bos',
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
                  SizedBox(height: 6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: fillPercent,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fillPercent > 0.9
                            ? AppColors.red
                            : fillPercent > 0.75
                            ? AppColors.gold
                            : AppColors.green,
                      ),
                      minHeight: 4.h,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
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
    final storesAsync = ref.watch(storesListProvider);
    final scopedProducts = productsAsync.hasValue && warehousesAsync.hasValue
        ? _productsForActiveWarehouse(
            productsAsync.value ?? const <ProductModel>[],
            warehousesAsync.value ?? const <WarehouseModel>[],
          )
        : const <ProductModel>[];
    final selectedWarehouse = warehousesAsync.hasValue
        ? (warehousesAsync.value ?? const <WarehouseModel>[])
              .where((warehouse) => warehouse.id == _activeWarehouseId)
              .firstOrNull
        : null;
    final selectedStore = storesAsync.hasValue
        ? _storeForWarehouse(
            stores: storesAsync.value ?? const <StoreModel>[],
            warehouse: selectedWarehouse,
          )
        : null;
    final horizontalSellingProductIds = _sellingProductIdsForStore(
      selectedStore,
    );
    final horizontalProductNeedById = _neededCapacityByProductForStore(
      selectedStore,
    );

    final factories = ref.watch(factoryListProvider).value ?? const [];
    final farms = ref.watch(farmListProvider).value ?? const [];
    final fields = ref.watch(fieldListProvider).value ?? const [];

    final productionNeedById = <String, int>{};
    final allProducts = productsAsync.value ?? const [];

    void addBuildingNeeds(String buildingId, int inputCapacity, int inputStockQuantity, Set<String> inputProductIds) {
      final freeCapacity = inputCapacity - inputStockQuantity;
      if (freeCapacity <= 0) return;
      for (final inputId in inputProductIds) {
        productionNeedById.update(
          inputId,
          (value) => value + freeCapacity,
          ifAbsent: () => freeCapacity,
        );
      }
    }

    for (final f in factories) {
      final pId = f.selectedProduct?.id;
      if (pId != null && pId.isNotEmpty) {
        final product = allProducts.where((p) => p.id == pId).firstOrNull;
        if (product != null) {
          addBuildingNeeds(f.factory.id, f.factory.inputCapacity, f.inputStockQuantity, product.inputProductIds);
        }
      }
    }

    for (final f in farms) {
      final activeSlotsProductIds = <String>{};
      for (final slot in f.slots) {
        if (slot.isActive && slot.productId != null && slot.productId!.isNotEmpty) {
          activeSlotsProductIds.add(slot.productId!);
        }
      }
      for (final pId in activeSlotsProductIds) {
        final product = allProducts.where((p) => p.id == pId).firstOrNull;
        if (product != null) {
          addBuildingNeeds(f.farm.id, f.farm.inputCapacity, f.inputStockQuantity, product.inputProductIds);
        }
      }
    }

    for (final f in fields) {
      final activeSlotsProductIds = <String>{};
      for (final slot in f.slots) {
        if (slot.isActive && slot.productId != null && slot.productId!.isNotEmpty) {
          activeSlotsProductIds.add(slot.productId!);
        }
      }
      for (final pId in activeSlotsProductIds) {
        final product = allProducts.where((p) => p.id == pId).firstOrNull;
        if (product != null) {
          addBuildingNeeds(f.field.id, f.field.inputCapacity, f.inputStockQuantity, product.inputProductIds);
        }
      }
    }

    final activeProductionIngredients = productionNeedById.keys.toSet();

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
    final buyerWarehouseAsync = _activeWarehouseId.isNotEmpty
        ? ref.watch(marketBuyerWarehouseProvider(_activeWarehouseId))
        : const AsyncValue<MarketBuyerWarehouseModel?>.data(null);
    final capacityAsync = _activeWarehouseId.isNotEmpty
        ? ref.watch(warehouseCapacityStatusProvider(_activeWarehouseId))
        : const AsyncValue<WarehouseCapacityStatusModel?>.data(null);
    final previewListings = listingsAsync.value ?? const <MarketListingModel>[];
    final capacityBannerMessage = _buildCapacityBannerMessage(
      product: productAsync.value,
      capacity: capacityAsync.value,
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
                        _requiresInitialSelection ? 12.h : 4.h,
                        5.w,
                        _hasCart ? 92.h : 32.h,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (_requiresInitialSelection) ...[
                            productsAsync.when(
                              data: (products) => warehousesAsync.when(
                                data: (warehouses) => storesAsync.when(
                                   data: (stores) => _buildInitialSelectionCard(
                                    products,
                                    warehouses,
                                    stores,
                                    productionNeedById,
                                    activeProductionIngredients,
                                  ),
                                  loading: _buildLoadingCard,
                                  error: (e, s) => _buildErrorCard(
                                    'Magaza listesi alinamadi.',
                                  ),
                                ),
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
                            _buildUnifiedSelectionCard(
                              product: productAsync.value,
                              products: scopedProducts,
                              sellingProductIds: horizontalSellingProductIds,
                              productNeedById: horizontalProductNeedById,
                              activeProductionIngredients: activeProductionIngredients,
                              productionNeedById: productionNeedById,
                              buyerWarehouse: buyerWarehouseAsync.value,
                              capacity: capacityAsync.value,
                            ),
                            _buildLojistikKilitBanner(),
                          ],
                          if (capacityBannerMessage != null) ...[
                            SizedBox(height: 4.h),
                            _buildInfoBox(
                              capacityBannerMessage,
                              capacityBannerMessage.contains('Dikkat')
                                  ? AppColors.gold
                                  : AppColors.red,
                            ),
                          ],
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                      sliver: SliverToBoxAdapter(
                        child: _buildSectionHeader(
                          'SATIS NOKTALARI',
                          'Pazar Listesi',
                        ),
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
                          );
                          final filteredListings = _applyCartCityRules(
                            baseListings,
                          );
                          final finalMarketListings = filteredListings;

                          MarketListingModel? cheapestListing;
                          if (finalMarketListings.isNotEmpty) {
                            cheapestListing = finalMarketListings.reduce(
                              (curr, next) => curr.price < next.price ? curr : next,
                            );
                          }

                          return _buildListingsSliver(
                            listings: finalMarketListings,
                            buyer: buyerWarehouseAsync.value,
                            fallbackCity: fallbackCityAsync.value,
                            product: productAsync.value,
                            cheapestListingId: cheapestListing?.listingId,
                          );
                        },
                        loading: () =>
                            SliverToBoxAdapter(child: _buildLoadingCard()),
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

  Widget _buildListingsSliver({
    required List<MarketListingModel> listings,
    required MarketBuyerWarehouseModel? buyer,
    required Map<String, dynamic>? fallbackCity,
    required ProductModel? product,
    String? cheapestListingId,
  }) {
    if (listings.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildListDelegate.fixed([
        ...listings.map(
          (listing) => _buildListingCard(
            listing,
            buyer,
            fallbackCity,
            product,
            isCheapest: listing.listingId == cheapestListingId,
          ),
        ),
      ]),
    );
  }

  Widget _buildListingCard(
    MarketListingModel listing,
    MarketBuyerWarehouseModel? buyer,
    Map<String, dynamic>? fallbackCity,
    ProductModel? product, {
    bool isCheapest = false,
  }) {
    final capacityStatus = _activeWarehouseId.isNotEmpty
        ? ref.read(warehouseCapacityStatusProvider(_activeWarehouseId)).value
        : null;
    final canAddToCart = _canAddListingToCart(
      listing: listing,
      product: product,
      capacity: capacityStatus,
    );
    final addDisabledReason = canAddToCart
        ? null
        : _listingCapacityWarning(
            listing: listing,
            product: product,
            capacity: capacityStatus,
          );
    final targetCityX = _resolveCoordinate(
      buyer?.cityX,
      fallbackCity?['map_position_x'],
    );
    final targetCityY = _resolveCoordinate(
      buyer?.cityY,
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
        border: Border.all(
          color: isCheapest
              ? AppColors.gold.withValues(alpha: 0.65)
              : AppColors.borderGold.withValues(alpha: 0.15),
          width: isCheapest ? 1.3.w : 1.w,
        ),
        boxShadow: [
          if (isCheapest)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08),
              blurRadius: 8.r,
              spreadRadius: 0.5.r,
            ),
        ],
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
                                      color: AppColors.borderGold.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: ClipOval(
                                    child:
                                        listing.sellerGoogleAvatarUrl != null &&
                                            listing.sellerGoogleAvatarUrl!
                                                .trim()
                                                .isNotEmpty
                                        ? Image.network(
                                            listing.sellerGoogleAvatarUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Padding(
                                              padding: EdgeInsets.all(5.w),
                                              child: CachedAssetImage(
                                                fileName:
                                                    listing.sellerAvatarId,
                                              ),
                                            ),
                                          )
                                        : Padding(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              listing.sellerPlayerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (isCheapest) ...[
                                            SizedBox(width: 6.w),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 5.w,
                                                vertical: 1.5.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.gold.withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(6.r),
                                                border: Border.all(
                                                  color: AppColors.gold.withValues(alpha: 0.65),
                                                  width: 0.8.w,
                                                ),
                                              ),
                                              child: Text(
                                                'En Ucuz',
                                                style: TextStyle(
                                                  color: AppColors.gold,
                                                  fontSize: 8.sp,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
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
                            SizedBox(height: 8.h),
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
                                _buildInlineMetric(
                                  icon: Icons.square_foot_outlined,
                                  label: 'Birim Hacim',
                                  value: '${listing.unitVolume.toStringAsFixed(1)} m3',
                                  color: AppColors.textSecondary,
                                ),
                                if (listing.isNpc)
                                  _buildTypeBadge(
                                    'NPC / Kalite 1',
                                    AppColors.blue,
                                  ),
                                _buildTypeBadge(
                                  isInstantDelivery
                                      ? 'Aynı sehir / Anında'
                                      : 'Sehirler arası / Araç',
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
                                  ? () => _openAddToCartSheet(listing, product)
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
        Text(
          title,
          style: AppTextStyles.titleGold.copyWith(letterSpacing: 1.2),
        ),
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
          Icon(
            Icons.storefront_outlined,
            color: AppColors.textMuted,
            size: 48.sp,
          ),
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
    if (_activeWarehouseId.isEmpty) return 0;
    return ref
            .read(warehouseCapacityStatusProvider(_activeWarehouseId))
            .value
            ?.availableCapacity ??
        0;
  }

  bool get _cartFitsCurrentCapacity =>
      _cartTotalVolume <= _currentTargetAvailableCapacity();

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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _buildCartSummaryBar(
          sheetContext: sheetContext,
          refreshSheet: setSheetState,
        ),
      ),
    );
  }

  Widget _buildCartLauncherButton() {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: GestureDetector(
        onTap: _showCartSheet,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: AppDecorations.glowingAction(AppColors.gold, 16.r),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 18.sp,
              ),
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
              Icon(Icons.expand_less, color: Colors.white70, size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSummaryBar({
    required BuildContext sheetContext,
    required void Function(void Function()) refreshSheet,
  }) {
    final currentAvailableCapacity = _currentTargetAvailableCapacity();
    final remainingAfterCart = (currentAvailableCapacity - _cartTotalVolume)
        .clamp(-999999, 999999);
    final capacityOk = _cartFitsCurrentCapacity;
    final capacityColor = capacityOk ? AppColors.green : AppColors.red;
    final largestItem = _largestCartItemByVolume;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
        decoration: AppDecorations.panelGlass(24.r),
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
                SizedBox(width: 8.w),
                IconButton(
                  icon: Icon(Icons.delete_sweep_rounded, color: AppColors.red, size: 20.sp),
                  tooltip: 'Sepeti Temizle',
                  onPressed: () {
                    _clearCart();
                    Navigator.of(sheetContext).pop();
                  },
                ),
                SizedBox(width: 4.w),
                _buildCartIconsRow(),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Şehir: ${_resolveLockedCityName()} - Hacim: ${_cartTotalVolume.toStringAsFixed(1)} m³',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 10.sp,
              ),
            ),
            if (largestItem != null) ...[
              SizedBox(height: 4.h),
              Text(
                'En çok yer kaplayan: ${largestItem.listing.productName} • ${largestItem.totalVolume.toStringAsFixed(1)} m³',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.gold,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            SizedBox(height: 6.h),
            Text(
              capacityOk
                  ? 'Hedef kapasite uygun • Kalan: ${remainingAfterCart.toStringAsFixed(1)} m3'
                  : 'Kapasite aşıldı • Eksik: ${(-remainingAfterCart).toStringAsFixed(1)} m3',
              style: AppTextStyles.body.copyWith(
                color: capacityColor,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              height: 56.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _cartItems.length,
                separatorBuilder: (context, index) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final item = _cartItems[index];
                  return _buildCartItemPill(
                    item,
                    onRemove: () {
                      _removeCartItem(item);
                      if (!mounted) return;
                      if (_cartItems.isEmpty) {
                        Navigator.of(sheetContext).pop();
                        return;
                      }
                      refreshSheet(() {});
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: capacityOk
                    ? () {
                        Navigator.of(sheetContext).pop();
                        _openCartCheckout();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Alımı Tamamla'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemPill(_MarketCartItem item, {VoidCallback? onRemove}) {
    return Container(
      width: 190.w,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.25)),
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
                  '${item.quantity} adet • ${item.totalVolume.toStringAsFixed(1)} m³',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove ?? () => _removeCartItem(item),
            child: Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(Icons.close, size: 13.sp, color: AppColors.red),
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

    final TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>
    vehicleResult;
    try {
      vehicleResult = await ref
          .read(marketActionProvider)
          .getIntercityVehicleOptions(
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
        decoration: AppDecorations.panelGlass(20.r),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Araç Seçin',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '${sourceCity.name} -> ${targetCity.name} | ${_cartTotalVolume.toStringAsFixed(1)} m³',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  return TransferVehicleOptionCard(
                    vehicleName: option.vehicleName,
                    isRental: option.isRental,
                    capacity: option.capacity,
                    speedKmh: option.speedKmh,
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

    final result = await ref
        .read(marketActionProvider)
        .startMultiMarketTransfer(
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
  final String targetCityId;
  final ProductModel product;
  final BuildContext parentContext;
  final Future<void> Function({required bool isInstant}) onSuccess;
  final Future<void> Function() onPreparedSlotRollback;

  const _PurchaseSheet({
    required this.listing,
    required this.buyerWarehouseId,
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

  const _MarketCartSelection({required this.listing, required this.quantity});
}

class _MarketCartItem {
  final MarketListingModel listing;
  final int quantity;

  const _MarketCartItem({required this.listing, required this.quantity});

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

  const _AddToCartSheet({
    required this.listing,
    required this.product,
    required this.buyerWarehouseId,
  });

  @override
  ConsumerState<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends ConsumerState<_AddToCartSheet> {
  late final TextEditingController _quantityController;
  int _quantity = 1;

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
    if (warehouseCapacity != null) {
      final free = math.max(
        warehouseCapacity.availableCapacity - reservedVolume,
        0,
      );
      byCapacity = widget.listing.unitVolume <= 0
          ? byStock
          : (free / widget.listing.unitVolume).floor();
    }

    return [
      byStock,
      byCash,
      byCapacity,
    ].reduce((a, b) => a < b ? a : b).clamp(0, byStock);
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
    final warehouseCapacityAsync = widget.buyerWarehouseId != null
        ? ref.watch(warehouseCapacityStatusProvider(widget.buyerWarehouseId!))
        : const AsyncValue<WarehouseCapacityStatusModel?>.data(null);
    final player = ref.watch(playerProvider).value;
    final inheritedState = context
        .findAncestorStateOfType<_MarketScreenState>();
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
          16.w,
          16.h,
          16.w,
          MediaQuery.of(context).viewInsets.bottom + 16.h,
        ),
        decoration: AppDecorations.panelGlass(24.r),
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
                      : (maxQuantity / 4)
                            .floor()
                            .clamp(1, maxQuantity)
                            .toString(),
                ),
                NumericKeyboardShortcut(
                  label: 'Yari',
                  value: maxQuantity <= 0
                      ? '0'
                      : (maxQuantity / 2)
                            .floor()
                            .clamp(1, maxQuantity)
                            .toString(),
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
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.2),
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
            SizedBox(
              width: double.infinity,
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
      ),
    );
  }

  Future<void> _openCartCheckout() async {
    if (_cartItems.isEmpty || _lockedSourceCityId == null) return;
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
      vehicleResult = await ref
          .read(marketActionProvider)
          .getIntercityVehicleOptions(
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
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  return TransferVehicleOptionCard(
                    vehicleName: option.vehicleName,
                    isRental: option.isRental,
                    capacity: option.capacity,
                    speedKmh: option.speedKmh,
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

    final totalCost = _cartItems.fold<double>(0.0, (sum, item) => sum + (item.listing.price * item.quantity));
    await _refreshAfterPurchase(isInstant: isInstant);
    _clearCart();

    if (!mounted) return;
    if (totalCost > 0) {
      FloatingFeedback.show(
        context,
        amount: totalCost,
        type: FloatingFeedbackType.cashRemove,
      );
    }
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
}

StoreModel? _storeForWarehouse({
  required List<StoreModel> stores,
  required WarehouseModel? warehouse,
}) {
  final storeId = warehouse?.storeId;
  if (storeId == null || storeId.isEmpty) return null;

  for (final store in stores) {
    if (store.id == storeId) return store;
  }

  return null;
}

Set<String> _sellingProductIdsForStore(StoreModel? store) {
  if (store == null || !store.isActive) return const <String>{};

  return store.slots
      .where(
        (slot) =>
            slot.isActive &&
            (slot.productId ?? '').isNotEmpty &&
            slot.qualityLevel > 0,
      )
      .map((slot) => slot.productId!)
      .toSet();
}

Map<String, int> _neededCapacityByProductForStore(StoreModel? store) {
  if (store == null || !store.isActive) return const <String, int>{};

  final result = <String, int>{};
  for (final slot in store.slots) {
    final productId = slot.productId;
    if (!slot.isActive || productId == null || productId.isEmpty) {
      continue;
    }
    if (slot.qualityLevel <= 0) continue;

    final availableCapacity =
        slot.capacity - slot.quantity - slot.pendingQuantity;
    if (availableCapacity <= 0) continue;

    result.update(
      productId,
      (value) => value + availableCapacity,
      ifAbsent: () => availableCapacity,
    );
  }

  return result;
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

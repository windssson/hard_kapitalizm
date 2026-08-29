import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/managers/asset_manager.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/app_network_image.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/price_sparkline.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/market/models/seller_market_sale_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_list_item_model.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_list_item_model.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';

const _defaultBrandId = '00000000-0000-0000-0000-000000000000';

class _MyWarehouseSlotEntry {
  final WarehouseModel warehouse;
  final WarehouseSlotModel slot;
  const _MyWarehouseSlotEntry({required this.warehouse, required this.slot});
}

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
  final Set<String> _prefetchedProductIcons = <String>{};
  String? _lockedSourceCityId;
  bool _cityCatalogEnabled = false;
  String _productSearchQuery = '';
  late String _selectedProductId;
  late String _selectedWarehouseId;
  late String _selectedCityId;
  String _selectedSortOption = 'fiyat';

  int _marketViewTab = 0; // 0: Pazar (Alis), 1: Ilanlarim (Satis)
  int _myListingsSubTab = 0; // 0: Aktif İlanlar, 1: Satış Geçmişi
  String _myListingsSearchQuery = '';
  String _myListingsWarehouseId = 'all';
  String _salesHistorySearchQuery = '';
  String _targetWarehouseSearchQuery = '';
  String _targetWarehouseFilterKind = 'all';

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.productId;
    _selectedWarehouseId = widget.warehouseId;
    _selectedCityId = widget.cityId;
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
    ref.invalidate(warehouseListProvider);
    ref.invalidate(storesListProvider);
    if (_marketViewTab == 1) {
      ref.invalidate(playerBrandCompanyProvider);
      ref.invalidate(sellerMarketSalesHistoryProvider);
      return;
    }

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
    ref.invalidate(buyerTransferMapProvider);
    ref.invalidate(buyerTransferHistoryProvider);
    if (_activeWarehouseId.isNotEmpty) {
      ref.invalidate(marketBuyerWarehouseProvider(_activeWarehouseId));
      ref.invalidate(warehouseCapacityStatusProvider(_activeWarehouseId));
    }
    if (isInstant) {
      ref.invalidate(warehouseListProvider);
      if (_activeWarehouseId.isNotEmpty) {
        ref.invalidate(warehouseDetailProvider(_activeWarehouseId));
      }
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
        message: 'Ürün bilgisi yüklenmeden satın alma açılamaz.',
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
        backgroundColor: AppColors.transparent,
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
        title: 'Şehir Kilidi',
        message:
            'Sepetteki ürünlerle aynı şehirden devam etmelisiniz: ${_resolveLockedCityName()}.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() {
      _lockedSourceCityId ??= selection.listing.cityId;
      _cartItems.addOrMerge(selection.listing, selection.quantity);
    });
    AppHaptic.medium();

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
    AppHaptic.light();
    setState(() {
      _cartItems.removeWhere((entry) => entry.key == item.key);
      if (_cartItems.isEmpty) {
        _lockedSourceCityId = null;
        _cityCatalogEnabled = false;
      }
    });
  }

  void _clearCart() {
    AppHaptic.light();
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
        style: AppTextStyles.body.standardCopyWith(color: color, fontSize: AppTypography.body),
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
          Icon(AppIcons.localShippingOutlined, color: AppColors.blue, size: AppIconSizes.xSmall),
          SizedBox(width: 6.w),
          Text(
            'Lojistik Rotası:',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            cityName,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.blue,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: _showLojistikBilgiDialog,
            child: Icon(
              AppIcons.helpOutline,
              color: AppColors.blue,
              size: AppIconSizes.small,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearCart,
            child: Text(
              'Sıfırla',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.red,
                fontSize: AppTypography.caption,
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
        backgroundColor: AppColors.transparent,
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
                  Icon(AppIcons.localShipping, color: AppColors.blue, size: AppIconSizes.compact),
                  SizedBox(width: 8.w),
                  Text(
                    'Lojistik Taşıma Kuralları',
                    style: AppTextStyles.titleBold.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodyLarge,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'Sepete ilk eklediğiniz ürünün bulunduğu şehir çıkış noktası olarak kilitlenir. '
                'Tek bir transfer seferinde lojistik araçları sadece aynı şehirden kalkan ürünleri birleştirebilir. '
                'Farklı bir şehirden ürün eklemek istiyorsanız sepeti sıfırlamanız gerekir.',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodySmall,
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
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.gold,
                      fontSize: AppTypography.bodySmall,
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
        style: AppTextStyles.body.standardCopyWith(color: color, fontSize: AppTypography.caption),
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
      return 'Seçili depoda hiç boş kapasite kalmadı. Yeni alım başlatılamaz.';
    }

    final unitVolume = product?.birimHacim ?? 0;
    if (unitVolume > 0) {
      final maxUnits = (available / unitVolume).floor();
      if (maxUnits <= 0) {
        return 'Bu ürün için seçili depoda yeterli yer yok. En az ${unitVolume.toStringAsFixed(1)} m3 boş alan gerekli.';
      }
      if (maxUnits < 5) {
        return 'Dikkat: seçili depoda bu üründen en fazla $maxUnits adet yer var.';
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
    return 'Bu ilan sepete eklenemiyor. Gereken en az hacim: ${unitVolume.toStringAsFixed(1)} m3, mevcut boş kapasite: ${available.toStringAsFixed(1)} m3.';
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

  void _prefetchMarketIcons(Iterable<ProductModel> products) {
    final iconsToFetch = products
        .map((product) => product.urunIconu.trim())
        .where(
          (icon) =>
              icon.isNotEmpty && !_prefetchedProductIcons.contains(icon),
        )
        .toList(growable: false);

    if (iconsToFetch.isEmpty) return;

    _prefetchedProductIcons.addAll(iconsToFetch);
    Future.microtask(() async {
      try {
        await ref.read(assetManagerProvider).prefetchAssetList(iconsToFetch);
      } catch (_) {
        _prefetchedProductIcons.removeAll(iconsToFetch);
      }
    });
  }

  Widget _buildUnifiedSelectionCard({
    required ProductModel? product,
    required List<ProductModel> products,
    required List<WarehouseModel> warehouses,
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
                  onTap: () => _openWarehouseSelectionSheet(warehouses: warehouses),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(AppIcons.warehouseOutlined, color: AppColors.gold, size: AppIconSizes.compact),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontSize: AppTypography.bodySmall,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                Text(
                                  cityName,
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.caption,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(AppIcons.swapHoriz, size: AppIconSizes.xxSmall, color: AppColors.gold),
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
                              width: 34.w,
                              height: 34.w,
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: AppFx.panelWash(0.2),
                                borderRadius: BorderRadius.circular(8.r),
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
                                    style: AppTextStyles.body.standardCopyWith(
                                      color: AppColors.goldLight,
                                      fontSize: AppTypography.bodySmall,
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
                                          style: AppTextStyles.caption.standardCopyWith(
                                            color: needCount > 0
                                                ? AppColors.gold
                                                : (prodNeedCount > 0 || isProductionInput
                                                    ? AppColors.blue
                                                    : AppColors.textMuted),
                                            fontSize: AppTypography.caption,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      Icon(AppIcons.swapHoriz, size: AppIconSizes.xxSmall, color: AppColors.gold),
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
          if (product != null) ...[
            SizedBox(height: 10.h),
            _buildPriceHistorySection(product.id),
          ],
          SizedBox(height: 10.h),
          // Kapasite Bilgisi & İlerleme Çubuğu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kapasite Doluluğu',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                capacityLabel,
                style: AppTextStyles.caption.standardCopyWith(
                  color: cartVolume > 0
                      ? AppColors.goldLight
                      : AppColors.textSecondary,
                  fontSize: AppTypography.caption,
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

  Widget _buildPriceHistorySection(String productId) {
    final historyAsync = ref.watch(productPriceHistoryProvider(productId));

    return historyAsync.when(
      data: (history) {
        if (history == null || history.prices.isEmpty) {
          return const SizedBox.shrink();
        }

        final visiblePrices = history.prices.where((price) => price > 0).toList();
        if (visiblePrices.length < 2) {
          return const SizedBox.shrink();
        }

        final isUp = visiblePrices.last >= visiblePrices.first;
        final trendColor = isUp ? AppColors.green : AppColors.red;
        final diff = visiblePrices.last - visiblePrices.first;
        final diffPercent =
            (diff / (visiblePrices.first > 0 ? visiblePrices.first : 1.0)) * 100;
        final sign = diff >= 0 ? '+' : '';

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: AppColors.borderGoldLight.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '5 Günlük Fiyat Trendi',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$sign${diffPercent.toStringAsFixed(1)}% ($sign${diff.toStringAsFixed(1)} ₺)',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: trendColor,
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              SizedBox(
                width: double.infinity,
                child: PriceSparkline(
                  prices: visiblePrices,
                  height: 52.h,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 50.h,
        alignment: Alignment.center,
        child: SizedBox(
          width: 16.w,
          height: 16.w,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
      ),
      error: (e, s) => const SizedBox.shrink(),
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

    final int usedFlex = (usedProgress * 1000).round();
    final int cartFlex = (cartProgress * 1000).round();
    int remainingFlex = 1000 - usedFlex - cartFlex;
    if (remainingFlex < 0) remainingFlex = 0;

    return Container(
      height: 6.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.08),
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.r),
        child: Row(
          children: [
            if (usedFlex > 0)
              Expanded(
                flex: usedFlex,
                child: Container(
                  color: AppColors.blue,
                ),
              ),
            if (cartFlex > 0)
              Expanded(
                flex: cartFlex,
                child: Container(
                  color: AppColors.gold,
                ),
              ),
            if (remainingFlex > 0)
              Spacer(
                flex: remainingFlex,
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

  void _openWarehouseSelectionSheet({
    required List<WarehouseModel> warehouses,
  }) {
    final activeWarehouses = warehouses.where((warehouse) => warehouse.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final factories = ref.read(factoryListProvider).value ?? const [];
    final farms = ref.read(farmListProvider).value ?? const [];
    final fields = ref.read(fieldListProvider).value ?? const [];
    final stores = ref.read(storesListProvider).value ?? const [];

    String modalSearchQuery = '';
    String modalFilterKind = 'all';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          var filtered = activeWarehouses;
          if (modalFilterKind == 'normal') {
            filtered = filtered.where((w) => w.warehouseKind != 'store').toList();
          } else if (modalFilterKind == 'store') {
            filtered = filtered.where((w) => w.warehouseKind == 'store').toList();
          }

          if (modalSearchQuery.trim().isNotEmpty) {
            final q = modalSearchQuery.trim().toLowerCase();
            filtered = filtered.where((w) {
              final name = w.name.toLowerCase();
              final city = (w.cityName ?? '').toLowerCase();
              return name.contains(q) || city.contains(q);
            }).toList();
          }

          final normalCount = activeWarehouses.where((w) => w.warehouseKind != 'store').length;
          final storeCount = activeWarehouses.where((w) => w.warehouseKind == 'store').length;

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppFx.softOverlay(0.2),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          AppIcons.warehouseOutlined,
                          color: AppColors.gold,
                          size: AppIconSizes.medium,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hedef Teslimat Deposu',
                              style: AppTextStyles.h2.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontSize: AppTypography.headline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Pazar alımlarının sevk edileceği merkezi seçin',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(AppIcons.cancelRounded, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    onChanged: (val) {
                      setModalState(() {
                        modalSearchQuery = val;
                      });
                    },
                    style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Depo adı veya şehir ara...',
                      hintStyle: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.bodySmall,
                      ),
                      prefixIcon: Icon(
                        AppIcons.search,
                        color: AppColors.gold.withValues(alpha: 0.6),
                        size: AppIconSizes.regular,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                      filled: true,
                      fillColor: AppColors.cardBgLight.withValues(alpha: 0.4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AppColors.borderGold.withValues(alpha: 0.25),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: AppColors.gold, width: 1.2),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChipInModal(
                          label: 'Tümü (${activeWarehouses.length})',
                          isSelected: modalFilterKind == 'all',
                          onTap: () => setModalState(() => modalFilterKind = 'all'),
                        ),
                        SizedBox(width: 6.w),
                        _buildFilterChipInModal(
                          label: '🏢 Genel Depolar ($normalCount)',
                          isSelected: modalFilterKind == 'normal',
                          onTap: () => setModalState(() => modalFilterKind = 'normal'),
                        ),
                        SizedBox(width: 6.w),
                        _buildFilterChipInModal(
                          label: '🏪 Mağaza Depoları ($storeCount)',
                          isSelected: modalFilterKind == 'store',
                          onTap: () => setModalState(() => modalFilterKind = 'store'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (filtered.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 30.h),
                      child: Center(
                        child: Text(
                          'Aramanıza uygun depo bulunamadı.',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final warehouse = filtered[index];
                          final cityFactories = factories.where((f) => f.factory.cityId == warehouse.cityId).toList();
                          final cityFarms = farms.where((f) => f.farm.cityId == warehouse.cityId).toList();
                          final cityFields = fields.where((f) => f.field.cityId == warehouse.cityId).toList();
                          final cityStores = stores.where((s) => s.cityId == warehouse.cityId).toList();

                          return _buildSelectableWarehouseCard(
                            warehouse: warehouse,
                            isSelected: warehouse.id == _activeWarehouseId,
                            cityFactories: cityFactories,
                            cityFarms: cityFarms,
                            cityFields: cityFields,
                            cityStores: cityStores,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              AppHaptic.selection();
                              setState(() {
                                _selectedWarehouseId = warehouse.id;
                                _selectedCityId = warehouse.cityId;
                                _resetCartState();
                              });
                            },
                          );
                        },
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

  Widget _buildFilterChipInModal({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        AppHaptic.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.2)
              : AppColors.cardBgLight.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.borderGold.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: isSelected ? AppColors.gold : AppColors.textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: AppTypography.caption,
          ),
        ),
      ),
    );
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
    final factories = ref.watch(factoryListProvider).value ?? const [];
    final farms = ref.watch(farmListProvider).value ?? const [];
    final fields = ref.watch(fieldListProvider).value ?? const [];

    final activeWarehouses =
        warehouses.where((warehouse) => warehouse.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final selectedWarehouse = activeWarehouses
        .where((warehouse) => warehouse.id == _activeWarehouseId)
        .firstOrNull;
    final sellingProductIds = _calculateSellingProductIds(
      stores: stores,
      selectedWarehouse: selectedWarehouse,
    );
    final productNeedById = _calculateStoreNeeds(
      stores: stores,
      selectedWarehouse: selectedWarehouse,
    );

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
    _prefetchMarketIcons(filteredProducts.take(8));
    final gridRowCount = (filteredProducts.length / 2).ceil();
    final gridHeight = math.min(
      (gridRowCount * 84.h) + (math.max(0, gridRowCount - 1) * 8.h),
      320.h,
    );
    final selectedProduct = sortedProducts
        .where((product) => product.id == _activeProductId)
        .firstOrNull;
    // Step 1: Warehouse Selection Mode
    if (selectedWarehouse == null) {
      final normalCount = activeWarehouses.where((w) => w.warehouseKind != 'store').length;
      final storeCount = activeWarehouses.where((w) => w.warehouseKind == 'store').length;

      var displayWarehouses = activeWarehouses;
      if (_targetWarehouseFilterKind == 'normal') {
        displayWarehouses = displayWarehouses.where((w) => w.warehouseKind != 'store').toList();
      } else if (_targetWarehouseFilterKind == 'store') {
        displayWarehouses = displayWarehouses.where((w) => w.warehouseKind == 'store').toList();
      }

      if (_targetWarehouseSearchQuery.trim().isNotEmpty) {
        final q = _targetWarehouseSearchQuery.trim().toLowerCase();
        displayWarehouses = displayWarehouses.where((w) {
          final name = w.name.toLowerCase();
          final city = (w.cityName ?? '').toLowerCase();
          return name.contains(q) || city.contains(q);
        }).toList();
      }

      if (ref.watch(tutorialProvider).step == TutorialStep.selectMarketWarehouse) {
        displayWarehouses = [...displayWarehouses]..sort((a, b) {
          final aStore = a.warehouseKind == 'store' ? 1 : 0;
          final bStore = b.warehouseKind == 'store' ? 1 : 0;
          if (aStore != bStore) return bStore.compareTo(aStore);
          return a.name.compareTo(b.name);
        });
      }

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
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Icon(AppIcons.warehouse, color: AppColors.gold, size: AppIconSizes.medium),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hedef Teslimat Deposu',
                        style: AppTextStyles.h2.standardCopyWith(
                          fontSize: AppTypography.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Pazardan yapacağınız alımlar bu depoya teslim edilir.',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            TextField(
              onChanged: (value) {
                setState(() {
                  _targetWarehouseSearchQuery = value;
                });
              },
              style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Depo adı veya şehir ara...',
                hintStyle: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodySmall,
                ),
                prefixIcon: Icon(
                  AppIcons.search,
                  color: AppColors.gold.withValues(alpha: 0.6),
                  size: AppIconSizes.regular,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                filled: true,
                fillColor: AppColors.cardBgLight.withValues(alpha: 0.4),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: AppColors.borderGold.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.gold, width: 1.2),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChipInModal(
                    label: 'Tümü (${activeWarehouses.length})',
                    isSelected: _targetWarehouseFilterKind == 'all',
                    onTap: () => setState(() => _targetWarehouseFilterKind = 'all'),
                  ),
                  SizedBox(width: 6.w),
                  _buildFilterChipInModal(
                    label: '🏢 Genel Depolar ($normalCount)',
                    isSelected: _targetWarehouseFilterKind == 'normal',
                    onTap: () => setState(() => _targetWarehouseFilterKind = 'normal'),
                  ),
                  SizedBox(width: 6.w),
                  _buildFilterChipInModal(
                    label: '🏪 Mağaza Depoları ($storeCount)',
                    isSelected: _targetWarehouseFilterKind == 'store',
                    onTap: () => setState(() => _targetWarehouseFilterKind = 'store'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            if (displayWarehouses.isNotEmpty)
              ...displayWarehouses.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final warehouse = entry.value;
                  final cityFactories = factories.where((f) => f.factory.cityId == warehouse.cityId).toList();
                  final cityFarms = farms.where((f) => f.farm.cityId == warehouse.cityId).toList();
                  final cityFields = fields.where((f) => f.field.cityId == warehouse.cityId).toList();
                  final cityStores = stores.where((s) => s.cityId == warehouse.cityId).toList();

                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _buildSelectableWarehouseCard(
                      key: (ref.watch(tutorialProvider).step == TutorialStep.selectMarketWarehouse && index == 0)
                          ? TutorialKeys.marketWarehouseFirstItemKey
                          : null,
                      warehouse: warehouse,
                      isSelected: warehouse.id == _activeWarehouseId,
                      cityFactories: cityFactories,
                      cityFarms: cityFarms,
                      cityFields: cityFields,
                      cityStores: cityStores,
                      onTap: () {
                        if (ref.read(tutorialProvider).step == TutorialStep.selectMarketWarehouse) {
                          ref.read(tutorialProvider.notifier).setStep(TutorialStep.selectMarketProduct);
                        }
                        setState(() {
                          _selectedWarehouseId = warehouse.id;
                          _selectedCityId = warehouse.cityId;
                          _selectedProductId = '';
                          _productSearchQuery = '';
                          _resetCartState();
                        });
                      },
                    ),
                  );
                },
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Center(
                  child: Text(
                    'Aramanıza veya filtrenize uygun depo bulunamadı.',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ),
              ),
            if (activeWarehouses.isEmpty) ...[
              SizedBox(height: 12.h),
              _buildInfoBox(
                'Pazara alım yapabilmek için önce aktif bir depo gereklidir.',
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
                    AppIcons.warehouseOutlined,
                    color: AppColors.blue,
                    size: AppIconSizes.regular,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEDEF DEPO SEÇİLDİ',
                        style: AppTextStyles.overline.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.caption,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        selectedWarehouse.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      _buildTypeBadge(
                        selectedWarehouse.warehouseKind == 'store'
                            ? 'Mağaza Deposu'
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
                              child: AppProgressBar(
                                value: fillPercent,
                                backgroundColor: AppFx.softOverlay(0.10),
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
                            '${availableCapacity.toStringAsFixed(0)} m3 boş',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textSecondary,
                              fontSize: AppTypography.caption,
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
                    AppIcons.swapHoriz,
                    size: AppIconSizes.small,
                    color: AppColors.gold,
                  ),
                  label: Text(
                    'Değiştir',
                    style: AppTextStyles.label.standardCopyWith(
                      fontSize: AppTypography.label,
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
            style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ürün ara...',
              hintStyle: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.body,
              ),
              prefixIcon: Icon(
                AppIcons.search,
                color: AppColors.gold.withValues(alpha: 0.6),
                size: AppIconSizes.regular,
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
                borderSide: BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'Ürün Seçin',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          if (filteredProducts.isEmpty)
            _buildInfoBox('Bu depo için uygun ürün bulunamadı.', AppColors.red)
          else
            SizedBox(
              key: (ref.watch(tutorialProvider).step == TutorialStep.selectMarketProduct)
                  ? TutorialKeys.marketProductFirstItemKey
                  : null,
              height: gridHeight,
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8.h,
                  crossAxisSpacing: 8.w,
                  childAspectRatio: 2.0,
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
                      if (ref.read(tutorialProvider).step == TutorialStep.selectMarketProduct) {
                        ref.read(tutorialProvider.notifier).setStep(TutorialStep.clickMarketBuyListing);
                      }
                      setState(() {
                        _selectedProductId = product.id;
                      });
                    },
                  );
                },
              ),
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
    Key? key,
    required ProductModel product,
    required bool isSelected,
    required bool isSellingInStore,
    required bool isProductionInput,
    required int needCount,
    required int prodNeedCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
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
              width: 48.w,
              height: 48.w,
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppFx.panelWash(0.2),
                borderRadius: BorderRadius.circular(12.r),
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
                    style: AppTextStyles.body.standardCopyWith(
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.textPrimary,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${product.bazSatisFiyati.toStringAsFixed(0)} TL',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.caption,
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
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.micro,
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
              color: AppFx.panelWash(0.25),
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
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  product.urunAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${product.bazSatisFiyati.toStringAsFixed(1)} TL',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.gold,
              fontSize: AppTypography.bodySmall,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessMiniChip(IconData icon, String name, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.5.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSizes.xxSmall, color: color),
          SizedBox(width: 3.w),
          Text(
            _truncateBusinessName(name),
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.micro,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _truncateBusinessName(String name) {
    if (name.length > 14) {
      return '${name.substring(0, 13)}…';
    }
    return name;
  }

  Widget _buildSelectableWarehouseCard({
    Key? key,
    required WarehouseModel warehouse,
    required bool isSelected,
    required List<FactoryListItemModel> cityFactories,
    required List<FarmListItemModel> cityFarms,
    required List<FieldListItemModel> cityFields,
    required List<StoreModel> cityStores,
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
    final isFull = availableCapacity <= 0;
    final isStore = warehouse.warehouseKind == 'store';
    final hasConnectedBusinesses = cityFactories.isNotEmpty ||
        cityFarms.isNotEmpty ||
        cityFields.isNotEmpty ||
        cityStores.isNotEmpty;

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.08)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.borderGold.withValues(alpha: 0.20),
            width: isSelected ? 1.5.w : 1.w,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.12),
                blurRadius: 10.r,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Üst Satır: İkon + Depo Adı & Şehir + Seçim Durumu Rozeti
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: isStore
                        ? AppColors.blue.withValues(alpha: 0.15)
                        : AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: (isStore ? AppColors.blue : AppColors.gold)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    isStore ? AppIcons.storefrontOutlined : AppIcons.warehouseOutlined,
                    color: isStore ? AppColors.blue : AppColors.gold,
                    size: AppIconSizes.medium,
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
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(
                            AppIcons.locationOnOutlined,
                            size: AppIconSizes.xxSmall,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            warehouse.cityName ?? 'Şehir',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.goldLight,
                              fontSize: AppTypography.caption,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '•',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            isStore ? 'Mağaza Satış Deposu' : 'Genel Lojistik Deposu',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: isStore ? AppColors.blue : AppColors.textMuted,
                              fontSize: AppTypography.caption,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.cardBgLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.borderGold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(AppIcons.check, size: AppIconSizes.xxSmall, color: AppColors.textOnAccent),
                        SizedBox(width: 4.w),
                      ],
                      Text(
                        isSelected ? 'Seçili' : 'Seç',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: isSelected ? AppColors.textOnAccent : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTypography.micro,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // 2. Kapasite Durum Kutusu (Net & Anlaşılır)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppFx.softOverlay(0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isFull ? AppIcons.warningAmberRounded : AppIcons.storage,
                            size: AppIconSizes.xSmall,
                            color: isFull
                                ? AppColors.red
                                : availableCapacity <= 50
                                    ? AppColors.gold
                                    : AppColors.green,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            isFull
                                ? 'Depo Tamamen Dolu'
                                : '${availableCapacity.toStringAsFixed(0)} m³ Kullanılabilir Boş Alan',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: isFull
                                  ? AppColors.red
                                  : availableCapacity <= 50
                                      ? AppColors.gold
                                      : AppColors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: AppTypography.caption,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Toplam: ${warehouse.capacity.toStringAsFixed(0)} m³ (%${(fillPercent * 100).toStringAsFixed(0)} Dolu)',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.micro,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: AppProgressBar(
                      value: fillPercent,
                      backgroundColor: AppFx.softOverlay(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fillPercent >= 0.95
                            ? AppColors.red
                            : fillPercent >= 0.75
                                ? AppColors.gold
                                : AppColors.green,
                      ),
                      minHeight: 5.h,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Şehirdeki Bağlantılı Tesisler
            if (hasConnectedBusinesses) ...[
              SizedBox(height: 8.h),
              Text(
                'ŞEHİRDEKİ BAĞLANTILI İŞLETMELERİNİZ:',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Wrap(
                spacing: 5.w,
                runSpacing: 4.h,
                children: [
                  ...cityFactories.map((f) =>
                      _buildBusinessMiniChip(AppIcons.factoryOutlined, f.factory.name, AppColors.blue)),
                  ...cityFarms.map((f) =>
                      _buildBusinessMiniChip(AppIcons.agricultureOutlined, f.farm.name, AppColors.gold)),
                  ...cityFields.map((f) =>
                      _buildBusinessMiniChip(AppIcons.grass, f.field.name, AppColors.teal)),
                  ...cityStores.map((s) =>
                      _buildBusinessMiniChip(AppIcons.storefront, s.name, AppColors.green)),
                ],
              ),
            ],
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
    final horizontalSellingProductIds = _calculateSellingProductIds(
      stores: storesAsync.value ?? const <StoreModel>[],
      selectedWarehouse: selectedWarehouse,
    );
    final horizontalProductNeedById = _calculateStoreNeeds(
      stores: storesAsync.value ?? const <StoreModel>[],
      selectedWarehouse: selectedWarehouse,
    );

    final factories = ref.watch(factoryListProvider).value ?? const [];
    final farms = ref.watch(farmListProvider).value ?? const [];
    final fields = ref.watch(fieldListProvider).value ?? const [];
    final allProducts = productsAsync.value ?? const [];

    final productionNeedById = _calculateProductionNeeds(
      factories: factories,
      farms: farms,
      fields: fields,
      allProducts: allProducts,
      selectedWarehouse: selectedWarehouse,
    );

    final activeProductionIngredients = productionNeedById.keys.toSet();
    _prefetchMarketIcons(scopedProducts.take(8));

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
      backgroundColor: AppColors.transparent,
      floatingActionButton: _marketViewTab == 0
          ? (_hasCart ? _buildCartLauncherButton() : null)
          : _buildAddListingFab(warehousesAsync.value ?? []),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 3,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Global Pazar'),
            _buildMarketTabBar(),
            Expanded(
              child: _marketViewTab == 0
                  ? RefreshIndicator(
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
                                          'Mağaza listesi alınamadı.',
                                        ),
                                      ),
                                      loading: _buildLoadingCard,
                                      error: (e, s) =>
                                          _buildErrorCard('Depo listesi alinamadi.'),
                                    ),
                                    loading: _buildLoadingCard,
                                    error: (e, s) =>
                                        _buildErrorCard('Ürün listesi alınamadı.'),
                                  ),
                                  SizedBox(height: 8.h),
                                ],
                                if (!_requiresInitialSelection) ...[
                                  _buildUnifiedSelectionCard(
                                    product: productAsync.value,
                                    products: scopedProducts,
                                    warehouses: warehousesAsync.value ?? const [],
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'SATIS NOKTALARI',
                                    style: AppTextStyles.titleGold.standardCopyWith(letterSpacing: 1.2),
                                  ),
                                  _buildSortDropdown(),
                                ],
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
                                var finalMarketListings = [...filteredListings];

                                final targetCityX = _resolveCoordinate(
                                  buyerWarehouseAsync.value?.cityX,
                                  fallbackCityAsync.value?['map_position_x'],
                                );
                                final targetCityY = _resolveCoordinate(
                                  buyerWarehouseAsync.value?.cityY,
                                  fallbackCityAsync.value?['map_position_y'],
                                );

                                double getDistance(MarketListingModel l) {
                                  final hasTarget = _hasUsableCoordinates(targetCityX, targetCityY) &&
                                      _hasUsableCoordinates(l.cityX, l.cityY);
                                  return hasTarget
                                      ? _calculateDistanceKm(targetCityX, targetCityY, l.cityX, l.cityY)
                                      : 999999.0;
                                }

                                if (_selectedSortOption == 'fiyat') {
                                  finalMarketListings.sort((a, b) => a.price.compareTo(b.price));
                                } else if (_selectedSortOption == 'kalite') {
                                  finalMarketListings.sort((a, b) => b.qualityLevel.compareTo(a.qualityLevel));
                                } else if (_selectedSortOption == 'mesafe') {
                                  finalMarketListings.sort((a, b) => getDistance(a).compareTo(getDistance(b)));
                                }

                                if (finalMarketListings.length > 50) {
                                  finalMarketListings = finalMarketListings.take(50).toList();
                                }

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
                                child: _buildErrorCard('Pazar verileri alınamadı.'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : warehousesAsync.when(
                      data: (warehouses) => productsAsync.when(
                        data: (products) =>
                            _buildMyListingsView(warehouses, products),
                        loading: _buildLoadingCard,
                        error: (e, s) =>
                            _buildErrorCard('Ürün verileri alınamadı.'),
                      ),
                      loading: _buildLoadingCard,
                      error: (e, s) =>
                          _buildErrorCard('Depo verileri alınamadı.'),
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
    final priceDeltaPercent = _resolvePriceDeltaPercent(product, listing.price);
    final priceDeltaBadge = _buildPriceDeltaBadge(priceDeltaPercent);

    return Container(
      key: (ref.watch(tutorialProvider).step ==
                  TutorialStep.clickMarketBuyListing &&
              isCheapest)
          ? TutorialKeys.marketListingFirstAddKey
          : null,
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
                decoration: BoxDecoration(color: AppColors.green),
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
                                        ? AppNetworkImage(
                                            imageUrl:
                                                listing.sellerGoogleAvatarUrl!,
                                            width: 32.w,
                                            height: 32.w,
                                            fit: BoxFit.cover,
                                            errorWidget: Padding(
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
                                              style: AppTextStyles.title.standardCopyWith(
                                                color: AppColors.textPrimary,
                                                fontSize: AppTypography.bodyLarge,
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
                                                style: AppTextStyles.caption.standardCopyWith(
                                                  color: AppColors.gold,
                                                  fontSize: AppTypography.micro,
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
                                        style: AppTextStyles.body.standardCopyWith(
                                          fontSize: AppTypography.label,
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
                                  icon: AppIcons.inventory2Outlined,
                                  label: 'Stok',
                                  value: listing.quantity.toString(),
                                  color: AppColors.blue,
                                  isProminent: true,
                                ),
                                _buildInlineQualityMetric(
                                  label: 'Kalite',
                                  qualityLevel: listing.qualityLevel,
                                  color: AppColors.gold,
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
                          Row(
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
                                  style: AppTextStyles.body.standardCopyWith(
                                    color: AppColors.green,
                                    fontSize: AppTypography.bodySmall,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
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
                                  style: AppTextStyles.label.standardCopyWith(
                                    color: distanceColor,
                                    fontSize: AppTypography.label,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          SizedBox(
                            height: 28.h,
                            child: ElevatedButton(
                              onPressed: canAddToCart
                                  ? () {
                                      if (ref.read(tutorialProvider).step ==
                                          TutorialStep.clickMarketBuyListing) {
                                        ref
                                            .read(tutorialProvider.notifier)
                                            .setStep(
                                              TutorialStep.confirmMarketCartBuy,
                                            );
                                      }
                                      _openAddToCartSheet(listing, product);
                                    }
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
                                style: AppTextStyles.button.standardCopyWith(
                                  color: AppColors.textOnAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: AppTypography.bodySmall,
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
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.red,
                                  fontSize: AppTypography.caption,
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
    bool isProminent = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isProminent ? AppIconSizes.small : AppIconSizes.xSmall),
        SizedBox(width: 4.w),
        Text(
          '$label:',
          style: AppTextStyles.body.standardCopyWith(
            color: isProminent
                ? AppColors.textSecondary
                : AppColors.textMuted,
            fontSize: isProminent ? 11.sp : 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          value,
          style: AppTextStyles.body.standardCopyWith(
            color: isProminent
                ? AppColors.goldLight
                : AppColors.textPrimary,
            fontSize: isProminent ? 12.sp : 11.sp,
            fontWeight: FontWeight.w900,
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
        Icon(AppIcons.stars, color: color, size: AppIconSizes.xSmall),
        SizedBox(width: 4.w),
        Text(
          '$label:',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
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
                filled ? AppIcons.star : AppIcons.starBorder,
                color: filled ? color : AppFx.softOverlay(0.24),
                size: AppIconSizes.xxSmall,
              ),
            );
          }),
        ),
      ],
    );
  }


  Widget _buildSortDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      height: 32.h,
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSortOption,
          dropdownColor: AppColors.cardBg,
          icon: Icon(Icons.arrow_drop_down, color: AppColors.gold, size: 18.sp),
          style: AppTextStyles.body.standardCopyWith(
            fontSize: AppTypography.label,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedSortOption = newValue;
              });
            }
          },
          items: const [
            DropdownMenuItem<String>(
              value: 'fiyat',
              child: Text('Fiyat (En Düşük)'),
            ),
            DropdownMenuItem<String>(
              value: 'kalite',
              child: Text('Kalite (En Yüksek)'),
            ),
            DropdownMenuItem<String>(
              value: 'mesafe',
              child: Text('Mesafe (En Yakın)'),
            ),
          ],
        ),
      ),
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
            AppIcons.storefrontOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 16.h),
          Text(
            'Satis Noktasi Bulunamadi',
            style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.titleLarge),
          ),
          SizedBox(height: 8.h),
          Text(
            'Bu ürün için şu anda fiyat girilmiş aktif satış listesi bulunmuyor.',
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
    child: Center(
      child: AppLoadingIndicator(color: AppColors.gold),
    ),
  );

  Widget _buildErrorCard(String message) => Container(
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16.r),
    ),
    child: Text(
      message,
      style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
    ),
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


  Future<void> _showCartSheet() async {
    if (!_hasCart) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
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
        key: ref.watch(tutorialProvider).step ==
                TutorialStep.confirmMarketCheckout
            ? TutorialKeys.marketCartLauncherKey
            : null,
        onTap: _showCartSheet,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: AppDecorations.glowingAction(AppColors.gold, 16.r),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.shoppingBagOutlined,
                color: AppColors.textPrimary,
                size: AppIconSizes.regular,
              ),
              SizedBox(width: 8.w),
              Text(
                'Sepet • $_cartTotalQuantity',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${_cartTotalProductCost.toStringAsFixed(1)} TL',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(AppIcons.expandLess, color: AppColors.textSecondary, size: AppIconSizes.regular),
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
    final capacityStatus = _activeWarehouseId.isNotEmpty
        ? ref.read(warehouseCapacityStatusProvider(_activeWarehouseId)).value
        : null;

    final double totalCap = capacityStatus?.totalCapacity ?? 0.0;
    final double usedCap = capacityStatus?.usedCapacity ?? 0.0;
    final double cartVolume = _cartTotalVolume;
    final double remainingAfterCart = (totalCap - usedCap - cartVolume);
    final capacityOk = usedCap + cartVolume <= totalCap;
    final capacityColor = capacityOk ? AppColors.green : AppColors.red;
    final largestItem = _largestCartItemByVolume;

    return SafeArea(
      top: false,
      child: Container(
        key: ref.watch(tutorialProvider).step ==
                TutorialStep.confirmMarketCheckout
            ? TutorialKeys.marketCheckoutConfirmKey
            : null,
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
        decoration: AppDecorations.panelGlass(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Kısım: Başlık ve Temizle Butonu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alışveriş Sepeti',
                  style: AppTextStyles.h1.standardCopyWith(fontSize: AppTypography.headline),
                ),
                TextButton.icon(
                  onPressed: () {
                    _clearCart();
                    Navigator.of(sheetContext).pop();
                  },
                  icon: Icon(AppIcons.deleteSweepRounded, color: AppColors.red, size: AppIconSizes.compact),
                  label: Text(
                    'Temizle',
                    style: AppTextStyles.label.standardCopyWith(
                      color: AppColors.red,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Şehir & Toplam Hacim Satırı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.locationOnOutlined, color: AppColors.gold, size: AppIconSizes.small),
                    SizedBox(width: 4.w),
                    Text(
                      'Şehir: ${_resolveLockedCityName()}',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodySmall,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Sepet Hacmi: ${cartVolume.toStringAsFixed(1)} m³',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.goldLight,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // Kapasite Progress Bar
            _buildCapacityProgressBar(total: totalCap, used: usedCap, cart: cartVolume),
            SizedBox(height: 6.h),

            // Kapasite Durumu Text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hedef Depo Kapasitesi:',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  capacityOk
                      ? 'Uygun (Kalan Boş: ${remainingAfterCart.toStringAsFixed(1)} m³)'
                      : 'Aşıldı (Eksik: ${(-remainingAfterCart).toStringAsFixed(1)} m³)',
                  style: AppTextStyles.body.standardCopyWith(
                    color: capacityColor,
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (largestItem != null) ...[
              SizedBox(height: 8.h),
              Text(
                'En çok yer kaplayan: ${largestItem.listing.productName} • ${largestItem.totalVolume.toStringAsFixed(1)} m³',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(height: 12.h),

            // Sepet Ürünleri Listesi
            SizedBox(
              height: 54.h,
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
            SizedBox(height: 14.h),

            // Satın Alma Butonu
            SizedBox(
              width: double.infinity,
              height: 42.h,
              child: ElevatedButton(
                onPressed: capacityOk
                    ? () {
                        Navigator.of(sheetContext).pop();
                        _openCartCheckout();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'ALIMI TAMAMLA (${_cartTotalProductCost.toStringAsFixed(1)} TL)',
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
              color: AppFx.panelWash(0.18),
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
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${item.quantity} adet • ${item.totalVolume.toStringAsFixed(1)} m³',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                  ),
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
              child: Icon(AppIcons.close, size: AppIconSizes.small, color: AppColors.red),
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
            'Sepet hacmi hedef depo kapasitesini aşıyor. Sepeti küçültmeden alım tamamlanamaz.',
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
        title: 'Şehir Verisi Eksik',
        message: 'Araç seçimi için şehir bilgileri okunamadı.',
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
        title: 'Araç Seçim Hatası',
        message: 'Araç seçenekleri alınamadı: ${e.toString()}',
        type: SnackbarType.error,
      );
      return;
    }
    final options = vehicleResult.options;

    if (options.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Araç Yok',
        message:
            vehicleResult.unavailableReason ??
            'Şehirler arası alım için uygun araç bulunamadı.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (!mounted) return;

    final selectedVehicleId = await showTransferVehicleSelectionSheet(
      context: context,
      sourceCityName: sourceCity.name,
      targetCityName: targetCity.name,
      totalVolume: _cartTotalVolume,
      options: options.map(TransferVehicleOptionItem.fromMarket).toList(),
      unavailableReason: !vehicleResult.hasSelectableOptions
          ? vehicleResult.unavailableReason
          : null,
    );

    if (selectedVehicleId != null && mounted) {
      await _submitMultiMarketTransfer(
        vehicleId: selectedVehicleId,
      );
    }
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
              'Anlık market transferi tamamlanamadı.',
          type: SnackbarType.error,
        );
        return;
      }
    }

    await _refreshAfterPurchase(isInstant: isInstant);
    _clearCart();

    final tutorial = ref.read(tutorialProvider);
    if (tutorial.step == TutorialStep.confirmMarketCheckout ||
        tutorial.step == TutorialStep.confirmMarketCartBuy ||
        tutorial.step == TutorialStep.clickMarketBuyListing) {
      ref.read(tutorialProvider.notifier).setStep(TutorialStep.returnToHome);
    }

    if (!mounted) return;
    AppSnackbar.show(
      context,
      title: 'Başarılı',
      message: isInstant
          ? 'Market alımı anında tamamlandı ve deponuza teslim edildi!'
          : 'Pazar transferi başlatıldı. Araç yola çıktı.',
      type: SnackbarType.success,
    );
  }

  CityModel? _findCityById(List<CityModel> cities, String cityId) {
    for (final city in cities) {
      if (city.id == cityId) return city;
    }
    return null;
  }

  Widget _buildMarketTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              icon: AppIcons.storefrontOutlined,
              label: 'Pazar (Alış)',
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: _buildTabButton(
              index: 1,
              icon: AppIcons.sellOutlined,
              label: 'İlanlarım (Satış)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _marketViewTab == index;
    return GestureDetector(
      onTap: () {
        if (_marketViewTab != index) {
          AppHaptic.selection();
          setState(() {
            _marketViewTab = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : AppColors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 6.r,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppIconSizes.small,
              color: isSelected ? AppColors.textOnAccent : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: isSelected ? AppColors.textOnAccent : AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildAddListingFab(List<WarehouseModel> warehouses) {
    if (warehouses.isEmpty) return null;
    return FloatingActionButton.extended(
      onPressed: () => _openNewListingSheet(context, warehouses),
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.textOnAccent,
      icon: Icon(AppIcons.addCircleOutline, size: AppIconSizes.small),
      label: Text(
        'Yeni İlan Satışa Çıkar',
        style: AppTextStyles.button.standardCopyWith(
          color: AppColors.textOnAccent,
          fontSize: AppTypography.bodySmall,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMyListingsView(
    List<WarehouseModel> warehouses,
    List<ProductModel> allProducts,
  ) {
    final activeEntries = <_MyWarehouseSlotEntry>[];
    for (final w in warehouses) {
      for (final s in w.slots) {
        if (s.isAvailableForSale) {
          activeEntries.add(_MyWarehouseSlotEntry(warehouse: w, slot: s));
        }
      }
    }

    var filtered = activeEntries;
    if (_myListingsWarehouseId != 'all') {
      filtered = filtered.where((e) => e.warehouse.id == _myListingsWarehouseId).toList();
    }

    if (_myListingsSearchQuery.trim().isNotEmpty) {
      final q = _myListingsSearchQuery.trim().toLowerCase();
      filtered = filtered.where((e) {
        final pName = (e.slot.productName ?? '').toLowerCase();
        final wName = e.warehouse.name.toLowerCase();
        final cName = (e.warehouse.cityName ?? '').toLowerCase();
        return pName.contains(q) || wName.contains(q) || cName.contains(q);
      }).toList();
    }

    final totalActiveListings = activeEntries.length;
    final totalActiveStock = activeEntries.fold<int>(0, (sum, e) => sum + e.slot.quantity);
    final totalActiveRevenue = activeEntries.fold<double>(
      0.0,
      (sum, e) => sum + (e.slot.quantity * e.slot.price),
    );

    final salesHistoryAsync = ref.watch(sellerMarketSalesHistoryProvider);
    final totalSalesCount = salesHistoryAsync.value?.totalSalesCount ?? 0;

    return RefreshIndicator(
      onRefresh: _refreshPage,
      color: AppColors.gold,
      backgroundColor: AppColors.cardBg,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 80.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMyListingsSubTabBar(totalActiveListings, totalSalesCount),
                SizedBox(height: 8.h),
                if (_myListingsSubTab == 0) ...[
                  _buildMyListingsKpiHeader(
                    activeCount: totalActiveListings,
                    totalStock: totalActiveStock,
                    potentialRevenue: totalActiveRevenue,
                    totalSlots: activeEntries.length,
                  ),
                  SizedBox(height: 12.h),
                  _buildMyListingsFilterControls(warehouses, activeEntries),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AKTİF İLANLARIM (${filtered.length})',
                        style: AppTextStyles.titleGold.standardCopyWith(
                          letterSpacing: 1.1,
                          fontSize: AppTypography.caption,
                        ),
                      ),
                      if (activeEntries.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showBulkListingActionsSheet(activeEntries),
                          child: Row(
                            children: [
                              Icon(AppIcons.tuneRounded, color: AppColors.gold, size: AppIconSizes.small),
                              SizedBox(width: 4.w),
                              Text(
                                'Toplu İşlem',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  if (filtered.isEmpty)
                    _buildMyListingsEmptyState(activeEntries.isEmpty)
                  else
                    ...filtered.map((entry) => _buildMyListingCard(entry)),
                ] else ...[
                  _buildMySalesHistoryContent(salesHistoryAsync),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyListingsSubTabBar(int activeCount, int salesCount) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.3),
            blurRadius: 6.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSubTabButton(
              index: 0,
              icon: AppIcons.inventory2Outlined,
              label: 'Aktif İlanlarım ($activeCount)',
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: _buildSubTabButton(
              index: 1,
              icon: AppIcons.paymentsOutlined,
              label: 'Satış Geçmişi ($salesCount)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _myListingsSubTab == index;
    return GestureDetector(
      onTap: () {
        if (_myListingsSubTab != index) {
          AppHaptic.selection();
          setState(() {
            _myListingsSubTab = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : AppColors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 6.r,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppIconSizes.small,
              color: isSelected ? AppColors.textOnAccent : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.standardCopyWith(
                  color: isSelected ? AppColors.textOnAccent : AppColors.textMuted,
                  fontSize: AppTypography.caption,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySalesHistoryContent(
    AsyncValue<SellerMarketSalesHistoryResponse> salesHistoryAsync,
  ) {
    return salesHistoryAsync.when(
      loading: () => Container(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        alignment: Alignment.center,
        child: const AppLoadingIndicator(),
      ),
      error: (err, stack) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(AppIcons.errorOutline, color: AppColors.red, size: AppIconSizes.large),
            SizedBox(height: 8.h),
            Text(
              'Satış geçmişi yüklenirken hata oluştu',
              style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
            ),
            SizedBox(height: 8.h),
            TextButton.icon(
              onPressed: () => ref.invalidate(sellerMarketSalesHistoryProvider),
              icon: Icon(AppIcons.refresh, size: AppIconSizes.small, color: AppColors.gold),
              label: Text('Yeniden Dene', style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      ),
      data: (data) {
        final allSales = data.sales;
        var filteredSales = allSales;

        if (_salesHistorySearchQuery.trim().isNotEmpty) {
          final q = _salesHistorySearchQuery.trim().toLowerCase();
          filteredSales = filteredSales.where((s) {
            final buyerPlayer = s.buyerPlayerName.toLowerCase();
            final buyerCompany = s.buyerCompanyName.toLowerCase();
            final buyerCity = s.buyerCityName.toLowerCase();
            final warehouseName = s.sellerWarehouseName.toLowerCase();
            final hasMatchingItem = s.items.any(
              (item) => item.productName.toLowerCase().contains(q),
            );
            return buyerPlayer.contains(q) ||
                buyerCompany.contains(q) ||
                buyerCity.contains(q) ||
                warehouseName.contains(q) ||
                hasMatchingItem;
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMySalesKpiHeader(data),
            SizedBox(height: 12.h),
            _buildMySalesFilterControls(),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OYUNCU SATIŞLARI (${filteredSales.length})',
                  style: AppTextStyles.titleGold.standardCopyWith(
                    letterSpacing: 1.1,
                    fontSize: AppTypography.caption,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            if (filteredSales.isEmpty)
              _buildMySalesEmptyState(allSales.isEmpty)
            else
              ...filteredSales.map((sale) => _buildSellerSaleCard(sale)),
          ],
        );
      },
    );
  }

  Widget _buildMySalesKpiHeader(SellerMarketSalesHistoryResponse data) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.04),
            blurRadius: 10.r,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMyListingsKpiItem(
              title: 'Toplam Satış',
              value: '${data.totalSalesCount} işlem',
              icon: AppIcons.sellOutlined,
              color: AppColors.gold,
            ),
          ),
          Container(width: 1.w, height: 36.h, color: AppFx.softOverlay(0.1)),
          Expanded(
            child: _buildMyListingsKpiItem(
              title: 'Satılan Ürün',
              value: '${_formatStockNumber(data.totalSoldQuantity)} ad.',
              icon: AppIcons.inventory2Outlined,
              color: AppColors.blue,
            ),
          ),
          Container(width: 1.w, height: 36.h, color: AppFx.softOverlay(0.1)),
          Expanded(
            child: _buildMyListingsKpiItem(
              title: 'Toplam Hasılat',
              value: '₺${_formatCurrency(data.totalRevenue)}',
              icon: AppIcons.paymentsOutlined,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySalesFilterControls() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _salesHistorySearchQuery = value;
        });
      },
      style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Alıcı, şirket, şehir veya ürün ara...',
        hintStyle: AppTextStyles.body.standardCopyWith(
          color: AppColors.textMuted,
          fontSize: AppTypography.bodySmall,
        ),
        prefixIcon: Icon(
          AppIcons.search,
          color: AppColors.gold.withValues(alpha: 0.6),
          size: AppIconSizes.regular,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
        filled: true,
        fillColor: AppColors.cardBgLight.withValues(alpha: 0.4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.borderGold.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.gold, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildSellerSaleCard(SellerMarketSaleModel sale) {
    final formattedDate = sale.completedAt != null
        ? _formatDateTime(sale.completedAt!)
        : (sale.startedAt != null ? _formatDateTime(sale.startedAt!) : '-');

    final isCompleted = sale.status == 'completed';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isCompleted
              ? AppColors.green.withValues(alpha: 0.3)
              : AppColors.gold.withValues(alpha: 0.3),
          width: 1.2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompleted ? AppColors.green : AppColors.gold).withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Buyer Info + Price
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.cardBgLight.withValues(alpha: 0.4),
                border: Border(
                  bottom: BorderSide(color: AppFx.softOverlay(0.08)),
                ),
              ),
              child: Row(
                children: [
                  // Buyer Avatar
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        width: 1.2.w,
                      ),
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CachedAssetImage(
                          fileName: sale.buyerAvatarId.isNotEmpty
                              ? sale.buyerAvatarId
                              : 'ae1.webp',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                sale.buyerCompanyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTypography.bodySmall,
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                sale.buyerCityName,
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: AppTypography.micro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Yönetici: ${sale.buyerPlayerName}',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.micro,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Total Earned
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+₺${_formatCurrency(sale.totalPrice)}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.w900,
                          fontSize: AppTypography.title,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        formattedDate,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.micro,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Route & Warehouse info
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
              child: Row(
                children: [
                  Icon(AppIcons.warehouseOutlined, size: AppIconSizes.xSmall, color: AppColors.textMuted),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      'Satış Deposu: ${sale.sellerWarehouseName} (${sale.sellerCityName})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.micro,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.green.withValues(alpha: 0.12)
                          : AppColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted ? AppIcons.checkCircleOutline : AppIcons.localShippingOutlined,
                          size: 10.sp,
                          color: isCompleted ? AppColors.green : AppColors.blue,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          isCompleted ? 'Teslim Edildi' : 'Yolda',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: isCompleted ? AppColors.green : AppColors.blue,
                            fontSize: AppTypography.micro,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Items List
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                children: sale.items.map((item) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 6.h),
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppFx.softOverlay(0.06)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36.w,
                          height: 36.w,
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: AppFx.panelWash(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: BrandedProductImage(
                            fileName: item.productIcon,
                            brandId: item.brandId,
                            productId: item.productId,
                            fit: BoxFit.contain,
                            showFrame: false,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTypography.bodySmall,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Row(
                                children: [
                                  for (int i = 0; i < 5; i++)
                                    Icon(
                                      i < item.qualityLevel
                                          ? AppIcons.starRounded
                                          : AppIcons.starBorderRounded,
                                      color: i < item.qualityLevel
                                          ? AppColors.gold
                                          : AppFx.softOverlay(0.12),
                                      size: 10.sp,
                                    ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    '${_formatStockNumber(item.quantity)} ad. × ₺${_formatCurrency(item.unitPrice)}',
                                    style: AppTextStyles.caption.standardCopyWith(
                                      color: AppColors.textMuted,
                                      fontSize: AppTypography.micro,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₺${_formatCurrency(item.totalPrice)}',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySalesEmptyState(bool isAbsoluteEmpty) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.storefrontOutlined,
              size: AppIconSizes.large,
              color: AppColors.gold,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            isAbsoluteEmpty ? 'Henüz Satışın Yok' : 'Eşleşen Satış Bulunamadı',
            style: AppTextStyles.titleGold.standardCopyWith(
              fontSize: AppTypography.titleLarge,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isAbsoluteEmpty
                ? 'Depolarındaki malları pazar fiyatına uygun olarak satışa koyduğunda diğer oyuncular satın alacak ve hasılatın anında hesabına geçecektir.'
                : 'Arama kriterlerine uygun satış kaydı bulunamadı.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodySmall,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyListingsKpiHeader({
    required int activeCount,
    required int totalStock,
    required double potentialRevenue,
    required int totalSlots,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.04),
            blurRadius: 10.r,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMyListingsKpiItem(
              title: 'Aktif İlan',
              value: '$activeCount adet',
              icon: AppIcons.sellOutlined,
              color: AppColors.green,
            ),
          ),
          Container(width: 1.w, height: 36.h, color: AppFx.softOverlay(0.1)),
          Expanded(
            child: _buildMyListingsKpiItem(
              title: 'Satıştaki Stok',
              value: '${_formatStockNumber(totalStock)} ad.',
              icon: AppIcons.inventory2Outlined,
              color: AppColors.blue,
            ),
          ),
          Container(width: 1.w, height: 36.h, color: AppFx.softOverlay(0.1)),
          Expanded(
            child: _buildMyListingsKpiItem(
              title: 'Potansiyel Gelir',
              value: '₺${_formatCurrency(potentialRevenue)}',
              icon: AppIcons.paymentsOutlined,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyListingsKpiItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppIconSizes.xSmall, color: color),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
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
          style: AppTextStyles.body.standardCopyWith(
            color: color,
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMyListingsFilterControls(
    List<WarehouseModel> warehouses,
    List<_MyWarehouseSlotEntry> activeEntries,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) {
              setState(() {
                _myListingsSearchQuery = value;
              });
            },
            style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Aktif ilanlarda ara...',
              hintStyle: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
              prefixIcon: Icon(
                AppIcons.search,
                color: AppColors.gold.withValues(alpha: 0.6),
                size: AppIconSizes.regular,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
              filled: true,
              fillColor: AppColors.cardBgLight.withValues(alpha: 0.4),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: AppColors.borderGold.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppColors.gold, width: 1.2),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        PopupMenuButton<String>(
          initialValue: _myListingsWarehouseId,
          tooltip: 'Depoya Göre Filtrele',
          onSelected: (val) {
            setState(() {
              _myListingsWarehouseId = val;
            });
          },
          color: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'all',
              child: Text(
                '🏢 Tüm Depolar (${warehouses.length})',
                style: AppTextStyles.body.standardCopyWith(
                  color: _myListingsWarehouseId == 'all'
                      ? AppColors.gold
                      : AppColors.textPrimary,
                ),
              ),
            ),
            ...warehouses.map(
              (w) => PopupMenuItem(
                value: w.id,
                child: Text(
                  '${w.cityName ?? ''} • ${w.name}',
                  style: AppTextStyles.body.standardCopyWith(
                    color: _myListingsWarehouseId == w.id
                        ? AppColors.gold
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: _myListingsWarehouseId != 'all'
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : AppColors.cardBgLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: _myListingsWarehouseId != 'all'
                    ? AppColors.gold
                    : AppColors.borderGold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.warehouseOutlined,
                  size: AppIconSizes.xSmall,
                  color: _myListingsWarehouseId != 'all'
                      ? AppColors.gold
                      : AppColors.textMuted,
                ),
                SizedBox(width: 4.w),
                Text(
                  _myListingsWarehouseId == 'all'
                      ? 'Depo'
                      : warehouses
                          .firstWhere(
                            (w) => w.id == _myListingsWarehouseId,
                            orElse: () => warehouses.first,
                          )
                          .name,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: _myListingsWarehouseId != 'all'
                        ? AppColors.gold
                        : AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  AppIcons.arrowDropDown,
                  size: AppIconSizes.xSmall,
                  color: _myListingsWarehouseId != 'all'
                      ? AppColors.gold
                      : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyListingCard(_MyWarehouseSlotEntry entry) {
    final slot = entry.slot;
    final warehouse = entry.warehouse;
    final currentBrandName = ref.watch(playerBrandCompanyProvider).value?.brandName;
    final hasBrand = slot.brandId != _defaultBrandId;
    final brandTitle = hasBrand ? (currentBrandName ?? 'Markalı') : null;

    final double profitMargin = slot.cost > 0 && slot.price > 0
        ? ((slot.price - slot.cost) / slot.cost) * 100
        : 0;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.35),
          width: 1.2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.04),
            blurRadius: 8.r,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppFx.panelWash(0.25),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.green.withValues(alpha: 0.25),
              ),
            ),
            child: BrandedProductImage(
              fileName: slot.productIcon ?? 'default.webp',
              brandId: slot.brandId,
              brandName: brandTitle,
              productId: slot.productId,
              fit: BoxFit.contain,
              showFrame: false,
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
                        (slot.productName ?? 'Ürün') +
                            (hasBrand ? ' ($brandTitle)' : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    for (int i = 0; i < 5; i++)
                      Icon(
                        i < slot.qualityLevel
                            ? AppIcons.starRounded
                            : AppIcons.starBorderRounded,
                        color: i < slot.qualityLevel
                            ? AppColors.gold
                            : AppFx.softOverlay(0.12),
                        size: AppIconSizes.xSmall,
                      ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        '| Satışta: ${slot.quantity} ad.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(
                      AppIcons.locationOnOutlined,
                      size: AppIconSizes.xxSmall,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        '${warehouse.cityName ?? ''} • ${warehouse.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.micro,
                        ),
                      ),
                    ),
                  ],
                ),
                if (slot.cost > 0 && slot.price > 0) ...[
                  SizedBox(height: 2.h),
                  Text(
                    'Maliyet: ₺${slot.cost.toStringAsFixed(1)} • Kâr: ${profitMargin >= 0 ? '+' : ''}${profitMargin.toStringAsFixed(0)}%',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: profitMargin >= 0 ? AppColors.green : AppColors.red,
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _showMySlotPriceDialog(warehouse, slot),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: slot.price > 0
                        ? AppColors.gold.withValues(alpha: 0.12)
                        : AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: slot.price > 0
                          ? AppColors.gold.withValues(alpha: 0.35)
                          : AppColors.red.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slot.price > 0
                            ? '₺${slot.price.toStringAsFixed(1)}'
                            : 'Fiyat Belirle',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: slot.price > 0 ? AppColors.gold : AppColors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTypography.caption,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        AppIcons.edit,
                        size: AppIconSizes.xxSmall,
                        color: slot.price > 0 ? AppColors.gold : AppColors.red,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              GestureDetector(
                onTap: () => _toggleMySlotSaleStatus(warehouse, slot),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.pauseCircleOutline,
                        size: AppIconSizes.xSmall,
                        color: AppColors.red,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Satıştan Çek',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTypography.micro,
                        ),
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

  Widget _buildMyListingsEmptyState(bool noActiveListingsAtAll) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      margin: EdgeInsets.only(top: 20.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(
            noActiveListingsAtAll
                ? AppIcons.sellOutlined
                : AppIcons.searchOff,
            color: AppColors.gold.withValues(alpha: 0.6),
            size: AppIconSizes.emptyState,
          ),
          SizedBox(height: 12.h),
          Text(
            noActiveListingsAtAll
                ? 'Aktif Satış İlanınız Yok'
                : 'Filtreye Uygun İlan Yok',
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.headline,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            noActiveListingsAtAll
                ? 'Deponuzdaki ürünleri pazara sunmak için aşağıdaki "Yeni İlan Satışa Çıkar" butonuna dokunun.'
                : 'Arama teriminizi veya depo seçiminizi değiştirerek aktif ilanlarınızı görüntüleyebilirsiniz.',
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

  Future<void> _toggleMySlotSaleStatus(
    WarehouseModel warehouse,
    WarehouseSlotModel slot,
  ) async {
    if (!slot.isAvailableForSale && slot.price <= 0) {
      AppSnackbar.show(
        context,
        title: 'Fiyat Gerekli',
        message: 'Lütfen önce bu ürün için bir pazar satış fiyatı belirleyin.',
        type: SnackbarType.warning,
      );
      await _showMySlotPriceDialog(warehouse, slot);
      return;
    }

    final newStatus = !slot.isAvailableForSale;
    final result = await ref
        .read(warehouseActionProvider)
        .setWarehouseSlotSaleStatus(
          warehouseSlotId: slot.id,
          isAvailableForSale: newStatus,
        );

    if (!mounted) return;

    if (result['success'] == true) {
      ref.read(warehouseListProvider.notifier).patchSlotSaleStatus(
        warehouseId: warehouse.id,
        slotId: slot.id,
        isAvailableForSale: newStatus,
      );
      ref.read(warehouseDetailProvider(warehouse.id).notifier).patchSlotSaleStatus(
        slotId: slot.id,
        isAvailableForSale: newStatus,
      );
      if (slot.productId != null && slot.productId!.isNotEmpty) {
        ref.invalidate(marketListingsProvider(slot.productId!));
      } else {
        ref.invalidate(marketListingsProvider);
      }
      AppHaptic.medium();
      AppSnackbar.show(
        context,
        title: newStatus ? 'Satışa Açıldı' : 'Satıştan Çekildi',
        message: newStatus
            ? '${slot.productName ?? 'Ürün'} pazarda listeleniyor.'
            : '${slot.productName ?? 'Ürün'} pazardan kaldırıldı.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: result['message']?.toString() ?? 'Satış durumu değiştirilemedi.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _showMySlotPriceDialog(
    WarehouseModel warehouse,
    WarehouseSlotModel slot,
  ) async {
    final currentBrandName = ref.read(playerBrandCompanyProvider).value?.brandName;
    final hasBrand = slot.brandId != _defaultBrandId;

    final productId = slot.productId ?? '';

    // Canlı pazar ve rakip verilerini çek
    ProductModel? marketProduct;
    List<MarketListingModel> marketListings = [];
    if (productId.isNotEmpty) {
      final productFuture = ref.read(marketProductProvider(productId).future);
      final listingsFuture = ref.read(marketListingsProvider(productId).future);
      try {
        final results = await Future.wait([productFuture, listingsFuture]);
        marketProduct = results[0] as ProductModel?;
        marketListings = (results[1] as List<MarketListingModel>?) ?? [];
      } catch (_) {}
    }

    final competitors = marketListings.where((l) => l.slotId != slot.id).toList();
    competitors.sort((a, b) => a.price.compareTo(b.price));

    double minPrice = 0.0;
    double maxPrice = 0.0;
    double avgPrice = 0.0;

    if (competitors.isNotEmpty) {
      minPrice = competitors.first.price;
      maxPrice = competitors.last.price;
      avgPrice = competitors.fold<double>(0.0, (sum, c) => sum + c.price) / competitors.length;
    } else if (marketProduct != null) {
      minPrice = marketProduct.enDusukFiyat > 0 ? marketProduct.enDusukFiyat : marketProduct.bazSatisFiyati;
      maxPrice = marketProduct.enYuksekFiyat > 0 ? marketProduct.enYuksekFiyat : marketProduct.bazSatisFiyati;
      avgPrice = marketProduct.ortalamaFiyat > 0 ? marketProduct.ortalamaFiyat : marketProduct.bazSatisFiyati;
    }
    final basePrice = marketProduct?.bazSatisFiyati ?? 0.0;

    String priceShortcut(double value) {
      if (value <= 0) return '';
      return value.toStringAsFixed(1);
    }

    double parsePrice(String value) {
      return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }

    final controller = TextEditingController(
      text: slot.price > 0 ? slot.price.toStringAsFixed(1) : '',
    );

    final shortcuts = <NumericKeyboardShortcut>[
      if (slot.cost > 0)
        NumericKeyboardShortcut(
          label: 'Maliyet (₺${slot.cost.toStringAsFixed(1)})',
          value: priceShortcut(slot.cost),
        ),
      if (minPrice > 0)
        NumericKeyboardShortcut(
          label: 'En Düşük (₺${minPrice.toStringAsFixed(1)})',
          value: priceShortcut(minPrice),
        ),
      if (avgPrice > 0)
        NumericKeyboardShortcut(
          label: 'Ortalama (₺${avgPrice.toStringAsFixed(1)})',
          value: priceShortcut(avgPrice),
        ),
      if (slot.price > 0)
        NumericKeyboardShortcut(
          label: 'Mevcut (₺${slot.price.toStringAsFixed(1)})',
          value: priceShortcut(slot.price),
        ),
    ];

    if (!mounted) return;

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardBg,
        insetPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.92,
            maxWidth: 420.w,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Ürün Başlık Bilgisi
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
                  child: Row(
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.w,
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: AppFx.panelWash(0.25),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: BrandedProductImage(
                          fileName: slot.productIcon ?? 'default.webp',
                          brandId: slot.brandId,
                          brandName: hasBrand ? currentBrandName : null,
                          productId: slot.productId,
                          fit: BoxFit.contain,
                          showFrame: false,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (slot.productName ?? 'Ürün') +
                                  (hasBrand ? ' (${currentBrandName ?? 'Markalı'})' : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontSize: AppTypography.bodyLarge,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              children: [
                                for (int i = 0; i < 5; i++)
                                  Icon(
                                    i < slot.qualityLevel
                                        ? AppIcons.starRounded
                                        : AppIcons.starBorderRounded,
                                    color: i < slot.qualityLevel
                                        ? AppColors.gold
                                        : AppFx.softOverlay(0.12),
                                    size: AppIconSizes.xSmall,
                                  ),
                                SizedBox(width: 6.w),
                                Text(
                                  '• ${warehouse.cityName ?? ''} (${slot.quantity} ad.)',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.caption,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppFx.softOverlay(0.1), height: 1),

                // 2. Piyasa Fiyat Özeti Bandı (Hızlı İstatistikler)
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PİYASA FİYATLARI (DOKUN VE EŞİTLE)',
                        style: AppTextStyles.titleGold.standardCopyWith(
                          fontSize: AppTypography.micro,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMarketPriceTile(
                              title: 'En Düşük',
                              price: minPrice,
                              color: AppColors.green,
                              onTap: minPrice > 0
                                  ? () {
                                      AppHaptic.selection();
                                      controller.text = priceShortcut(minPrice);
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: _buildMarketPriceTile(
                              title: 'Ortalama',
                              price: avgPrice,
                              color: AppColors.gold,
                              onTap: avgPrice > 0
                                  ? () {
                                      AppHaptic.selection();
                                      controller.text = priceShortcut(avgPrice);
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: _buildMarketPriceTile(
                              title: 'En Yüksek',
                              price: maxPrice,
                              color: AppColors.red,
                              onTap: maxPrice > 0
                                  ? () {
                                      AppHaptic.selection();
                                      controller.text = priceShortcut(maxPrice);
                                    }
                                  : null,
                            ),
                          ),
                          if (basePrice > 0) ...[
                            SizedBox(width: 6.w),
                            Expanded(
                              child: _buildMarketPriceTile(
                                title: 'Taban (NPC)',
                                price: basePrice,
                                color: AppColors.blue,
                                onTap: () {
                                  AppHaptic.selection();
                                  controller.text = priceShortcut(basePrice);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Rakip Satıcılar Listesi
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
                  child: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PAZARDAKİ DİĞER SATICILAR (${competitors.length})',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: AppTypography.micro,
                              ),
                            ),
                            if (competitors.isNotEmpty)
                              Text(
                                'Fiyata dokunarak kopyala',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: AppTypography.micro,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        if (competitors.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.checkCircle,
                                  size: AppIconSizes.xSmall,
                                  color: AppColors.green,
                                ),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    'Pazarda bu ürünü satan başka rakip yok! Fiyatı istediğiniz gibi belirleyebilirsiniz.',
                                    style: AppTextStyles.caption.standardCopyWith(
                                      color: AppColors.green,
                                      fontSize: AppTypography.micro,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 115.h),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: competitors.length > 8 ? 8 : competitors.length,
                              separatorBuilder: (context, index) => Divider(
                                color: AppFx.softOverlay(0.08),
                                height: 8.h,
                              ),
                              itemBuilder: (context, index) {
                                final comp = competitors[index];
                                final compHasBrand = comp.brandName != null && comp.brandName!.isNotEmpty;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(6.r),
                                  onTap: () {
                                    AppHaptic.selection();
                                    controller.text = priceShortcut(comp.price);
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2.h),
                                    child: Row(
                                      children: [
                                        Icon(
                                          comp.isNpc ? AppIcons.storefrontOutlined : AppIcons.store,
                                          size: AppIconSizes.xSmall,
                                          color: comp.isNpc ? AppColors.blue : AppColors.gold,
                                        ),
                                        SizedBox(width: 6.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comp.sellerPlayerName +
                                                    (compHasBrand ? ' (${comp.brandName})' : ''),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.caption.standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: AppTypography.micro,
                                                ),
                                              ),
                                              Text(
                                                '${comp.cityName} • Q${comp.qualityLevel} • ${comp.quantity} ad.',
                                                style: AppTextStyles.caption.standardCopyWith(
                                                  color: AppColors.textMuted,
                                                  fontSize: AppTypography.micro,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6.r),
                                            border: Border.all(
                                              color: AppColors.gold.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            '₺${comp.price.toStringAsFixed(1)}',
                                            style: AppTextStyles.caption.standardCopyWith(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: AppTypography.caption,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 4. Belirlenen Fiyat & Kâr Marjı Kutusu
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final price = parsePrice(value.text);
                      final profit = slot.cost > 0 ? price - slot.cost : 0.0;
                      final profitPercent = slot.cost > 0
                          ? (profit / slot.cost) * 100
                          : 0.0;
                      final profitColor = slot.cost <= 0
                          ? AppColors.textMuted
                          : profit >= 0
                              ? AppColors.green
                              : AppColors.red;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: AppFx.panelWash(0.3),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Birim Satış Fiyatı',
                                      style: AppTextStyles.body.standardCopyWith(
                                        color: AppColors.gold,
                                        fontSize: AppTypography.micro,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      value.text.isEmpty ? '0.0 ₺' : '₺${value.text}',
                                      style: AppTextStyles.largeTitle.standardCopyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: AppTypography.titleLarge,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (slot.cost > 0)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Maliyet: ₺${slot.cost.toStringAsFixed(1)}',
                                        style: AppTextStyles.caption.standardCopyWith(
                                          color: AppColors.textMuted,
                                          fontSize: AppTypography.micro,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Kâr: ₺${profit.toStringAsFixed(1)} (${profitPercent.toStringAsFixed(0)}%)',
                                        style: AppTextStyles.caption.standardCopyWith(
                                          color: profitColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: AppTypography.caption,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 5. Sayısal Klavye
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  child: NumericKeyboard(
                    controller: controller,
                    allowDecimal: true,
                    shortcuts: shortcuts,
                    buttonHeight: 40.h,
                  ),
                ),

                // 6. Eylem Butonları
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                          ),
                          child: Text(
                            'İptal',
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.body,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final parsed = parsePrice(controller.text);
                            Navigator.pop(dialogContext, parsed > 0 ? parsed : null);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.textOnAccent,
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                          ),
                          child: Text(
                            'Fiyatı Kaydet',
                            style: AppTextStyles.button.standardCopyWith(
                              color: AppColors.textOnAccent,
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null || result <= 0) return;

    final updateRes = await ref.read(warehouseActionProvider).updateWarehouseSlotPrice(
      warehouseSlotId: slot.id,
      price: result,
    );

    if (!mounted) return;

    if (updateRes['success'] == true) {
      ref.read(warehouseListProvider.notifier).patchSlotPrice(
        warehouseId: warehouse.id,
        slotId: slot.id,
        price: result,
      );
      ref.read(warehouseDetailProvider(warehouse.id).notifier).patchSlotPrice(
        slotId: slot.id,
        price: result,
      );
      if (!slot.isAvailableForSale) {
        final saleRes = await ref.read(warehouseActionProvider).setWarehouseSlotSaleStatus(
          warehouseSlotId: slot.id,
          isAvailableForSale: true,
        );
        if (saleRes['success'] == true) {
          ref.read(warehouseListProvider.notifier).patchSlotSaleStatus(
            warehouseId: warehouse.id,
            slotId: slot.id,
            isAvailableForSale: true,
          );
          ref.read(warehouseDetailProvider(warehouse.id).notifier).patchSlotSaleStatus(
            slotId: slot.id,
            isAvailableForSale: true,
          );
        }
      }
      if (!mounted) return;
      if (slot.productId != null && slot.productId!.isNotEmpty) {
        ref.invalidate(marketListingsProvider(slot.productId!));
      } else {
        ref.invalidate(marketListingsProvider);
      }
      AppHaptic.medium();
      AppSnackbar.show(
        context,
        title: 'Fiyat Güncellendi',
        message: '${slot.productName ?? 'Ürün'} birim satış fiyatı ₺${result.toStringAsFixed(1)} olarak pazarlandı.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: updateRes['message']?.toString() ?? 'Fiyat güncellenemedi.',
        type: SnackbarType.error,
      );
    }
  }

  Widget _buildMarketPriceTile({
    required String title,
    required double price,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.micro,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              price > 0 ? '₺${price.toStringAsFixed(1)}' : '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.standardCopyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkListingActionsSheet(
    List<_MyWarehouseSlotEntry> entries,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toplu Pazar İşlemleri',
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.headline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Tüm depolarınızdaki ürünler için hızlı satış eylemleri:',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodySmall,
                ),
              ),
              SizedBox(height: 16.h),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(AppIcons.checkCircle, color: AppColors.green, size: AppIconSizes.small),
                ),
                title: Text(
                  'Fiyatı Olan Tüm Ürünleri Satışa Aç',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
                subtitle: Text(
                  'Fiyatı belirlenmiş ama pasifte duran tüm stokları pazara sunar.',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.micro,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final pricedInactive = entries
                      .where((e) => !e.slot.isAvailableForSale && e.slot.price > 0)
                      .toList();
                  if (pricedInactive.isEmpty) {
                    if (!mounted) return;
                    AppSnackbar.show(
                      context,
                      title: 'Bilgi',
                      message: 'Satışa açılabilecek fiyatı hazır pasif stok bulunamadı.',
                      type: SnackbarType.info,
                    );
                    return;
                  }
                  for (final item in pricedInactive) {
                    await ref.read(warehouseActionProvider).setWarehouseSlotSaleStatus(
                      warehouseSlotId: item.slot.id,
                      isAvailableForSale: true,
                    );
                    ref.read(warehouseListProvider.notifier).patchSlotSaleStatus(
                      warehouseId: item.warehouse.id,
                      slotId: item.slot.id,
                      isAvailableForSale: true,
                    );
                    ref.read(warehouseDetailProvider(item.warehouse.id).notifier).patchSlotSaleStatus(
                      slotId: item.slot.id,
                      isAvailableForSale: true,
                    );
                  }
                  final affectedProductIds = pricedInactive
                      .map((item) => item.slot.productId)
                      .whereType<String>()
                      .where((id) => id.isNotEmpty)
                      .toSet();
                  for (final pid in affectedProductIds) {
                    ref.invalidate(marketListingsProvider(pid));
                  }
                  if (!mounted) return;
                  AppSnackbar.show(
                    context,
                    title: 'Toplu İşlem Tamamlandı',
                    message: '${pricedInactive.length} adet ürün satışa açıldı.',
                    type: SnackbarType.success,
                  );
                },
              ),
              Divider(color: AppFx.softOverlay(0.1)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(AppIcons.pauseCircleOutline, color: AppColors.red, size: AppIconSizes.small),
                ),
                title: Text(
                  'Tüm İlanları Satıştan Çek (Pasife Al)',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
                subtitle: Text(
                  'Tüm pazardaki ilanlarınızı dondurur ve satışa kapatır.',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.micro,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final activeListings = entries
                      .where((e) => e.slot.isAvailableForSale)
                      .toList();
                  if (activeListings.isEmpty) {
                    if (!mounted) return;
                    AppSnackbar.show(
                      context,
                      title: 'Bilgi',
                      message: 'Şu an pazarda aktif satışta ürün bulunmuyor.',
                      type: SnackbarType.info,
                    );
                    return;
                  }
                  for (final item in activeListings) {
                    await ref.read(warehouseActionProvider).setWarehouseSlotSaleStatus(
                      warehouseSlotId: item.slot.id,
                      isAvailableForSale: false,
                    );
                    ref.read(warehouseListProvider.notifier).patchSlotSaleStatus(
                      warehouseId: item.warehouse.id,
                      slotId: item.slot.id,
                      isAvailableForSale: false,
                    );
                    ref.read(warehouseDetailProvider(item.warehouse.id).notifier).patchSlotSaleStatus(
                      slotId: item.slot.id,
                      isAvailableForSale: false,
                    );
                  }
                  final affectedProductIds = activeListings
                      .map((item) => item.slot.productId)
                      .whereType<String>()
                      .where((id) => id.isNotEmpty)
                      .toSet();
                  for (final pid in affectedProductIds) {
                    ref.invalidate(marketListingsProvider(pid));
                  }
                  if (!mounted) return;
                  AppSnackbar.show(
                    context,
                    title: 'Toplu İşlem Tamamlandı',
                    message: '${activeListings.length} adet ürün satıştan çekildi.',
                    type: SnackbarType.success,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNewListingSheet(
    BuildContext context,
    List<WarehouseModel> warehouses,
  ) {
    final unlistedEntries = <_MyWarehouseSlotEntry>[];
    for (final w in warehouses) {
      for (final s in w.slots) {
        if (!s.isAvailableForSale) {
          unlistedEntries.add(_MyWarehouseSlotEntry(warehouse: w, slot: s));
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Satışa Çıkarılacak Stok Seçin',
              style: AppTextStyles.h2.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.headline,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Deponuzdaki bir ürünü seçerek fiyatını belirleyin ve pazara koyun:',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
            ),
            SizedBox(height: 14.h),
            if (unlistedEntries.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Depolarınızdaki tüm stoklar zaten satışta veya deponuzda stok yok.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: unlistedEntries.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8.h),
                  itemBuilder: (_, index) {
                    final entry = unlistedEntries[index];
                    final slot = entry.slot;
                    final warehouse = entry.warehouse;
                    return ListTile(
                      tileColor: AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: AppColors.borderGold.withValues(alpha: 0.15),
                        ),
                      ),
                      leading: Container(
                        width: 40.w,
                        height: 40.w,
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: AppFx.panelWash(0.2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: BrandedProductImage(
                          fileName: slot.productIcon ?? 'default.webp',
                          brandId: slot.brandId,
                          productId: slot.productId,
                          fit: BoxFit.contain,
                          showFrame: false,
                        ),
                      ),
                      title: Text(
                        slot.productName ?? 'Ürün',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTypography.bodySmall,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              for (int i = 0; i < 5; i++)
                                Padding(
                                  padding: EdgeInsets.only(right: 1.w),
                                  child: Icon(
                                    i < slot.qualityLevel
                                        ? AppIcons.starRounded
                                        : AppIcons.starBorderRounded,
                                    color: i < slot.qualityLevel
                                        ? AppColors.gold
                                        : AppFx.softOverlay(0.15),
                                    size: 13.w,
                                  ),
                                ),
                              SizedBox(width: 4.w),
                              Text(
                                'Q${slot.qualityLevel}',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: AppTypography.micro,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${warehouse.cityName ?? ''} • ${warehouse.name} | Stok: ${slot.quantity} ad.',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.micro,
                            ),
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.textOnAccent,
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showMySlotPriceDialog(warehouse, slot);
                        },
                        child: Text(
                          'Pazara Koy',
                          style: AppTextStyles.button.standardCopyWith(
                            color: AppColors.textOnAccent,
                            fontSize: AppTypography.micro,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  String _formatStockNumber(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(1);
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
  int _quantity = 0;

  @override
  void initState() {
    super.initState();
    final isTutorial = ref.read(tutorialProvider).step == TutorialStep.confirmMarketCartBuy;
    _quantity = isTutorial ? 50 : 0;
    _quantityController = TextEditingController(text: isTutorial ? '50' : '');
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
    final cleanValue = value.trim();
    if (cleanValue.isEmpty || cleanValue == '0') {
      setState(() {
        _quantity = 0;
      });
      if (_quantityController.text != '') {
        _quantityController.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }
      return;
    }

    final parsed = int.tryParse(cleanValue) ?? 0;
    final safe = maxQuantity <= 0 ? 0 : parsed.clamp(0, maxQuantity);
    final safeText = safe == 0 ? '' : safe.toString();

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
      color: AppColors.transparent,
      child: Container(
        key: (ref.watch(tutorialProvider).step ==
                TutorialStep.confirmMarketCartBuy)
            ? TutorialKeys.marketAddToCartConfirmKey
            : null,
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
                    style: AppTextStyles.h1.standardCopyWith(fontSize: AppTypography.headline),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    AppIcons.close,
                    color: AppColors.textMuted,
                    size: AppIconSizes.medium,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: _quantityController,
              readOnly: true,
              showCursor: true,
              enableInteractiveSelection: false,
              style: AppTextStyles.input,
              decoration: InputDecoration(
                labelText: 'Miktar',
                labelStyle: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                ),
                helperText: maxQuantity > 0
                    ? 'En fazla $maxQuantity adet ekleyebilirsiniz'
                    : 'Yeterli nakit veya kapasite yok',
                helperStyle: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.label,
                ),
                filled: true,
                fillColor: AppColors.cardBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.gold),
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
                  label: 'Yarı',
                  value: maxQuantity <= 0
                      ? '0'
                      : (maxQuantity / 2)
                            .floor()
                            .clamp(1, maxQuantity)
                            .toString(),
                ),
                NumericKeyboardShortcut(
                  label: 'Tamamı',
                  value: maxQuantity.toString(),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Toplam Tutar:',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₺${totalPrice.toStringAsFixed(1)}',
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.green,
                      fontSize: AppTypography.title,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              height: 42.h,
              child: ElevatedButton(
                onPressed: _quantity <= 0
                    ? null
                    : () {
                        if (ref.read(tutorialProvider).step ==
                            TutorialStep.confirmMarketCartBuy) {
                          ref
                              .read(tutorialProvider.notifier)
                              .setStep(TutorialStep.confirmMarketCheckout);
                        }
                        Navigator.of(context).pop(
                          _MarketCartSelection(
                            listing: widget.listing,
                            quantity: _quantity,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'SEPETE EKLE',
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
    );
  }
}

class _PurchaseSheetState extends ConsumerState<_PurchaseSheet> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
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
                    style: AppTextStyles.h1.standardCopyWith(fontSize: AppTypography.displaySmall),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    AppIcons.close,
                    color: AppColors.textMuted,
                    size: AppIconSizes.medium,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Eski tekli market satın alma akışı devre dışı bırakıldı. Yeni sistemde alımlar çoklu sepet akışı üzerinden ilerliyor.',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                ),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Set<String> _calculateSellingProductIds({
  required List<StoreModel> stores,
  required WarehouseModel? selectedWarehouse,
}) {
  List<StoreModel> targetStores;
  if (selectedWarehouse != null) {
    if (selectedWarehouse.warehouseKind == 'store') {
      final linkedStore = stores.where((s) => s.id == selectedWarehouse.storeId).firstOrNull;
      targetStores = linkedStore != null ? [linkedStore] : [];
    } else {
      targetStores = stores.where((s) => s.isActive && s.cityId == selectedWarehouse.cityId).toList();
    }
  } else {
    targetStores = stores.where((s) => s.isActive).toList();
  }

  final sellingIds = <String>{};
  for (final store in targetStores) {
    for (final slot in store.slots) {
      if (slot.isActive && (slot.productId ?? '').isNotEmpty && slot.qualityLevel > 0) {
        sellingIds.add(slot.productId!);
      }
    }
  }
  return sellingIds;
}

Map<String, int> _calculateStoreNeeds({
  required List<StoreModel> stores,
  required WarehouseModel? selectedWarehouse,
}) {
  final result = <String, int>{};

  List<StoreModel> targetStores;
  if (selectedWarehouse != null) {
    if (selectedWarehouse.warehouseKind == 'store') {
      final linkedStore = stores.where((s) => s.id == selectedWarehouse.storeId).firstOrNull;
      targetStores = linkedStore != null ? [linkedStore] : [];
    } else {
      targetStores = stores.where((s) => s.isActive && s.cityId == selectedWarehouse.cityId).toList();
    }
  } else {
    targetStores = stores.where((s) => s.isActive).toList();
  }

  final grossDemandByProduct = <String, int>{};
  for (final store in targetStores) {
    for (final slot in store.slots) {
      final productId = slot.productId;
      if (!slot.isActive || productId == null || productId.isEmpty) continue;
      if (slot.qualityLevel <= 0) continue;

      final freeSlotCap = slot.capacity - slot.quantity - slot.pendingQuantity;
      if (freeSlotCap > 0) {
        grossDemandByProduct.update(
          productId,
          (val) => val + freeSlotCap,
          ifAbsent: () => freeSlotCap,
        );
      }
    }
  }

  grossDemandByProduct.forEach((productId, grossDemand) {
    int availableInWarehouse = 0;
    if (selectedWarehouse != null) {
      for (final slot in selectedWarehouse.slots) {
        if (slot.productId == productId) {
          availableInWarehouse += slot.quantity;
        }
      }
    }
    final netDemand = math.max(0, grossDemand - availableInWarehouse);
    if (netDemand > 0) {
      result[productId] = netDemand;
    }
  });

  return result;
}

Map<String, int> _calculateProductionNeeds({
  required List<FactoryListItemModel> factories,
  required List<FarmListItemModel> farms,
  required List<FieldListItemModel> fields,
  required List<ProductModel> allProducts,
  required WarehouseModel? selectedWarehouse,
}) {
  final grossProductionDemand = <String, int>{};

  final targetFactories = selectedWarehouse != null
      ? factories.where((f) => f.factory.cityId == selectedWarehouse.cityId).toList()
      : factories;
  final targetFarms = selectedWarehouse != null
      ? farms.where((f) => f.farm.cityId == selectedWarehouse.cityId).toList()
      : farms;
  final targetFields = selectedWarehouse != null
      ? fields.where((f) => f.field.cityId == selectedWarehouse.cityId).toList()
      : fields;

  for (final f in targetFactories) {
    final pId = f.selectedProduct?.id;
    if (pId == null || pId.isEmpty) continue;
    final product = allProducts.where((p) => p.id == pId).firstOrNull;
    if (product == null || product.inputProductIds.isEmpty) continue;

    final freeCap = math.max(0, f.factory.inputCapacity - f.inputStockQuantity);
    if (freeCap <= 0) continue;

    final rawMaterials = <(String, double)>[];
    if ((product.hammadde1Id ?? '').isNotEmpty && (product.hammadde1Miktar ?? 0) > 0) {
      rawMaterials.add((product.hammadde1Id!, product.hammadde1Miktar!));
    }
    if ((product.hammadde2Id ?? '').isNotEmpty && (product.hammadde2Miktar ?? 0) > 0) {
      rawMaterials.add((product.hammadde2Id!, product.hammadde2Miktar!));
    }
    if ((product.hammadde3Id ?? '').isNotEmpty && (product.hammadde3Miktar ?? 0) > 0) {
      rawMaterials.add((product.hammadde3Id!, product.hammadde3Miktar!));
    }

    if (rawMaterials.isNotEmpty) {
      final totalRecipeSum = rawMaterials.fold<double>(0.0, (sum, r) => sum + r.$2);
      for (final raw in rawMaterials) {
        final proportion = totalRecipeSum > 0 ? (raw.$2 / totalRecipeSum) : (1.0 / rawMaterials.length);
        final needUnits = (freeCap * proportion).round();
        if (needUnits > 0) {
          grossProductionDemand.update(
            raw.$1,
            (val) => val + needUnits,
            ifAbsent: () => needUnits,
          );
        }
      }
    } else {
      final count = product.inputProductIds.length;
      final perItem = (freeCap / count).round();
      for (final inputId in product.inputProductIds) {
        grossProductionDemand.update(
          inputId,
          (val) => val + perItem,
          ifAbsent: () => perItem,
        );
      }
    }
  }

  for (final f in targetFarms) {
    final freeCap = math.max(0, f.farm.inputCapacity - f.inputStockQuantity);
    if (freeCap <= 0) continue;

    final distinctInputIds = <String>{};
    for (final slot in f.slots) {
      if (slot.isActive && slot.productId != null && slot.productId!.isNotEmpty) {
        final product = allProducts.where((p) => p.id == slot.productId).firstOrNull;
        if (product != null) {
          distinctInputIds.addAll(product.inputProductIds);
        }
      }
    }

    if (distinctInputIds.isNotEmpty) {
      final perItem = (freeCap / distinctInputIds.length).round();
      for (final inputId in distinctInputIds) {
        grossProductionDemand.update(
          inputId,
          (val) => val + perItem,
          ifAbsent: () => perItem,
        );
      }
    }
  }

  for (final f in targetFields) {
    final freeCap = math.max(0, f.field.inputCapacity - f.inputStockQuantity);
    if (freeCap <= 0) continue;

    final distinctInputIds = <String>{};
    for (final slot in f.slots) {
      if (slot.isActive && slot.productId != null && slot.productId!.isNotEmpty) {
        final product = allProducts.where((p) => p.id == slot.productId).firstOrNull;
        if (product != null) {
          distinctInputIds.addAll(product.inputProductIds);
        }
      }
    }

    if (distinctInputIds.isNotEmpty) {
      final perItem = (freeCap / distinctInputIds.length).round();
      for (final inputId in distinctInputIds) {
        grossProductionDemand.update(
          inputId,
          (val) => val + perItem,
          ifAbsent: () => perItem,
        );
      }
    }
  }

  final netProductionDemand = <String, int>{};
  grossProductionDemand.forEach((productId, grossNeed) {
    int availableInWarehouse = 0;
    if (selectedWarehouse != null) {
      for (final slot in selectedWarehouse.slots) {
        if (slot.productId == productId) {
          availableInWarehouse += slot.quantity;
        }
      }
    }
    final netNeed = math.max(0, grossNeed - availableInWarehouse);
    if (netNeed > 0) {
      netProductionDemand[productId] = netNeed;
    }
  });

  return netProductionDemand;
}

double _resolvePriceDeltaPercent(ProductModel? product, double listingPrice) {
  final basePrice = product?.bazSatisFiyati ?? 0;
  if (basePrice <= 0) return 0;
  return ((listingPrice - basePrice) / basePrice) * 100;
}

(String, Color)? _buildPriceDeltaBadge(double deltaPercent) {
  if (deltaPercent <= -3) {
    final absPercent = deltaPercent.abs().toStringAsFixed(0);
    return ('%$absPercent Ucuz', AppColors.green);
  } else if (deltaPercent >= 3) {
    final absPercent = deltaPercent.toStringAsFixed(0);
    return ('%$absPercent Pahalı', AppColors.red);
  } else {
    return ('Normal', AppColors.gold);
  }
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/auth/models/player_model.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String playerId;

  const PublicProfileScreen({super.key, required this.playerId});

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProfileProvider(widget.playerId));
    final listingsAsync = ref.watch(
      playerMarketListingsProvider(widget.playerId),
    );

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
        onItemSelected: (_) {},
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Oyuncu Profili'),
            Expanded(
              child: profileAsync.when(
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (err, _) => Center(
                  child: Text(
                    'Oyuncu bilgileri alinamadi.\n$err',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (player) {
                  if (player == null) {
                    return Center(
                      child: Text(
                        'Oyuncu bulunamadi.',
                        style: AppTextStyles.body,
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(publicProfileProvider(widget.playerId));
                      ref.invalidate(
                        playerMarketListingsProvider(widget.playerId),
                      );
                    },
                    color: AppColors.gold,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPlayerHeader(player),
                          SizedBox(height: 16.h),
                          _buildCompanyDetails(player),
                          SizedBox(height: 20.h),
                          _buildFeaturedBadges(player),
                          SizedBox(height: 24.h),
                          Text(
                            'Satistaki Urunleri 📦',
                            style: AppTextStyles.h2.standardCopyWith(
                              color: AppColors.gold,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          listingsAsync.when(
                            loading: () => Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: AppLoadingIndicator(
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                            error: (err, _) => Text(
                              'Urun listesi alinamadi: $err',
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.red,
                              ),
                            ),
                            data: (listings) {
                              if (listings.isEmpty) {
                                return _buildEmptyListings();
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: listings.length,
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: 10.h),
                                itemBuilder: (context, index) {
                                  final listing = listings[index];
                                  return _buildListingCard(listing);
                                },
                              );
                            },
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
    );
  }

  Widget _buildPlayerHeader(PlayerModel player) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.gold.withValues(alpha: 0.1), AppColors.cardBg],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBgLight,
              border: Border.all(color: AppColors.gold, width: 2.w),
            ),
            child: ClipOval(
              child: player.avatarId.startsWith('http')
                  ? Image.network(
                      player.avatarId,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          CachedAssetImage(
                            fileName: 'ae1.webp',
                            fit: BoxFit.cover,
                          ),
                    )
                  : CachedAssetImage(
                      fileName: player.avatarId,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.playerName,
                        style: AppTextStyles.h1.standardCopyWith(
                          fontSize: AppTypography.headline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        'Sv.${player.level}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: AppTypography.micro,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  player.companyName,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6.h),
                // XP Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: AppProgressBar(
                        value: player.expProgressRatio,
                        size: AppProgressSize.compact,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${player.currentLevelExperience}/${player.nextLevelRequiredExperience} XP',
                      style: AppTextStyles.caption.standardCopyWith(
                        fontSize: AppTypography.micro,
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

  Widget _buildCompanyDetails(PlayerModel player) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sirket Degeri', style: AppTextStyles.caption),
              SizedBox(height: 2.h),
              Text(
                AppMoney.compact(player.companyValue),
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(height: 30.h, width: 1.w, color: AppColors.border),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Katilma Tarihi', style: AppTextStyles.caption),
              SizedBox(height: 2.h),
              Text(
                '${player.createdAt.day}.${player.createdAt.month}.${player.createdAt.year}',
                style: AppTextStyles.body.standardCopyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBadges(PlayerModel player) {
    if (player.featuredBadges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vitrin Rozetleri 🏆',
          style: AppTextStyles.h2.standardCopyWith(color: AppColors.gold),
        ),
        SizedBox(height: 8.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.w,
            childAspectRatio: 0.95,
          ),
          itemCount: player.featuredBadges.length,
          itemBuilder: (context, index) {
            final badge = player.featuredBadges[index];
            final color = _badgeColor(badge.badgeColor);
            return Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      width: 26.w,
                      height: 26.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        _badgeIcon(badge.badgeKey),
                        color: color,
                        size: AppIconSizes.small,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    badge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.standardCopyWith(
                      fontSize: AppTypography.micro,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildEmptyListings() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.storeMallDirectoryOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.displayLarge,
          ),
          SizedBox(height: 8.h),
          Text(
            'Oyuncunun satista aktif urunu bulunmuyor.',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(MarketListingModel listing) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.border),
            ),
            child: CachedAssetImage(
              fileName: listing.productIcon,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        listing.productName,
                        style: AppTextStyles.body.standardCopyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        'Q${listing.qualityLevel}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: AppTypography.micro,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  'Stok: ${listing.quantity} adet',
                  style: AppTextStyles.caption,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Konum: ${listing.cityName} (${listing.warehouseName})',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppMoney.full(listing.price),
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              ElevatedButton(
                onPressed: () => _openPurchaseSheet(listing),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.textOnAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                child: Text(
                  'Satin Al',
                  style: AppTextStyles.button.standardCopyWith(
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPurchaseSheet(MarketListingModel listing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      barrierColor: AppFx.scrim(0.6),
      builder: (sheetContext) =>
          _PurchaseBottomSheet(listing: listing, ref: ref),
    ).then((_) {
      ref.invalidate(playerMarketListingsProvider(widget.playerId));
    });
  }

  IconData _badgeIcon(String key) {
    switch (key) {
      case 'store':
        return AppIcons.storefrontRounded;
      case 'warehouse':
        return AppIcons.warehouseRounded;
      case 'factory':
        return AppIcons.precisionManufacturingRounded;
      case 'field':
      case 'farm':
        return AppIcons.agricultureRounded;
      case 'mine':
        return AppIcons.landscapeRounded;
      case 'builder':
        return AppIcons.handymanRounded;
      case 'trade':
        return AppIcons.pointOfSaleRounded;
      case 'truck':
        return AppIcons.localShippingRounded;
      case 'science':
        return AppIcons.scienceRounded;
      case 'upgrade':
        return AppIcons.trendingUpRounded;
      case 'crown':
        return AppIcons.workspacePremiumRounded;
      default:
        return AppIcons.militaryTechRounded;
    }
  }

  Color _badgeColor(String key) {
    return AppColorPresets.badge(key);
  }
}

class _PurchaseBottomSheet extends StatefulWidget {
  final MarketListingModel listing;
  final WidgetRef ref;

  const _PurchaseBottomSheet({required this.listing, required this.ref});

  @override
  State<_PurchaseBottomSheet> createState() => _PurchaseBottomSheetState();
}

class _PurchaseBottomSheetState extends State<_PurchaseBottomSheet> {
  WarehouseModel? _selectedWarehouse;
  int _quantity = 1;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = widget.ref.watch(warehouseListProvider);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: AppDecorations.panelGlass(24.r),
          padding: EdgeInsets.fromLTRB(
            16.w,
            16.h,
            16.w,
            MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Urun Satin Al', style: AppTextStyles.h1),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      AppIcons.close,
                      color: AppColors.textMuted,
                      size: AppIconSizes.medium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Listing summary
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CachedAssetImage(
                      fileName: widget.listing.productIcon,
                      width: 32.w,
                      height: 32.w,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.listing.productName,
                            style: AppTextStyles.body.standardCopyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Satici: ${widget.listing.sellerPlayerName}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppMoney.full(widget.listing.price),
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Stok: ${widget.listing.quantity}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text('Hedef Depo Secin 🏢', style: AppTextStyles.h2),
              SizedBox(height: 8.h),
              warehousesAsync.when(
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (err, _) => Text(
                  'Depolar yuklenemedi: $err',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.red,
                  ),
                ),
                data: (warehouses) {
                  if (warehouses.isEmpty) {
                    return Text(
                      'Satin alinan urunu koyacak bir deponuz bulunmuyor!',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                      ),
                    );
                  }
                  _selectedWarehouse ??= warehouses.firstWhere(
                    (w) => w.cityId == widget.listing.cityId,
                    orElse: () => warehouses.first,
                  );
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<WarehouseModel>(
                        value: _selectedWarehouse,
                        dropdownColor: AppColors.cardBgLight,
                        isExpanded: true,
                        icon: Icon(
                          AppIcons.arrowDropDown,
                          color: AppColors.gold,
                        ),
                        items: warehouses.map((w) {
                          final isSameCity = w.cityId == widget.listing.cityId;
                          return DropdownMenuItem<WarehouseModel>(
                            value: w,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${w.name} (${w.cityName})',
                                  style: AppTextStyles.body,
                                ),
                                if (isSameCity)
                                  Text(
                                    'Yerel (Anlik Alim)',
                                    style: AppTextStyles.caption
                                        .standardCopyWith(
                                          color: AppColors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: AppTypography.micro,
                                        ),
                                  )
                                else
                                  Text(
                                    'Farkli Sehir',
                                    style: AppTextStyles.caption
                                        .standardCopyWith(
                                          color: AppColors.gold,
                                          fontSize: AppTypography.micro,
                                        ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedWarehouse = val;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Miktar', style: AppTextStyles.h2),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: Icon(
                          AppIcons.removeCircleOutline,
                          color: AppColors.gold,
                        ),
                      ),
                      Text(
                        '$_quantity',
                        style: AppTextStyles.title.standardCopyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _quantity < widget.listing.quantity
                            ? () => setState(() => _quantity++)
                            : null,
                        icon: Icon(
                          AppIcons.addCircleOutline,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Slider(
                value: _quantity.toDouble(),
                min: 1,
                max: widget.listing.quantity.toDouble(),
                activeColor: AppColors.gold,
                inactiveColor: AppColors.cardBgLight,
                onChanged: (val) {
                  setState(() {
                    _quantity = val.toInt();
                  });
                },
              ),
              SizedBox(height: 14.h),
              Divider(color: AppColors.border),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Toplam Tutar', style: AppTextStyles.body),
                  Text(
                    AppMoney.full(widget.listing.price * _quantity),
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading || _selectedWarehouse == null
                      ? null
                      : _submitPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.textOnAccent,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: AppLoadingIndicator(
                            color: AppColors.textOnAccent,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Satinalmayi Onayla',
                          style: AppTextStyles.button.standardCopyWith(
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

  Future<void> _submitPurchase() async {
    if (_selectedWarehouse == null) return;
    final targetWarehouse = _selectedWarehouse!;
    final isSameCity = targetWarehouse.cityId == widget.listing.cityId;

    if (isSameCity) {
      await _executePurchaseTransfer(null);
    } else {
      await _showIntercityVehiclePicker(targetWarehouse);
    }
  }

  Future<void> _showIntercityVehiclePicker(
    WarehouseModel targetWarehouse,
  ) async {
    setState(() {
      _loading = true;
    });

    final totalVolume = _quantity * widget.listing.unitVolume;

    try {
      final vehicleResult = await widget.ref
          .read(marketActionProvider)
          .getIntercityVehicleOptions(
            sourceCityId: widget.listing.cityId,
            targetCityId: targetWarehouse.cityId,
            totalVolume: totalVolume,
          );

      setState(() {
        _loading = false;
      });

      final options = vehicleResult.options;
      if (options.isEmpty) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          title: 'Arac Yok',
          message: 'Sehirler arasi alim icin bosta arac bulunamadi.',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Arac Secin', style: AppTextStyles.h1),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: Icon(
                      AppIcons.close,
                      color: AppColors.textMuted,
                      size: AppIconSizes.medium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                '${widget.listing.cityName} -> ${targetWarehouse.cityName} | ${totalVolume.toStringAsFixed(1)} m3',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodyLarge,
                ),
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
                              Navigator.pop(sheetContext);
                              await _executePurchaseTransfer(option.vehicleId);
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
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'Arac secenekleri alinamadi: $e',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _executePurchaseTransfer(String? vehicleId) async {
    if (_selectedWarehouse == null) return;
    setState(() {
      _loading = true;
    });

    final targetWarehouse = _selectedWarehouse!;
    final isSameCity = targetWarehouse.cityId == widget.listing.cityId;

    final items = [
      {'seller_slot_id': widget.listing.slotId, 'quantity': _quantity},
    ];

    try {
      final result = await widget.ref
          .read(marketActionProvider)
          .startMultiMarketTransfer(
            buyerWarehouseId: targetWarehouse.id,
            sourceCityId: widget.listing.cityId,
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
        setState(() {
          _loading = false;
        });
        return;
      }

      final isInstant =
          result['mode']?.toString() == 'instant' ||
          (isSameCity && vehicleId == null);
      if (isInstant && result['transfer_id'] != null) {
        final completeResult = await widget.ref
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
          setState(() {
            _loading = false;
          });
          return;
        }
      }

      // Success
      if (!mounted) return;
      FloatingFeedback.show(
        context,
        amount: widget.listing.price * _quantity,
        type: FloatingFeedbackType.cashRemove,
      );
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: isInstant
            ? 'Satin alma islemi aninda tamamlandi!'
            : 'Satin alma islemi baslatildi. Arac yola cikti!',
        type: SnackbarType.success,
      );
      widget.ref.invalidate(warehouseListProvider);
      widget.ref.invalidate(playerProvider);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString(),
        type: SnackbarType.error,
      );
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatTransferDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${minutes}dk';
  }
}

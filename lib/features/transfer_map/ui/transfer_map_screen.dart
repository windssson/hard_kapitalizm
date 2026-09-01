import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_ad_action_flow.dart';
import 'package:hard_kapitalizm/core/ads/transfer_finish_rewarded_ad_service.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_history_item_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_management_screen.dart';
import 'package:hard_kapitalizm/features/transfer_map/ui/widgets/consolidated_transfer_sheet.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/consolidated_transfer_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/player_facility_city_model.dart';
import 'package:city_picker_from_map/city_picker_from_map.dart';
// ignore: implementation_imports
import 'package:city_picker_from_map/src/parser.dart';
// ignore: implementation_imports
import 'package:city_picker_from_map/src/size_controller.dart';

class TransferMapScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const TransferMapScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<TransferMapScreen> createState() => _TransferMapScreenState();
}

class _TransferMapScreenState extends ConsumerState<TransferMapScreen> {
  final int _selectedIndex = 2;
  List<City> _cityList = [];
  bool _isLoadingMap = true;
  late TransformationController _transformationController;
  bool _hasCenteredMap = false;

  String _normalizeString(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  Future<void> _loadCityList() async {
    try {
      final list = await Parser.instance.svgToCityList(Maps.TURKEY);
      if (!mounted) return;
      setState(() {
        _cityList = list;
        _isLoadingMap = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMap = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _transformationController = TransformationController();
    _loadCityList();
  }

  @override
  void didUpdateWidget(TransferMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _selectedTab = widget.initialTab;
      });
    }
  }

  late int _selectedTab;
  String? _selectedTransferId;
  String? _expandedHistoryId;
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final Map<String, GlobalKey> _transferCardKeys = {};

  PlayerFacilityCityModel? _calloutCity;
  Offset? _calloutCityPos;
  TransferMapItemModel? _calloutTransfer;
  Offset? _calloutTransferPos;
  int _cityCalloutTab = 0; // 0: Tümü, 1: İşletmeler, 2: Stoklar

  void _openCityCallout(PlayerFacilityCityModel city, Offset svgPos) {
    AppHaptic.medium();
    setState(() {
      _cityCalloutTab = 0;
      _calloutCity = city;
      _calloutCityPos = svgPos;
      _calloutTransfer = null;
      _calloutTransferPos = null;
    });
  }

  void _openTransferCallout(TransferMapItemModel transfer, Offset svgPos) {
    AppHaptic.medium();
    setState(() {
      _calloutTransfer = transfer;
      _calloutTransferPos = svgPos;
      _calloutCity = null;
      _calloutCityPos = null;
      _selectedTransferId = transfer.id;
    });
  }

  void _dismissCallout() {
    if (_calloutCity != null || _calloutTransfer != null) {
      setState(() {
        _calloutCity = null;
        _calloutCityPos = null;
        _calloutTransfer = null;
        _calloutTransferPos = null;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _activeScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
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
      case 3:
        context.go('/market');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  String _transferTitle({
    required bool isMultiItem,
    required String productName,
    required int itemCount,
  }) {
    if (!isMultiItem) return productName;
    return 'Coklu Sevkiyat ($itemCount kalem)';
  }

  String _transferQuantitySummary({
    required int quantity,
    required bool isMultiItem,
    required int itemCount,
  }) {
    if (!isMultiItem) return '$quantity adet';
    return '$quantity adet | $itemCount kalem';
  }

  String _transferRouteSummary({
    required String sourceName,
    required String sourceKind,
    required String targetName,
    required String targetKind,
  }) {
    return '$sourceKind: $sourceName -> $targetKind: $targetName';
  }

  Widget _buildTransferAvatar({
    required bool isMultiItem,
    required String productIcon,
    required String? brandName,
    required int itemCount,
    required Color accentColor,
    String? brandId,
    String? productId,
  }) {
    return Container(
      width: 48.w,
      height: 48.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: isMultiItem
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    AppIcons.inventory2Outlined,
                    color: accentColor,
                    size: AppIconSizes.mediumLarge,
                  ),
                ),
                Positioned(
                  right: -4.w,
                  top: -4.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '$itemCount',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textOnAccent,
                        fontSize: AppTypography.caption,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : BrandedProductImage(
              fileName: productIcon,
              brandId: brandId,
              brandName: brandName,
              productId: productId,
              fit: BoxFit.contain,
              showFrame: false,
            ),
    );
  }

  Future<void> _showTransferInfo(TransferMapItemModel transfer) async {
    final accentColor = transfer.isRental ? AppColors.warning : AppColors.gold;
    final routeDistanceKm = _estimateRouteDistanceKm(
      transfer.sellerWarehouse.city,
      transfer.buyerWarehouse.city,
    );
    final totalCost = transfer.totalPrice + transfer.transportCost;
    final unitCost = transfer.displayQuantity > 0
        ? totalCost / transfer.displayQuantity
        : 0.0;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 24.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560.w,
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
            child: Consumer(
              builder: (context, ref, _) {
                final now =
                    ref.watch(secondTickerProvider).value ?? DateTime.now();
                final remaining = transfer.finishAt.difference(now);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            transfer.isRental
                                ? AppIcons.localShipping
                                : AppIcons.directionsCar,
                            color: accentColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _transferTitle(
                                  isMultiItem: transfer.isMultiItem,
                                  productName: transfer.product.name,
                                  itemCount: transfer.itemCount,
                                ),
                                style: AppTextStyles.h2.standardCopyWith(
                                  fontSize: AppTypography.headline,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Transfer Detaylari',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: AppTypography.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            AppIcons.closeRounded,
                            color: AppColors.textMuted,
                            size: AppIconSizes.medium,
                          ),
                          splashRadius: 20.r,
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: AppFx.panelWash(0.2),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: AppFx.softOverlay(0.05),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildDialogInfoRow(
                                    AppIcons.myLocation,
                                    'Cikis (${transfer.sellerKindLabel})',
                                    '${transfer.sellerWarehouse.name} | ${transfer.sellerWarehouse.city.name}',
                                  ),
                                  Divider(
                                    color: AppFx.softOverlay(0.1),
                                    height: 22.h,
                                  ),
                                  _buildDialogInfoRow(
                                    AppIcons.locationOn,
                                    'Varis (${transfer.buyerKindLabel})',
                                    '${transfer.buyerWarehouse.name} | ${transfer.buyerWarehouse.city.name}',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 14.h),
                            _buildDialogDetailRow(
                              'Miktar',
                              _transferQuantitySummary(
                                quantity: transfer.displayQuantity,
                                isMultiItem: transfer.isMultiItem,
                                itemCount: transfer.itemCount,
                              ),
                            ),
                            if (!transfer.isMultiItem) ...[
                              _buildDialogDetailRow(
                                'Kalite',
                                'Kalite ${transfer.qualityLevel}',
                              ),
                              _buildDialogDetailRow(
                                'Brand',
                                transfer.hasBrand
                                    ? 'Markalı Ürün'
                                    : 'Standart Brand',
                              ),
                            ],
                            if (transfer.isMultiItem)
                              _buildDialogDetailRow(
                                'Kalem Sayisi',
                                '${transfer.itemCount} farklı ürün',
                              ),
                            _buildDialogDetailRow(
                              'Nakliye Tipi',
                              transfer.isRental ? 'Kiralık Araç' : 'Özmal Araç',
                            ),
                            _buildDialogDetailRow(
                              'Rota',
                              _isSameCityTransfer(transfer)
                                  ? 'Aynı Şehir'
                                  : 'Şehirler Arası',
                            ),
                            _buildDialogDetailRow(
                              'Mesafe',
                              '${routeDistanceKm.toStringAsFixed(0)} km',
                            ),
                            _buildDialogDetailRow(
                              'Ürün Bedeli',
                              _formatCurrency(transfer.totalPrice),
                            ),
                            _buildDialogDetailRow(
                              'Kira Bedeli',
                              _formatCurrency(transfer.rentalCost),
                            ),
                            _buildDialogDetailRow(
                              'Nakliye Maliyeti',
                              _formatCurrency(transfer.transportCost),
                            ),
                            _buildDialogDetailRow(
                              'Toplam Maliyet',
                              _formatCurrency(totalCost),
                            ),
                            _buildDialogDetailRow(
                              'Birim Maliyet',
                              _formatCurrency(unitCost),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    AppIcons.timerOutlined,
                                    color: accentColor,
                                    size: AppIconSizes.compact,
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      'Kalan Süre: ${_formatRemaining(remaining)}',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.body
                                          .standardCopyWith(
                                            color: accentColor,
                                            fontSize: AppTypography.title,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (remaining.inSeconds > 0) ...[
                              SizedBox(height: 12.h),
                              GoldFinishButton(
                                starCost: (remaining.inSeconds / 600.0).ceil(),
                                onPressed: () {
                                  final starCost = (remaining.inSeconds / 600.0)
                                      .ceil();
                                  _confirmFinishWithStars(
                                    context,
                                    ref,
                                    transfer,
                                    starCost,
                                  );
                                },
                              ),
                              if (_canFinishWithRewardedAd(remaining)) ...[
                                SizedBox(height: 10.h),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44.h,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _finishTransferWithRewardedAd(
                                          context,
                                          ref,
                                          transfer,
                                          remaining,
                                        ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.gold,
                                      side: BorderSide(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                      backgroundColor: AppColors.gold
                                          .withValues(alpha: 0.08),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                    ),
                                    icon: Icon(
                                      AppIcons.playCircleFill,
                                      size: AppIconSizes.regular,
                                    ),
                                    label: Text(
                                      'Reklam izle ve hemen bitir',
                                      style: AppTextStyles.button
                                          .standardCopyWith(
                                            color: AppColors.gold,
                                            fontSize: AppTypography.bodyLarge,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Sadece son 10 dakika icindeki transferlerde aktif olur.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.bodySmall,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmFinishWithStars(
    BuildContext context,
    WidgetRef ref,
    TransferMapItemModel transfer,
    int starCost,
  ) async {
    final player = ref.read(playerProvider).value;
    final currentGold = player?.gold ?? 0;

    if (currentGold < starCost) {
      AppSnackbar.show(
        context,
        title: 'Yetersiz Yıldız',
        message:
            'Bu işlemi gerçekleştirmek için yeterli yıldızınız yok. Gerekli: $starCost, Mevcut: ${currentGold.toInt()}',
        type: SnackbarType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(
              AppIcons.starRounded,
              color: AppColors.gold,
              size: AppIconSizes.large,
            ),
            SizedBox(width: 8.w),
            Text(
              'Hemen Bitir',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Bu transferi $starCost ⭐ harcayarak anında tamamlamak istiyor musunuz?\n\nMevcut Yıldızınız: ${currentGold.toInt()}',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgeç',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.title,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
            ),
            child: Text(
              'Tamamla',
              style: AppTextStyles.body.standardCopyWith(
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: AppLoadingIndicator(color: AppColors.gold)),
    );

    try {
      final result = await ref
          .read(warehouseActionProvider)
          .finishLogisticsTransferWithGold(transfer.id);

      if (context.mounted) {
        Navigator.of(context).pop(); // Pop loading dialog
      }

      if (result['success'] == true) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Pop details dialog
        }

        ref.read(buyerTransferMapProvider.notifier).patchRemoveTransfer(transfer.id);
        ref.read(buyerTransferHistoryProvider.notifier).refresh();
        ref.invalidate(warehouseListProvider);
        _invalidateAffectedTransferTargets(transfer);

        if (context.mounted) {
          AppSnackbar.show(
            context,
            title: 'Başarılı',
            message: 'Transfer yıldız kullanılarak anında tamamlandı!',
            type: SnackbarType.success,
          );
        }
      } else {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message:
                result['message'] ?? 'Transfer tamamlanırken bir hata oluştu.',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Pop loading dialog
      }
      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    }
  }

  bool _canFinishWithRewardedAd(Duration remaining) {
    return remaining.inSeconds > 0 &&
        remaining <= TransferFinishRewardedAdService.maxEligibleRemaining;
  }

  Future<void> _finishTransferWithRewardedAd(
    BuildContext context,
    WidgetRef ref,
    TransferMapItemModel transfer,
    Duration remaining,
  ) async {
    if (!_canFinishWithRewardedAd(remaining)) {
      AppSnackbar.show(
        context,
        title: 'Reklamla Hızlı Bitir Kilitli',
        message:
            'Bu özellik sadece transferin bitmesine 10 dakika veya daha az kaldıysa kullanılabilir.',
        type: SnackbarType.warning,
      );
      return;
    }

    final success = await RewardedAdActionFlow.run(
      context,
      rewardKind: 'transfer_finish',
      resourceId: transfer.id,
      loadingMessage: 'Google AdMob test reklamı yükleniyor.',
      successTitle: 'Transfer Tamamlandı',
      successMessage: 'Reklam ödülü kullanıldı ve transfer anında tamamlandı.',
      onApplyAction: () async {
        final result = await ref
            .read(warehouseActionProvider)
            .finishLogisticsTransferWithAdReward(transfer.id);

        if (result['success'] == true) {
          ref.read(buyerTransferMapProvider.notifier).patchRemoveTransfer(transfer.id);
          ref.read(buyerTransferHistoryProvider.notifier).refresh();
          ref.invalidate(warehouseListProvider);
          _invalidateAffectedTransferTargets(transfer);
        }

        return result;
      },
    );

    if (success && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _invalidateAffectedTransferTargets(TransferMapItemModel transfer) {
    try {
      final buyerId = transfer.buyerEndpoint.id;
      final kind = transfer.buyerEndpoint.kind;
      if (buyerId.isNotEmpty) {
        if (kind == 'warehouse') {
          ref.invalidate(warehouseDetailProvider(buyerId));
        } else if (kind == 'store' || kind == 'store_slot') {
          ref.invalidate(storeDetailPageProvider(buyerId));
        }
      }
    } catch (_) {}
  }

  Widget _buildDialogInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.gold, size: AppIconSizes.compact),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodyLarge,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.w600,
              ),
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
    final facilityCitiesAsync = ref.watch(playerFacilityCitiesProvider);
    final facilityCities = facilityCitiesAsync.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Lojistik'),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
              child: _buildModeSelector(),
            ),
            Expanded(
              child: _selectedTab == 0
                  ? transfersAsync.when(
                      data: (transfers) {
                        _pruneTransferCardKeys(transfers);
                        TransferMapItemModel? selectedTransfer;
                        if (transfers.isNotEmpty) {
                          for (final item in transfers) {
                            if (item.id == _selectedTransferId) {
                              selectedTransfer = item;
                              break;
                            }
                          }
                          selectedTransfer ??= transfers.first;
                        }
                        final dueCount = transfers
                            .where(
                              (transfer) =>
                                  !transfer.finishAt.isAfter(DateTime.now()),
                            )
                            .length;

                        return RefreshIndicator(
                          onRefresh: () async {
                            await ref.read(buyerTransferMapProvider.notifier).refresh();
                            await ref.read(buyerTransferHistoryProvider.notifier).refresh();
                            ref.invalidate(playerFacilityCitiesProvider);
                          },
                          child: CustomScrollView(
                            controller: _activeScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    12.w,
                                    4.h,
                                    12.w,
                                    0,
                                  ),
                                  child: _buildFleetStatusBanner(),
                                ),
                              ),
                              if (dueCount > 0)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      12.w,
                                      8.h,
                                      12.w,
                                      0,
                                    ),
                                    child: _buildDueTransfersBanner(
                                      dueCount,
                                    ),
                                  ),
                                ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    12.w,
                                    8.h,
                                    12.w,
                                    0,
                                  ),
                                  child: RepaintBoundary(
                                    child: _buildMapCard(
                                      transfers,
                                      selectedTransferId:
                                          selectedTransfer?.id ??
                                          _selectedTransferId,
                                      facilityCities: facilityCities,
                                    ),
                                  ),
                                ),
                              ),
                              if (transfers.isNotEmpty)
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    12.w,
                                    16.h,
                                    12.w,
                                    24.h,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      final transfer = transfers[index];
                                      return KeyedSubtree(
                                        key: _cardKeyFor(transfer.id),
                                        child: RepaintBoundary(
                                          child: _buildTransferSummaryCard(
                                            transfer,
                                            isSelected:
                                                transfer.id ==
                                                (selectedTransfer?.id ??
                                                    _selectedTransferId),
                                          ),
                                        ),
                                      );
                                    }, childCount: transfers.length),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                      loading: () => Center(
                        child: AppLoadingIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    )
                  : _selectedTab == 1
                      ? const LogisticsManagementScreen(isEmbedded: true)
                      : historyAsync.when(
                      data: (history) {
                        final sortedHistory = [...history]
                          ..sort((a, b) {
                            final aDate = a.completedAt ?? a.finishAt;
                            final bDate = b.completedAt ?? b.finishAt;
                            return bDate.compareTo(aDate);
                          });

                        return RefreshIndicator(
                          onRefresh: () async {
                            await ref
                                .read(buyerTransferHistoryProvider.notifier)
                                .refresh();
                          },
                          child: sortedHistory.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                  ),
                                  children: [
                                    SizedBox(height: 120.h),
                                    _buildHistoryEmptyState(),
                                  ],
                                )
                              : ListView.separated(
                                  controller: _historyScrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    16.w,
                                    12.h,
                                    16.w,
                                    24.h,
                                  ),
                                  itemCount: sortedHistory.length,
                                  itemBuilder: (context, index) =>
                                      _buildHistoryCard(sortedHistory[index]),
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: 12.h),
                                ),
                        );
                      },
                      loading: () => Center(
                        child: AppLoadingIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.standardCopyWith(
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

  Widget _buildFleetStatusBanner() {
    final vehiclesAsync = ref.watch(logisticsVehicleListProvider);
    return vehiclesAsync.maybeWhen(
      data: (vehicles) {
        if (vehicles.isEmpty) return const SizedBox.shrink();
        final inTransit = vehicles.where((v) => v.status == 'in_transit').length;
        final idle = vehicles.where((v) => v.status != 'in_transit' && v.status != 'scrapped').length;
        final lowFuel = vehicles.where((v) => v.currentFuel < (v.fuelCapacity * 0.25)).length;
        final needsRepair = vehicles.where((v) => v.condition < 40).length;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTab = 1;
            });
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: AppColors.cardBg.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.borderGold.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(5.w),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.localShipping,
                    size: 13.sp,
                    color: AppColors.gold,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        '🚚 $inTransit Yolda',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '🟢 $idle Garajda',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (lowFuel > 0)
                        Text(
                          '⛽ $lowFuel Yakıt Az',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (needsRepair > 0)
                        Text(
                          '🔧 $needsRepair Bakım',
                          style: TextStyle(
                            color: AppColors.red,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          '⚡ Filo Hazır',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filom',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 8.sp,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildDueTransfersBanner(int dueCount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.notificationsActive,
            color: AppColors.gold,
            size: AppIconSizes.compact,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              '$dueCount transfer teslimata hazır. Otomatik tamamlanacak.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.label,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameCityTransfer(TransferMapItemModel transfer) {
    return transfer.sellerWarehouse.city.id == transfer.buyerWarehouse.city.id;
  }

  void _pruneTransferCardKeys(List<TransferMapItemModel> transfers) {
    final validIds = transfers.map((transfer) => transfer.id).toSet();
    _transferCardKeys.removeWhere((key, _) => !validIds.contains(key));
  }

  void _focusTransferCard(
    List<TransferMapItemModel> transfers,
    String transferId,
  ) {
    final index = transfers.indexWhere((item) => item.id == transferId);
    if (index < 0 || !_activeScrollController.hasClients) return;
    final cardContext = _transferCardKeys[transferId]?.currentContext;
    if (cardContext != null) {
      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  GlobalKey _cardKeyFor(String transferId) {
    return _transferCardKeys.putIfAbsent(transferId, GlobalKey.new);
  }

  Widget _buildModeSelector() {
    final vehicles = ref.watch(logisticsVehicleListProvider).value ?? [];
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.2),
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
              label: 'Harita',
              icon: AppIcons.route,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: _buildModeButton(
              index: 1,
              label: vehicles.isNotEmpty ? 'Filom (${vehicles.length})' : 'Filom',
              icon: AppIcons.localShipping,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: _buildModeButton(
              index: 2,
              label: 'Geçmiş',
              icon: AppIcons.history,
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
        padding: EdgeInsets.symmetric(vertical: 10.h),
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
          color: isSelected ? null : AppColors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.transparent,
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
              size: AppIconSizes.compact,
              color: isSelected ? AppColors.gold : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: AppTypography.body,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(
    List<TransferMapItemModel> transfers, {
    String? selectedTransferId,
    List<PlayerFacilityCityModel> facilityCities = const [],
  }) {
    if (_isLoadingMap) {
      return Container(
        height: 180.h,
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.3),
          ),
        ),
        child: Center(child: AppLoadingIndicator(color: AppColors.gold)),
      );
    }

    final cities = <TransferMapCityModel>[
      for (final transfer in transfers) transfer.sellerWarehouse.city,
      for (final transfer in transfers) transfer.buyerWarehouse.city,
    ];
    final uniqueCities = <String, TransferMapCityModel>{
      for (final city in cities) city.id: city,
    }.values.toList();
    final cityTransferCounts = <String, int>{};
    for (final transfer in transfers) {
      cityTransferCounts.update(
        transfer.sellerWarehouse.city.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      cityTransferCounts.update(
        transfer.buyerWarehouse.city.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.2),
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
                    colors: [AppFx.softOverlay(0.05), AppColors.transparent],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 7.w,
                        height: 7.w,
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
                        style: AppTextStyles.h2.standardCopyWith(
                          fontSize: AppTypography.bodyLarge,
                          color: AppColors.gold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${transfers.length} sevkiyat',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final mapHeight = transfers.isEmpty ? 500.h : 310.h;

                    Offset projectCityName(String cityName) {
                      if (_cityList.isEmpty) return Offset.zero;
                      final matched = _cityList.cast<City?>().firstWhere(
                        (c) =>
                            c != null &&
                            _normalizeString(c.title) ==
                                _normalizeString(cityName),
                        orElse: () => null,
                      );
                      if (matched == null) return Offset.zero;
                      return matched.path.getBounds().center;
                    }

                    Offset project(TransferMapCityModel cityModel) =>
                        projectCityName(cityModel.name);

                    final childWidth = SizeController.instance.mapSize.width;
                    final childHeight = SizeController.instance.mapSize.height;
                    final initialScale = (width / childWidth) * 1.25;

                    if (!_hasCenteredMap) {
                      _hasCenteredMap = true;
                      final tx = (width - childWidth * initialScale) / 2;
                      final ty = (mapHeight - childHeight * initialScale) / 2;
                      // ignore: deprecated_member_use
                      _transformationController.value = Matrix4.identity()
                        // ignore: deprecated_member_use
                        ..translate(tx, ty)
                        // ignore: deprecated_member_use
                        ..scale(initialScale);
                    }

                    return SizedBox(
                      height: mapHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24.r),
                        child: Stack(
                          children: [
                            InteractiveViewer(
                              transformationController: _transformationController,
                              onInteractionStart: (_) => _dismissCallout(),
                              boundaryMargin: EdgeInsets.symmetric(
                                horizontal: childWidth,
                                vertical: childHeight,
                              ),
                              constrained: false,
                              clipBehavior: Clip.none,
                              minScale: 0.1,
                              maxScale: 5.0,
                              scaleEnabled: true,
                              panEnabled: true,
                              child: SizedBox(
                                width: childWidth,
                                height: childHeight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapUp: (details) {
                                    final localPos = details.localPosition;
                                    for (final city in _cityList) {
                                      if (city.path.contains(localPos)) {
                                        for (final fc in facilityCities) {
                                          if (_normalizeString(fc.cityName) ==
                                              _normalizeString(city.title)) {
                                            final pos = projectCityName(fc.cityName);
                                            _openCityCallout(fc, pos);
                                            return;
                                          }
                                        }
                                        break;
                                      }
                                    }
                                    _dismissCallout();
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter:
                                              _TurkeyTransferMapBackgroundPainter(
                                                cities: _cityList,
                                                transfers: transfers,
                                                selectedTransferId:
                                                    selectedTransferId,
                                                facilityCities: facilityCities,
                                                normalizeFn: _normalizeString,
                                              ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _TransferMapPainter(
                                            transfers: transfers,
                                            projector: project,
                                            selectedTransferId: selectedTransferId,
                                          ),
                                        ),
                                      ),
                                      // İşletmesi olan şehirler için rozetler / pinler
                                      for (final fc in facilityCities)
                                        Builder(
                                          builder: (context) {
                                            final position =
                                                projectCityName(fc.cityName);
                                            if (position == Offset.zero) {
                                              return const SizedBox.shrink();
                                            }
                                            return _buildFacilityCityMarker(
                                              fc,
                                              position,
                                            );
                                          },
                                        ),
                                      // İşletme olmayan diğer transfer şehirleri
                                      ...uniqueCities
                                          .where(
                                            (c) => !facilityCities.any(
                                              (fc) =>
                                                  _normalizeString(fc.cityName) ==
                                                  _normalizeString(c.name),
                                            ),
                                          )
                                          .map((city) {
                                  final position = project(city);
                                  if (position == Offset.zero) {
                                    return const SizedBox.shrink();
                                  }
                                  const markerWidth = 80.0;
                                  return Positioned(
                                    left: position.dx - markerWidth / 2,
                                    top: position.dy - 8.w,
                                    width: markerWidth,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 16.w,
                                              height: 16.w,
                                              decoration: BoxDecoration(
                                                color: AppColors.gold,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.textPrimary,
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.gold
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              right: -10.w,
                                              top: -8.h,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4.w,
                                                  vertical: 1.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999.r,
                                                      ),
                                                ),
                                                child: Text(
                                                  '${cityTransferCounts[city.id] ?? 0}',
                                                  style: AppTextStyles.caption
                                                      .standardCopyWith(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize:
                                                            AppTypography.micro,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4.h),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6.w,
                                            vertical: 2.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppFx.panelWash(0.8),
                                            borderRadius: BorderRadius.circular(
                                              12.r,
                                            ),
                                            border: Border.all(
                                              color: AppColors.gold.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            city.name,
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize: AppTypography.micro,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                Positioned.fill(
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final now =
                                          ref
                                              .watch(secondTickerProvider)
                                              .value ??
                                          DateTime.now();
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          for (final transfer in transfers)
                                            _TransferMapMovingMarker(
                                              transfer: transfer,
                                              selectedTransferId:
                                                  selectedTransferId,
                                              start: project(
                                                transfer.sellerWarehouse.city,
                                              ),
                                              end: project(
                                                transfer.buyerWarehouse.city,
                                              ),
                                              progress: _calculateProgress(
                                                transfer,
                                                now: now,
                                              ),
                                              onTap: (pos) {
                                                _openTransferCallout(
                                                  transfer,
                                                  pos,
                                                );
                                              },
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                            // Floating popover windows (tıklanan yerin hemen yanında açılan pencere)
                            if (_calloutCity != null && _calloutCityPos != null)
                              _buildCityCalloutOverlay(
                                city: _calloutCity!,
                                svgPos: _calloutCityPos!,
                                mapWidth: width,
                                mapHeight: mapHeight,
                              ),
                            if (_calloutTransfer != null &&
                                _calloutTransferPos != null)
                              _buildTransferCalloutOverlay(
                                transfer: _calloutTransfer!,
                                svgPos: _calloutTransferPos!,
                                mapWidth: width,
                                mapHeight: mapHeight,
                              ),
                          ],
                        ),
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

  Widget _buildFacilityCityMarker(
    PlayerFacilityCityModel fc,
    Offset position,
  ) {
    const markerWidth = 84.0;
    return Positioned(
      left: position.dx - markerWidth / 2,
      top: position.dy - 16.h,
      width: markerWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openCityCallout(fc, position),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.5.h),
              decoration: BoxDecoration(
                color: AppColors.cardBg.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.gold,
                  width: 1.2.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 8.r,
                    offset: Offset(0, 2.h),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 6.r,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.gold,
                    size: 11.sp,
                  ),
                  SizedBox(width: 2.w),
                  Flexible(
                    child: Text(
                      fc.cityName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      '${fc.facilityCount}',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 7.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: Size(8.w, 4.h),
              painter: _TrianglePointerPainter(color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityCalloutOverlay({
    required PlayerFacilityCityModel city,
    required Offset svgPos,
    required double mapWidth,
    required double mapHeight,
  }) {
    final cardPos = MatrixUtils.transformPoint(
      _transformationController.value,
      svgPos,
    );
    final calloutWidth = math.min(320.w, mapWidth - 16.w);
    final calloutHeight = math.min(300.h, mapHeight - 16.h);

    double left = cardPos.dx + 14.w;
    if (left + calloutWidth > mapWidth - 8.w) {
      left = cardPos.dx - 14.w - calloutWidth;
    }
    if (left < 8.w) {
      left = ((mapWidth - calloutWidth) / 2).clamp(8.w, mapWidth - calloutWidth);
    }

    double top = cardPos.dy - 12.h - calloutHeight;
    if (top < 8.h) {
      top = cardPos.dy + 18.h;
    }
    if (top + calloutHeight > mapHeight - 8.h) {
      top = ((mapHeight - calloutHeight) / 2).clamp(8.h, mapHeight - calloutHeight);
    }

    return Positioned(
      left: left,
      top: top,
      width: calloutWidth,
      height: calloutHeight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.gold,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 18.r,
                offset: Offset(0, 6.h),
              ),
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.25),
                blurRadius: 10.r,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 10.h, 6.w, 6.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(5.w),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.gold,
                        size: 14.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            city.cityName,
                            style: AppTextStyles.h2.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            '${city.facilityCount} İşletme • ${AppMoney.full(city.totalCityStock, withSymbol: false)} Toplam Stok',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: _dismissCallout,
                      child: Padding(
                        padding: EdgeInsets.all(6.w),
                        child: Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                          size: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCalloutTabChip(
                        title: 'Tümü',
                        isSelected: _cityCalloutTab == 0,
                        onTap: () => setState(() => _cityCalloutTab = 0),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: _buildCalloutTabChip(
                        title: 'İşletmeler (${city.facilities.length})',
                        isSelected: _cityCalloutTab == 1,
                        onTap: () => setState(() => _cityCalloutTab = 1),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: _buildCalloutTabChip(
                        title: 'Stoklar',
                        isSelected: _cityCalloutTab == 2,
                        onTap: () => setState(() => _cityCalloutTab = 2),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: AppColors.borderGold.withValues(alpha: 0.25),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  children: [
                    if (_cityCalloutTab == 0 || _cityCalloutTab == 1) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h, left: 2.w),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 11.sp,
                              color: AppColors.gold,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'İŞLETMELER (${city.facilities.length})',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final fac in city.facilities)
                        _buildCalloutFacilityRow(fac),
                      if (_cityCalloutTab == 0) SizedBox(height: 6.h),
                    ],
                    if (_cityCalloutTab == 0 || _cityCalloutTab == 2) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h, left: 2.w),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 11.sp,
                              color: AppColors.gold,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'ŞEHİRDEKİ STOKLAR',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final candidatesAsync = ref.watch(
                            consolidatedTransferCityCandidatesProvider(
                              city.cityId,
                            ),
                          );
                          return candidatesAsync.when(
                            data: (items) {
                              if (items.isEmpty) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 8.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBgLight.withValues(
                                      alpha: 0.4,
                                    ),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 12.sp,
                                        color: AppColors.textMuted,
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          'Bu şehirde hazır ürün stoğu bulunmuyor.',
                                          style: TextStyle(
                                            fontSize: 8.5.sp,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  for (final item in items)
                                    _buildCalloutStockRow(item),
                                ],
                              );
                            },
                            loading: () => Container(
                              padding: EdgeInsets.all(8.h),
                              child: const Center(
                                child: AppLoadingIndicator.compact(),
                              ),
                            ),
                            error: (_, _) => Container(
                              padding: EdgeInsets.all(6.h),
                              child: Text(
                                'Stok bilgisi alınamadı.',
                                style: TextStyle(
                                  fontSize: 8.5.sp,
                                  color: AppColors.red,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 4.h, 10.w, 8.h),
                child: SizedBox(
                  width: double.infinity,
                  height: 34.h,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.textOnAccent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    icon: Icon(AppIcons.localShipping, size: 14.sp),
                    label: Text(
                      '${city.cityName} Şehrinden Sevkiyat Yap',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _dismissCallout();
                      ConsolidatedTransferSheet.show(
                        context,
                        initialCityId: city.cityId,
                        initialCityName: city.cityName,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalloutTabChip({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 4.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.22)
              : AppColors.cardBgLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white10,
            width: isSelected ? 1 : 0.6,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.gold : AppColors.textMuted,
            fontSize: 8.5.sp,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCalloutFacilityRow(PlayerFacilityItemModel fac) {
    final visual = _getFacilityKindVisual(fac.kind);
    final icon = visual.$1;
    final color = visual.$2;
    return Container(
      margin: EdgeInsets.only(bottom: 3.5.h),
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5.r),
            ),
            child: Icon(icon, color: color, size: 12.sp),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fac.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    fac.kindDisplay,
                    style: TextStyle(
                      color: color,
                      fontSize: 7.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '${AppMoney.full(fac.totalStock, withSymbol: false)} / ${AppMoney.full(fac.totalCapacity, withSymbol: false)}',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalloutStockRow(ConsolidatedCandidateItemModel item) {
    return Container(
      margin: EdgeInsets.only(bottom: 3.5.h),
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppColors.borderGold.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20.w,
            height: 20.w,
            child: BrandedProductImage(
              fileName: item.productIcon ?? '',
              productId: item.productId,
              brandId: item.brandId,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  item.sourceName,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 7.5.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${AppMoney.full(item.availableQuantity, withSymbol: false)} Adet',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 8.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCalloutOverlay({
    required TransferMapItemModel transfer,
    required Offset svgPos,
    required double mapWidth,
    required double mapHeight,
  }) {
    final cardPos = MatrixUtils.transformPoint(
      _transformationController.value,
      svgPos,
    );
    final calloutWidth = math.min(300.w, mapWidth - 20.w);
    final calloutHeight = math.min(255.h, mapHeight - 24.h);
    final accentColor = transfer.isRental ? AppColors.warning : AppColors.gold;
    final totalCost = transfer.totalPrice + transfer.transportCost + transfer.rentalCost;
    final sameCity = _isSameCityTransfer(transfer);
    final routeDistanceKm = _estimateRouteDistanceKm(
      transfer.sellerWarehouse.city,
      transfer.buyerWarehouse.city,
    );

    double left = cardPos.dx + 14.w;
    if (left + calloutWidth > mapWidth - 8.w) {
      left = cardPos.dx - 14.w - calloutWidth;
    }
    if (left < 8.w) {
      left = ((mapWidth - calloutWidth) / 2).clamp(8.w, mapWidth - calloutWidth);
    }

    double top = cardPos.dy - 12.h - calloutHeight;
    if (top < 8.h) {
      top = cardPos.dy + 18.h;
    }
    if (top + calloutHeight > mapHeight - 8.h) {
      top = ((mapHeight - calloutHeight) / 2).clamp(8.h, mapHeight - calloutHeight);
    }

    return Positioned(
      left: left,
      top: top,
      width: calloutWidth,
      height: calloutHeight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: accentColor,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 18.r,
                offset: Offset(0, 6.h),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.25),
                blurRadius: 10.r,
              ),
            ],
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
              final remaining = transfer.finishAt.difference(now);
              final progress = _calculateProgress(transfer, now: now);
              final isDue = !transfer.finishAt.isAfter(now);
              final starCost = math.max(
                1,
                (remaining.inSeconds / 60).ceil(),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 10.h, 6.w, 8.h),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            transfer.isRental
                                ? AppIcons.localShipping
                                : AppIcons.directionsCar,
                            color: accentColor,
                            size: 15.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _transferTitle(
                                  isMultiItem: transfer.isMultiItem,
                                  productName: transfer.product.name,
                                  itemCount: transfer.itemCount,
                                ),
                                style: AppTextStyles.h2.standardCopyWith(
                                  color: accentColor,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                '${transfer.isRental ? 'Kiralık Filo' : 'Öz Filo'} • ${sameCity ? 'Şehir İçi' : '${routeDistanceKm.toStringAsFixed(0)} km'}',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(12.r),
                          onTap: _dismissCallout,
                          child: Padding(
                            padding: EdgeInsets.all(6.w),
                            child: Icon(
                              Icons.close,
                              color: AppColors.textMuted,
                              size: 16.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: accentColor.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                AppIcons.routeOutlined,
                                size: 12.sp,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  '${transfer.sellerWarehouse.city.name} ➔ ${transfer.buyerWarehouse.city.name}',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999.r),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.cardBgLight,
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              minHeight: 6.h,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isDue ? 'Varış Noktasında' : 'Kalan: ${_formatRemaining(remaining)}',
                                style: TextStyle(
                                  color: isDue ? AppColors.green : accentColor,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '%${(progress * 100).toInt()}',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 8.5.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: AppColors.cardBgLight.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MİKTAR',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 7.5.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _transferQuantitySummary(
                                          quantity: transfer.displayQuantity,
                                          isMultiItem: transfer.isMultiItem,
                                          itemCount: transfer.itemCount,
                                        ),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 9.5.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 20.h,
                                  color: AppColors.borderGold.withValues(alpha: 0.2),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TOPLAM TUTAR',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 7.5.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(totalCost),
                                        style: TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 9.5.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 34.h,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: accentColor.withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                _dismissCallout();
                                _showTransferInfo(transfer);
                              },
                              child: Text(
                                'Detaylar',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!isDue && remaining.inMinutes <= 10) ...[
                          SizedBox(width: 8.w),
                          Expanded(
                            child: SizedBox(
                              height: 34.h,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.textOnAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () {
                                  _dismissCallout();
                                  _confirmFinishWithStars(
                                    context,
                                    ref,
                                    transfer,
                                    starCost,
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      AppIcons.starRounded,
                                      size: 13.sp,
                                      color: AppColors.textOnAccent,
                                    ),
                                    SizedBox(width: 3.w),
                                    Text(
                                      'Bitir ($starCost)',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  (IconData, Color) _getFacilityKindVisual(String kind) {
    switch (kind.toLowerCase()) {
      case 'warehouse':
        return (AppIcons.inventory2Outlined, AppColors.gold);
      case 'factory':
        return (Icons.precision_manufacturing_outlined, Colors.blueAccent);
      case 'farm':
        return (Icons.grass_outlined, AppColors.green);
      case 'field':
        return (Icons.pets_outlined, Colors.orangeAccent);
      case 'mine':
        return (Icons.terrain_outlined, Colors.purpleAccent);
      case 'store':
        return (AppIcons.storefrontOutlined, Colors.tealAccent);
      default:
        return (Icons.business_outlined, AppColors.gold);
    }
  }

  Widget _buildTransferSummaryCard(
    TransferMapItemModel transfer, {
    bool isSelected = false,
  }) {
    final accentColor = transfer.isRental ? AppColors.warning : AppColors.gold;
    final sameCity = _isSameCityTransfer(transfer);
    final routeDistanceKm = _estimateRouteDistanceKm(
      transfer.sellerWarehouse.city,
      transfer.buyerWarehouse.city,
    );
    final totalCost = transfer.totalPrice + transfer.transportCost + transfer.rentalCost;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTransferId = transfer.id;
        });
        final currentTransfers =
            ref.read(buyerTransferMapProvider).value ?? const [];
        _focusTransferCard(currentTransfers, transfer.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? AppColors.blue.withValues(alpha: 0.8)
                : AppColors.borderGold.withValues(alpha: 0.15),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.blue.withValues(alpha: 0.16)
                  : AppFx.panelWash(0.2),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Always Visible)
            Row(
              children: [
                _buildTransferAvatar(
                  isMultiItem: transfer.isMultiItem,
                  productIcon: transfer.product.icon,
                  brandName: transfer.brandName,
                  itemCount: transfer.itemCount,
                  accentColor: accentColor,
                  brandId: transfer.brandId,
                  productId: transfer.product.id,
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
                              _transferTitle(
                                isMultiItem: transfer.isMultiItem,
                                productName: transfer.product.name,
                                itemCount: transfer.itemCount,
                              ),
                              style: AppTextStyles.h2.standardCopyWith(
                                fontSize: AppTypography.title,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          _buildTransferChip(
                            transfer.isRental ? 'Kiralık' : 'Özmal',
                            accentColor,
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${transfer.sellerWarehouse.city.name} ➔ ${transfer.buyerWarehouse.city.name}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.bold,
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
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: _TransferProgressBar(
                      transfer: transfer,
                      accentColor: accentColor,
                      calculateProgress: _calculateProgress,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Consumer(
                  builder: (context, ref, _) {
                    final now =
                        ref.watch(secondTickerProvider).value ??
                        DateTime.now();
                    final remaining = transfer.finishAt.difference(now);
                    return Text(
                      _formatRemaining(remaining),
                      style: AppTextStyles.body.standardCopyWith(
                        color: accentColor,
                        fontSize: AppTypography.bodySmall,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),

            // Expanded view details
            if (isSelected) ...[
              Divider(color: AppFx.softOverlay(0.08), height: 16.h),

              Text(
                _transferRouteSummary(
                  sourceName: transfer.sellerWarehouse.name,
                  sourceKind: transfer.sellerKindLabel,
                  targetName: transfer.buyerWarehouse.name,
                  targetKind: transfer.buyerKindLabel,
                ),
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodySmall,
                ),
                maxLines: 2,
              ),
              SizedBox(height: 8.h),

              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  if (!transfer.isMultiItem)
                    _buildInlineMetaChip(
                      _buildQualityBrandSummary(
                        qualityLevel: transfer.qualityLevel,
                        hasBrand: transfer.hasBrand,
                      ),
                      AppColors.textPrimary,
                    ),
                  _buildInlineMetaChip(
                    '${routeDistanceKm.toStringAsFixed(0)} km',
                    sameCity ? AppColors.green : AppColors.blue,
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.18),
                  ),
                ),
                child: _TransferLiveMeta(
                  transfer: transfer,
                  accentColor: accentColor,
                  formatRemaining: _formatRemaining,
                  formatDateTime: _formatDateTime,
                ),
              ),
              if (transfer.isMultiItem) ...[
                SizedBox(height: 12.h),
                Divider(color: AppFx.softOverlay(0.08), height: 16.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sevkiyat İçeriği (${transfer.itemCount} Kalem)',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                _NestedTransferItemsList(transferId: transfer.id),
              ],

              SizedBox(height: 12.h),
              Divider(color: AppFx.softOverlay(0.08), height: 16.h),
              SizedBox(height: 8.h),

              _buildCompactMetaRow(
                leftIcon: AppIcons.inventory2Outlined,
                leftText: 'Miktar: ${_transferQuantitySummary(
                  quantity: transfer.displayQuantity,
                  isMultiItem: transfer.isMultiItem,
                  itemCount: transfer.itemCount,
                )}',
                rightIcon: AppIcons.paymentsOutlined,
                rightText: 'Ürün Bedeli: ${_formatCurrency(transfer.totalPrice)}',
              ),
              SizedBox(height: 6.h),
              _buildCompactMetaRow(
                leftIcon: AppIcons.localShippingOutlined,
                leftText: 'Lojistik: ${_formatCurrency(transfer.transportCost + transfer.rentalCost)}',
                rightIcon: AppIcons.paymentsOutlined,
                rightText: 'Toplam: ${_formatCurrency(totalCost)}',
              ),
              SizedBox(height: 10.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showTransferInfo(transfer),
                    icon: Icon(
                      AppIcons.openInFull,
                      size: AppIconSizes.small,
                      color: AppColors.gold,
                    ),
                    label: Text(
                      'Tüm İrsaliye Detayları',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetaRow({
    required IconData leftIcon,
    required String leftText,
    required IconData rightIcon,
    required String rightText,
  }) {
    return Row(
      children: [
        Expanded(child: _buildMetaLine(leftIcon, leftText)),
        SizedBox(width: 12.w),
        Expanded(child: _buildMetaLine(rightIcon, rightText)),
      ],
    );
  }

  Widget _buildMetaLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: AppIconSizes.xSmall),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.bold,
        ),
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
            color: AppFx.panelWash(0.2),
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
              color: AppFx.softOverlay(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.historyOutlined,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: AppIconSizes.hero,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Geçmiş Kayıt Bulunamadı',
            style: AppTextStyles.h2.standardCopyWith(
              fontSize: AppTypography.headline,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Tamamlanan veya iptal edilen tüm sevkiyatlarınız burada loglanacaktır.',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TransferHistoryItemModel item) {
    final isExpanded = item.id == _expandedHistoryId;
    final statusColor = item.status == 'completed'
        ? AppColors.green
        : AppColors.warning;
    final completedText = item.completedAt == null
        ? '-'
        : _formatDateTime(item.completedAt!);
    final totalMinutes = item.finishAt.difference(item.startedAt).inMinutes;
    final unitLogisticsCost = item.displayQuantity > 0
        ? item.transportCost / item.displayQuantity
        : 0.0;
    final totalCost = item.totalPrice + item.transportCost;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedHistoryId = isExpanded ? null : item.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isExpanded
                ? statusColor.withValues(alpha: 0.8)
                : AppColors.borderGold.withValues(alpha: 0.1),
            width: isExpanded ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppFx.panelWash(0.15),
              blurRadius: isExpanded ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTransferAvatar(
                  isMultiItem: item.isMultiItem,
                  productIcon: item.product.icon,
                  brandName: item.brandName,
                  itemCount: item.itemCount,
                  accentColor: statusColor,
                  brandId: item.brandId,
                  productId: item.product.id,
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
                              _transferTitle(
                                isMultiItem: item.isMultiItem,
                                productName: item.product.name,
                                itemCount: item.itemCount,
                              ),
                              style: AppTextStyles.h2.standardCopyWith(
                                fontSize: AppTypography.title,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          _buildTransferChip(
                            _statusLabel(item.status),
                            statusColor,
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${item.sellerWarehouse.city.name} ➔ ${item.buyerWarehouse.city.name}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 8.h),

            // Collapsed view summary
            if (!isExpanded) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Süre: $totalMinutes dk',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Tamamlandı: $completedText',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ],

            // Expanded view details
            if (isExpanded) ...[
              Divider(color: AppFx.softOverlay(0.08), height: 16.h),

              Text(
                _transferRouteSummary(
                  sourceName: item.sellerWarehouse.name,
                  sourceKind: item.sellerKind,
                  targetName: item.buyerWarehouse.name,
                  targetKind: item.buyerKind,
                ),
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodySmall,
                ),
                maxLines: 2,
              ),
              SizedBox(height: 8.h),

              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  _buildInlineMetaChip(
                    '${item.sellerKind} ➔ ${item.buyerKind}',
                    AppColors.gold,
                  ),
                  if (!item.isMultiItem)
                    _buildInlineMetaChip(
                      _buildQualityBrandSummary(
                        qualityLevel: item.qualityLevel,
                        hasBrand: item.hasBrand,
                      ),
                      AppColors.textPrimary,
                    ),
                  _buildInlineMetaChip('$totalMinutes dk', statusColor),
                ],
              ),
              if (item.isMultiItem) ...[
                SizedBox(height: 12.h),
                Divider(color: AppFx.softOverlay(0.08), height: 16.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sevkiyat İçeriği (${item.itemCount} Kalem)',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                _NestedTransferItemsList(transferId: item.id),
              ],
              SizedBox(height: 12.h),

              _buildCompactMetaRow(
                leftIcon: AppIcons.inventory2Outlined,
                leftText: _transferQuantitySummary(
                  quantity: item.displayQuantity,
                  isMultiItem: item.isMultiItem,
                  itemCount: item.itemCount,
                ),
                rightIcon: AppIcons.paymentsOutlined,
                rightText: _formatCurrency(item.totalPrice),
              ),
              SizedBox(height: 6.h),
              _buildCompactMetaRow(
                leftIcon: AppIcons.localShippingOutlined,
                leftText: _formatCurrency(item.transportCost + item.rentalCost),
                rightIcon: item.isRental
                    ? AppIcons.localShippingOutlined
                    : AppIcons.directionsCarOutlined,
                rightText: item.isRental
                    ? '${_formatCurrency(unitLogisticsCost)} / adet'
                    : 'Ozmal transfer',
              ),
              if (item.isMultiItem) ...[
                SizedBox(height: 6.h),
                _buildCompactMetaRow(
                  leftIcon: AppIcons.paymentsOutlined,
                  leftText: _formatCurrency(totalCost),
                  rightIcon: AppIcons.listAltOutlined,
                  rightText: '${item.itemCount} kalem',
                ),
              ],
              SizedBox(height: 8.h),
              _buildMetaLine(
                AppIcons.eventOutlined,
                'Bitiş Tarihi: $completedText',
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateProgress(TransferMapItemModel transfer, {DateTime? now}) {
    final total = transfer.finishAt.difference(transfer.startedAt).inSeconds;
    if (total <= 0) return 1;
    final elapsed = (now ?? DateTime.now())
        .difference(transfer.startedAt)
        .inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  double _estimateRouteDistanceKm(
    TransferMapCityModel from,
    TransferMapCityModel to,
  ) {
    const kmPerLat = 111.0;
    final avgLatRadians = ((from.x + to.x) / 2) * 0.0174533;
    final kmPerLon = 111.0 * math.cos(avgLatRadians);
    final dx = (to.y - from.y) * kmPerLon;
    final dy = (to.x - from.x) * kmPerLat;
    return math.sqrt(dx * dx + dy * dy);
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
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      default:
        return status;
    }
  }

  String _formatCurrency(double value) {
    return AppMoney.full(value, decimals: 1);
  }

  String _buildQualityBrandSummary({
    required int qualityLevel,
    required bool hasBrand,
  }) {
    final brandLabel = hasBrand ? 'Markali' : 'Brandsiz';
    return 'Q$qualityLevel | $brandLabel';
  }

  Widget _buildInlineMetaChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TransferLiveMeta extends ConsumerWidget {
  final TransferMapItemModel transfer;
  final Color accentColor;
  final String Function(Duration duration) formatRemaining;
  final String Function(DateTime value) formatDateTime;

  const _TransferLiveMeta({
    required this.transfer,
    required this.accentColor,
    required this.formatRemaining,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final remaining = transfer.finishAt.difference(now);

    return Row(
      children: [
        Icon(AppIcons.schedule, color: accentColor, size: AppIconSizes.compact),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Kalan Süre: ${formatRemaining(remaining)}',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          'Varis ${formatDateTime(transfer.finishAt)}',
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
          ),
        ),
      ],
    );
  }
}

class _TransferProgressBar extends ConsumerWidget {
  final TransferMapItemModel transfer;
  final Color accentColor;
  final double Function(TransferMapItemModel transfer, {DateTime? now})
  calculateProgress;

  const _TransferProgressBar({
    required this.transfer,
    required this.accentColor,
    required this.calculateProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final progress = calculateProgress(transfer, now: now);

    return AppProgressBar(
      value: progress,
      backgroundColor: AppFx.panelWash(0.3),
      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
      minHeight: 6.h,
    );
  }
}

class _TransferMapMovingMarker extends StatelessWidget {
  final TransferMapItemModel transfer;
  final String? selectedTransferId;
  final Offset start;
  final Offset end;
  final double progress;
  final void Function(Offset position) onTap;

  const _TransferMapMovingMarker({
    required this.transfer,
    required this.selectedTransferId,
    required this.start,
    required this.end,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final position = Offset.lerp(start, end, progress)!;
    final isSelected = transfer.id == selectedTransferId;
    final color = isSelected
        ? AppColors.blue
        : transfer.isRental
        ? AppColors.warning
        : AppColors.gold;

    return Positioned(
      left: position.dx - 15.w,
      top: position.dy - 15.w,
      child: GestureDetector(
        onTap: () => onTap(position),
        child: Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  transfer.isRental
                      ? AppIcons.localShipping
                      : AppIcons.directionsCar,
                  color: transfer.isRental ? AppColors.warning : AppColors.gold,
                  size: AppIconSizes.small,
                ),
              ),
              if (transfer.isMultiItem)
                Positioned(
                  right: -4.w,
                  top: -4.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '${transfer.itemCount}',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textOnAccent,
                        fontSize: AppTypography.micro,
                        fontWeight: FontWeight.w800,
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

class _TransferMapPainter extends CustomPainter {
  final List<TransferMapItemModel> transfers;
  final Offset Function(TransferMapCityModel city) projector;
  final String? selectedTransferId;

  _TransferMapPainter({
    required this.transfers,
    required this.projector,
    this.selectedTransferId,
  });

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
      final isSelected = transfer.id == selectedTransferId;
      linePaint
        ..color = isSelected
            ? AppColors.blue.withValues(alpha: 0.85)
            : transfer.isRental
            ? AppColors.warning.withValues(alpha: 0.6)
            : AppColors.gold.withValues(alpha: 0.6)
        ..strokeWidth = isSelected ? 4 : 2.5;

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
  bool shouldRepaint(covariant _TransferMapPainter oldDelegate) {
    if (selectedTransferId != oldDelegate.selectedTransferId) {
      return true;
    }
    if (transfers.length != oldDelegate.transfers.length) {
      return true;
    }
    for (var i = 0; i < transfers.length; i++) {
      final current = transfers[i];
      final previous = oldDelegate.transfers[i];
      if (current.id != previous.id ||
          current.isRental != previous.isRental ||
          current.sellerWarehouse.city.id != previous.sellerWarehouse.city.id ||
          current.buyerWarehouse.city.id != previous.buyerWarehouse.city.id) {
        return true;
      }
    }
    return false;
  }
}

class _TurkeyTransferMapBackgroundPainter extends CustomPainter {
  final List<City> cities;
  final List<TransferMapItemModel> transfers;
  final String? selectedTransferId;
  final List<PlayerFacilityCityModel> facilityCities;
  final String Function(String) normalizeFn;

  _TurkeyTransferMapBackgroundPainter({
    required this.cities,
    required this.transfers,
    this.selectedTransferId,
    this.facilityCities = const [],
    required this.normalizeFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Border and Fill paints
    final strokePaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final defaultFillPaint = Paint()
      ..color = AppColors.cardBg.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    // Active cities paint (involved in active transfers)
    final activeFillPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final selectedFillPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    // Facility cities paint (cities owned by the player)
    final facilityFillPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final facilityStrokePaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.8)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Collect all city names involved in transfers
    final activeCityNames = <String>{};
    String? selectedSellerCityName;
    String? selectedBuyerCityName;

    for (final transfer in transfers) {
      activeCityNames.add(normalizeFn(transfer.sellerWarehouse.city.name));
      activeCityNames.add(normalizeFn(transfer.buyerWarehouse.city.name));
      if (transfer.id == selectedTransferId) {
        selectedSellerCityName = normalizeFn(
          transfer.sellerWarehouse.city.name,
        );
        selectedBuyerCityName = normalizeFn(transfer.buyerWarehouse.city.name);
      }
    }

    final facilityCityNames = <String>{
      for (final fc in facilityCities) normalizeFn(fc.cityName),
    };

    for (final city in cities) {
      final cityTitleNormalized = normalizeFn(city.title);
      Paint fillPaint = defaultFillPaint;
      final isFacilityCity = facilityCityNames.contains(cityTitleNormalized);

      if (cityTitleNormalized == selectedSellerCityName ||
          cityTitleNormalized == selectedBuyerCityName) {
        fillPaint = selectedFillPaint;
      } else if (activeCityNames.contains(cityTitleNormalized)) {
        fillPaint = activeFillPaint;
      } else if (isFacilityCity) {
        fillPaint = facilityFillPaint;
      }

      canvas.drawPath(city.path, fillPaint);
      if (isFacilityCity) {
        canvas.drawPath(city.path, facilityStrokePaint);
      } else {
        canvas.drawPath(city.path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _TurkeyTransferMapBackgroundPainter oldDelegate,
  ) {
    return oldDelegate.cities != cities ||
        oldDelegate.transfers != transfers ||
        oldDelegate.selectedTransferId != selectedTransferId ||
        oldDelegate.facilityCities != facilityCities;
  }
}

class _TrianglePointerPainter extends CustomPainter {
  final Color color;
  const _TrianglePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NestedTransferItemsList extends ConsumerWidget {
  final String transferId;
  const _NestedTransferItemsList({required this.transferId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(transferItemsProvider(transferId));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Text(
              'İçerik bulunamadı.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final brandLabel = item.brandName.toLowerCase() == 'standart' ? '' : ' | ${item.brandName}';
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppFx.panelWash(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                    ),
                    child: BrandedProductImage(
                      fileName: item.productIcon,
                      productId: item.productId,
                      brandId: item.brandId,
                      brandName: item.brandName,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.bodySmall,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Q${item.qualityLevel}$brandLabel',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.micro,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${AppMoney.full(item.quantity, withSymbol: false)} adet',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.blue,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    AppMoney.full(item.totalPrice),
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ),
      ),
      error: (err, stack) => Text(
        'İçerik yüklenemedi: $err',
        style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
      ),
    );
  }
}

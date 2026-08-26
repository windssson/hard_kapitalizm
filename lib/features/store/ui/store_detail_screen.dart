import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_ad_action_flow.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_quote_provider.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/building_upgrade_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/features/auth/models/experience_gain_model.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_detail_page_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';
import 'package:hard_kapitalizm/features/store/ui/widgets/store_detail_header.dart';
import 'package:hard_kapitalizm/features/store/ui/widgets/store_quick_actions.dart';
import 'package:hard_kapitalizm/core/data/player_active_products_service.dart';

class StoreDetailScreen extends ConsumerStatefulWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen>
    with WidgetsBindingObserver {
  static const String _defaultBrandId = '00000000-0000-0000-0000-000000000000';
  String? _lastShownSalesResultKey;
  Timer? _salesRefreshTimer;
  bool _isAutoRefreshingStoreSales = false;
  bool _isFillingShelves = false;
  bool _isBulkUpdatingPrices = false;
  static const Map<int, int> _storeBoostStarCosts = {6: 3, 12: 6, 24: 12};

  @override
  void initState() {
    super.initState();
    _lastShownSalesResultKey = null;
    WidgetsBinding.instance.addObserver(this);
    _salesRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshSalesIfWorthChecking(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSalesIfWorthChecking(force: true);
      final tutorial = ref.read(tutorialProvider);
      final storeData = ref
          .read(storeDetailPageProvider(widget.storeId))
          .value
          ?.store;

      if (tutorial.step == TutorialStep.clickEnterStore) {
        if (storeData != null && storeData.slots.isNotEmpty) {
          ref
              .read(tutorialProvider.notifier)
              .setStep(TutorialStep.clickGoToMarket);
        } else {
          ref
              .read(tutorialProvider.notifier)
              .setStep(TutorialStep.clickCreateShelf);
        }
      } else if (tutorial.step == TutorialStep.returnToStoreDetail) {
        _refreshStorePageAndSync(widget.storeId).then((_) {
          if (mounted) {
            ref
                .read(tutorialProvider.notifier)
                .setStep(TutorialStep.clickSelectProduct);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _salesRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSalesIfWorthChecking(force: true);
    }
  }

  bool _storeHasSaleCandidates(StoreModel store) {
    if (!store.isActive) return false;
    return store.slots.any(
      (slot) =>
          slot.isActive &&
          slot.productId != null &&
          slot.qualityLevel > 0 &&
          slot.quantity > 0 &&
          (slot.price ?? 0) > 0,
    );
  }

  Future<void> _refreshSalesIfWorthChecking({bool force = false}) async {
    if (!mounted || _isAutoRefreshingStoreSales) return;

    final page = ref.read(storeDetailPageProvider(widget.storeId)).value;
    if (page == null) return;
    if (!force && !_storeHasSaleCandidates(page.store)) return;

    _isAutoRefreshingStoreSales = true;
    try {
      await _refreshStorePageAndSync(widget.storeId);
    } catch (_) {
      // Background sale checks should not interrupt gameplay with errors.
    } finally {
      _isAutoRefreshingStoreSales = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeDetailPageProvider(widget.storeId));

    ref.listen(storeDetailPageProvider(widget.storeId), (prev, next) {
      final page = next.value;
      if (page != null) {
        _syncTutorialStepIfUnfinished(page);
      }
    });

    // Pazardan dönüşte store verisini yenileyerek stale data sorununu önle
    ref.listen(tutorialProvider, (prev, next) {
      if (next.step == TutorialStep.returnToStoreDetail) {
        _refreshStorePageAndSync(widget.storeId).then((_) {
          if (mounted) {
            ref
                .read(tutorialProvider.notifier)
                .setStep(TutorialStep.clickSelectProduct);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
        onItemSelected: (_) {},
      ),
      body: SafeArea(
        child: storeAsync.when(
          data: (page) {
            _scheduleSalesSummaryDialog(page);
            return _buildMainContent(context, ref, page);
          },
          loading: () =>
              Center(child: AppLoadingIndicator(color: AppColors.gold)),
          error: (e, s) => _buildErrorState(ref, e),
        ),
      ),
    );
  }

  void _syncTutorialStepIfUnfinished(StoreDetailPageModel page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tutorial = ref.read(tutorialProvider);
      final currentStep = tutorial.step;
      final store = page.store;
      final storeWarehouse = page.storeWarehouse;

      final firstSlot = store.slots.isNotEmpty ? store.slots.first : null;
      final hasProduct = (firstSlot?.productId ?? '').isNotEmpty;
      final hasPrice = (firstSlot?.price ?? 0) > 0;
      final hasStock = (firstSlot?.quantity ?? 0) > 0;
      final isStoreComplete =
          store.slots.isNotEmpty && hasProduct && hasPrice && hasStock;

      if (isStoreComplete || tutorial.hasSeenTutorial || tutorial.isPaused) {
        return;
      }

      if (currentStep == TutorialStep.none ||
          currentStep == TutorialStep.clickEnterStore ||
          currentStep == TutorialStep.returnToHome ||
          currentStep == TutorialStep.returnToStoresModule ||
          currentStep == TutorialStep.returnToStoreDetail ||
          currentStep == TutorialStep.clickCreateShelf ||
          currentStep == TutorialStep.clickGoToMarket ||
          currentStep == TutorialStep.clickSelectProduct ||
          currentStep == TutorialStep.clickSetPrice ||
          currentStep == TutorialStep.clickAddStock) {
        if (store.slots.isEmpty) {
          if (currentStep != TutorialStep.clickCreateShelf) {
            ref
                .read(tutorialProvider.notifier)
                .setStep(TutorialStep.clickCreateShelf);
          }
        } else {
          final warehouseHasStock =
              storeWarehouse != null &&
              storeWarehouse.slots.any((s) => s.quantity > 0);

          if (!hasProduct) {
            if (!warehouseHasStock) {
              if (currentStep != TutorialStep.clickGoToMarket &&
                  currentStep != TutorialStep.selectMarketWarehouse &&
                  currentStep != TutorialStep.selectMarketProduct &&
                  currentStep != TutorialStep.clickMarketBuyListing &&
                  currentStep != TutorialStep.confirmMarketCartBuy &&
                  currentStep != TutorialStep.confirmMarketCheckout &&
                  currentStep != TutorialStep.returnToHome &&
                  currentStep != TutorialStep.returnToStoresModule &&
                  currentStep != TutorialStep.returnToStoreDetail) {
                ref
                    .read(tutorialProvider.notifier)
                    .setStep(TutorialStep.clickGoToMarket);
              }
            } else {
              if (currentStep != TutorialStep.clickSelectProduct) {
                ref
                    .read(tutorialProvider.notifier)
                    .setStep(TutorialStep.clickSelectProduct);
              }
            }
          } else if (!hasStock) {
            if (currentStep != TutorialStep.clickAddStock) {
              ref
                  .read(tutorialProvider.notifier)
                  .setStep(TutorialStep.clickAddStock);
            }
          } else if (!hasPrice) {
            if (currentStep != TutorialStep.clickSetPrice) {
              ref
                  .read(tutorialProvider.notifier)
                  .setStep(TutorialStep.clickSetPrice);
            }
          } else {
            if (currentStep != TutorialStep.finished &&
                currentStep != TutorialStep.viewSalesReport &&
                currentStep != TutorialStep.none) {
              ref
                  .read(tutorialProvider.notifier)
                  .setStep(TutorialStep.finished);
            }
          }
        }
      }
    });
  }

  void _scheduleSalesSummaryDialog(StoreDetailPageModel page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(storeHistoryDirtyProvider(page.store.id).notifier).state =
          page.changed.historyDirty;
      ref.read(storePerformanceDirtyProvider(page.store.id).notifier).state =
          page.changed.performanceDirty;
    });

    final result = page.saleResult;
    if (result == null || !result.processed || !result.hasVisibleSales) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final resultKey =
          '${page.store.id}_${result.processedAt?.toIso8601String() ?? 'no_time'}_${result.totalSoldQuantity}_${result.totalRevenue}';
      if (_lastShownSalesResultKey == resultKey) {
        return;
      }
      _lastShownSalesResultKey = resultKey;

      // Automatic store sales change the player's cash balance, but the
      // backend response does not always flag player changes explicitly.

      // Clear the sale result from the provider so it doesn't pop up again when returning to this screen
      ref
          .read(storeDetailPageProvider(page.store.id).notifier)
          .clearSaleResult();

      if (result.success != true && (result.message ?? '').trim().isNotEmpty) {
        AppSnackbar.show(
          context,
          title: 'Satis Hesaplanamadi',
          message: result.message!,
          type: SnackbarType.error,
        );
        return;
      }

      await _showStoreSalesSummaryDialog(context, result, page.store.slots);

      if (!mounted) return;
      final exp = result.experience;
      if (exp != null && exp.leveledUp) {
        await _showLevelUpDialog(context, exp);
      }
    });
  }

  Future<void> _showStoreSalesSummaryDialog(
    BuildContext context,
    StoreSaleResultModel result,
    List<StoreSlotModel> slots,
  ) {
    final profitColor = result.totalProfit >= 0
        ? AppColors.green
        : AppColors.red;
    final currentBrandName = ref
        .read(playerBrandCompanyProvider)
        .value
        ?.brandName;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Container(
          key:
              (ref.watch(tutorialProvider).step == TutorialStep.viewSalesReport)
              ? TutorialKeys.salesReportDialogKey
              : null,
          padding: EdgeInsets.all(16.w),
          decoration: AppDecorations.premiumCard(profitColor, 20.r),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: profitColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: profitColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        result.totalProfit >= 0
                            ? AppIcons.trendingUpRounded
                            : AppIcons.trendingDownRounded,
                        color: profitColor,
                        size: AppIconSizes.medium,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satis Ozeti',
                            style: AppTextStyles.h2.standardCopyWith(
                              color: AppColors.white,
                              fontSize: AppTypography.titleLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Gecen Sure: ${_formatElapsedSalesDuration(result.elapsedMinutes)}',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppFx.softOverlay(0.02),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: AppFx.softOverlay(0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSalesSummaryMetric(
                              'Adet',
                              result.totalSoldQuantity.toString(),
                              AppColors.gold,
                            ),
                          ),
                          Expanded(
                            child: _buildSalesSummaryMetric(
                              'Ciro',
                              AppMoney.full(result.totalRevenue, decimals: 1),
                              AppColors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildSalesSummaryMetric(
                              'Kar',
                              AppMoney.full(result.totalProfit, decimals: 1),
                              profitColor,
                            ),
                          ),
                        ],
                      ),
                      if ((result.experience?.amount ?? 0) > 0) ...[
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 6.h,
                            horizontal: 12.w,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.blue.withValues(alpha: 0.15),
                                AppColors.info.withValues(alpha: 0.03),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                AppIcons.starRounded,
                                color: AppColors.blue,
                                size: AppIconSizes.small,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                '+${result.experience!.amount} XP Kazandin!',
                                style: AppTextStyles.label.standardCopyWith(
                                  color: AppColors.white,
                                  fontSize: AppTypography.bodySmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                if (result.items.isNotEmpty) ...[
                  Text(
                    'Urunler',
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.white.withValues(alpha: 0.70),
                      fontSize: AppTypography.bodyLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 250.h),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: result.items.length,
                      separatorBuilder: (_, index) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final item = result.items[index];
                        final slot = slots.firstWhere(
                          (s) =>
                              s.slotIndex == item.slotIndex ||
                              s.productId == item.productId,
                          orElse: () => StoreSlotModel(
                            id: '',
                            storeId: '',
                            slotIndex: item.slotIndex,
                            brandId: _defaultBrandId,
                            quantity: 0,
                            pendingQuantity: 0,
                            qualityLevel: item.qualityLevel,
                            capacity: 0,
                            boostMultiplier: 1.0,
                            isActive: false,
                            isEmpty: true,
                            usedCapacityRatio: 0.0,
                          ),
                        );
                        final productIcon =
                            slot.productIcon ??
                            slot.product?.urunIconu ??
                            'default.webp';

                        return Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppFx.softOverlay(0.03),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppFx.softOverlay(0.06)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36.w,
                                height: 36.w,
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: AppFx.panelWash(0.25),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: AppFx.softOverlay(0.08),
                                  ),
                                ),
                                child: BrandedProductImage(
                                  fileName: productIcon,
                                  brandId: slot.brandId,
                                  brandName: slot.brandId != _defaultBrandId
                                      ? currentBrandName
                                      : null,
                                  productId: item.productId,
                                  fit: BoxFit.contain,
                                  showFrame: false,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.title
                                          .standardCopyWith(
                                            color: AppColors.white,
                                            fontSize: AppTypography.body,
                                            fontWeight: FontWeight.bold,
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
                                                : AppFx.softOverlay(0.10),
                                            size: AppIconSizes.xxSmall,
                                          ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          '| Slot ${item.slotIndex}',
                                          style: AppTextStyles.caption
                                              .standardCopyWith(
                                                color: AppColors.textMuted,
                                                fontSize: AppTypography.caption,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item.soldQuantity} Adet',
                                    style: AppTextStyles.label.standardCopyWith(
                                      color: AppColors.gold,
                                      fontSize: AppTypography.bodySmall,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${item.profit >= 0 ? '+' : ''}${item.profit.toStringAsFixed(1)} TL',
                                    style: AppTextStyles.label.standardCopyWith(
                                      color: item.profit >= 0
                                          ? AppColors.green
                                          : AppColors.red,
                                      fontSize: AppTypography.bodySmall,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: profitColor.withValues(alpha: 0.16),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: profitColor,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(vertical: 11.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    onPressed: () {
                      if (ref.read(tutorialProvider).step ==
                          TutorialStep.viewSalesReport) {
                        ref
                            .read(tutorialProvider.notifier)
                            .setStep(TutorialStep.finished);
                      }
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(
                      'Tamam',
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
      ),
    );
  }

  Future<void> _showLevelUpDialog(
    BuildContext context,
    ExperienceGainModel experience,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Seviye Atladi!',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.gold,
            fontSize: AppTypography.headline,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tebrikler, sirket seviyen yukseldi.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
            SizedBox(height: 12.h),
            _buildSalesSummaryRow(
              'Eski Seviye',
              experience.oldLevel.toString(),
            ),
            _buildSalesSummaryRow(
              'Yeni Seviye',
              experience.newLevel.toString(),
              valueColor: AppColors.gold,
            ),
            _buildSalesSummaryRow(
              'Kazanilan XP',
              '+${experience.amount}',
              valueColor: AppColors.blue,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Harika'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.body,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.standardCopyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label.standardCopyWith(
            color: color,
            fontSize: AppTypography.bodyLarge,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  String _formatElapsedSalesDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainMinutes = minutes % 60;
      if (remainMinutes == 0) return '${hours}s';
      return '${hours}s ${remainMinutes}dk';
    }
    return '${minutes}dk';
  }

  Widget _buildStoreWarehouseCard(
    BuildContext context,
    StoreModel store,
    StoreWarehouseSummaryModel warehouse,
  ) {
    final double fillRatio = warehouse.capacity > 0
        ? (warehouse.usedCapacity / warehouse.capacity).clamp(0.0, 1.0)
        : 0.0;
    final int fillPercent = (fillRatio * 100).toInt();

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => context.push('/store/${store.id}/warehouse'),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: AppColors.blue.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Satır: İkon + Başlık + Doluluk Hapı + Ok
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.warehouse_rounded,
                      color: AppColors.blue,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mağaza Deposu',
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          warehouse.name,
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: 10.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '%$fillPercent Dolu',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.blue,
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.textMuted,
                    size: 18.sp,
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // İlerleme Çubuğu ve Kapasite Metinleri
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Depo Kapasitesi',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${warehouse.usedCapacity.toStringAsFixed(1)} / ${warehouse.capacity.toStringAsFixed(1)} m³ (${warehouse.slots.length} Ürün Çeşidi)',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(3.r),
                child: LinearProgressIndicator(
                  value: fillRatio,
                  minHeight: 5.h,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fillRatio >= 0.90
                        ? AppColors.red
                        : fillRatio >= 0.70
                        ? AppColors.gold
                        : AppColors.blue,
                  ),
                ),
              ),

              // Depodaki Ürünlerin Yatay Vitrini
              if (warehouse.slots.isNotEmpty) ...[
                SizedBox(height: 10.h),
                SizedBox(
                  height: 48.w,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: warehouse.slots.length,
                    separatorBuilder: (context, index) => SizedBox(width: 8.w),
                    itemBuilder: (context, index) {
                      final slot = warehouse.slots[index];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.w,
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: AppColors.cardBgLight.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppColors.blue.withValues(alpha: 0.25),
                              ),
                            ),
                            child: BrandedProductImage(
                              fileName: slot.productIcon ?? 'default.webp',
                              brandId: slot.brandId,
                              brandName: _warehouseSlotBrandName(slot),
                              productId: slot.productId,
                              fit: BoxFit.contain,
                              showFrame: false,
                            ),
                          ),
                          Positioned(
                            bottom: 2.h,
                            right: 2.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4.r),
                                border: Border.all(
                                  color: AppColors.borderGold.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${slot.quantity}',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    StoreDetailPageModel page,
  ) {
    final store = page.store;
    final storeWarehouse = page.storeWarehouse;
    final activeBoost = page.activeBoost;
    final activeUpgrade = page.activeUpgrade;

    return Column(
      children: [
        SecondaryTopBar(title: 'Magaza Yonetimi'),
        Consumer(
          builder: (context, ref, _) {
            final listAsync = ref.watch(storesListProvider);
            return listAsync.maybeWhen(
              data: (list) {
                if (list.length <= 1) return const SizedBox.shrink();
                final hasCurrent = list.any((item) => item.id == store.id);
                if (!hasCurrent) return const SizedBox.shrink();

                return Container(
                  margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.borderGold.withValues(alpha: 0.25),
                      width: 1.w,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: store.id,
                      isExpanded: true,
                      dropdownColor: AppColors.cardBg,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.gold,
                      ),
                      items: list.map((item) {
                        final displayCity = item.cityName ?? 'Bilinmeyen Sehir';
                        return DropdownMenuItem<String>(
                          value: item.id,
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.pointOfSale,
                                color: AppColors.gold,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  '${item.name} ($displayCity)',
                                  style: AppTextStyles.body.standardCopyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: AppTypography.bodySmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null && newId != store.id) {
                          context.pushReplacement('/store/$newId');
                        }
                      },
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.background,
            onRefresh: () =>
                _refreshStorePageAndSync(store.id, refreshPlayer: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12.h),
                  StoreDetailHeader(
                    store: store,
                    onToggleActiveTap: () =>
                        _toggleStoreActive(context, ref, store),
                    onReportTap: () =>
                        context.push('/store/${store.id}/report'),
                    onHistoryTap: () =>
                        context.push('/store/${store.id}/history'),
                    onSellTap: () => _showSellStoreDialog(context, ref, store),
                  ),
                  SizedBox(height: 16.h),
                  StoreQuickActions(
                    openSlotKey:
                        (ref.watch(tutorialProvider).step ==
                            TutorialStep.clickCreateShelf)
                        ? TutorialKeys.storeQuickActionOpenSlotKey
                        : null,
                    canOpenNewSlot: store.currentSlotCount < store.maxSlotCount,
                    onUpgradeTap: () => _showStoreUpgradeSheet(
                      context,
                      ref,
                      store,
                      activeUpgrade,
                    ),
                    onBoostTap: () =>
                        _showStoreBoostSheet(context, ref, store, activeBoost),
                    onReportTap: () =>
                        context.push('/store/${store.id}/report'),
                    onOpenSlotTap: () => _handleOpenSlot(context, ref, store),
                    onHistoryTap: () =>
                        context.push('/store/${store.id}/history'),
                  ),
                  if (activeBoost != null) ...[
                    SizedBox(height: 16.h),
                    _ActiveBoostCard(boost: activeBoost),
                  ],
                  if (activeUpgrade != null) ...[
                    SizedBox(height: 16.h),
                    _ActiveUpgradeCard(
                      upgrade: activeUpgrade,
                      onFinishWithGold: () =>
                          _finishStoreUpgradeWithGold(activeUpgrade),
                      onReduceTimeWithAd: () =>
                          _reduceStoreUpgradeTimeWithAd(activeUpgrade),
                      calculateStarCost: _calculateUpgradeStarCost,
                      formatCountdown: _formatCountdown,
                    ),
                  ],

                  if (storeWarehouse != null) ...[
                    SizedBox(height: 16.h),
                    _buildStoreWarehouseCard(context, store, storeWarehouse),
                  ],
                  SizedBox(height: 22.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Başlık & Dolu Raf Sayacı
                      Row(
                        children: [
                          Text(
                            'Mağaza Rafları',
                            style: AppTextStyles.h2.standardCopyWith(
                              color: AppColors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '${store.slots.where((s) => !s.isEmpty).length}/${store.slots.length}',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.gold,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Sağ Taraf: Toplu Fiyat ve Hızlı Doldur Butonları
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toplu Fiyat Butonu
                          InkWell(
                            onTap:
                                !_isBulkUpdatingPrices &&
                                    _canBulkUpdateStorePrices(store)
                                ? () => _showBulkPriceUpdateDialog(
                                    context,
                                    ref,
                                    store,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: _canBulkUpdateStorePrices(store)
                                    ? AppColors.blue.withValues(alpha: 0.12)
                                    : AppColors.cardBgLight.withValues(
                                        alpha: 0.3,
                                      ),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: _canBulkUpdateStorePrices(store)
                                      ? AppColors.blue.withValues(alpha: 0.4)
                                      : AppColors.border.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isBulkUpdatingPrices)
                                    SizedBox(
                                      width: 12.sp,
                                      height: 12.sp,
                                      child: AppLoadingIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.blue,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.sell_outlined,
                                      color: _canBulkUpdateStorePrices(store)
                                          ? AppColors.blue
                                          : AppColors.textMuted,
                                      size: 13.sp,
                                    ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    _isBulkUpdatingPrices ? '...' : 'Fiyat',
                                    style: AppTextStyles.caption
                                        .standardCopyWith(
                                          color:
                                              _canBulkUpdateStorePrices(store)
                                              ? AppColors.blue
                                              : AppColors.textMuted,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),

                          // Tümünü Doldur Butonu
                          InkWell(
                            onTap:
                                !_isFillingShelves &&
                                    _canFillStoreShelves(store, storeWarehouse)
                                ? () => _fillStoreShelves(context, ref, store)
                                : null,
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    _canFillStoreShelves(store, storeWarehouse)
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.gold.withValues(
                                            alpha: 0.25,
                                          ),
                                          AppColors.gold.withValues(
                                            alpha: 0.08,
                                          ),
                                        ],
                                      )
                                    : null,
                                color:
                                    _canFillStoreShelves(store, storeWarehouse)
                                    ? null
                                    : AppColors.cardBgLight.withValues(
                                        alpha: 0.3,
                                      ),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color:
                                      _canFillStoreShelves(
                                        store,
                                        storeWarehouse,
                                      )
                                      ? AppColors.gold.withValues(alpha: 0.5)
                                      : AppColors.border.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isFillingShelves)
                                    SizedBox(
                                      width: 12.sp,
                                      height: 12.sp,
                                      child: AppLoadingIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.gold,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.bolt_rounded,
                                      color:
                                          _canFillStoreShelves(
                                            store,
                                            storeWarehouse,
                                          )
                                          ? AppColors.gold
                                          : AppColors.textMuted,
                                      size: 14.sp,
                                    ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    _isFillingShelves ? 'Doluyor' : 'Doldur',
                                    style: AppTextStyles.caption
                                        .standardCopyWith(
                                          color:
                                              _canFillStoreShelves(
                                                store,
                                                storeWarehouse,
                                              )
                                              ? AppColors.gold
                                              : AppColors.textMuted,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
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
                  SizedBox(height: 12.h),
                  _buildSlotList(context, ref, store),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleOpenSlot(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final result = await ref.read(storeActionProvider).addStoreSlot(store.id);

    if (context.mounted) {
      if (result['success'] == true) {
        final tutorial = ref.read(tutorialProvider);
        if (tutorial.step == TutorialStep.clickCreateShelf) {
          ref
              .read(tutorialProvider.notifier)
              .setStep(TutorialStep.clickGoToMarket);
        }
        await _refreshStorePageAndSync(store.id, performanceDirty: true);
        if (!context.mounted) return;
        _showSuccess(context, 'Yeni raf başarıyla oluşturuldu!');
      } else {
        if (!context.mounted) return;
        _showError(
          context,
          _buildGuidedError(
            'Yeni raf oluşturulamadı.',
            detail: result['message']?.toString(),
            suggestion:
                'Bakiyeni, mağaza seviyeni ve boş raf limitini kontrol edip tekrar dene.',
          ),
        );
      }
    }
  }

  Future<void> _toggleStoreActive(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final nextActive = !store.isActive;
    final result = await ref
        .read(storeActionProvider)
        .setStoreActive(storeId: store.id, isActive: nextActive);

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref
          .read(storeDetailPageProvider(store.id).notifier)
          .patchStoreActive(nextActive);
      ref
          .read(storesListProvider.notifier)
          .patchStoreActive(storeId: store.id, isActive: nextActive);
      ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
      _showSuccess(
        context,
        nextActive ? 'Magaza aktif edildi.' : 'Magaza pasife alindi.',
      );
      return;
    }

    _showError(
      context,
      _buildGuidedError(
        'Magaza durumu guncellenemedi.',
        detail: result['message']?.toString(),
        suggestion:
            'Aktif transfer, vergi veya isletme kisitlarini kontrol edip tekrar dene.',
      ),
    );
  }

  Future<void> _showSellStoreDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final quote = await ref
        .read(storeActionProvider)
        .sellStore(storeId: store.id, confirm: false);

    if (!context.mounted) return;

    if (quote['success'] != true) {
      _showError(
        context,
        _buildGuidedError(
          'Satis teklifi hazirlanamadi.',
          detail: quote['message']?.toString(),
          suggestion:
              'Magaza deposunda veya transferlerinde bekleyen bir islem varsa once onu tamamla.',
        ),
      );
      return;
    }

    final constructionRefund =
        (quote['construction_refund'] as num?)?.toDouble() ?? 0;
    final stockRefund = (quote['stock_refund'] as num?)?.toDouble() ?? 0;
    final totalRefund = (quote['total_refund'] as num?)?.toDouble() ?? 0;

    final shouldSell = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Magazayi Sat',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.red,
            fontSize: AppTypography.headline,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${store.name} kalici olarak silinecek. Bu islem geri alinamaz.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
                height: 1.35,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _buildSalesSummaryRow(
                    'Kurulus Iadesi',
                    constructionRefund.toStringAsFixed(1),
                    valueColor: AppColors.gold,
                  ),
                  _buildSalesSummaryRow(
                    'Stok ve Depo Iadesi',
                    stockRefund.toStringAsFixed(1),
                    valueColor: AppColors.gold,
                  ),
                  Divider(color: AppColors.border, height: 12.h),
                  _buildSalesSummaryRow(
                    'Toplam Odeme',
                    totalRefund.toStringAsFixed(1),
                    valueColor: AppColors.green,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Aktif transfer varsa satis engellenir. Magaza deposu ve icindeki stoklar iade hesabina dahildir; satis sonrasi depo kapanir.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Magazayi Sat',
              style: AppTextStyles.button.standardCopyWith(
                color: AppColors.textOnAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldSell != true || !context.mounted) return;

    final result = await ref
        .read(storeActionProvider)
        .sellStore(storeId: store.id, confirm: true);

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref.read(storesListProvider.notifier).removeStore(store.id);
      _showSuccess(
        context,
        'Magaza satildi. ${((result['total_refund'] as num?)?.toDouble() ?? totalRefund).toStringAsFixed(1)} TL eklendi.',
      );
      context.go('/store');
      return;
    }

    _showError(
      context,
      _buildGuidedError(
        'Magaza satilamadi.',
        detail: result['message']?.toString(),
        suggestion:
            'Aktif transferleri, magaza deposunu ve devam eden yukseltmeleri kontrol edip tekrar dene.',
      ),
    );
  }

  Future<StoreDetailPageModel> _refreshStorePageAndSync(
    String storeId, {
    bool refreshPlayer = false,
    bool historyDirty = false,
    bool performanceDirty = false,
  }) async {
    final page = await ref
        .read(storeDetailPageProvider(storeId).notifier)
        .refresh();
    ref.read(storesListProvider.notifier).replaceStore(page.store);

    if (refreshPlayer || page.changed.player != null) {}

    if (historyDirty || page.changed.historyDirty) {
      ref.read(storeHistoryDirtyProvider(storeId).notifier).state = true;
    }

    if (performanceDirty || page.changed.performanceDirty) {
      ref.read(storePerformanceDirtyProvider(storeId).notifier).state = true;
    }

    return page;
  }

  String? _productNameFromMap(Map<String, dynamic> product) {
    return (product['name'] ?? product['urun_adi'])?.toString();
  }

  String? _productIconFromMap(Map<String, dynamic> product) {
    return (product['icon'] ?? product['urun_iconu'])?.toString();
  }

  String? _slotBrandName(StoreSlotModel slot) {
    if (slot.brandId == _defaultBrandId) return null;
    return ref.watch(playerBrandCompanyProvider).value?.brandName;
  }

  String? _warehouseSlotBrandName(StoreWarehouseSlotSummaryModel slot) {
    if (slot.brandId == _defaultBrandId) return null;
    return ref.watch(playerBrandCompanyProvider).value?.brandName;
  }

  String _buildGuidedError(
    String summary, {
    String? detail,
    String? suggestion,
  }) {
    final parts = <String>[summary.trim()];
    final cleanDetail = detail?.trim();
    if (cleanDetail != null && cleanDetail.isNotEmpty) {
      parts.add(cleanDetail);
    }
    final cleanSuggestion = suggestion?.trim();
    if (cleanSuggestion != null && cleanSuggestion.isNotEmpty) {
      parts.add(cleanSuggestion);
    }
    return parts.join(' ');
  }

  String _formatCountdown(Duration remaining) {
    if (remaining.inSeconds <= 0) return 'Tamamlaniyor';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    }
    return '${remaining.inMinutes}dk';
  }

  Future<void> _showStoreBoostSheet(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    BuildingBoostModel? activeBoost,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Sürükleme Çizgisi (Drag Handle)
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // Başlık & İkon & Kapat Butonu
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.25),
                          AppColors.gold.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      AppIcons.flashOnRounded,
                      color: AppColors.gold,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Mağaza Boostu',
                              style: AppTextStyles.h2.standardCopyWith(
                                color: AppColors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                '⚡ x2.0 Hız',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Tüm reyonlarda 2 kat hızlı satış',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: 10.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: AppColors.cardBgLight.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                        size: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Açıklama Metni Kutusu
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  activeBoost != null
                      ? 'Bu mağazada şu anda aktif bir boost bulunuyor. Kalan süre boyunca tüm satış slotları x${activeBoost.multiplier.toStringAsFixed(1)} hız katsayısıyla çalışarak satış döngülerini yarı sürede tamamlar.'
                      : 'Boost aktif edildiğinde tüm reyonların satış döngüsü süresi yarı yarıya iner (x2.0 hız). Satışlar iki kat hızlı gerçekleşir ve cironuz hızla artar.',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5.sp,
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              if (activeBoost == null) ...[
                // Reklamlı Hızlı Boost (30 dk)
                InkWell(
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await RewardedAdActionFlow.run(
                      context,
                      rewardKind: 'building_boost_start',
                      resourceId: 'store:${store.id}',
                      loadingMessage:
                          '30 dakikalık boost reklamı yükleniyor...',
                      successTitle: 'Boost Başlatıldı!',
                      successMessage:
                          'Mağaza boostu 30 dakika boyunca x2.0 hızla aktif edildi.',
                      feedbackAmount: 30,
                      feedbackType: FloatingFeedbackType.boostAdd,
                      onApplyAction: () async {
                        final result = await ref
                            .read(storeActionProvider)
                            .startStoreBoostWithAdReward(storeId: store.id);

                        if (result['success'] == true) {
                          await _refreshStorePageAndSync(
                            store.id,
                            refreshPlayer: true,
                          );
                        }
                        return result;
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.green.withValues(alpha: 0.12),
                          AppColors.green.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            AppIcons.playCircleFill,
                            color: AppColors.green,
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '30 Dakika Hızlı Boost',
                                    style: AppTextStyles.title.standardCopyWith(
                                      color: AppColors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 5.w,
                                      vertical: 1.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.green.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'Ücretsiz',
                                      style: AppTextStyles.caption
                                          .standardCopyWith(
                                            color: AppColors.green,
                                            fontSize: 8.5.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Reklam izleyerek yıldız harcamadan hızlandır',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 9.5.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'İzle',
                            style: AppTextStyles.label.standardCopyWith(
                              color: AppColors.background,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10.h),

                // Yıldızlı Boost Seçenekleri
                ..._storeBoostStarCosts.entries.map((entry) {
                  final hours = entry.key;
                  final stars = entry.value;
                  final isPopular = hours == 24;

                  final subtitle = hours == 6
                      ? 'Orta vadeli hızlı satış (6 Saat)'
                      : hours == 12
                      ? 'Yarım günlük kesintisiz hız (12 Saat)'
                      : '1 tam gün boyunca maksimum kâr (24 Saat)';

                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final result = await ref
                            .read(storeActionProvider)
                            .startStoreBoost(
                              storeId: store.id,
                              durationHours: hours,
                              starCost: stars,
                            );

                        if (!context.mounted) return;

                        if (result['success'] == true) {
                          await _refreshStorePageAndSync(
                            store.id,
                            refreshPlayer: true,
                          );
                          if (!context.mounted) return;
                          _showSuccess(
                            context,
                            '$hours saatlik mağaza boostu başlatıldı!',
                          );
                        } else {
                          _showError(
                            context,
                            result['message'] ?? 'Mağaza boostu başlatılamadı.',
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(14.r),
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: isPopular
                                ? AppColors.gold.withValues(alpha: 0.5)
                                : AppColors.border.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                AppIcons.flashOnRounded,
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
                                      Text(
                                        '$hours Saatlik Boost',
                                        style: AppTextStyles.title
                                            .standardCopyWith(
                                              color: AppColors.white,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (isPopular) ...[
                                        SizedBox(width: 6.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5.w,
                                            vertical: 1.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4.r,
                                            ),
                                          ),
                                          child: Text(
                                            'Popüler 🔥',
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color: AppColors.gold,
                                                  fontSize: 8.5.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    subtitle,
                                    style: AppTextStyles.caption
                                        .standardCopyWith(
                                          color: AppColors.textMuted,
                                          fontSize: 9.5.sp,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold.withValues(alpha: 0.25),
                                    AppColors.gold.withValues(alpha: 0.10),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.starRounded,
                                    color: AppColors.gold,
                                    size: 13.sp,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    '$stars',
                                    style: AppTextStyles.label.standardCopyWith(
                                      color: AppColors.gold,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.background,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(
                      'Tamam',
                      style: AppTextStyles.label.standardCopyWith(
                        color: AppColors.background,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _calculateUpgradeStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  Future<void> _finishStoreUpgradeWithGold(BuildingUpgradeModel upgrade) async {
    final starCost = _calculateUpgradeStarCost(upgrade.finishAt);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Yukseltmeyi Bitir',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.goldLight,
            fontSize: AppTypography.titleLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$starCost yildiz kullanarak yukseltmeyi aninda tamamlamak istiyor musunuz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Iptal',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Tamamla',
              style: AppTextStyles.button.standardCopyWith(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await ref
        .read(storeActionProvider)
        .finishStoreUpgradeWithGold(upgrade.id);

    if (!mounted) return;

    if (result['success'] == true) {
      await _refreshStorePageAndSync(widget.storeId, refreshPlayer: true);
      if (!mounted) return;
      _showSuccess(context, 'Magaza yukseltmesi tamamlandi!');
      await showExperienceFeedbackFromResult(context, result);
    } else {
      _showError(
        context,
        _buildGuidedError(
          'Yildiz ile aninda tamamlama basarisiz oldu.',
          detail: result['message']?.toString(),
          suggestion:
              'Yeterli yildizin oldugundan emin ol ve islemi biraz sonra tekrar dene.',
        ),
      );
    }
  }

  Future<void> _reduceStoreUpgradeTimeWithAd(
    BuildingUpgradeModel upgrade,
  ) async {
    final success = await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'upgrade_time_reduce',
      resourceId: upgrade.id,
      onApplyReduction: () => ref
          .read(storeActionProvider)
          .reduceStoreUpgradeTimeWithAd(upgrade.id),
      successMessage: 'Magaza yukseltme suresi 10 dakika kisaltildi.',
    );

    if (success) {
      await _refreshStorePageAndSync(widget.storeId, refreshPlayer: true);
    }
  }

  Future<void> _showStoreUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    if (activeUpgrade != null) {
      _showError(
        context,
        'Su anda oyun genelinde baska bir yukseltme devam ediyor. Once o yukseltmenin tamamlanmasini bekle.',
      );
      return;
    }
    final quote = await ref.read(
      buildingUpgradeQuoteProvider((
        buildingKind: 'store',
        entityId: store.id,
      )).future,
    );
    if (!context.mounted) return;
    if (quote.isMaximumLevel) {
      _showError(
        context,
        'Bu magaza zaten maksimum seviye ${quote.maxLevel}. Yeni yukseltme acmak icin once farkli bir magaza gelistirmen gerekir.',
      );
      return;
    }
    final targetLevel = quote.targetLevel!;
    final durationMinutes = quote.durationMinutes;
    final upgradeCost = quote.cashCost;
    final slotCapacityIncrease =
        quote.effect('store_slot_capacity')?.increase.toInt() ?? 0;
    final maxSlotIncrease =
        quote.effect('store_max_slot_count')?.increase.toInt() ?? 0;

    await showBuildingUpgradeSheet(
      context: context,
      title: 'Magaza Yukseltmesi',
      buildingName: store.name,
      icon: AppIcons.storefrontRounded,
      currentLevel: store.level,
      targetLevel: targetLevel,
      durationLabel: '$durationMinutes dk',
      costLabel: AppMoney.compact(upgradeCost),
      requirementLabel: quote.requirementLabel,
      benefits: [
        BuildingUpgradeBenefit(
          icon: AppIcons.inventory2Rounded,
          label: 'Raf kapasitesi',
          before: '${store.slotCapacity}',
          after: '${store.slotCapacity + slotCapacityIncrease}',
        ),
        BuildingUpgradeBenefit(
          icon: AppIcons.gridView,
          label: 'Maksimum raf',
          before: '${store.maxSlotCount}',
          after: '${store.maxSlotCount + maxSlotIncrease}',
        ),
      ],
      canConfirm: quote.canUpgrade,
      onConfirm: () async {
        final result = await ref
            .read(storeActionProvider)
            .startStoreUpgrade(store.id);
        if (!context.mounted) return;
        if (result['success'] == true) {
          await _refreshStorePageAndSync(store.id, refreshPlayer: true);
          if (!context.mounted) return;
          FloatingFeedback.show(
            context,
            amount: upgradeCost,
            type: FloatingFeedbackType.cashRemove,
          );
          _showSuccess(context, 'Magaza yukseltmesi baslatildi.');
        } else {
          _showError(
            context,
            _buildGuidedError(
              'Magaza yukseltmesi baslatilamadi.',
              detail: result['message']?.toString(),
              suggestion:
                  'Nakit durumunu, seviye gereksinimini ve acik yukseltme durumunu kontrol edip tekrar dene.',
            ),
          );
        }
      },
    );
  }

  Widget _buildSlotList(BuildContext context, WidgetRef ref, StoreModel store) {
    if (store.slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35),
            width: 1.2.w,
          ),
        ),
        child: Column(
          children: [
            Icon(AppIcons.addBox, color: AppColors.gold, size: 38.sp),
            SizedBox(height: 12.h),
            Text(
              'Henüz Raf Oluşturulmadı',
              style: AppTextStyles.h2.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Mağazanızda ürün sergilemek ve satış yapabilmek için hemen ilk rafınızı oluşturun.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              key:
                  (ref.watch(tutorialProvider).step ==
                      TutorialStep.clickCreateShelf)
                  ? TutorialKeys.storeEmptyShelfButtonKey
                  : null,
              onPressed: store.currentSlotCount < store.maxSlotCount
                  ? () => _handleOpenSlot(context, ref, store)
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('RAF OLUŞTUR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: store.slots.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return _buildProductSlotCard(
          context,
          ref,
          store,
          index + 1,
          store.slots[index],
        );
      },
    );
  }

  Widget _buildProductSlotCard(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    int index,
    StoreSlotModel slot,
  ) {
    final canAddStock = _canAddStockToSlot(slot);
    final canSendStock = _canSendStockFromSlot(slot);

    final qColor = slot.qualityLevel <= 1
        ? AppColors.red
        : slot.qualityLevel <= 2
        ? AppColors.warning
        : slot.qualityLevel <= 3
        ? AppColors.goldLight
        : slot.qualityLevel <= 4
        ? AppColors.success.withValues(alpha: 0.8)
        : AppColors.green;

    if (slot.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: AppColors.borderGold.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppFx.shadow(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: AppColors.cardBgLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                AppIcons.addShoppingCart,
                color: AppColors.gold.withValues(alpha: 0.5),
                size: 26.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boş Raf #$index',
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Satışa başlamak için depodan ürün seçin',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: 10.5.sp,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              key:
                  (ref.watch(tutorialProvider).step ==
                          TutorialStep.clickSelectProduct &&
                      index == 1)
                  ? TutorialKeys.storeSlotSelectProductKey
                  : null,
              onTap: () =>
                  _showProductSelectionDialog(context, ref, store, slot),
              borderRadius: BorderRadius.circular(10.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.25),
                      AppColors.gold.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.gold,
                      size: 14.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Ürün Seç',
                      style: AppTextStyles.label.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final double fillRatio = slot.capacity > 0
        ? (slot.quantity / slot.capacity).clamp(0.0, 1.0)
        : 0.0;
    final bool isLowStock = slot.isActive && fillRatio <= 0.20;

    final bool isBranded =
        slot.brandId.isNotEmpty && slot.brandId != _defaultBrandId;
    final String? brandTitle = isBranded
        ? (ref.watch(playerBrandCompanyProvider).value?.brandName ??
            _slotBrandName(slot))
        : null;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: slot.isActive ? 0.95 : 0.6),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: slot.isActive
              ? (isBranded
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : isLowStock
                      ? AppColors.red.withValues(alpha: 0.4)
                      : AppColors.borderGold.withValues(alpha: 0.35))
              : AppColors.border.withValues(alpha: 0.2),
          width: isBranded ? 1.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: slot.isActive
                ? (isBranded
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : isLowStock
                        ? AppColors.red.withValues(alpha: 0.08)
                        : AppColors.gold.withValues(alpha: 0.06))
                : AppFx.shadow(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isBranded
                        ? AppColors.gold.withValues(alpha: 0.6)
                        : AppColors.gold.withValues(alpha: 0.25),
                  ),
                ),
                child: BrandedProductImage(
                  fileName: slot.productIcon ?? 'default',
                  brandId: slot.brandId,
                  brandName: _slotBrandName(slot),
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
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  slot.productName ?? '',
                                  style: AppTextStyles.title.standardCopyWith(
                                    color: AppColors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isBranded && brandTitle != null && brandTitle.isNotEmpty) ...[
                                SizedBox(width: 5.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 1.5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.gold.withValues(alpha: 0.25),
                                        AppColors.gold.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        color: AppColors.gold,
                                        size: 9.sp,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        brandTitle,
                                        style: AppTextStyles.caption
                                            .standardCopyWith(
                                              color: AppColors.gold,
                                              fontSize: 8.5.sp,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!slot.isActive) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'PASİF',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.red,
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.h),

                    // Kalite Yıldızları
                    Row(
                      children: [
                        for (int barIndex = 0; barIndex < 5; barIndex++)
                          Icon(
                            AppIcons.starRounded,
                            color: barIndex < slot.qualityLevel
                                ? qColor
                                : AppColors.textMuted
                                    .withValues(alpha: 0.25),
                            size: 11.sp,
                          ),
                      ],
                    ),
                    SizedBox(height: 6.h),

                    // Fiyat + Kâr Marjı + Hız / Elastisite Rozetleri (Yan Yana)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Fiyat Rozeti
                        GestureDetector(
                          key: (ref.watch(tutorialProvider).step ==
                                      TutorialStep.clickSetPrice &&
                                  index == 1)
                              ? TutorialKeys.storeSlotPriceKey
                              : null,
                          onTap: () =>
                              _showPriceEditDialog(context, ref, store, slot),
                          child: Container(
                            height: 24.h,
                            padding: EdgeInsets.symmetric(horizontal: 7.w),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.45),
                                width: 1.w,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₺${slot.price?.toStringAsFixed(1) ?? '0'}',
                                  style: AppTextStyles.label.standardCopyWith(
                                    color: AppColors.gold,
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                Icon(
                                  AppIcons.edit,
                                  color: AppColors.gold
                                      .withValues(alpha: 0.85),
                                  size: 9.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 5.w),

                        // Kâr Marjı Rozeti
                        Container(
                          height: 24.h,
                          padding: EdgeInsets.symmetric(horizontal: 7.w),
                          decoration: BoxDecoration(
                            color: _storeSlotMarginColor(slot)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: _storeSlotMarginColor(slot)
                                  .withValues(alpha: 0.35),
                              width: 1.w,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _formatStoreSlotMargin(slot),
                            style: AppTextStyles.caption.standardCopyWith(
                              color: _storeSlotMarginColor(slot),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 5.w),

                        // Hız / Elastisite Rozeti
                        _buildElasticityBadge(slot),
                      ],
                    ),
                  ],
                ),
              ),

              // Sağ Üst: Popup Menü Butonu (3 nokta)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                color: AppColors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(
                    color: AppColors.borderGold.withValues(alpha: 0.3),
                  ),
                ),
                onSelected: (val) {
                  if (val == 'order' && canAddStock) {
                    _startStoreTransferFlow(context, ref, store, slot);
                  } else if (val == 'send' && canSendStock) {
                    _startStoreWarehouseOutboundFlow(context, ref, store, slot);
                  } else if (val == 'toggle') {
                    _toggleStoreSlotActive(context, ref, store, slot);
                  } else if (val == 'clear') {
                    _confirmClearStoreSlot(context, ref, store, slot);
                  } else if (val == 'change') {
                    _showProductSelectionDialog(context, ref, store, slot);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'order',
                    enabled: canAddStock,
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.addShoppingCart,
                          color: AppColors.green,
                          size: AppIconSizes.regular,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Depodan Rafa Stok Ekle',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'send',
                    enabled: canSendStock,
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.blue,
                          size: AppIconSizes.regular,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Stoğu Depoya Geri Aktar',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          slot.isActive
                              ? AppIcons.pauseCircleOutline
                              : AppIcons.playCircleOutline,
                          color: slot.isActive
                              ? AppColors.red
                              : AppColors.green,
                          size: AppIconSizes.regular,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          slot.isActive ? 'Pasif Yap' : 'Aktif Et',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'change',
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.swapHoriz,
                          color: AppColors.gold,
                          size: AppIconSizes.regular,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Ürünü Değiştir',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.cleaningServices,
                          color: AppColors.red,
                          size: AppIconSizes.regular,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Slotu Temizle',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: AppColors.cardBgLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    AppIcons.moreVert,
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                    size: 18.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Alt Çizgi: Reyon Stok Durumu + Progress Bar + Doldur Butonu
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                // Stok Bilgisi ve Barı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reyon Stoğu',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${slot.quantity} / ${slot.capacity}',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: isLowStock
                                  ? AppColors.red
                                  : AppColors.textPrimary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.h),
                      // Stok Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3.r),
                        child: LinearProgressIndicator(
                          value: fillRatio,
                          minHeight: 5.h,
                          backgroundColor: AppColors.background,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            fillRatio <= 0.20
                                ? AppColors.red
                                : fillRatio <= 0.50
                                ? AppColors.gold
                                : AppColors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),

                // Hızlı Doldur Butonu
                if (canAddStock) ...[
                  InkWell(
                    key: (ref.watch(tutorialProvider).step ==
                                TutorialStep.clickAddStock &&
                            index == 1)
                        ? TutorialKeys.storeSlotOrderStockKey
                        : null,
                    onTap: () => _startStoreTransferFlow(
                      context,
                      ref,
                      store,
                      slot,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLowStock
                              ? [AppColors.gold, AppColors.goldDark]
                              : [AppColors.green, const Color(0xFF1B8A5A)],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: (isLowStock
                                    ? AppColors.gold
                                    : AppColors.green)
                                .withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 13.sp,
                            color: AppColors.white,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'Doldur',
                            style: AppTextStyles.label.standardCopyWith(
                              color: AppColors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canAddStockToSlot(StoreSlotModel slot) {
    if (slot.productId == null || slot.productId!.isEmpty) return false;
    final remainingCapacity =
        slot.capacity - slot.quantity - slot.pendingQuantity;
    return remainingCapacity > 0;
  }

  bool _canSendStockFromSlot(StoreSlotModel slot) {
    return slot.quantity > 0;
  }

  bool _canFillStoreShelves(
    StoreModel store,
    StoreWarehouseSummaryModel? storeWarehouse,
  ) {
    if (storeWarehouse == null) return false;

    return store.slots.any((slot) {
      final availableCapacity =
          slot.capacity - slot.quantity - slot.pendingQuantity;
      if (!slot.isActive) return false;
      if ((slot.productId ?? '').isEmpty) return false;
      if (slot.qualityLevel <= 0) return false;
      if (availableCapacity <= 0) return false;

      return storeWarehouse.slots.any(
        (warehouseSlot) =>
            warehouseSlot.productId == slot.productId &&
            warehouseSlot.qualityLevel == slot.qualityLevel &&
            (warehouseSlot.brandId.isEmpty
                    ? _defaultBrandId
                    : warehouseSlot.brandId) ==
                (slot.brandId.isEmpty ? _defaultBrandId : slot.brandId) &&
            warehouseSlot.quantity > 0,
      );
    });
  }

  Widget _buildElasticityBadge(StoreSlotModel slot) {
    final double cost = slot.cost ?? 0;
    final double price = slot.price ?? 0;
    if (price <= 0 || cost <= 0) return const SizedBox.shrink();

    final double marginPercent = ((price - cost) / cost) * 100;
    String label;
    Color color;

    if (marginPercent <= 20) {
      label = '⚡ Hızlı';
      color = AppColors.green;
    } else if (marginPercent <= 45) {
      label = '⚖️ Dengeli';
      color = AppColors.gold;
    } else {
      label = '⚠️ Yavaş';
      color = AppColors.red;
    }

    return Container(
      height: 24.h,
      padding: EdgeInsets.symmetric(horizontal: 7.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.w),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _canBulkUpdateStorePrices(StoreModel store) {
    return store.slots.any(
      (slot) =>
          slot.isActive &&
          (slot.productId ?? '').isNotEmpty &&
          slot.qualityLevel > 0 &&
          (slot.cost ?? 0) > 0,
    );
  }

  void _showSuccess(BuildContext context, String message) {
    AppSnackbar.show(context, message: message, type: SnackbarType.success);
  }

  bool _shouldLockStoreSlotQualityV2(StoreSlotModel slot) {
    return (slot.quantity > 0 || slot.pendingQuantity > 0) &&
        slot.qualityLevel > 0;
  }

  void _showError(BuildContext context, String message) {
    AppSnackbar.show(context, message: message, type: SnackbarType.error);
  }

  Future<void> _fillStoreShelves(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    if (_isFillingShelves) return;

    setState(() {
      _isFillingShelves = true;
    });

    try {
      final result = await ref
          .read(storeActionProvider)
          .fillStoreShelves(storeId: store.id);

      if (!context.mounted) return;

      if (result['success'] == true) {
        await _refreshStorePageAndSync(
          store.id,
          refreshPlayer: true,
          historyDirty: true,
          performanceDirty: true,
        );
        if (!context.mounted) return;

        final transferredQuantity =
            (result['transferred_quantity'] as num?)?.toInt() ?? 0;
        final filledSlotCount =
            (result['filled_slot_count'] as num?)?.toInt() ?? 0;
        final message =
            result['message']?.toString() ??
            (transferredQuantity > 0
                ? 'Magaza raflari dolduruldu.'
                : 'Doldurulacak uygun depo stogu bulunamadi.');

        if (transferredQuantity > 0) {
          _showSuccess(
            context,
            '$message ($filledSlotCount raf, $transferredQuantity adet)',
          );
        } else {
          _showInfo(context, message);
        }
        return;
      }

      _showError(
        context,
        _buildGuidedError(
          'Raflar otomatik doldurulamadi.',
          detail: result['message']?.toString(),
          suggestion:
              'Magaza deposunda uygun stok oldugunu ve raflarda secili urun bulundugunu kontrol et.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFillingShelves = false;
        });
      }
    }
  }

  Future<void> _showBulkPriceUpdateDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    int selectedPercent = 30;
    final activeSlotCount = store.slots.where((s) => !s.isEmpty).length;

    final markupPercent = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String elasticityLabel;
            Color elasticityColor;
            IconData elasticityIcon;

            if (selectedPercent <= 20) {
              elasticityLabel = 'Yüksek Müşteri Trafiği (Hızlı Satış Hızı)';
              elasticityColor = AppColors.green;
              elasticityIcon = Icons.bolt_rounded;
            } else if (selectedPercent <= 45) {
              elasticityLabel = 'Dengeli Satış & Optimum Kâr Getirisi';
              elasticityColor = AppColors.gold;
              elasticityIcon = Icons.balance_rounded;
            } else {
              elasticityLabel = 'Yüksek Kâr Marjı (Daha Yavaş Satış Riski)';
              elasticityColor = AppColors.red;
              elasticityIcon = Icons.warning_amber_rounded;
            }

            return SafeArea(
              child: Container(
                padding: EdgeInsets.only(
                  left: 18.w,
                  right: 18.w,
                  top: 14.h,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                  border: Border.all(
                    color: AppColors.borderGold.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst Çizgi (Handle)
                      Center(
                        child: Container(
                          width: 36.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // Başlık Şeridi
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColors.blue.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Icon(
                              Icons.sell_outlined,
                              color: AppColors.blue,
                              size: 20.sp,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Toplu Fiyat Güncelleme',
                                  style: AppTextStyles.h2.standardCopyWith(
                                    color: AppColors.white,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '$activeSlotCount aktif reyon maliyetine göre ayarlanacak',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 10.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(sheetContext).pop(),
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: AppColors.cardBgLight.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: AppColors.textMuted,
                                size: 16.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Hazır Kâr Oranları (Presets) - Eşit Dağıtılmış ve Taşmasız
                      Text(
                        'Hazır Kâr Oranları',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [15, 25, 35, 50, 75].map((percent) {
                          final isSelected = selectedPercent == percent;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2.5.w),
                              child: InkWell(
                                onTap: () {
                                  setSheetState(() => selectedPercent = percent);
                                  AppHaptic.selection();
                                },
                                borderRadius: BorderRadius.circular(10.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 8.h),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [
                                              AppColors.gold,
                                              AppColors.goldDark,
                                            ],
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : AppColors.cardBgLight.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.gold
                                          : AppColors.borderGold.withValues(alpha: 0.25),
                                      width: 1.1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.gold.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+%$percent',
                                      style: AppTextStyles.caption.standardCopyWith(
                                        color: isSelected
                                            ? AppColors.background
                                            : AppColors.white,
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 16.h),

                      // Hedef Kâr Marjı Göstergesi & Stepper
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgLight.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Seçilen Kâr Marjı',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Azalt butonu (-)
                                    InkWell(
                                      onTap: selectedPercent > 5
                                          ? () {
                                              setSheetState(() {
                                                selectedPercent = (selectedPercent - 5).clamp(5, 100);
                                              });
                                              AppHaptic.selection();
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(6.r),
                                      child: Container(
                                        padding: EdgeInsets.all(4.w),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBg,
                                          borderRadius: BorderRadius.circular(6.r),
                                          border: Border.all(
                                            color: AppColors.border.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          color: selectedPercent > 5 ? AppColors.white : AppColors.textMuted,
                                          size: 14.sp,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      '+%$selectedPercent',
                                      style: AppTextStyles.h2.standardCopyWith(
                                        color: AppColors.gold,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    // Artır butonu (+)
                                    InkWell(
                                      onTap: selectedPercent < 100
                                          ? () {
                                              setSheetState(() {
                                                selectedPercent = (selectedPercent + 5).clamp(5, 100);
                                              });
                                              AppHaptic.selection();
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(6.r),
                                      child: Container(
                                        padding: EdgeInsets.all(4.w),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBg,
                                          borderRadius: BorderRadius.circular(6.r),
                                          border: Border.all(
                                            color: AppColors.border.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: selectedPercent < 100 ? AppColors.gold : AppColors.textMuted,
                                          size: 14.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4.h,
                                activeTrackColor: AppColors.gold,
                                inactiveTrackColor: AppColors.background,
                                thumbColor: AppColors.gold,
                                overlayColor: AppColors.gold.withValues(alpha: 0.2),
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7.r),
                              ),
                              child: Slider(
                                value: selectedPercent.toDouble(),
                                min: 5,
                                max: 100,
                                divisions: 19,
                                onChanged: (val) {
                                  setSheetState(() {
                                    selectedPercent = val.toInt();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // Elastisite / Satış Hızı Durum Kartı
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 9.h,
                        ),
                        decoration: BoxDecoration(
                          color: elasticityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: elasticityColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              elasticityIcon,
                              color: elasticityColor,
                              size: 16.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                elasticityLabel,
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: elasticityColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 18.h),

                      // Onay Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 46.h,
                        child: ElevatedButton(
                          onPressed: () {
                            AppHaptic.medium();
                            Navigator.of(sheetContext).pop(selectedPercent);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.background,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 16.sp,
                                color: AppColors.background,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'Fiyatları Güncelle (+%$selectedPercent)',
                                style: AppTextStyles.label.standardCopyWith(
                                  color: AppColors.background,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w900,
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
          },
        );
      },
    );

    if (markupPercent == null || !context.mounted) return;
    await _bulkUpdateStorePrices(context, ref, store, markupPercent);
  }

  Future<void> _bulkUpdateStorePrices(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    int markupPercent,
  ) async {
    if (_isBulkUpdatingPrices) return;

    setState(() {
      _isBulkUpdatingPrices = true;
    });

    try {
      final result = await ref
          .read(storeActionProvider)
          .bulkUpdateStoreSlotPrices(
            storeId: store.id,
            markupPercent: markupPercent,
          );

      if (!context.mounted) return;

      if (result['success'] == true) {
        await _refreshStorePageAndSync(
          store.id,
          refreshPlayer: false,
          historyDirty: false,
          performanceDirty: true,
        );
        if (!context.mounted) return;

        final updatedSlotCount =
            (result['updated_slot_count'] as num?)?.toInt() ?? 0;
        final message =
            result['message']?.toString() ??
            (updatedSlotCount > 0
                ? 'Toplu fiyat guncellemesi tamamlandi.'
                : 'Guncellenecek uygun raf bulunamadi.');

        if (updatedSlotCount > 0) {
          _showSuccess(context, '$message ($updatedSlotCount raf)');
        } else {
          _showInfo(context, message);
        }
        return;
      }

      _showError(
        context,
        _buildGuidedError(
          'Toplu fiyat guncellenemedi.',
          detail: result['message']?.toString(),
          suggestion:
              'Aktif raf ve gecerli maliyet bilgisi oldugundan emin olup tekrar dene.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBulkUpdatingPrices = false;
        });
      }
    }
  }

  void _showInfo(BuildContext context, String message) {
    AppSnackbar.show(context, message: message, type: SnackbarType.info);
  }

  void _showWarning(BuildContext context, String message) {
    AppSnackbar.show(context, message: message, type: SnackbarType.warning);
  }

  Future<void> _toggleStoreSlotActive(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final result = await ref
        .read(storeActionProvider)
        .setStoreSlotActive(slotId: slot.id, isActive: !slot.isActive);

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref
          .read(storeDetailPageProvider(store.id).notifier)
          .patchSlotActive(slotId: slot.id, isActive: !slot.isActive);
      ref
          .read(storesListProvider.notifier)
          .patchSlotActive(
            storeId: store.id,
            slotId: slot.id,
            isActive: !slot.isActive,
          );
      ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
      _showSuccess(
        context,
        slot.isActive ? 'Slot pasif yapildi.' : 'Slot aktif edildi.',
      );
      return;
    }

    _showError(context, result['message'] ?? 'Slot durumu guncellenemedi.');
  }

  Future<void> _confirmClearStoreSlot(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Slot Temizle',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.headline,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          slot.quantity > 0
              ? '${slot.productName ?? 'Bu ürün'} seçimini kaldırmak istiyor musun?\n\nRafta bulunan ${slot.quantity} adet ürün mağaza deposuna geri aktarılacaktır.'
              : '${slot.productName ?? 'Bu ürün'} seçimini kaldırmak istiyor musun?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodyLarge,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (shouldClear != true || !context.mounted) return;

    final result = await ref
        .read(storeActionProvider)
        .clearStoreSlotProduct(slot.id);

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref
          .read(storeDetailPageProvider(store.id).notifier)
          .patchSlotCleared(slotId: slot.id);
      ref
          .read(storesListProvider.notifier)
          .patchSlotCleared(storeId: store.id, slotId: slot.id);
      ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
      _showSuccess(context, 'Slot urun secimi temizlendi.');
      return;
    }

    _showError(
      context,
      _buildGuidedError(
        'Raf temizlenemedi.',
        detail: result['message']?.toString(),
        suggestion:
            'Rafta aktif stok, satis veya transfer varsa once bu islemleri bitir.',
      ),
    );
  }

  String _formatStoreSlotMargin(StoreSlotModel slot) {
    final price = slot.price ?? 0;
    final cost = slot.cost ?? 0;
    if (cost <= 0) return 'Maliyet';

    final marginRatio = ((price - cost) / cost) * 100;
    final sign = marginRatio >= 0 ? '+' : '';
    return '$sign${marginRatio.toStringAsFixed(0)}%';
  }

  Color _storeSlotMarginColor(StoreSlotModel slot) {
    final price = slot.price ?? 0;
    final cost = slot.cost ?? 0;
    if (cost <= 0) return AppColors.textMuted;
    return price >= cost ? AppColors.green : AppColors.red;
  }

  double _calculateStorePriceDemandMultiplier(
    double price,
    double referencePrice,
  ) {
    if (referencePrice <= 0) return 1.0;

    final ratio = price / referencePrice;
    if (ratio <= 1) {
      return (1 + ((1 - ratio) * 0.75)).clamp(0.05, 1.75).toDouble();
    }

    return (1 - ((ratio - 1) * 0.95)).clamp(0.05, 1.75).toDouble();
  }

  double _storeQualityPriceMultiplier(int qualityLevel) {
    switch (qualityLevel.clamp(1, 5)) {
      case 2:
        return 1.10;
      case 3:
        return 1.22;
      case 4:
        return 1.35;
      case 5:
        return 1.50;
      default:
        return 1.00;
    }
  }

  String _describeDemandEffect(double multiplier) {
    if (multiplier >= 1.35) return 'Cok yuksek talep';
    if (multiplier >= 1.1) return 'Yuksek talep';
    if (multiplier >= 0.9) return 'Dengeli talep';
    if (multiplier >= 0.6) return 'Dusuk talep';
    return 'Cok dusuk talep';
  }

  Color _demandEffectColor(double multiplier) {
    if (multiplier >= 1.1) return AppColors.green;
    if (multiplier >= 0.9) return AppColors.gold;
    return AppColors.red;
  }

  void _showPriceEditDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    final controller = TextEditingController(
      text: (slot.price ?? 0).toStringAsFixed(1).replaceAll('.', ','),
    );
    final cost = slot.cost ?? 0;
    final product = slot.product;
    final qualityPriceMultiplier = _storeQualityPriceMultiplier(
      slot.qualityLevel,
    );
    final basePrice = (product?.bazSatisFiyati ?? 0) * qualityPriceMultiplier;
    final averagePrice = product?.ortalamaFiyat ?? 0;
    final baseHourlyDemand = product?.satisAdedi ?? 0;
    double previewPrice = slot.price ?? 0;

    String shortcutValue(double value) =>
        value.toStringAsFixed(1).replaceAll('.', ',');

    final shortcuts = <NumericKeyboardShortcut>[
      if ((slot.price ?? 0) > 0)
        NumericKeyboardShortcut(
          label: 'Mevcut',
          value: shortcutValue(slot.price!),
        ),
      if (cost > 0)
        NumericKeyboardShortcut(label: 'Maliyet', value: shortcutValue(cost)),
      if (averagePrice > 0)
        NumericKeyboardShortcut(
          label: 'Pazar Ort.',
          value: shortcutValue(averagePrice),
        ),
    ];

    Future<void> savePrice(BuildContext sheetContext) async {
      final parsedPrice = double.tryParse(controller.text.replaceAll(',', '.'));

      if (parsedPrice == null || parsedPrice <= 0) {
        _showWarning(context, 'Gecerli bir fiyat girin.');
        return;
      }

      if (basePrice > 0 && parsedPrice > basePrice * 3) {
        _showWarning(
          context,
          'Fiyat baz fiyatın 3 katından fazla olamaz (Maks: ₺${(basePrice * 3).toStringAsFixed(1)}).',
        );
        return;
      }

      final result = await ref
          .read(storeActionProvider)
          .setStoreSlotPrice(slotId: slot.id, price: parsedPrice);

      if (!context.mounted || !sheetContext.mounted) return;

      if (result['success'] == true) {
        Navigator.of(sheetContext).pop();
        ref
            .read(storeDetailPageProvider(store.id).notifier)
            .patchSlotPrice(slotId: slot.id, price: parsedPrice);
        ref
            .read(storesListProvider.notifier)
            .patchSlotPrice(
              storeId: store.id,
              slotId: slot.id,
              price: parsedPrice,
            );
        ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
        if (ref.read(tutorialProvider).step == TutorialStep.clickSetPrice) {
          ref
              .read(tutorialProvider.notifier)
              .setStep(TutorialStep.viewSalesReport);
          // Zaman simülasyonu efekt modalını göster ve bitince RPC'yi tetikle
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => _TimeLapseSaleSimulationDialog(
              onComplete: () async {
                try {
                  await ref
                      .read(storeDetailPageProvider(store.id).notifier)
                      .triggerTutorialFirstSale();
                } catch (_) {}
              },
            ),
          );
        } else {
          _showSuccess(context, 'Satis fiyati kaydedildi.');
        }
        return;
      }

      _showError(
        context,
        _buildGuidedError(
          'Satis fiyati kaydedilemedi.',
          detail: result['message']?.toString(),
          suggestion:
              'Gecerli bir fiyat girdiginden emin ol ve rafi tekrar kaydet.',
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sheetContext, setState) {
          final marginAmount = previewPrice - cost;
          final marginRatio = cost > 0 ? (marginAmount / cost) * 100 : null;

          final demandMultiplier = _calculateStorePriceDemandMultiplier(
            previewPrice,
            basePrice,
          );
          final estimatedHourlyDemand = (baseHourlyDemand * demandMultiplier)
              .toDouble();
          final demandColor = _demandEffectColor(demandMultiplier);
          final profitColor = cost <= 0
              ? AppColors.gold
              : marginAmount >= 0
              ? AppColors.green
              : AppColors.red;
          final screenHeight = MediaQuery.of(sheetContext).size.height;

          return SafeArea(
            child: Container(
              key:
                  (ref.watch(tutorialProvider).step ==
                      TutorialStep.clickSetPrice)
                  ? TutorialKeys.priceDialogConfirmKey
                  : null,
              constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.22),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Satis Fiyati',
                                style: AppTextStyles.h2.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTypography.headline,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                (slot.productName ?? 'Urun') +
                                    (slot.brandId != _defaultBrandId
                                        ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})'
                                        : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: AppTypography.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
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
                      controller: controller,
                      readOnly: true,
                      keyboardType: TextInputType.none,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Birim satis fiyati',
                        labelStyle: AppTextStyles.body.standardCopyWith(
                          color: AppColors.gold,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textMuted),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.gold),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PriceDetailMetric(
                                label: 'BİRİM MALİYET',
                                value: AppMoney.full(cost),
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: _PriceDetailMetric(
                                label: 'TAHMİNİ NET KAR',
                                value: AppMoney.full(marginAmount),
                                subtitle: marginRatio == null
                                    ? 'Maliyet 0'
                                    : '%${marginRatio.toStringAsFixed(1)} marj',
                                color: profitColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: _PriceDetailMetric(
                                label: 'TAHMİNİ TALEP',
                                value: _describeDemandEffect(demandMultiplier),
                                subtitle: baseHourlyDemand > 0
                                    ? '${estimatedHourlyDemand.toStringAsFixed(1)} adet/saat'
                                    : 'Talep yok',
                                color: demandColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Text(
                            (averagePrice > 0
                                    ? 'Piyasa ortalamasi: ${averagePrice.toStringAsFixed(1)}'
                                    : basePrice > 0
                                    ? 'Kalite ${slot.qualityLevel} piyasa fiyati: ${basePrice.toStringAsFixed(1)} (x${qualityPriceMultiplier.toStringAsFixed(2)})'
                                    : 'Fiyat arttikca talep azalir, dustukce talep artar.') +
                                (basePrice > 0
                                    ? '\nMaksimum fiyat (3x): ₺${(basePrice * 3).toStringAsFixed(1)}'
                                    : ''),
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.bodySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    NumericKeyboard(
                      controller: controller,
                      allowDecimal: true,
                      buttonHeight: 44.h,
                      shortcuts: shortcuts,
                      onChanged: (value) {
                        setState(() {
                          previewPrice =
                              double.tryParse(value.replaceAll(',', '.')) ?? 0;
                        });
                      },
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Iptal'),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                            ),
                            onPressed: () => savePrice(dialogContext),
                            child: Text(
                              'Kaydet',
                              style: AppTextStyles.button.standardCopyWith(
                                color: AppColors.textOnAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showProductSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final parentContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: AppLoadingIndicator(color: AppColors.gold)),
    );

    Map<String, dynamic> result = const {};
    try {
      result = await ref
          .read(storeActionProvider)
          .getAvailableProductsForStore(store.id);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showError(
          context,
          _buildGuidedError(
            'Secilebilir urunler yuklenemedi.',
            detail: e.toString(),
            suggestion:
                'Baglantiyi ve magaza deposundaki stoklari kontrol edip tekrar dene.',
          ),
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (result['success'] != true) {
      if (context.mounted) {
        _showError(
          context,
          _buildGuidedError(
            'Secilebilir urunler getirilemedi.',
            detail: result['message']?.toString(),
            suggestion:
                'Magaza deposunda uygun urun oldugundan emin olup tekrar dene.',
          ),
        );
      }
      return;
    }

    const defaultBrandId = '00000000-0000-0000-0000-000000000000';
    final existingSignatures = store.slots
        .where((storeSlot) => storeSlot.id != slot.id)
        .where(
          (storeSlot) =>
              (storeSlot.productId ?? '').isNotEmpty &&
              storeSlot.qualityLevel > 0,
        )
        .map(
          (storeSlot) =>
              '${storeSlot.productId}|${storeSlot.qualityLevel}|${storeSlot.brandId.isEmpty ? defaultBrandId : storeSlot.brandId}',
        )
        .toSet();

    final List<dynamic> products = (result['products'] ?? []).where((product) {
      final productId = product['product_id']?.toString() ?? '';
      final qualityLevel = (product['quality_level'] as num?)?.toInt() ?? 1;
      final brandId = product['brand_id']?.toString().isNotEmpty == true
          ? product['brand_id'].toString()
          : defaultBrandId;
      final signature = '$productId|$qualityLevel|$brandId';
      return !existingSignatures.contains(signature);
    }).toList();

    if (products.isEmpty) {
      if (context.mounted) {
        _showInfo(
          context,
          'Magaza deposunda secilebilir yeni urun-kalite-brand kombinasyonu bulunamadi.',
        );
      }
      return;
    }

    final activeProducts = ref.read(playerActiveProductsProvider).value ?? [];
    final producedProductIds = activeProducts
        .where((p) => p.role == 'output')
        .map((p) => p.productId)
        .toSet();

    final options = products.map((product) {
      final productId = product['product_id']?.toString() ?? '';
      final isProduced = producedProductIds.contains(productId);
      final qualityLevel = (product['quality_level'] as num?)?.toInt() ?? 1;
      final quantity = (product['quantity'] as num?)?.toInt() ?? 0;
      return ProductSelectionOption(
        id: product['warehouse_slot_id']?.toString() ?? '',
        title: (product['name'] ?? 'Bilinmeyen Urun').toString(),
        subtitle: 'Kalite $qualityLevel | Stok: $quantity',
        iconPath: (product['icon'] ?? 'default').toString(),
        badgeText: 'Magaza Deposu',
        trailingWidget: isProduced
            ? Container(
                margin: EdgeInsets.only(top: 4.h),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.35),
                    width: 1.w,
                  ),
                ),
                child: Text(
                  'Üretilen',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.green,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () async {
          Navigator.pop(context);
          await _handleProductSelection(
            parentContext,
            ref,
            store,
            slot,
            product,
          );
        },
      );
    }).toList();

    if (!context.mounted) return;
    await ProductSelectionSheet.show(
      context: context,
      title: 'Ürün Seçimi',
      options: options,
    );
  }

  Future<void> _handleProductSelection(
    BuildContext parentContext,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> product,
  ) async {
    final result = await ref
        .read(storeActionProvider)
        .setStoreSlotProduct(
          slotId: slot.id,
          sourceWarehouseSlotId: product['warehouse_slot_id']?.toString(),
        );

    if (parentContext.mounted) {
      if (result['success'] == true) {
        final productId = product['product_id']?.toString() ?? '';
        final qualityLevel = (product['quality_level'] as num?)?.toInt() ?? 1;
        final brandId =
            product['brand_id']?.toString() ??
            '00000000-0000-0000-0000-000000000000';
        ref
            .read(storeDetailPageProvider(store.id).notifier)
            .patchSlotProduct(
              slotId: slot.id,
              productId: productId,
              qualityLevel: qualityLevel,
              brandId: brandId,
              productName: _productNameFromMap(product),
              productIcon: _productIconFromMap(product),
            );
        ref
            .read(storesListProvider.notifier)
            .patchSlotProduct(
              storeId: store.id,
              slotId: slot.id,
              productId: productId,
              qualityLevel: qualityLevel,
              brandId: brandId,
              productName: _productNameFromMap(product),
              productIcon: _productIconFromMap(product),
            );
        if (!parentContext.mounted) return;
        ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
        if (ref.read(tutorialProvider).step ==
            TutorialStep.clickSelectProduct) {
          ref
              .read(tutorialProvider.notifier)
              .setStep(TutorialStep.clickAddStock);
        }
        _showSuccess(parentContext, '${product['name']} basariyla eklendi!');
      } else {
        if (!parentContext.mounted) return;
        _showError(
          parentContext,
          _buildGuidedError(
            'Urun rafa eklenemedi.',
            detail: result['message']?.toString(),
            suggestion:
                'Secilen urunun depo stokta oldugunu ve rafin uygun kaliteye ayarlandigini kontrol et.',
          ),
        );
      }
    }
  }

  Widget _buildErrorState(WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.errorOutline,
            color: AppColors.red,
            size: AppIconSizes.hero,
          ),
          SizedBox(height: 16.h),
          Text(
            'Bir hata olustu: $error',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(storeDetailPageProvider(widget.storeId).notifier)
                  .refresh();
            },
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  void _startStoreTransferFlow(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    final page = ref.read(storeDetailPageProvider(store.id)).value;
    final storeWarehouse = page?.storeWarehouse;
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) {
      _showError(
        context,
        'Bu islem icin once rafta gecerli bir urun secmelisin.',
      );
      return;
    }

    if (storeWarehouse == null) {
      _showError(
        context,
        'Bu magazaya bagli depo bulunamadi. Depo olusmus mu kontrol et ve tekrar dene.',
      );
      return;
    }

    final shouldLockQuality = _shouldLockStoreSlotQualityV2(slot);
    final slotBrandId = slot.brandId.isEmpty
        ? '00000000-0000-0000-0000-000000000000'
        : slot.brandId;
    final matchingSlots = storeWarehouse.slots.where((warehouseSlot) {
      if (warehouseSlot.productId != productId) return false;
      if (warehouseSlot.quantity <= 0) return false;
      if (shouldLockQuality &&
          warehouseSlot.qualityLevel != slot.qualityLevel) {
        return false;
      }
      final warehouseBrandId = warehouseSlot.brandId.isEmpty
          ? '00000000-0000-0000-0000-000000000000'
          : warehouseSlot.brandId;
      if (warehouseBrandId != slotBrandId) {
        return false;
      }
      return true;
    }).toList();

    if (matchingSlots.isEmpty) {
      _showInfo(
        context,
        shouldLockQuality
            ? 'Magaza deposunda bu urunun secili urun-kalite-brand standardina uygun stogu yok.'
            : 'Magaza deposunda bu urune ait uygun stok bulunamadi.',
      );
      return;
    }

    matchingSlots.sort((a, b) {
      final quantityCompare = b.quantity.compareTo(a.quantity);
      if (quantityCompare != 0) return quantityCompare;
      return a.cost.compareTo(b.cost);
    });

    _showStoreWarehouseTransferQuantityDialog(
      context,
      ref,
      store,
      slot,
      matchingSlots.first,
    );
  }

  void _showStoreWarehouseTransferQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    StoreWarehouseSlotSummaryModel warehouseSlot,
  ) {
    final controller = TextEditingController(text: '1');
    final maxCanTake = slot.capacity - slot.quantity - slot.pendingQuantity;
    final limit = warehouseSlot.quantity < maxCanTake
        ? warehouseSlot.quantity
        : maxCanTake.toInt();

    if (limit <= 0) {
      _showWarning(context, 'Slot kapasitesi dolu veya depoda stok yok.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          void updateQuantity(String value) {
            final parsed = int.tryParse(value) ?? 1;
            final safe = limit <= 0 ? 0 : parsed.clamp(1, limit);
            final safeText = safe.toString();

            if (controller.text != safeText) {
              controller.value = TextEditingValue(
                text: safeText,
                selection: TextSelection.collapsed(offset: safeText.length),
              );
            }
          }

          return Material(
            color: AppColors.transparent,
            child: Container(
              key:
                  ref.watch(tutorialProvider).step == TutorialStep.clickAddStock
                  ? TutorialKeys.stockRefillConfirmKey
                  : null,
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Magaza Deposundan Cek',
                            style: AppTextStyles.h1.standardCopyWith(
                              fontSize: AppTypography.displaySmall,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
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
                      '${warehouseSlot.productName}${warehouseSlot.brandId != _defaultBrandId ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})' : ''} | Kalite ${warehouseSlot.qualityLevel}',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.title,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: controller,
                      readOnly: true,
                      showCursor: true,
                      enableInteractiveSelection: false,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Miktar',
                        labelStyle: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                        ),
                        helperText:
                            '1 - $limit adet arasi (Depo: ${warehouseSlot.quantity}, Slot: $maxCanTake)',
                        helperStyle: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.bodySmall,
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
                    SizedBox(height: 12.h),
                    NumericKeyboard(
                      controller: controller,
                      onChanged: updateQuantity,
                      shortcuts: [
                        NumericKeyboardShortcut(
                          label: '1/4',
                          value: limit <= 0
                              ? '0'
                              : (limit ~/ 4).clamp(1, limit).toString(),
                        ),
                        NumericKeyboardShortcut(
                          label: 'Yarisi',
                          value: limit <= 0
                              ? '0'
                              : (limit ~/ 2).clamp(1, limit).toString(),
                        ),
                        NumericKeyboardShortcut(
                          label: 'Tamami',
                          value: limit.toString(),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.textOnAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () {
                          final qty = int.tryParse(controller.text) ?? 0;
                          if (qty <= 0 || qty > limit) {
                            _showWarning(
                              context,
                              'Gecersiz miktar. 1 ile mevcut stok arasinda bir deger gir.',
                            );
                            return;
                          }
                          if (ref.read(tutorialProvider).step ==
                              TutorialStep.clickAddStock) {
                            ref
                                .read(tutorialProvider.notifier)
                                .setStep(TutorialStep.clickSetPrice);
                          }
                          Navigator.pop(dialogContext);
                          _startStoreWarehouseTransfer(
                            context,
                            ref,
                            store,
                            slot,
                            warehouseSlot,
                            qty,
                          );
                        },
                        child: Text(
                          'TRANSFER ET',
                          style: AppTextStyles.button.standardCopyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.title,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startStoreWarehouseTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    StoreWarehouseSlotSummaryModel warehouseSlot,
    int quantity,
  ) async {
    final productId = slot.productId;
    final needsSlotSetup =
        !_shouldLockStoreSlotQualityV2(slot) &&
        productId != null &&
        productId.isNotEmpty &&
        (slot.productId == null ||
            slot.qualityLevel != warehouseSlot.qualityLevel);

    if (needsSlotSetup) {
      final setupResult = await ref
          .read(storeActionProvider)
          .setStoreSlotProduct(
            slotId: slot.id,
            sourceWarehouseSlotId: warehouseSlot.id,
          );

      if (setupResult['success'] != true) {
        if (!context.mounted) return;
        _showError(
          context,
          _buildGuidedError(
            'Raf hazirlanamadi.',
            detail: setupResult['message']?.toString(),
            suggestion:
                'Raf urun eslesmesini kontrol edip transferi tekrar baslat.',
          ),
        );
        return;
      }
    }

    final result = await ref
        .read(storeActionProvider)
        .transferStoreWarehouseStockToSlot(
          storeSlotId: slot.id,
          warehouseSlotId: warehouseSlot.id,
          quantity: quantity,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      await _refreshStorePageAndSync(
        store.id,
        refreshPlayer: true,
        historyDirty: true,
        performanceDirty: true,
      );
      if (!context.mounted) return;
      _showSuccess(context, 'Stok magazaya tasindi.');
      return;
    }

    _showError(
      context,
      _buildGuidedError(
        'Depodan rafa stok tasinamadi.',
        detail: result['message']?.toString(),
        suggestion:
            'Depoda yeterli stok ve rafta bos kapasite oldugunu kontrol edip tekrar dene.',
      ),
    );
  }

  Widget _buildStatusPill(String label, Color accentColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.standardCopyWith(
          color: accentColor,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _startStoreWarehouseOutboundFlow(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final page = ref.read(storeDetailPageProvider(store.id)).value;
    final storeWarehouse = page?.storeWarehouse;

    if (slot.quantity <= 0) {
      _showError(
        context,
        'Depoya gonderecek stok yok. Once rafta urun oldugundan emin ol.',
      );
      return;
    }

    if (storeWarehouse == null) {
      _showError(
        context,
        'Bu magazaya bagli depo bulunamadi. Depo baglantisini kontrol edip tekrar dene.',
      );
      return;
    }

    _showStoreWarehouseReturnQuantityDialog(
      context,
      ref,
      store,
      slot,
      storeWarehouse,
    );
  }

  void _showStoreWarehouseReturnQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    StoreWarehouseSummaryModel storeWarehouse,
  ) {
    final controller = TextEditingController(text: '1');
    final limit = slot.quantity;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
          title: Text(
            'Magaza Deposuna Gonder',
            style: AppTextStyles.h2.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.headline,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (slot.productName ?? 'Urun') +
                            (slot.brandId != _defaultBrandId
                                ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})'
                                : ''),
                        style: AppTextStyles.title.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${store.name} -> ${storeWarehouse.name}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.body,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _buildStatusPill(
                            'Anlik Ic Transfer',
                            AppColors.green,
                          ),
                          _buildStatusPill('Maksimum $limit', AppColors.gold),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Miktar',
                    helperText: 'Depoya gonderilecek urun adedi',
                    labelStyle: AppTextStyles.body.standardCopyWith(
                      color: AppColors.gold,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.textMuted),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildQuickQuantityButton(
                      '1/4',
                      () => _applyStoreWarehouseReturnQuantity(
                        controller,
                        (limit / 4).ceil(),
                        limit,
                        setState,
                      ),
                    ),
                    _buildQuickQuantityButton(
                      'Yari',
                      () => _applyStoreWarehouseReturnQuantity(
                        controller,
                        (limit / 2).ceil(),
                        limit,
                        setState,
                      ),
                    ),
                    _buildQuickQuantityButton(
                      'Tamami',
                      () => _applyStoreWarehouseReturnQuantity(
                        controller,
                        limit,
                        limit,
                        setState,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () {
                final qty = int.tryParse(controller.text) ?? 0;
                if (qty <= 0 || qty > limit) {
                  _showWarning(
                    context,
                    'Gecersiz miktar. 1 ile mevcut stok arasinda bir deger gir.',
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                _startStoreWarehouseReturnTransfer(
                  context,
                  ref,
                  store,
                  slot,
                  qty,
                );
              },
              child: Text(
                'Transfer Et',
                style: AppTextStyles.button.standardCopyWith(
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQuantityButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  void _applyStoreWarehouseReturnQuantity(
    TextEditingController controller,
    int value,
    int limit,
    void Function(void Function()) setState,
  ) {
    final clamped = value.clamp(1, limit);
    setState(() {
      controller.text = clamped.toString();
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    });
  }

  Future<void> _startStoreWarehouseReturnTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    int quantity,
  ) async {
    final result = await ref
        .read(storeActionProvider)
        .returnStoreSlotStockToStoreWarehouse(
          storeSlotId: slot.id,
          quantity: quantity,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      await _refreshStorePageAndSync(
        store.id,
        refreshPlayer: true,
        historyDirty: true,
        performanceDirty: true,
      );
      if (!context.mounted) return;
      _showSuccess(context, 'Stok magaza deposuna gonderildi.');
      return;
    }

    _showError(
      context,
      _buildGuidedError(
        'Stok magaza deposuna gonderilemedi.',
        detail: result['message']?.toString(),
        suggestion:
            'Raftaki miktari ve depodaki uygun alan durumunu kontrol edip tekrar dene.',
      ),
    );
  }
}

class _ActiveBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveBoostCard({required this.boost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalSeconds = boost.finishAt.difference(boost.startedAt).inSeconds;
    final elapsedSeconds = now.difference(boost.startedAt).inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = boost.finishAt.difference(now);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: İkon + Başlık + Geri Sayım
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  AppIcons.flashOnRounded,
                  color: AppColors.gold,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'x${boost.multiplier.toStringAsFixed(1)} Satış Hızı Aktif',
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            '⚡ Boost',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      '${boost.durationLabel} Toplam Süre | ${boost.starCost > 0 ? '${boost.starCost} Yıldız' : 'Reklam Ödülü'}',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: 9.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _formatCountdownLabel(remaining),
                  style: AppTextStyles.label.standardCopyWith(
                    color: AppColors.gold,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // İnce İlerleme Çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4.h,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          SizedBox(height: 6.h),

          // Alt Satır: Yüzde Bilgisi
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '%${(progress * 100).toInt()} Tamamlandı',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final Future<void> Function()? onReduceTimeWithAd;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveUpgradeCard({
    required this.upgrade,
    required this.onFinishWithGold,
    this.onReduceTimeWithAd,
    required this.calculateStarCost,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalSeconds = upgrade.finishAt
        .difference(upgrade.startedAt)
        .inSeconds;
    final elapsedSeconds = now.difference(upgrade.startedAt).inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = upgrade.finishAt.difference(now);
    final starCost = calculateStarCost(upgrade.finishAt);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: İkon + Seviye Bilgisi + Geri Sayım
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  AppIcons.upgradeRounded,
                  color: AppColors.green,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Seviye ${upgrade.currentLevel} ➔ ${upgrade.targetLevel}',
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            '+${upgrade.slotCapacityIncrease} Kapasite',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.green,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Slotlar: +${upgrade.slotCapacityIncrease} | Max Slot: +${upgrade.maxSlotIncrease}',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: 9.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  formatCountdown(remaining),
                  style: AppTextStyles.label.standardCopyWith(
                    color: AppColors.gold,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // İnce İlerleme Çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4.h,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          SizedBox(height: 8.h),

          // Alt Satır: Yüzde + Hızlı Butonlar (-10dk reklam & Yıldız ile bitir)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '%${(progress * 100).toInt()} Tamamlandı',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (remaining.inSeconds > 0 &&
                      onReduceTimeWithAd != null) ...[
                    GestureDetector(
                      onTap: () => onReduceTimeWithAd!.call(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: AppColors.blue.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.blue,
                              size: 12.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '-10 dk',
                              style: AppTextStyles.label.standardCopyWith(
                                color: AppColors.blue,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                  ],
                  GestureDetector(
                    onTap: onFinishWithGold,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gold.withValues(alpha: 0.25),
                            AppColors.gold.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.starRounded,
                            color: AppColors.gold,
                            size: 13.sp,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            '$starCost Hemen Bitir',
                            style: AppTextStyles.label.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}

String _formatCountdownLabel(Duration remaining) {
  if (remaining.inSeconds <= 0) return 'Tamamlaniyor';
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours > 0) {
    return '${hours}s ${minutes}dk';
  }
  return '${remaining.inMinutes}dk';
}

class _PriceDetailMetric extends StatelessWidget {
  const _PriceDetailMetric({
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.label.standardCopyWith(
              color: color,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2.h),
            Text(
              subtitle!,
              style: AppTextStyles.caption.standardCopyWith(
                color: color.withValues(alpha: 0.75),
                fontSize: AppTypography.label,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeLapseSaleSimulationDialog extends StatefulWidget {
  final Future<void> Function() onComplete;

  const _TimeLapseSaleSimulationDialog({required this.onComplete});

  @override
  State<_TimeLapseSaleSimulationDialog> createState() =>
      _TimeLapseSaleSimulationDialogState();
}

class _TimeLapseSaleSimulationDialogState
    extends State<_TimeLapseSaleSimulationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  int _currentPhase = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _controller.addListener(() {
      final val = _controller.value;
      int newPhase = 0;
      if (val >= 0.82) {
        newPhase = 3;
      } else if (val >= 0.55) {
        newPhase = 2;
      } else if (val >= 0.25) {
        newPhase = 1;
      }
      if (newPhase != _currentPhase) {
        setState(() {
          _currentPhase = newPhase;
        });
        AppHaptic.medium();
      }
    });

    _controller.forward().then((_) async {
      AppHaptic.heavy();
      if (mounted) {
        Navigator.of(context).pop();
      }
      await widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.6),
            width: 1.5.w,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 30.r,
              spreadRadius: 2.r,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dönen ve parıldayan saat efekti
            RotationTransition(
              turns: _controller,
              child: Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.gold, width: 2.w),
                ),
                child: Icon(
                  AppIcons.accessTime,
                  color: AppColors.gold,
                  size: 34.sp,
                ),
              ),
            ),
            SizedBox(height: 18.h),

            // Sakin ve net zaman sayacı (09:00 -> 09:15 / +0 dk -> +15 dk)
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, _) {
                final mins = _progressAnimation.value.floor().clamp(0, 15);
                final clockStr = '09:${mins.toString().padLeft(2, '0')}';
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          clockStr,
                          style: AppTextStyles.h1.standardCopyWith(
                            color: AppColors.gold,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '+$mins dk',
                            style: AppTextStyles.badgeText.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '15 Dakikalık Açılış Satışı',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.caption,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: LinearProgressIndicator(
                        value: _controller.value,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.gold,
                        ),
                        minHeight: 6.h,
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 18.h),

            // Dinamik durum metinleri
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildPhaseContent(_currentPhase),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseContent(int phase) {
    String title;
    String subtitle;
    IconData icon;

    switch (phase) {
      case 0:
        title = 'Mağaza Kapıları Açıldı';
        subtitle =
            'Açılış tabelası asıldı, ilk müşteriler manava girmeye başladı...';
        icon = AppIcons.storefront;
        break;
      case 1:
        title = 'Yoğun Alışveriş Başladı';
        subtitle =
            'Müşteriler raftaki taze ürünleri inceliyor, sepetler doluyor...';
        icon = AppIcons.addShoppingCart;
        break;
      case 2:
        title = 'Kasa Sırası Oluşuyor';
        subtitle = 'Ürünler tek tek tartılıyor ve ödemeler alınıyor...';
        icon = AppIcons.accountBalanceWallet;
        break;
      default:
        title = '15 Dakika Tamamlandı!';
        subtitle = 'Kasa gün sonu raporu hazırlandı, kâr hesaplanıyor...';
        icon = AppIcons.attachMoney;
        break;
    }

    return Column(
      key: ValueKey<int>(phase),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.gold, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              title,
              style: AppTextStyles.h2.standardCopyWith(
                color: AppColors.white,
                fontSize: AppTypography.headline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }
}

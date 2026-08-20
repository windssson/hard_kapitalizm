import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/features/tender/data/tender_provider.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_detail_model.dart';

class TenderDetailScreen extends ConsumerStatefulWidget {
  const TenderDetailScreen({
    super.key,
    this.tenderId,
    this.playerTenderId,
  }) : assert(
         (tenderId != null && playerTenderId == null) ||
             (tenderId == null && playerTenderId != null),
         'Either tenderId or playerTenderId must be provided.',
       );

  final String? tenderId;
  final String? playerTenderId;

  @override
  ConsumerState<TenderDetailScreen> createState() => _TenderDetailScreenState();
}

class _TenderDetailScreenState extends ConsumerState<TenderDetailScreen> {
  String? _selectedWarehouseId;
  String? _selectedVehicleId;
  int _selectedQuantity = 0;
  bool _isSubmitting = false;
  final TextEditingController _bidAmountController = TextEditingController();

  bool get _isPlayerTender => widget.playerTenderId != null;
  bool _isTenderStillActive(TenderDetailModel detail) =>
      detail.playerTender?.status == 'active';

  @override
  void dispose() {
    _bidAmountController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(tenderActionProvider).refreshTenderRuntime();
    if (_isPlayerTender) {
      ref.invalidate(playerTenderDetailProvider(widget.playerTenderId!));
      await ref.read(playerTenderDetailProvider(widget.playerTenderId!).future);
      return;
    }
    ref.invalidate(tenderDetailProvider(widget.tenderId!));
    await ref.read(tenderDetailProvider(widget.tenderId!).future);
  }

  Future<void> _submitBid(TenderDetailModel detail) async {
    if (widget.tenderId == null || _isSubmitting) return;
    final bidAmount = _parseBidAmount(_bidAmountController.text);
    if (bidAmount <= 0) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'Gecerli bir teklif tutari gir.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .submitTenderBid(
          tenderId: widget.tenderId!,
          bidAmount: bidAmount,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: (result['message'] ?? 'Teklif kaydedildi.').toString(),
        type: SnackbarType.success,
      );
      _syncBidInput(detail, force: true);
      await _refresh();
      return;
    }
    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'Teklif verilemedi.').toString(),
      type: SnackbarType.error,
    );
  }

  Future<void> _acceptTender(TenderDetailModel detail) async {
    if (widget.tenderId == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .acceptTender(widget.tenderId!);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: (result['message'] ?? 'Ihale kabul edildi.').toString(),
        type: SnackbarType.success,
      );
      final playerTenderId = (result['player_tender_id'] ?? '').toString();
      if (playerTenderId.isNotEmpty) {
        context.go('/tenders/player/$playerTenderId');
      } else {
        await _refresh();
      }
      return;
    }
    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'Ihale kabul edilemedi.').toString(),
      type: SnackbarType.error,
    );
  }

  Future<void> _startDelivery(TenderDetailModel detail) async {
    final playerTender = detail.playerTender;
    final warehouse = _selectedWarehouse(detail);
    if (playerTender == null || warehouse == null || _selectedQuantity <= 0) {
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .startTenderDelivery(
          playerTenderId: playerTender.id,
          warehouseId: warehouse.warehouseId,
          vehicleId: warehouse.sameCity ? null : _selectedVehicleId,
          quantity: _selectedQuantity,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      final finishAt = DateTime.tryParse((result['finish_at'] ?? '').toString());
      final etaMinutes = (result['estimated_duration_minutes'] as num?)?.toInt();
      final etaText = etaMinutes == null
          ? 'Teslimat yola cikti.'
          : 'Teslimat yola cikti. Tahmini varis: ${_formatDateTime(finishAt)} (${_formatDurationMinutes(etaMinutes)}).';
      AppSnackbar.show(
        context,
        title: 'Teslimat Basladi',
        message: etaText,
        type: SnackbarType.success,
      );
      await _refresh();
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'Teslimat baslatilamadi.').toString(),
      type: SnackbarType.error,
    );
  }

  Future<void> _cancelTender(TenderDetailModel detail) async {
    final playerTender = detail.playerTender;
    if (playerTender == null || _isSubmitting) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Ihaleyi Iptal Et'),
          content: const Text(
            'Teminat yanacak ve yoldaki sevkiyatlar da kaybedilecek. Devam etmek istiyor musun?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Iptal Et'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(tenderActionProvider)
        .cancelPlayerTender(playerTender.id);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Ihale Iptal Edildi',
        message:
            (result['message'] ??
                    'Ihale iptal edildi. Teminat ve yoldaki sevkiyat yandi.')
                .toString(),
        type: SnackbarType.warning,
      );
      await _refresh();
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: (result['message'] ?? 'Ihale iptal edilemedi.').toString(),
      type: SnackbarType.error,
    );
  }

  TenderWarehouseOptionModel? _selectedWarehouse(TenderDetailModel detail) {
    if (detail.warehouseOptions.isEmpty) return null;
    if (_selectedWarehouseId != null) {
      for (final item in detail.warehouseOptions) {
        if (item.warehouseId == _selectedWarehouseId) {
          return item;
        }
      }
    }
    return detail.warehouseOptions.first;
  }

  void _syncSelection(TenderDetailModel detail) {
    final warehouse = _selectedWarehouse(detail);
    if (warehouse == null) {
      _selectedWarehouseId = null;
      _selectedVehicleId = null;
      _selectedQuantity = 0;
      return;
    }

    final maxQuantity = _resolveMaxQuantity(detail, warehouse);
    if (_selectedWarehouseId != warehouse.warehouseId) {
      _selectedWarehouseId = warehouse.warehouseId;
      _selectedVehicleId = null;
      _selectedQuantity = maxQuantity > 0 ? maxQuantity : 0;
      return;
    }

    if (_selectedQuantity > maxQuantity) {
      _selectedQuantity = maxQuantity;
    }
  }

  int _resolveMaxQuantity(
    TenderDetailModel detail,
    TenderWarehouseOptionModel warehouse,
  ) {
    final remaining = detail.playerTender?.remainingQuantity ?? 0;
    return warehouse.availableQuantity < remaining
        ? warehouse.availableQuantity
        : remaining;
  }

  double _resolveSelectedTransferVolume(TenderDetailModel detail) {
    final unitVolume = detail.tender.productUnitVolume > 0
        ? detail.tender.productUnitVolume
        : 1.0;
    return _selectedQuantity * unitVolume;
  }

  double _parseBidAmount(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  void _syncBidInput(TenderDetailModel detail, {bool force = false}) {
    if (_isPlayerTender) return;
    final desiredValue = ((detail.playerBid?.bidAmount ?? detail.tender.rewardCash)
            .round())
        .toString();
    if (force || _bidAmountController.text.trim().isEmpty) {
      _bidAmountController.value = TextEditingValue(
        text: desiredValue,
        selection: TextSelection.collapsed(offset: desiredValue.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = _isPlayerTender
        ? ref.watch(playerTenderDetailProvider(widget.playerTenderId!))
        : ref.watch(tenderDetailProvider(widget.tenderId!));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Ihale Detayi'),
            Expanded(
              child: detailAsync.when(
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                        fontSize: AppTypography.body,
                      ),
                    ),
                  ),
                ),
                data: (detail) {
                  _syncSelection(detail);
                  _syncBidInput(detail);
                  final selectedWarehouse = _selectedWarehouse(detail);
                  final playerTender = detail.playerTender;
                  final hasPlayerTender = playerTender != null;
                  final isActiveTender = _isTenderStillActive(detail);
                  final requiredQuantity = playerTender?.requiredQuantity ?? 0;
                  final committedQuantity =
                      (playerTender?.deliveredQuantity ?? 0) +
                      (playerTender?.inTransitQuantity ?? 0);
                  final vehicleOptionsRequest =
                      selectedWarehouse == null ||
                          selectedWarehouse.sameCity ||
                          _selectedQuantity <= 0
                      ? null
                      : TenderVehicleOptionsRequest(
                          sourceCityId: selectedWarehouse.cityId,
                          targetCityId: detail.tender.cityId,
                          totalVolume: _resolveSelectedTransferVolume(detail),
                        );
                  final vehicleOptionsAsync = vehicleOptionsRequest == null
                      ? null
                      : ref.watch(tenderVehicleOptionsProvider(vehicleOptionsRequest));
                  final progress =
                      playerTender == null || requiredQuantity <= 0
                          ? 0.0
                          : (committedQuantity / requiredQuantity)
                                .clamp(0, 1)
                                .toDouble();

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
                      children: [
                        _TenderHeroCard(
                          detail: detail,
                          isOpenTenderView: !_isPlayerTender,
                        ),
                        if (hasPlayerTender) ...[
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: AppDecorations.premiumCard(
                              AppColors.blue,
                              16.r,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Teslimat Durumu',
                                        style: AppTextStyles.title.standardCopyWith(
                                          color: AppColors.white,
                                          fontSize: AppTypography.bodyLarge,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '%${(progress * 100).round()}',
                                      style: AppTextStyles.label.standardCopyWith(
                                        color: AppColors.goldLight,
                                        fontSize: AppTypography.bodySmall,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999.r),
                                  child: AppProgressBar(
                                    value: progress,
                                    minHeight: 10.h,
                                    backgroundColor: AppFx.softOverlay(0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.gold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailMetric(
                                        label: 'Teslim',
                                        value:
                                            '${playerTender.deliveredQuantity} adet',
                                        color: AppColors.green,
                                      ),
                                    ),
                                    Expanded(
                                      child: _DetailMetric(
                                        label: 'Yolda',
                                        value:
                                            '${playerTender.inTransitQuantity} adet',
                                        color: AppColors.blue,
                                      ),
                                    ),
                                    Expanded(
                                      child: _DetailMetric(
                                        label: 'Kalan',
                                        value:
                                            '${playerTender.remainingQuantity} adet',
                                        color: AppColors.gold,
                                      ),
                                    ),
                                    Expanded(
                                      child: _DetailMetric(
                                        label: 'Son Tarih',
                                        value: _formatDateTime(playerTender.deadlineAt),
                                        color: AppColors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (detail.activeDeliveries.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          _ActiveDeliveriesCard(
                            deliveries: detail.activeDeliveries,
                          ),
                        ],
                        SizedBox(height: 12.h),
                        if (_isPlayerTender && hasPlayerTender) ...[
                          if (!isActiveTender) ...[
                            _ClosedTenderStateCard(detail: detail),
                            SizedBox(height: 12.h),
                          ],
                        ],
                        if (_isPlayerTender && hasPlayerTender && isActiveTender) ...[
                          Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: AppDecorations.premiumCard(AppColors.borderGoldLight, 18.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sevkiyat Hazırlığı',
                                  style: AppTextStyles.title.standardCopyWith(
                                    color: AppColors.white,
                                    fontSize: AppTypography.title,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                _WarehouseSelectionCard(
                                  detail: detail,
                                  selectedWarehouseId: _selectedWarehouseId,
                                  onSelected: (warehouseId) {
                                    setState(() {
                                      _selectedWarehouseId = warehouseId;
                                      _selectedVehicleId = null;
                                      _syncSelection(detail);
                                    });
                                  },
                                ),
                                if (selectedWarehouse != null) ...[
                                  if (!selectedWarehouse.sameCity) ...[
                                    SizedBox(height: 14.h),
                                    Divider(color: AppFx.softOverlay(0.10), height: 1),
                                    SizedBox(height: 14.h),
                                    _VehicleSelectionCard(
                                      optionsAsync: vehicleOptionsAsync,
                                      selectedVehicleId: _selectedVehicleId,
                                      onSelected: (vehicleId) {
                                        setState(() {
                                          _selectedVehicleId = vehicleId;
                                        });
                                      },
                                    ),
                                  ],
                                  SizedBox(height: 14.h),
                                  Divider(color: AppFx.softOverlay(0.10), height: 1),
                                  SizedBox(height: 14.h),
                                  _QuantityCard(
                                    quantity: _selectedQuantity,
                                    maxQuantity: _resolveMaxQuantity(
                                      detail,
                                      selectedWarehouse,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedQuantity = value;
                                        _selectedVehicleId = null;
                                      });
                                    },
                                  ),
                                  if (_selectedQuantity > 0) ...[
                                    SizedBox(height: 14.h),
                                    Builder(
                                      builder: (context) {
                                        double transportCost = 0.0;
                                        if (!selectedWarehouse.sameCity &&
                                            _selectedVehicleId != null &&
                                            vehicleOptionsAsync != null) {
                                          vehicleOptionsAsync.whenData((result) {
                                            for (final opt in result.options) {
                                              if (opt.vehicleId == _selectedVehicleId) {
                                                transportCost = opt.transportCost;
                                              }
                                            }
                                          });
                                        }
                                        final totalRequired = detail.playerTender?.requiredQuantity ??
                                            detail.tender.requiredQuantity;
                                        final totalReward = detail.tender.rewardCash;
                                        final unitReward = totalRequired > 0
                                            ? (totalReward / totalRequired)
                                            : 0.0;
                                        final double realUnitCost = selectedWarehouse.unitCost > 0
                                            ? selectedWarehouse.unitCost
                                            : (detail.tender.productBasePrice > 0
                                                ? detail.tender.productBasePrice
                                                : 0.0);
                                        final bool isCostEstimated = realUnitCost <= 0;

                                        return _DeliveryProfitCalculator(
                                          quantity: _selectedQuantity,
                                          unitRewardCash: unitReward,
                                          unitCost: isCostEstimated ? (unitReward * 0.60) : realUnitCost,
                                          isCostEstimated: isCostEstimated,
                                          sameCity: selectedWarehouse.sameCity,
                                          transportCost: transportCost,
                                        );
                                      },
                                    ),
                                  ],
                                  SizedBox(height: 14.h),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed:
                                          _isSubmitting ||
                                              _selectedQuantity <= 0 ||
                                              selectedWarehouse.availableQuantity <= 0 ||
                                              (!selectedWarehouse.sameCity &&
                                                  (_selectedVehicleId == null ||
                                                      _selectedVehicleId!.isEmpty)) ||
                                              (selectedWarehouse.sameCity &&
                                                  selectedWarehouse.canDeliverBeforeDeadline == false)
                                          ? null
                                          : () => _startDelivery(detail),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.gold,
                                        foregroundColor: AppColors.textOnAccent,
                                        padding: EdgeInsets.symmetric(vertical: 12.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                      ),
                                      icon: _isSubmitting
                                          ? SizedBox(
                                              width: 16.w,
                                              height: 16.w,
                                              child: AppLoadingIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.textOnAccent,
                                              ),
                                            )
                                          : Icon(AppIcons.localShippingRounded),
                                      label: Text(
                                        'Teslimatı Başlat',
                                        style: AppTextStyles.button.standardCopyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10.h),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => _cancelTender(detail),
                                      icon: Icon(
                                        AppIcons.cancelOutlined,
                                        color: AppColors.red,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: AppColors.red),
                                        padding: EdgeInsets.symmetric(vertical: 12.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                      ),
                                      label: Text(
                                        'İhaleyi İptal Et',
                                        style: AppTextStyles.button.standardCopyWith(color: AppColors.red, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (_isPlayerTender && !hasPlayerTender) ...[
                          _MissingPlayerTenderCard(),
                          SizedBox(height: 12.h),
                        ] else if (!_isPlayerTender) ...[
                          detail.tender.awardType == 'first_claim'
                              ? _FirstClaimActionCard(
                                  detail: detail,
                                  isSubmitting: _isSubmitting,
                                  onAccept: () => _acceptTender(detail),
                                )
                              : _BidActionCard(
                                  controller: _bidAmountController,
                                  detail: detail,
                                  isSubmitting: _isSubmitting,
                                  onSubmit: () => _submitBid(detail),
                                ),
                        ],
                      ],
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
}

class _TenderHeroCard extends StatelessWidget {
  const _TenderHeroCard({
    required this.detail,
    required this.isOpenTenderView,
  });

  final TenderDetailModel detail;
  final bool isOpenTenderView;

  @override
  Widget build(BuildContext context) {
    final tender = detail.tender;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: AppDecorations.glowingAction(AppColors.gold, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74.w,
                height: 74.w,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppFx.softOverlay(0.08),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.24),
                  ),
                ),
                child: CachedAssetImage(
                  fileName: tender.productIcon,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tender.title,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.white,
                        fontSize: AppTypography.titleLarge,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${tender.cityName} • ${tender.productName}',
                      style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.bodySmall),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _HeroPill(
                          text: tender.awardType == 'first_claim'
                              ? 'İlk Alan Kazanır'
                              : 'En Düşük Teklif',
                          color: tender.awardType == 'first_claim'
                              ? AppColors.goldLight
                              : AppColors.green,
                        ),
                        _HeroPill(
                          text: '${tender.requiredQuantity} adet',
                          color: AppColors.gold,
                        ),
                        _HeroPill(
                          text: 'Kalite ${tender.qualityLevel}',
                          color: AppColors.green,
                        ),
                        _HeroPill(
                          text: '${tender.deliveryDurationMinutes} dk süre',
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tender.description.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              tender.description,
              style: AppTextStyles.body.standardCopyWith(
                fontSize: AppTypography.bodySmall,
                color: AppColors.textPrimary.withValues(alpha: 0.82),
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: isOpenTenderView ? 'Tavan Ödül' : 'Ödül',
                  value: AppMoney.full(tender.rewardCash),
                  color: AppColors.green,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: 'Teminat',
                  value: AppMoney.full(tender.bondAmount),
                  color: AppColors.red,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: 'Son Kabul',
                  value: _formatDateTime(tender.acceptUntil),
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BidActionCard extends StatelessWidget {
  const _BidActionCard({
    required this.controller,
    required this.detail,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final TenderDetailModel detail;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tender = detail.tender;
    final playerBid = detail.playerBid;
    final totalStock = detail.warehouseOptions.fold<int>(
      0,
      (sum, item) => sum + item.availableQuantity,
    );
    final hasEnough = totalStock >= tender.requiredQuantity;
    final diff = (tender.requiredQuantity - totalStock).abs();

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.green, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teklif Ver',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.white,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'En düşük geçerli teklif kazanır. Teminat ilk teklifinizde kasanızdan ayrılır, kazanamazsanız eksiksiz iade edilir.',
            style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
          ),
          SizedBox(height: 10.h),
          // Depo Mevcut Stok Durumu Özeti
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: (hasEnough ? AppColors.green : AppColors.warning).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: (hasEnough ? AppColors.green : AppColors.warning).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasEnough ? AppIcons.checkCircleRounded : AppIcons.warningAmberRounded,
                  size: AppIconSizes.compact,
                  color: hasEnough ? AppColors.green : AppColors.warning,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Depolarınızdaki Toplam Stok: $totalStock adet',
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.white,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        hasEnough
                            ? 'İhale teslimatı için yeterli stoğunuz var.'
                            : 'İhale için $diff adet daha temin etmeniz gerekiyor.',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: hasEnough ? AppColors.green : AppColors.warning,
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
          SizedBox(height: 10.h),
          if (playerBid != null) ...[
            Row(
              children: [
                Expanded(
                  child: _DetailMetric(
                    label: 'Teklifin',
                    value: AppMoney.full(playerBid.bidAmount),
                    color: AppColors.gold,
                  ),
                ),
                Expanded(
                  child: _DetailMetric(
                    label: 'Bağlanan Teminat',
                    value: AppMoney.full(playerBid.bondPaid),
                    color: AppColors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
          ],
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: 'Teklif Tutarı',
              hintText: tender.rewardCash.round().toString(),
              helperText:
                  'Tavan ödül: ${AppMoney.full(tender.rewardCash)}',
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: AppLoadingIndicator(strokeWidth: 2),
                    )
                  : Icon(AppIcons.gavelRounded),
              label: Text(playerBid == null ? 'Teklif Ver' : 'Teklifi Güncelle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstClaimActionCard extends StatelessWidget {
  const _FirstClaimActionCard({
    required this.detail,
    required this.isSubmitting,
    required this.onAccept,
  });

  final TenderDetailModel detail;
  final bool isSubmitting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final tender = detail.tender;
    final totalStock = detail.warehouseOptions.fold<int>(
      0,
      (sum, item) => sum + item.availableQuantity,
    );
    final hasEnough = totalStock >= tender.requiredQuantity;
    final diff = (tender.requiredQuantity - totalStock).abs();

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.gold, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anlık Alım İhalesi',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Bu ihalede ilk kabul eden kazanır. Teminat kabul anında kesilir ve ihale derhal şirketinize atanır.',
            style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
          ),
          SizedBox(height: 10.h),
          // Depo Mevcut Stok Durumu Özeti
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: (hasEnough ? AppColors.green : AppColors.warning).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: (hasEnough ? AppColors.green : AppColors.warning).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasEnough ? AppIcons.checkCircleRounded : AppIcons.warningAmberRounded,
                  size: AppIconSizes.compact,
                  color: hasEnough ? AppColors.green : AppColors.warning,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Depolarınızdaki Toplam Stok: $totalStock adet',
                        style: AppTextStyles.label.standardCopyWith(
                          color: AppColors.white,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        hasEnough
                            ? 'İhale teslimatı için yeterli stoğunuz var.'
                            : 'İhale için $diff adet daha temin etmeniz gerekiyor.',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: hasEnough ? AppColors.green : AppColors.warning,
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
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  label: 'Ödül',
                  value: AppMoney.full(tender.rewardCash),
                  color: AppColors.green,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  label: 'Teminat',
                  value: AppMoney.full(tender.bondAmount),
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : onAccept,
              icon: isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: AppLoadingIndicator(strokeWidth: 2),
                    )
                  : Icon(AppIcons.flashOnRounded),
              label: const Text('İhaleyi Hemen Al'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseSelectionCard extends StatelessWidget {
  const _WarehouseSelectionCard({
    required this.detail,
    required this.selectedWarehouseId,
    required this.onSelected,
  });

  final TenderDetailModel detail;
  final String? selectedWarehouseId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (detail.warehouseOptions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(18.w),
        decoration: AppDecorations.premiumCard(AppColors.red, 16.r),
        child: Column(
          children: [
            Icon(AppIcons.inventory2Outlined, color: AppColors.red, size: AppIconSizes.xLarge),
            SizedBox(height: 10.h),
            Text(
              'Uygun Stok Bulunamadı',
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Bu ihalenin ürününü barındıran herhangi bir deponuz bulunmuyor.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.bodySmall),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.blue, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kaynak Depo Seç',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          ...detail.warehouseOptions.map((warehouse) {
            final isSelected = warehouse.warehouseId == selectedWarehouseId;
            final canDeliver = warehouse.sameCity
                ? (warehouse.canDeliverBeforeDeadline ?? true)
                : null;
            final accent = canDeliver == false
                ? AppColors.red
                : (warehouse.recommended ? AppColors.gold : AppColors.blue);
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: () => onSelected(warehouse.warehouseId),
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isSelected ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: accent.withValues(alpha: isSelected ? 0.42 : 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                warehouse.warehouseName,
                                style: AppTextStyles.title.standardCopyWith(
                                  color: AppColors.white,
                                  fontSize: AppTypography.body,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                '${warehouse.cityName} • ${warehouse.availableQuantity} adet hazır',
                                style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
                              ),
                              SizedBox(height: 6.h),
                              Wrap(
                                spacing: 6.w,
                                runSpacing: 6.h,
                                children: [
                                  _HeroPill(
                                    text: warehouse.sameCity
                                        ? 'Aynı Şehir'
                                        : '${warehouse.distanceKm.toStringAsFixed(0)} km',
                                    color: warehouse.sameCity
                                        ? AppColors.green
                                        : AppColors.blue,
                                  ),
                                  if (warehouse.sameCity &&
                                      warehouse.estimatedDurationMinutes != null)
                                    _HeroPill(
                                      text: _formatDurationMinutes(
                                        warehouse.estimatedDurationMinutes!,
                                      ),
                                      color: AppColors.goldLight,
                                    ),
                                  if (!warehouse.sameCity)
                                    _HeroPill(
                                      text: 'Süre araca bağlı',
                                      color: AppColors.goldLight,
                                    ),
                                  _HeroPill(
                                    text: warehouse.sameCity
                                        ? (canDeliver == false
                                              ? 'Geç Kalır'
                                              : 'Yetişir')
                                        : 'Araç seçimi belirler',
                                    color: warehouse.sameCity
                                        ? (canDeliver == false
                                              ? AppColors.red
                                              : AppColors.green)
                                        : AppColors.blue,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          isSelected
                              ? AppIcons.radioButtonCheckedRounded
                              : AppIcons.radioButtonOffRounded,
                          color: accent,
                          size: AppIconSizes.regular,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuantityCard extends StatelessWidget {
  const _QuantityCard({
    required this.quantity,
    required this.maxQuantity,
    required this.onChanged,
  });

  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeMax = maxQuantity < 0 ? 0 : maxQuantity;
    final progress = safeMax <= 0 ? 0.0 : (quantity / safeMax).clamp(0, 1).toDouble();

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.gold, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gonderilecek Adet',
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.white,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$quantity / $safeMax',
                style: AppTextStyles.label.standardCopyWith(
                  color: AppColors.goldLight,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: AppProgressBar(
              value: progress,
              minHeight: 10.h,
              backgroundColor: AppFx.softOverlay(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: safeMax <= 0 ? null : () => onChanged(safeMax),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.gold, width: 1.w),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'Tamamı',
                style: AppTextStyles.button.standardCopyWith(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleSelectionCard extends StatelessWidget {
  const _VehicleSelectionCard({
    required this.optionsAsync,
    required this.selectedVehicleId,
    required this.onSelected,
  });

  final AsyncValue<TransferVehicleOptionsResult<TenderVehicleOptionModel>>?
  optionsAsync;
  final String? selectedVehicleId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final asyncValue = optionsAsync;
    if (asyncValue == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.blue, 16.r),
      child: asyncValue.when(
        loading: () => SizedBox(
          height: 72.h,
          child: Center(
            child: AppLoadingIndicator(color: AppColors.gold),
          ),
        ),
        error: (error, _) => Text(
          error.toString(),
          style: AppTextStyles.label.standardCopyWith(
            color: AppColors.red,
            fontSize: AppTypography.bodySmall,
          ),
        ),
        data: (result) {
          if (result.options.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Araç Seçimi',
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.white,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  result.unavailableReason ?? 'Bu rota için uygun araç bulunamadı.',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.red,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Araç Seçimi',
                style: AppTextStyles.title.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodyLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Şehirler arası teslimatta varış süresi ve lojistik maliyeti seçilen araca göre hesaplanır.',
                style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
              ),
              SizedBox(height: 10.h),
              ...result.options.map((option) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: TransferVehicleOptionCard(
                    vehicleName: option.vehicleName,
                    isRental: option.isRental,
                    capacity: option.capacity,
                    speedKmh: option.speedKmh,
                    distanceKm: option.distanceKm,
                    durationLabel: _formatDurationSeconds(
                      option.estimatedDurationSeconds,
                    ),
                    transportCost: option.transportCost,
                    rentalCost: option.rentalCost,
                    fuelCost: option.fuelCost,
                    fuelNeeded: option.fuelNeeded,
                    conditionNeeded: option.conditionNeeded,
                    canSelect: option.canSelect,
                    isSelected: option.vehicleId == selectedVehicleId,
                    disabledReason: option.disabledReason,
                    onTap: () => onSelected(option.vehicleId),
                  ),
                );
              }),
              if (selectedVehicleId != null) ...[
                SizedBox(height: 4.h),
                Text(
                  'Nakliye bedeli teslimat yola çıktığında kasanızdan kesilir.',
                  style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ActiveDeliveriesCard extends ConsumerWidget {
  const _ActiveDeliveriesCard({required this.deliveries});

  final List<TenderActiveDeliveryModel> deliveries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.green, 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yoldaki Teslimatlar',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.white,
              fontSize: AppTypography.bodyLarge,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          ...deliveries.map((delivery) {
            final remaining =
                (delivery.finishAt ?? now).difference(now);
            final isDone = remaining.inSeconds <= 0;
            final progress = _buildDeliveryProgress(
              now: now,
              startedAt: delivery.startedAt,
              finishAt: delivery.finishAt,
            );
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppFx.softOverlay(0.04),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppFx.softOverlay(0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34.w,
                    height: 34.w,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      AppIcons.localShippingRounded,
                      color: AppColors.green,
                      size: AppIconSizes.regular,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${delivery.sourceWarehouseName} • ${delivery.quantity} adet',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.white,
                            fontSize: AppTypography.bodySmall,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          '${delivery.sourceCityName} ➔ Varış: ${_formatDateTime(delivery.finishAt)}',
                          style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          isDone
                              ? 'Teslim ediliyor...'
                              : 'Kalan Süre: ${_formatLiveCountdown(remaining)}',
                          style: AppTextStyles.label.standardCopyWith(
                            color: AppColors.goldLight,
                            fontSize: AppTypography.label,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: AppProgressBar(
                            value: progress,
                            minHeight: 7.h,
                            backgroundColor: AppFx.softOverlay(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeroPill(
                    text: delivery.sameCity ? 'Kısa Hat' : 'Uzun Hat',
                    color: delivery.sameCity
                        ? AppColors.green
                        : AppColors.goldLight,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            style: AppTextStyles.label.standardCopyWith(
              color: color,
              fontSize: AppTypography.bodySmall,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month $hour:$minute';
}

String _formatDurationMinutes(int minutes) {
  if (minutes <= 0) return '0 dk';
  if (minutes < 60) return '$minutes dk';
  final hours = minutes ~/ 60;
  final remainMinutes = minutes % 60;
  if (remainMinutes == 0) return '${hours}s';
  return '${hours}s ${remainMinutes}dk';
}

String _formatDurationSeconds(int seconds) {
  if (seconds <= 0) return '0 dk';
  return _formatDurationMinutes((seconds / 60).ceil());
}

String _formatLiveCountdown(Duration remaining) {
  if (remaining.inSeconds <= 0) return '00:00:00';
  final safe = remaining.isNegative ? Duration.zero : remaining;
  final hours = safe.inHours.toString().padLeft(2, '0');
  final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

double _buildDeliveryProgress({
  required DateTime now,
  required DateTime? startedAt,
  required DateTime? finishAt,
}) {
  if (startedAt == null || finishAt == null) return 0;
  final totalSeconds = finishAt.difference(startedAt).inSeconds;
  if (totalSeconds <= 0) return 1;
  final elapsedSeconds = now.difference(startedAt).inSeconds.clamp(0, totalSeconds);
  return (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
}

class _ClosedTenderStateCard extends StatelessWidget {
  const _ClosedTenderStateCard({required this.detail});

  final TenderDetailModel detail;

  @override
  Widget build(BuildContext context) {
    final playerTender = detail.playerTender;
    if (playerTender == null) {
      return const _MissingPlayerTenderCard();
    }

    final isCompleted = playerTender.status == 'completed';
    final isCancelled = playerTender.status == 'cancelled';
    final accent = isCompleted ? AppColors.green : AppColors.red;
    final title = isCompleted
        ? 'İhale Tamamlandı'
        : isCancelled
        ? 'İhale İptal Edildi'
        : 'İhale Sonuçlandı';
    final message = isCompleted
        ? 'Bu ihale başarıyla kapandı. Şirketiniz taahhüdü başarıyla tamamladı.'
        : isCancelled
        ? 'Bu ihaleyi siz iptal ettiniz. Teminat ve yoldaki sevkiyatlar kaybedildi.'
        : 'Bu ihale aktif değil. Süre aşımı veya kapanış nedeniyle teslimat kabul edilmiyor.';

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(accent, 16.r),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(
              isCompleted ? AppIcons.checkCircleRounded : AppIcons.warningAmberRounded,
              color: accent,
              size: AppIconSizes.medium,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.white,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  message,
                  style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingPlayerTenderCard extends StatelessWidget {
  const _MissingPlayerTenderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(AppColors.red, 16.r),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              AppIcons.infoOutlineRounded,
              color: AppColors.red,
              size: AppIconSizes.medium,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İhale Kaydı Bulunamadı',
                  style: AppTextStyles.title.standardCopyWith(
                    color: AppColors.white,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Bu ihalenin oyuncu kaydı şu anda yüklenemedi. Listeyi yenileyip tekrar deneyebilirsiniz.',
                  style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryProfitCalculator extends StatelessWidget {
  const _DeliveryProfitCalculator({
    required this.quantity,
    required this.unitRewardCash,
    required this.unitCost,
    required this.isCostEstimated,
    required this.sameCity,
    required this.transportCost,
  });

  final int quantity;
  final double unitRewardCash;
  final double unitCost;
  final bool isCostEstimated;
  final bool sameCity;
  final double transportCost;

  @override
  Widget build(BuildContext context) {
    if (quantity <= 0) return const SizedBox.shrink();

    final totalProdCost = quantity * unitCost;
    final totalCost = totalProdCost + transportCost;
    final estRevenue = quantity * unitRewardCash;
    final netProfit = estRevenue - totalCost;
    final isProfitable = netProfit > 0;
    final profitMargin = estRevenue > 0 ? (netProfit / estRevenue * 100) : 0.0;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.25),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: (isProfitable ? AppColors.green : AppColors.red).withValues(alpha: 0.3),
          width: 1.2.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sevkiyat Maliyet & Kâr Analizi (Tahmini)',
            style: AppTextStyles.title.standardCopyWith(
              color: AppColors.gold,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isCostEstimated ? 'Tahmini Ürün Maliyeti (Est. %60):' : 'Gerçek Ürün Maliyeti:',
                style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
              ),
              Text(
                AppMoney.full(totalProdCost),
                style: AppTextStyles.label.standardCopyWith(
                  color: AppColors.white,
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sevkiyat Yol Bedeli (Lojistik):',
                style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
              ),
              Text(
                sameCity ? 'Ücretsiz (Aynı Şehir)' : AppMoney.full(transportCost),
                style: AppTextStyles.label.standardCopyWith(
                  color: sameCity ? AppColors.green : AppColors.white,
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Divider(color: AppFx.softOverlay(0.10)),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Oransal Hak Ediş Geliri:',
                style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
              ),
              Text(
                AppMoney.full(estRevenue),
                style: AppTextStyles.label.standardCopyWith(
                  color: AppColors.white,
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tahmini Net Kâr / Zarar:',
                style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.label),
              ),
              Text(
                '${isProfitable ? '+' : ''}${AppMoney.full(netProfit)} (${profitMargin.toStringAsFixed(1)}%)',
                style: AppTextStyles.body.standardCopyWith(
                  color: isProfitable ? AppColors.green : AppColors.red,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
